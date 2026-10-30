import 'dart:convert';

import 'package:coopvote_app/app.dart';
import 'package:coopvote_app/screen_flow/screen_api.dart';
import 'package:coopvote_app/session/api_origin.dart';
import 'package:coopvote_app/session/auth_api.dart';
import 'package:coopvote_app/session/session_controller.dart';
import 'package:coopvote_app/session/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final entry = Uri.parse('https://api.example.test/api/v1/mobile');
  final origin = ApiOrigin(entry, allowInsecureHttp: false);

  http.Client apiClient(
    List<http.Request> requests, {
    bool firstScreen401 = false,
  }) {
    var screens = 0;
    return MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        final body = jsonDecode(request.body) as Map;
        if (body['password'] != 'segredo') {
          return http.Response('{"code":"INVALID_CREDENTIALS"}', 401);
        }
        return http.Response(
          jsonEncode({
            'tokenType': 'Bearer',
            'accessToken': 'jwt-login',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 30))
                .toIso8601String(),
            'roles': ['VOTER'],
          }),
          200,
        );
      }
      screens++;
      if (firstScreen401 && screens == 1) {
        return http.Response('{"code":"AUTHENTICATION_REQUIRED"}', 401);
      }
      return http.Response(
        jsonEncode({
          'tipo': 'SELECAO',
          'titulo': 'Pautas',
          'itens': <Object?>[],
        }),
        200,
      );
    });
  }

  Widget app(http.Client client, SessionController session) => CoopVoteApp(
    entryUri: entry,
    sessionController: session,
    screenApiFactory: (origin, token) =>
        ScreenApi(origin, client: client, token: token),
  );

  testWidgets(
    'sem sessão mostra o login; senha errada informa; login válido abre o fluxo',
    (tester) async {
      final requests = <http.Request>[];
      final client = apiClient(requests);
      final session = SessionController(
        AuthApi(origin, client: client),
        InMemorySessionStore(),
      );

      await tester.pumpWidget(app(client, session));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login_submit')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Informe o identificador.'), findsOneWidget);
      expect(requests, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('login_associate_id')),
        'associado-1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login_password')),
        'errada',
      );
      await tester.tap(find.byKey(const ValueKey('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Identificador ou senha inválidos.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('login_password')),
        'segredo',
      );
      await tester.tap(find.byKey(const ValueKey('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Pautas'), findsOneWidget);
      final screenRequest = requests.firstWhere(
        (r) => r.url.path == '/api/v1/mobile',
      );
      expect(screenRequest.headers['authorization'], 'Bearer jwt-login');
    },
  );

  testWidgets('401 durante o fluxo volta ao login e não transfere a sessão', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = apiClient(requests, firstScreen401: true);
    final session = SessionController(
      AuthApi(origin, client: client),
      InMemorySessionStore(),
    );

    await tester.pumpWidget(app(client, session));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login_associate_id')),
      'associado-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login_password')),
      'segredo',
    );
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login_submit')), findsOneWidget);
    expect(find.text('Sua sessão expirou. Entre novamente.'), findsOneWidget);
    expect(session.signedIn, isFalse);
  });

  testWidgets('botão Sair encerra a sessão', (tester) async {
    final requests = <http.Request>[];
    final client = apiClient(requests);
    final session = SessionController(
      AuthApi(origin, client: client),
      InMemorySessionStore(),
    );

    await tester.pumpWidget(app(client, session));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login_associate_id')),
      'associado-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login_password')),
      'segredo',
    );
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login_submit')), findsOneWidget);
    expect(session.signedIn, isFalse);
  });

  testWidgets(
    'login e fluxo continuam utilizáveis com fonte ampliada e tela estreita',
    (tester) async {
      final requests = <http.Request>[];
      final client = apiClient(requests);
      final session = SessionController(
        AuthApi(origin, client: client),
        InMemorySessionStore(),
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: app(client, session),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Com fonte dobrada a tela rola; cada campo é trazido à vista antes de usar.
      Future<void> reveal(Key key) => tester.scrollUntilVisible(
        find.byKey(key),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      await reveal(const ValueKey('login_associate_id'));
      await tester.enterText(
        find.byKey(const ValueKey('login_associate_id')),
        'associado-1',
      );
      await reveal(const ValueKey('login_password'));
      await tester.enterText(
        find.byKey(const ValueKey('login_password')),
        'segredo',
      );
      await reveal(const ValueKey('login_submit'));
      await tester.tap(find.byKey(const ValueKey('login_submit')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Pautas'), findsOneWidget);
    },
  );
}
