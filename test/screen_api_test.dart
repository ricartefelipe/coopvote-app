import 'dart:async';
import 'dart:convert';

import 'package:coopvote_app/screen_flow/screen_api.dart';
import 'package:coopvote_app/screen_flow/screen_models.dart';
import 'package:coopvote_app/session/api_origin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final origin = ApiOrigin(
    Uri.parse('https://api.example.test/api/v1/mobile'),
    allowInsecureHttp: false,
  );
  final mobile = Uri.parse('https://api.example.test/api/v1/mobile');

  String screenJson() =>
      jsonEncode({'tipo': 'SELECAO', 'titulo': 'Pautas', 'itens': <Object?>[]});

  test('envia POST JSON com o token e interpreta a próxima tela', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        screenJson(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ScreenApi(origin, client: client, token: () => 'jwt-abc');

    final screen = await api.post(mobile, body: {'title': 'Assembleia'});

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.headers['accept'], 'application/json');
    expect(capturedRequest.headers['content-type'], 'application/json');
    expect(capturedRequest.headers['authorization'], 'Bearer jwt-abc');
    expect(capturedRequest.followRedirects, isFalse);
    expect(jsonDecode(capturedRequest.body), {'title': 'Assembleia'});
    expect(screen, isA<SelectionScreen>());
  });

  test('não envia nada, nem o token, a uma origem diferente da API', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(screenJson(), 200);
    });
    final api = ScreenApi(origin, client: client, token: () => 'jwt-abc');

    for (final url in [
      'https://evil.example/api/v1/mobile',
      'https://api.example.test:8443/api/v1/mobile',
      'http://api.example.test/api/v1/mobile',
      'https://u:p@api.example.test/api/v1/mobile',
      'https://api.example.test/api/v1/auth/login',
    ]) {
      await expectLater(
        api.post(Uri.parse(url)),
        throwsA(isA<ScreenRequestException>()),
      );
    }
    expect(calls, 0);
  });

  test('não segue redirecionamentos', () async {
    final client = MockClient(
      (_) async => http.Response(
        '',
        302,
        headers: {'location': 'https://evil.example/'},
      ),
    );
    final api = ScreenApi(origin, client: client);

    await expectLater(
      api.post(mobile),
      throwsA(
        isA<ScreenRequestException>().having(
          (e) => e.message,
          'message',
          contains('redirecion'),
        ),
      ),
    );
  });

  test('401 vira sessão expirada', () async {
    final client = MockClient(
      (_) async => http.Response('{"code":"AUTHENTICATION_REQUIRED"}', 401),
    );
    final api = ScreenApi(origin, client: client, token: () => 'velho');

    await expectLater(
      api.post(mobile),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('limita o corpo da resposta com e sem Content-Length', () async {
    final huge = '{"tipo":"SELECAO","titulo":"${'x' * 300}","itens":[]}';
    final declared = MockClient((_) async => http.Response(huge, 200));
    final apiDeclared = ScreenApi(origin, client: declared, maxBodyBytes: 100);
    await expectLater(
      apiDeclared.post(mobile),
      throwsA(isA<ScreenProtocolException>()),
    );

    final streaming = MockClient.streaming((request, bodyStream) async {
      final chunks = Stream<List<int>>.fromIterable([
        utf8.encode(huge.substring(0, 150)),
        utf8.encode(huge.substring(150)),
      ]);
      return http.StreamedResponse(chunks, 200);
    });
    final apiStreaming = ScreenApi(
      origin,
      client: streaming,
      maxBodyBytes: 100,
    );
    await expectLater(
      apiStreaming.post(mobile),
      throwsA(isA<ScreenProtocolException>()),
    );
  });

  test('timeout é sinalizado como resultado incerto', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response(screenJson(), 200);
    });
    final api = ScreenApi(
      origin,
      client: client,
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(api.post(mobile), throwsA(isA<ScreenTimeoutException>()));
  });

  test('preserva o detalhe e o código de uma resposta de erro', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'detail': 'Sessão encerrada.',
          'code': 'VOTING_SESSION_CLOSED',
        }),
        409,
      ),
    );
    final api = ScreenApi(origin, client: client);

    await expectLater(
      api.post(mobile),
      throwsA(
        isA<ScreenRequestException>()
            .having((e) => e.message, 'message', 'Sessão encerrada.')
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'VOTING_SESSION_CLOSED'),
      ),
    );
  });

  test(
    'rejeita uma resposta de sucesso fora do protocolo e sem JSON',
    () async {
      final api = ScreenApi(
        origin,
        client: MockClient((_) async => http.Response('{"tipo":"X"}', 200)),
      );
      await expectLater(
        api.post(mobile),
        throwsA(isA<ScreenProtocolException>()),
      );
      final broken = ScreenApi(
        origin,
        client: MockClient((_) async => http.Response('not json', 200)),
      );
      await expectLater(
        broken.post(mobile),
        throwsA(isA<ScreenProtocolException>()),
      );
      final plain = ScreenApi(
        origin,
        client: MockClient((_) async => http.Response('erro', 500)),
      );
      await expectLater(
        plain.post(mobile),
        throwsA(
          isA<ScreenRequestException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    },
  );

  test(
    'identifica o callback de voto e consulta o recibo com o token',
    () async {
      expect(
        ScreenApi.voteAgendaId(
          Uri.parse(
            'https://api.example.test/api/v1/mobile/agendas/2285cfba-09c4-4687-8113-c133dff61f30/votes',
          ),
        ),
        '2285cfba-09c4-4687-8113-c133dff61f30',
      );
      expect(
        ScreenApi.voteAgendaId(
          Uri.parse(
            'https://api.example.test/api/v1/mobile/agendas/x/votes/new',
          ),
        ),
        isNull,
      );

      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          request.url.path.endsWith('/votes/me') ? '{"vote":"Sim"}' : '',
          200,
        );
      });
      final api = ScreenApi(origin, client: client, token: () => 'jwt');
      expect(await api.hasVoteReceipt('abc'), isTrue);
      expect(captured.method, 'GET');
      expect(
        captured.url.toString(),
        'https://api.example.test/api/v1/agendas/abc/votes/me',
      );
      expect(captured.headers['authorization'], 'Bearer jwt');

      final absent = ScreenApi(
        origin,
        client: MockClient(
          (_) async => http.Response('{"code":"VOTE_NOT_FOUND"}', 404),
        ),
      );
      expect(await absent.hasVoteReceipt('abc'), isFalse);
    },
  );
}
