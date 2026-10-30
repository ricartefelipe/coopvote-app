import 'dart:convert';

import 'package:coopvote_app/screen_flow/screen_api.dart';
import 'package:coopvote_app/screen_flow/screen_controller.dart';
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
  const agendaId = '2285cfba-09c4-4687-8113-c133dff61f30';
  final entry = Uri.parse('https://api.example.test/api/v1/mobile');
  final voteAction = ScreenAction(
    text: 'Sim',
    url: Uri.parse(
      'https://api.example.test/api/v1/mobile/agendas/$agendaId/votes',
    ),
    body: const {'vote': 'Sim'},
  );
  String actionsScreen() =>
      jsonEncode({'tipo': 'SELECAO', 'titulo': 'Pauta', 'itens': <Object?>[]});

  test('timeout no voto consulta o recibo antes de repetir: voto já registrado não é reenviado', () async {
    final posts = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/votes')) {
        posts.add(request.url.path);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (request.url.path.endsWith('/votes/me')) {
        return http.Response('{"vote":"Sim"}', 200);
      }
      return http.Response(actionsScreen(), 200);
    });
    final api = ScreenApi(
      origin,
      client: client,
      timeout: const Duration(milliseconds: 5),
    );
    final controller = ScreenController(api, entry);

    await controller.submit(voteAction);
    expect(controller.voteOutcome, VoteOutcome.pending);
    expect(controller.errorMessage, contains('recibo'));

    await controller.retry();
    expect(controller.voteOutcome, VoteOutcome.confirmed);
    expect(posts.length, 1, reason: 'o voto não deve ser reenviado');
    expect(controller.errorMessage, contains('já estava registrado'));
  });

  test('timeout no voto sem recibo libera a repetição', () async {
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/votes')) {
        attempts++;
        if (attempts == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        return http.Response(actionsScreen(), 200);
      }
      if (request.url.path.endsWith('/votes/me')) {
        return http.Response('{"code":"VOTE_NOT_FOUND"}', 404);
      }
      return http.Response(actionsScreen(), 200);
    });
    final api = ScreenApi(
      origin,
      client: client,
      timeout: const Duration(milliseconds: 20),
    );
    final controller = ScreenController(api, entry);

    await controller.submit(voteAction);
    expect(controller.voteOutcome, VoteOutcome.pending);

    // Uma única repetição: confere o recibo (ausente) e só então reenvia.
    await controller.retry();
    expect(attempts, 2);
    expect(controller.voteOutcome, VoteOutcome.none);
    expect(controller.screen, isA<SelectionScreen>());
  });

  test('dois envios simultâneos produzem uma única requisição', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return http.Response(actionsScreen(), 200);
    });
    final controller = ScreenController(
      ScreenApi(origin, client: client),
      entry,
    );

    await Future.wait([
      controller.submit(voteAction),
      controller.submit(voteAction),
    ]);

    expect(calls, 1);
  });

  test('401 encerra a sessão em vez de mostrar um erro genérico', () async {
    var expired = 0;
    final client = MockClient(
      (_) async => http.Response('{"code":"AUTHENTICATION_REQUIRED"}', 401),
    );
    final controller = ScreenController(
      ScreenApi(origin, client: client),
      entry,
      onSessionExpired: () async => expired++,
    );

    await controller.loadInitial();

    expect(expired, 1);
    expect(controller.errorMessage, contains('expirou'));
  });
}
