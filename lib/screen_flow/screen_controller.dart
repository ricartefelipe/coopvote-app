import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'screen_api.dart';
import 'screen_models.dart';

/// Estado de um envio de voto cuja resposta não chegou.
enum VoteOutcome {
  /// Nada pendente.
  none,

  /// O envio expirou; o recibo será consultado antes de qualquer repetição.
  pending,

  /// A API confirma que o voto existe: não repetir.
  confirmed,

  /// A API confirma que não há voto: o envio pode ser repetido.
  notRegistered,
}

/// Coordena a tela corrente e o ciclo de cada callback.
///
/// Um timeout no registro de voto não é tratado como falha nem como sucesso: o recibo é
/// consultado antes de liberar a repetição, para que dois toques ou uma reconexão não produzam
/// dois envios sem necessidade. A duplicidade real continua garantida pelo backend.
class ScreenController extends ChangeNotifier {
  ScreenController(this._api, this._entryUri, {this.onSessionExpired});

  final ScreenApi _api;
  final Uri _entryUri;
  final Future<void> Function()? onSessionExpired;

  AppScreen? _screen;
  bool _loading = false;
  String? _errorMessage;
  Uri? _lastUri;
  Map<String, Object?>? _lastBody;
  VoteOutcome _voteOutcome = VoteOutcome.none;
  String? _pendingVoteAgendaId;
  bool _disposed = false;

  AppScreen? get screen => _screen;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  VoteOutcome get voteOutcome => _voteOutcome;

  Future<void> loadInitial() => _send(_entryUri);

  Future<void> submit(
    ScreenAction action, {
    Map<String, Object?> inputValues = const {},
  }) {
    return _send(action.url, body: action.payloadWith(inputValues));
  }

  /// Repete o último envio. Para um voto pendente, primeiro confere o recibo.
  Future<void> retry() async {
    final agendaId = _pendingVoteAgendaId;
    if (agendaId != null) {
      await _resolvePendingVote(agendaId);
      if (_voteOutcome == VoteOutcome.confirmed ||
          _voteOutcome == VoteOutcome.pending) {
        return;
      }
    }
    await _send(_lastUri ?? _entryUri, body: _lastBody);
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    _notifyListeners();
  }

  Future<void> _send(Uri uri, {Map<String, Object?>? body}) async {
    if (_loading || _disposed) {
      return;
    }
    _loading = true;
    _errorMessage = null;
    _lastUri = uri;
    _lastBody = body == null ? null : Map.unmodifiable(body);
    _notifyListeners();
    try {
      _screen = await _api.post(uri, body: body);
      _voteOutcome = VoteOutcome.none;
      _pendingVoteAgendaId = null;
    } on ScreenTimeoutException catch (error, stackTrace) {
      final agendaId = ScreenApi.voteAgendaId(uri);
      if (agendaId != null) {
        _voteOutcome = VoteOutcome.pending;
        _pendingVoteAgendaId = agendaId;
        _errorMessage = 'Sem resposta ao registrar o voto. O recibo será conferido antes de repetir.';
      } else {
        _errorMessage = error.message;
      }
      _logFailure(error, stackTrace);
    } on SessionExpiredException {
      await _expireSession();
    } on ScreenRequestException catch (error, stackTrace) {
      _errorMessage = error.message;
      _logFailure(error, stackTrace);
    } on ScreenProtocolException catch (error, stackTrace) {
      _errorMessage =
          'A resposta da API não pôde ser exibida: ${error.message}';
      _logFailure(error, stackTrace);
    } catch (error, stackTrace) {
      _errorMessage = 'Ocorreu um erro inesperado. Tente novamente.';
      _logFailure(error, stackTrace);
    } finally {
      _loading = false;
      _notifyListeners();
    }
  }

  Future<void> _resolvePendingVote(String agendaId) async {
    if (_loading || _disposed) {
      return;
    }
    _loading = true;
    _notifyListeners();
    try {
      final registered = await _api.hasVoteReceipt(agendaId);
      if (registered) {
        _voteOutcome = VoteOutcome.confirmed;
        _pendingVoteAgendaId = null;
        _errorMessage = 'Seu voto já estava registrado; nada foi reenviado.';
        _lastUri = _api.origin.resolve('/api/v1/mobile/agendas/$agendaId');
        _lastBody = null;
      } else {
        _voteOutcome = VoteOutcome.notRegistered;
        _errorMessage = null;
      }
    } on SessionExpiredException {
      await _expireSession();
    } on ScreenRequestException catch (error, stackTrace) {
      _errorMessage = 'Não foi possível conferir o recibo: ${error.message}';
      _logFailure(error, stackTrace);
    } finally {
      _loading = false;
      _notifyListeners();
    }
  }

  Future<void> _expireSession() async {
    _errorMessage = 'Sua sessão expirou. Entre novamente.';
    await onSessionExpired?.call();
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    developer.log(
      'Falha ao processar fluxo de tela',
      name: 'coopvote.screen_flow',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
