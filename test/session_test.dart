import 'dart:convert';

import 'package:coopvote_app/session/api_origin.dart';
import 'package:coopvote_app/session/auth_api.dart';
import 'package:coopvote_app/session/auth_session.dart';
import 'package:coopvote_app/session/session_controller.dart';
import 'package:coopvote_app/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final origin = ApiOrigin(
    Uri.parse('https://api.example.test/api/v1/mobile'),
    allowInsecureHttp: false,
  );
  final now = DateTime.utc(2026, 10, 29, 12);

  AuthApi authApi(http.Client client) => AuthApi(origin, client: client);

  test(
    'login envia credenciais ao endpoint da API e guarda a sessão',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'tokenType': 'Bearer',
            'accessToken': 'jwt-1',
            'expiresAt': '2026-10-29T12:30:00Z',
            'roles': ['VOTER'],
          }),
          200,
        );
      });
      final store = InMemorySessionStore();
      final session = SessionController(authApi(client), store, now: () => now);

      await session.login(' associado-1 ', 'segredo');

      expect(
        captured.url.toString(),
        'https://api.example.test/api/v1/auth/login',
      );
      expect(jsonDecode(captured.body), {
        'associateId': 'associado-1',
        'password': 'segredo',
      });
      expect(session.signedIn, isTrue);
      expect(session.session!.roles, ['VOTER']);
      expect((await store.read())!.accessToken, 'jwt-1');
    },
  );

  test(
    'credencial inválida não cria sessão e informa a causa sem detalhes',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"code":"INVALID_CREDENTIALS"}', 401),
      );
      final session = SessionController(
        authApi(client),
        InMemorySessionStore(),
        now: () => now,
      );

      await session.login('associado-1', 'errada');

      expect(session.signedIn, isFalse);
      expect(session.message, 'Identificador ou senha inválidos.');
    },
  );

  test('sessão expirada guardada é descartada na retomada do app', () async {
    final store = InMemorySessionStore();
    await store.write(
      AuthSession(
        accessToken: 'velho',
        expiresAt: now.subtract(const Duration(minutes: 1)),
        roles: const [],
      ),
    );
    final session = SessionController(
      authApi(MockClient((_) async => http.Response('', 500))),
      store,
      now: () => now,
    );

    await session.restore();

    expect(session.restored, isTrue);
    expect(session.signedIn, isFalse);
    expect(await store.read(), isNull);
    expect(session.message, contains('expirou'));
  });

  test('sessão válida guardada é restaurada e o logout a apaga', () async {
    final store = InMemorySessionStore();
    await store.write(
      AuthSession(
        accessToken: 'ok',
        expiresAt: now.add(const Duration(minutes: 10)),
        roles: const ['MANAGER'],
      ),
    );
    final session = SessionController(
      authApi(MockClient((_) async => http.Response('', 500))),
      store,
      now: () => now,
    );

    await session.restore();
    expect(session.signedIn, isTrue);
    expect(session.session!.canManage, isTrue);

    await session.logout();
    expect(session.signedIn, isFalse);
    expect(await store.read(), isNull);
  });

  test('serialização da sessão ignora dados corrompidos', () {
    expect(AuthSession.fromJson({'accessToken': '', 'expiresAt': 'x'}), isNull);
    expect(AuthSession.fromJson('lixo'), isNull);
    final roundTrip = AuthSession.fromJson(
      AuthSession(
        accessToken: 't',
        expiresAt: now,
        roles: const ['VOTER'],
      ).toJson(),
    );
    expect(roundTrip!.accessToken, 't');
    expect(roundTrip.expiresAt, now);
  });
}
