@Tags(['contract'])
library;

import 'dart:io';

import 'package:coopvote_app/screen_flow/screen_api.dart';
import 'package:coopvote_app/screen_flow/screen_models.dart';
import 'package:coopvote_app/session/api_origin.dart';
import 'package:coopvote_app/session/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato real com a CoopVote API (sem mocks). Executa somente com
/// `COOPVOTE_API_URL` (ex.: http://127.0.0.1:8080) apontando para uma API com
/// o seed local (`AUTH_LOCAL_SEED=true`).
void main() {
  final base = Platform.environment['COOPVOTE_API_URL'];
  final password =
      Platform.environment['COOPVOTE_SEED_PASSWORD'] ?? 'coopvote-local';

  test(
    'login, pauta, sessão, voto, recibo e apuração contra a API real',
    () async {
      if (base == null || base.isEmpty) {
        markTestSkipped(
          'COOPVOTE_API_URL não definida: contrato real não executado.',
        );
        return;
      }
      final entry = Uri.parse('$base/api/v1/mobile');
      final origin = ApiOrigin(
        entry,
        allowInsecureHttp: entry.scheme == 'http',
      );
      final auth = AuthApi(origin);
      addTearDown(auth.close);

      await expectLater(
        auth.login('gestora', 'senha-errada'),
        throwsA(isA<AuthException>()),
      );
      final manager = await auth.login('gestora', password);
      final voter = await auth.login('associado-1', password);
      expect(manager.roles, contains('MANAGER'));

      final managerApi = ScreenApi(origin, token: () => manager.accessToken);
      final voterApi = ScreenApi(origin, token: () => voter.accessToken);
      addTearDown(managerApi.close);
      addTearDown(voterApi.close);

      final home = await managerApi.post(entry) as SelectionScreen;
      final newAgenda = home.items.firstWhere(
        (a) => a.text == 'Cadastrar nova pauta',
      );
      final form = await managerApi.post(newAgenda.url) as FormScreen;
      final actions = await managerApi.post(
        form.okButton.url,
        body: form.okButton.payloadWith({
          'title': 'Contrato app ${DateTime.now().millisecondsSinceEpoch}',
        }),
      ) as SelectionScreen;
      final openSession = actions.items.firstWhere(
        (a) => a.text == 'Abrir sessão de votação',
      );
      final sessionForm = await managerApi.post(openSession.url) as FormScreen;
      final opened = await managerApi.post(
        sessionForm.okButton.url,
        body: sessionForm.okButton.payloadWith({'durationMinutes': 5}),
      ) as SelectionScreen;
      final voteAction = opened.items.firstWhere((a) => a.text == 'Votar');
      final agendaId = RegExp(r'/agendas/([0-9a-f-]{36})/')
          .firstMatch(voteAction.url.path)!
          .group(1)!;

      // Eleitor comum não recebe ações de gestão.
      final voterHome = await voterApi.post(entry) as SelectionScreen;
      expect(
        voterHome.items.map((a) => a.text),
        isNot(contains('Cadastrar nova pauta')),
      );

      expect(await voterApi.hasVoteReceipt(agendaId), isFalse);
      final voteForm = await voterApi.post(voteAction.url) as FormScreen;
      expect(
        voteForm.items.whereType<InputFormItem>(),
        isEmpty,
        reason: 'sem campo de identificação',
      );
      final afterVote = await voterApi.post(
        voteForm.okButton.url,
        body: voteForm.okButton.payloadWith({}),
      ) as SelectionScreen;
      expect(
        afterVote.items.map((a) => a.text),
        contains('Consultar resultado'),
      );
      expect(await voterApi.hasVoteReceipt(agendaId), isTrue);

      // Segundo envio: a API recusa com 409; o app não contorna a duplicidade.
      await expectLater(
        voterApi.post(
          voteForm.okButton.url,
          body: voteForm.okButton.payloadWith({}),
        ),
        throwsA(
          isA<ScreenRequestException>().having(
            (e) => e.code,
            'code',
            'DUPLICATE_VOTE',
          ),
        ),
      );

      final result = await voterApi.post(
        afterVote.items.firstWhere((a) => a.text == 'Consultar resultado').url,
      ) as FormScreen;
      final lines = result.items
          .whereType<TextFormItem>()
          .map((i) => i.text)
          .toList();
      expect(lines, contains('Votos Sim: disponível após o encerramento'));

      // Token forjado: 401 vira sessão expirada.
      final forged = ScreenApi(origin, token: () => 'xxx.yyy.zzz');
      addTearDown(forged.close);
      await expectLater(
        forged.post(entry),
        throwsA(isA<SessionExpiredException>()),
      );
    },
  );
}
