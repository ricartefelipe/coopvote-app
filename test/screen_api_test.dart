import 'dart:convert';

import 'package:coopvote_app/screen_flow/screen_api.dart';
import 'package:coopvote_app/screen_flow/screen_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('envia POST JSON e interpreta a próxima tela', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
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
    final api = ScreenApi(client: client);

    final screen = await api.post(
      Uri.parse('https://api.example.test/mobile'),
      body: {'title': 'Assembleia'},
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.headers['accept'], 'application/json');
    expect(capturedRequest.headers['content-type'], 'application/json');
    expect(jsonDecode(capturedRequest.body), {'title': 'Assembleia'});
    expect(screen, isA<SelectionScreen>());
  });

  test('preserva o detalhe e o código de uma resposta de erro', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'detail': 'A sessão de votação está encerrada.',
          'code': 'VOTING_SESSION_CLOSED',
        }),
        409,
        headers: {'content-type': 'application/problem+json; charset=utf-8'},
      ),
    );
    final api = ScreenApi(client: client);

    await expectLater(
      api.post(Uri.parse('https://api.example.test/votes')),
      throwsA(
        isA<ScreenRequestException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having((error) => error.code, 'code', 'VOTING_SESSION_CLOSED')
            .having(
              (error) => error.message,
              'message',
              'A sessão de votação está encerrada.',
            ),
      ),
    );
  });

  test('rejeita uma resposta de sucesso fora do protocolo', () async {
    final client = MockClient((_) async => http.Response('não é JSON', 200));
    final api = ScreenApi(client: client);

    await expectLater(
      api.post(Uri.parse('https://api.example.test/mobile')),
      throwsA(isA<ScreenProtocolException>()),
    );
  });

  test(
    'não envia corpo nem content-type quando a ação não possui dados',
    () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'tipo': 'SELECAO',
            'titulo': 'Pautas',
            'itens': <Object?>[],
          }),
          200,
        );
      });
      final api = ScreenApi(client: client);

      await api.post(Uri.parse('https://api.example.test/mobile'));

      expect(capturedRequest.body, isEmpty);
      expect(capturedRequest.headers, isNot(contains('content-type')));
    },
  );

  test('usa mensagem padrão quando o erro não possui JSON', () async {
    final client = MockClient((_) async => http.Response('indisponível', 502));
    final api = ScreenApi(client: client);

    await expectLater(
      api.post(Uri.parse('https://api.example.test/mobile')),
      throwsA(
        isA<ScreenRequestException>().having(
          (error) => error.message,
          'message',
          'A API recusou a operação (502).',
        ),
      ),
    );
  });

  test('rejeita callback com esquema não permitido', () async {
    final api = ScreenApi(
      client: MockClient((_) async => http.Response('', 200)),
    );

    await expectLater(
      api.post(Uri.parse('ftp://api.example.test/mobile')),
      throwsA(isA<ScreenRequestException>()),
    );
  });
}
