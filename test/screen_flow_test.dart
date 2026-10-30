import 'dart:convert';

import 'package:coopvote_app/app.dart';
import 'package:coopvote_app/screen_flow/screen_api.dart';
import 'package:coopvote_app/session/api_origin.dart';
import 'package:coopvote_app/session/auth_api.dart';
import 'package:coopvote_app/session/auth_session.dart';
import 'package:coopvote_app/session/session_controller.dart';
import 'package:coopvote_app/session/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Sessão válida já guardada: os testes de fluxo começam autenticados.
Future<SessionController> signedInSession() async {
  final store = InMemorySessionStore();
  await store.write(
    AuthSession(
      accessToken: 'jwt-teste',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      roles: const ['VOTER', 'MANAGER'],
    ),
  );
  final origin = ApiOrigin(
    Uri.parse('https://api.example.test/api/v1/mobile'),
    allowInsecureHttp: false,
  );
  return SessionController(
    AuthApi(origin, client: MockClient((_) async => http.Response('', 500))),
    store,
  );
}

Widget appWith(http.Client client, SessionController session) => CoopVoteApp(
  entryUri: Uri.parse('https://api.example.test/api/v1/mobile'),
  sessionController: session,
  screenApiFactory: (origin, token) =>
      ScreenApi(origin, client: client, token: token),
);

void main() {
  testWidgets('navega por seleção, formulário e callback', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final response = switch (request.url.path) {
        '/api/v1/mobile' => {
          'tipo': 'SELECAO',
          'titulo': 'Pautas',
          'itens': [
            {
              'texto': 'Cadastrar nova pauta',
              'url': 'https://api.example.test/api/v1/mobile/agendas/new',
            },
          ],
        },
        '/api/v1/mobile/agendas/new' => {
          'tipo': 'FORMULARIO',
          'titulo': 'Nova pauta',
          'itens': [
            {'tipo': 'TEXTO', 'texto': 'Informe os dados da pauta.'},
            {'tipo': 'INPUT_TEXTO', 'id': 'title', 'titulo': 'Título'},
            {'tipo': 'INPUT_TEXTO', 'id': 'description', 'titulo': 'Descrição'},
          ],
          'botaoOk': {
            'texto': 'Cadastrar',
            'url': 'https://api.example.test/api/v1/mobile/agendas',
            'body': {'source': 'app'},
          },
          'botaoCancelar': {
            'texto': 'Cancelar',
            'url': 'https://api.example.test/api/v1/mobile',
          },
        },
        '/api/v1/mobile/agendas' => {
          'tipo': 'SELECAO',
          'titulo': 'Pauta criada',
          'itens': <Object?>[],
        },
        _ => throw StateError('Callback inesperado: ${request.url.path}'),
      };
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(appWith(client, await signedInSession()));
    await tester.pumpAndSettle();

    expect(find.text('Pautas'), findsOneWidget);
    await tester.tap(find.text('Cadastrar nova pauta'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('input_title')),
      'Pauta 1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('input_description')),
      'Descrição da pauta',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('Pauta criada'), findsOneWidget);
    expect(find.text('Nenhuma opção disponível.'), findsOneWidget);
    expect(requests, hasLength(3));
    expect(
      requests.every((r) => r.headers['authorization'] == 'Bearer jwt-teste'),
      isTrue,
    );
    expect(requests.last.method, 'POST');
    expect(jsonDecode(requests.last.body), {
      'source': 'app',
      'title': 'Pauta 1',
      'description': 'Descrição da pauta',
    });
  });

  testWidgets('exibe erro da API e permite repetir a requisição', (
    tester,
  ) async {
    var attempts = 0;
    final client = MockClient((_) async {
      attempts++;
      if (attempts == 1) {
        return http.Response(
          jsonEncode({'detail': 'Serviço temporariamente indisponível.'}),
          503,
          headers: {'content-type': 'application/problem+json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({
          'tipo': 'SELECAO',
          'titulo': 'Pautas',
          'itens': <Object?>[],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(appWith(client, await signedInSession()));
    await tester.pumpAndSettle();

    expect(find.text('Serviço temporariamente indisponível.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Pautas'), findsOneWidget);
  });

  testWidgets('preserva a seleção quando um callback falha', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/falha')) {
        return http.Response(
          jsonEncode({'detail': 'Não foi possível concluir a operação.'}),
          409,
          headers: {'content-type': 'application/problem+json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({
          'tipo': 'SELECAO',
          'titulo': 'Pautas',
          'itens': [
            {
              'texto': 'Operação com falha',
              'url': 'https://api.example.test/api/v1/mobile/falha',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(appWith(client, await signedInSession()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operação com falha'));
    await tester.pumpAndSettle();

    expect(find.text('Pautas'), findsOneWidget);
    expect(find.text('Operação com falha'), findsOneWidget);
    expect(find.text('Não foi possível concluir a operação.'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar mensagem'));
    await tester.pump();
    expect(find.text('Não foi possível concluir a operação.'), findsNothing);
  });
}
