// Jornada móvel real: o app de verdade, no emulador/dispositivo, contra a CoopVote API real.
//
// Executa com (ver tool/journey/run.sh):
//   flutter test integration_test/journey_test.dart -d <device>
//     --dart-define=COOPVOTE_ENTRY_URL=http://10.0.2.2:18080/api/v1/mobile
//     --dart-define=COOPVOTE_ALLOW_HTTP=true
//     --dart-define=COOPVOTE_CONTROL_URL=http://10.0.2.2:18099
//
// O servidor de controle (tool/journey/control_server.py) pausa/recria a API real e aciona o
// sistema do dispositivo (HOME, retomada, escala de fonte, captura de tela). Nada é simulado.
import 'dart:async';
import 'dart:convert';

import 'package:coopvote_app/app.dart';
import 'package:coopvote_app/config/app_config.dart';
import 'package:coopvote_app/screen_flow/screen_api.dart';
import 'package:coopvote_app/screen_flow/screen_models.dart';
import 'package:coopvote_app/session/api_origin.dart';
import 'package:coopvote_app/session/auth_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const _controlUrl = String.fromEnvironment('COOPVOTE_CONTROL_URL');
const _password = String.fromEnvironment(
  'COOPVOTE_SEED_PASSWORD',
  defaultValue: 'coopvote-local',
);
const _voteTimeout = Duration(seconds: 15);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jornada 1 a 10 contra a API real', (tester) async {
    expect(_controlUrl, isNotEmpty, reason: 'COOPVOTE_CONTROL_URL ausente');
    final entry = AppConfig.entryUri;
    final origin = ApiOrigin(
      entry,
      allowInsecureHttp: AppConfig.allowInsecureHttp,
    );
    final lifecycle = _LifecycleLog();
    binding.addObserver(lifecycle);
    addTearDown(() => binding.removeObserver(lifecycle));
    addTearDown(() => _control('/device/font-scale?value=1.0'));
    addTearDown(() => _control('/api/recreate?callback=good&secret=keep'));

    // Dados sintéticos criados pela gestora na API real.
    final fixtures = await _Fixtures.create(origin, entry);
    final voterA = await fixtures.auth.login('associado-1', _password);
    var voterApi = ScreenApi(origin, token: () => voterA.accessToken);

    await tester.pumpWidget(CoopVoteApp(entryUri: entry));
    await _waitFor(tester, find.byType(Scaffold));
    if (find.byKey(const ValueKey('logout')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('logout')));
      await _waitFor(tester, find.byKey(const ValueKey('login_submit')));
    }

    _step(1, 'login e lista de pautas');
    await _login(tester, 'associado-1');
    await _waitFor(tester, find.text(fixtures.open.title));
    await _shot('01-pautas');

    _step(
      2,
      'eleitor autorizado; ação de gestão não oferecida e recusada pela API',
    );
    expect(find.text('Cadastrar nova pauta'), findsNothing);
    final forbidden = await http.post(
      origin.resolve('/api/v1/mobile/agendas/new'),
      headers: {'Authorization': 'Bearer ${voterA.accessToken}'},
    );
    expect(forbidden.statusCode, 403, reason: 'gestão com token de eleitor');
    await tester.tap(find.text(fixtures.open.title));
    await _waitFor(tester, find.text('Votar'));
    await _shot('02-acoes-eleitor');

    _step(3, 'voto com recibo confirmado pelo servidor');
    await tester.tap(find.text('Votar'));
    await _waitFor(tester, find.text('Registrar voto'));
    expect(
      find.byType(TextFormField),
      findsNothing,
      reason: 'sem campo de identificação',
    );
    await tester.tap(find.text('Sim'));
    await _waitFor(tester, find.text('Consultar resultado'));
    final receipt = await _receipt(
      origin,
      voterA.accessToken,
      fixtures.open.id,
    );
    expect(receipt.statusCode, 200, reason: 'recibo do servidor');
    _log('recibo: ${receipt.body}');
    await _shot('03-apos-voto');

    _step(4, 'toque duplo não duplica');
    await _goHome(tester);
    await tester.tap(find.text(fixtures.doubleTap.title));
    await _waitFor(tester, find.text('Votar'));
    await tester.tap(find.text('Votar'));
    await _waitFor(tester, find.text('Registrar voto'));
    await tester.tap(find.text('Sim'));
    await tester.tap(find.text('Sim'));
    await _waitFor(tester, find.text('Consultar resultado'));
    expect(
      find.byKey(const ValueKey('retry')),
      findsNothing,
      reason: 'sem erro de duplicidade',
    );
    expect(
      (await _receipt(
        origin,
        voterA.accessToken,
        fixtures.doubleTap.id,
      )).statusCode,
      200,
    );
    await _shot('04-toque-duplo');

    _step(5, 'timeout e reconexão: recibo consultado antes de reenviar');
    // 5a: o voto já existe no servidor quando a resposta se perde → nada é reenviado.
    await voterApi.post(
      origin.resolve(
        '/api/v1/mobile/agendas/${fixtures.timeoutRegistered.id}/votes',
      ),
      body: const {'vote': 'Sim'},
    );
    final registeredBefore = jsonDecode(
      (await _receipt(
        origin,
        voterA.accessToken,
        fixtures.timeoutRegistered.id,
      )).body,
    )['id'];
    await _goHome(tester);
    await _openVoteForm(tester, fixtures.timeoutRegistered.title);
    await _control('/api/pause');
    await tester.tap(find.text('Sim'));
    await _waitFor(
      tester,
      find.text(
        'Sem resposta ao registrar o voto. O recibo será conferido antes de repetir.',
      ),
      timeout: _voteTimeout + const Duration(seconds: 10),
    );
    expect(find.text('Conferir recibo'), findsOneWidget);
    await _shot('05a-timeout');
    await _control('/api/unpause');
    await tester.tap(find.byKey(const ValueKey('retry')));
    await _waitFor(
      tester,
      find.text('Seu voto já estava registrado; nada foi reenviado.'),
    );
    await _shot('05b-recibo-existente');
    // Com o recibo confirmado, "Tentar novamente" só reabre as ações da pauta.
    await tester.tap(find.text('Tentar novamente'));
    await _waitFor(tester, find.text('Consultar resultado'));
    expect(
      jsonDecode(
        (await _receipt(
          origin,
          voterA.accessToken,
          fixtures.timeoutRegistered.id,
        )).body,
      )['id'],
      registeredBefore,
      reason: 'o mesmo recibo de antes do timeout',
    );
    // 5b: sem voto no servidor → um único reenvio após conferir o recibo.
    await _goHome(tester);
    await _openVoteForm(tester, fixtures.timeoutMissing.title);
    await _control('/api/pause');
    await tester.tap(find.text('Sim'));
    await _waitFor(
      tester,
      find.text('Conferir recibo'),
      timeout: _voteTimeout + const Duration(seconds: 10),
    );
    // A API cai antes de processar o que ficou enfileirado durante a pausa.
    await _control('/api/drop');
    expect(
      (await _receipt(
        origin,
        voterA.accessToken,
        fixtures.timeoutMissing.id,
      )).statusCode,
      404,
      reason: 'nenhum voto foi registrado antes da queda',
    );
    await tester.tap(find.byKey(const ValueKey('retry')));
    await _waitFor(tester, find.text('Consultar resultado'));
    expect(
      (await _receipt(
        origin,
        voterA.accessToken,
        fixtures.timeoutMissing.id,
      )).statusCode,
      200,
      reason: 'reenviado uma vez',
    );
    await _shot('05c-reenvio-unico');

    _step(6, 'pausa e retomada pelo sistema');
    await _control('/device/home');
    await Future<void>.delayed(const Duration(seconds: 3));
    await _control('/device/resume');
    await _waitUntil(
      () => lifecycle.states.contains(AppLifecycleState.resumed),
      tester,
    );
    _log(
      'ciclo de vida observado: ${lifecycle.states.map((s) => s.name).join(' → ')}',
    );
    expect(lifecycle.states, contains(AppLifecycleState.paused));
    expect(
      find.text('Consultar resultado'),
      findsOneWidget,
      reason: 'tela preservada',
    );
    await _goHome(tester);
    await _shot('06-retomada');

    _step(
      7,
      'sessão expirada no servidor e troca de conta sem transferir estado',
    );
    await _control('/api/recreate?callback=good&secret=rotate');
    await tester.tap(find.text(fixtures.open.title));
    await _waitFor(tester, find.text('Sua sessão expirou. Entre novamente.'));
    await _shot('07a-sessao-expirada');
    final voterB = await fixtures.auth.login('associado-2', _password);
    voterApi.close();
    voterApi = ScreenApi(origin, token: () => voterB.accessToken);
    await _login(tester, 'associado-2');
    await _waitFor(tester, find.text(fixtures.open.title));
    await tester.tap(find.text(fixtures.open.title));
    await _waitFor(tester, find.text('Votar'));
    expect(
      (await _receipt(origin, voterB.accessToken, fixtures.open.id)).statusCode,
      404,
      reason: 'o voto do associado-1 não é do associado-2',
    );
    await _shot('07b-outra-conta');

    _step(8, 'pauta encerrada pelo horário do servidor');
    await _waitUntil(
      () async =>
          (await fixtures.sessionStatus(origin, fixtures.closed.id)) ==
          'CLOSED',
      tester,
      timeout: const Duration(seconds: 90),
    );
    await _goHome(tester);
    await tester.tap(find.text(fixtures.closed.title));
    await _waitFor(tester, find.text('Voltar às pautas'));
    expect(find.text('Votar'), findsNothing, reason: 'a API não oferece votar');
    await tester.tap(find.text('Consultar resultado'));
    await _waitFor(tester, find.text('Sessão: Encerrada'));
    // Um callback de voto forjado para a pauta encerrada não registra nada: o domínio
    // responde 409 e o fluxo móvel devolve a apuração, sem recibo.
    final closedVote = await http.post(
      origin.resolve('/api/v1/agendas/${fixtures.closed.id}/votes'),
      headers: {
        'Authorization': 'Bearer ${voterB.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'vote': 'Sim'}),
    );
    expect(closedVote.statusCode, 409);
    expect(closedVote.body, contains('VOTING_SESSION_CLOSED'));
    final closedScreen = await voterApi.post(
      origin.resolve('/api/v1/mobile/agendas/${fixtures.closed.id}/votes'),
      body: const {'vote': 'Sim'},
    );
    expect(closedScreen, isA<FormScreen>());
    expect(
      (closedScreen as FormScreen).items.whereType<TextFormItem>().map(
        (i) => i.text,
      ),
      contains('Sessão: Encerrada'),
    );
    expect(
      (await _receipt(
        origin,
        voterB.accessToken,
        fixtures.closed.id,
      )).statusCode,
      404,
    );
    await _shot('08-pauta-encerrada');

    _step(9, 'callback de outra origem recusado sem rede');
    await tester.tap(find.text('Voltar à pauta'));
    await _waitFor(tester, find.text('Voltar às pautas'));
    await _control('/api/recreate?callback=bad&secret=keep');
    await _goHome(tester);
    await tester.tap(find.text(fixtures.open.title));
    await _waitFor(tester, find.text(CallbackRejection.origin.message));
    expect(
      await _control('/hits'),
      '0',
      reason: 'nada chegou à origem estranha',
    );
    await _shot('09-origem-recusada');
    await _control('/api/recreate?callback=good&secret=keep');
    await tester.tap(find.byTooltip('Fechar mensagem'));

    _step(10, 'fonte ampliada pelo sistema e navegação principal');
    await _control('/device/font-scale?value=2.0');
    await _waitUntil(
      () => tester.platformDispatcher.textScaleFactor >= 1.9,
      tester,
    );
    _log('textScaleFactor: ${tester.platformDispatcher.textScaleFactor}');
    // A lista em tela ainda veio da API com callbacks estranhos: sair e entrar de novo
    // percorre a navegação principal (login → pautas → pauta → voltar) com a fonte ampliada.
    await tester.tap(find.byKey(const ValueKey('logout')));
    await _waitFor(tester, find.byKey(const ValueKey('login_submit')));
    await _shot('10a-fonte-ampliada-login');
    expect(tester.takeException(), isNull, reason: 'sem overflow no login');
    await _login(tester, 'associado-2');
    await _waitFor(tester, find.text(fixtures.open.title));
    await _shot('10b-fonte-ampliada-pautas');
    await tester.tap(find.text(fixtures.open.title));
    await _waitFor(tester, find.text('Votar'));
    await _shot('10c-fonte-ampliada-acoes');
    await _goHome(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: 'sem overflow ou erro de layout',
    );
    voterApi.close();
    fixtures.close();
    _log('JORNADA CONCLUÍDA');
  });
}

class _Agenda {
  const _Agenda(this.id, this.title);
  final String id;
  final String title;
}

/// Pautas criadas pela gestora pelas telas da API real.
class _Fixtures {
  _Fixtures._(
    this.auth, {
    required this.open,
    required this.doubleTap,
    required this.timeoutRegistered,
    required this.timeoutMissing,
    required this.closed,
  });

  final AuthApi auth;
  final _Agenda open;
  final _Agenda doubleTap;
  final _Agenda timeoutRegistered;
  final _Agenda timeoutMissing;
  final _Agenda closed;

  static Future<_Fixtures> create(ApiOrigin origin, Uri entry) async {
    final auth = AuthApi(origin);
    final manager = await auth.login('gestora', _password);
    final api = ScreenApi(origin, token: () => manager.accessToken);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    Future<_Agenda> agenda(String name, int minutes) async {
      final home = await api.post(entry) as SelectionScreen;
      final form = await api.post(
        home.items.firstWhere((a) => a.text == 'Cadastrar nova pauta').url,
      ) as FormScreen;
      final title = 'Jornada $name $stamp';
      final actions = await api.post(
        form.okButton.url,
        body: form.okButton.payloadWith({'title': title}),
      ) as SelectionScreen;
      final sessionForm = await api.post(
        actions.items
            .firstWhere((a) => a.text == 'Abrir sessão de votação')
            .url,
      ) as FormScreen;
      final opened = await api.post(
        sessionForm.okButton.url,
        body: sessionForm.okButton.payloadWith({'durationMinutes': minutes}),
      ) as SelectionScreen;
      final id = RegExp(r'/agendas/([0-9a-f-]{36})/')
          .firstMatch(
            opened.items.firstWhere((a) => a.text == 'Votar').url.path,
          )!
          .group(1)!;
      return _Agenda(id, title);
    }

    try {
      final closed = await agenda('encerrada', 1);
      return _Fixtures._(
        auth,
        open: await agenda('aberta', 30),
        doubleTap: await agenda('toque-duplo', 30),
        timeoutRegistered: await agenda('timeout-registrado', 30),
        timeoutMissing: await agenda('timeout-ausente', 30),
        closed: closed,
      );
    } finally {
      api.close();
    }
  }

  /// Estado da sessão segundo o servidor (a gestora pode consultar a apuração).
  Future<String?> sessionStatus(ApiOrigin origin, String agendaId) async {
    final manager = await auth.login('gestora', _password);
    final response = await http.get(
      origin.resolve('/api/v1/agendas/$agendaId/result'),
      headers: {'Authorization': 'Bearer ${manager.accessToken}'},
    );
    if (response.statusCode != 200) {
      return null;
    }
    return (jsonDecode(response.body) as Map<String, Object?>)['sessionStatus']
        ?.toString();
  }

  void close() => auth.close();
}

class _LifecycleLog with WidgetsBindingObserver {
  final states = <AppLifecycleState>[];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => states.add(state);
}

Future<void> _login(WidgetTester tester, String associateId) async {
  await _waitFor(tester, find.byKey(const ValueKey('login_submit')));
  await tester.enterText(
    find.byKey(const ValueKey('login_associate_id')),
    associateId,
  );
  await tester.enterText(
    find.byKey(const ValueKey('login_password')),
    _password,
  );
  await tester.tap(find.byKey(const ValueKey('login_submit')));
}

Future<void> _goHome(WidgetTester tester) async {
  await tester.tap(find.text('Voltar às pautas'));
  await _waitFor(tester, find.text('Pautas'));
}

Future<void> _openVoteForm(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await _waitFor(tester, find.text('Votar'));
  await tester.tap(find.text('Votar'));
  await _waitFor(tester, find.text('Registrar voto'));
}

Future<http.Response> _receipt(
  ApiOrigin origin,
  String token,
  String agendaId,
) => http.get(
  origin.resolve('/api/v1/agendas/$agendaId/votes/me'),
  headers: {'Authorization': 'Bearer $token'},
);

Future<String> _control(String path) async {
  final response = await http
      .get(Uri.parse('$_controlUrl$path'))
      .timeout(const Duration(minutes: 3));
  expect(response.statusCode, 200, reason: 'controle $path: ${response.body}');
  _log('controle $path → ${response.body.trim()}');
  return response.body.trim();
}

Future<void> _shot(String name) => _control('/device/screenshot?name=$name');

/// Bombeia quadros até o finder existir; o indicador de progresso anima sem parar,
/// por isso pumpAndSettle não serve aqui.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) => _waitUntil(
  () => finder.evaluate().isNotEmpty,
  tester,
  timeout: timeout,
  what: '$finder',
);

Future<void> _waitUntil(
  FutureOr<bool> Function() condition,
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
  String what = 'condição',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!(await condition())) {
    if (DateTime.now().isAfter(deadline)) {
      fail('tempo esgotado aguardando $what');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump();
}

void _step(int n, String description) => _log('PASSO $n: $description');

void _log(String message) {
  // ignore: avoid_print
  print('[jornada] $message');
}
