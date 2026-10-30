import 'package:flutter/foundation.dart';

import 'auth_api.dart';
import 'auth_session.dart';
import 'session_store.dart';

/// Estado de autenticação do app: restaura, cria e encerra a sessão.
class SessionController extends ChangeNotifier {
  SessionController(this._authApi, this._store, {DateTime Function()? now})
    : _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final AuthApi _authApi;
  final SessionStore _store;
  final DateTime Function() _now;

  AuthSession? _session;
  bool _restored = false;
  bool _busy = false;
  String? _message;

  AuthSession? get session => _session;
  bool get restored => _restored;
  bool get busy => _busy;
  String? get message => _message;
  bool get signedIn => _session != null && !_session!.isExpiredAt(_now());

  /// Recupera a sessão guardada; uma sessão expirada é descartada, nunca reaproveitada.
  Future<void> restore() async {
    final stored = await _store.read();
    if (stored != null && stored.isExpiredAt(_now())) {
      await _store.clear();
      _message = 'Sua sessão expirou. Entre novamente.';
    } else {
      _session = stored;
    }
    _restored = true;
    notifyListeners();
  }

  Future<void> login(String associateId, String password) async {
    if (_busy) {
      return;
    }
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final session = await _authApi.login(associateId, password);
      await _store.write(session);
      _session = session;
    } on AuthException catch (error) {
      _message = error.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Encerra localmente (não há revogação no servidor; tokens são de curta duração).
  Future<void> logout({String? reason}) async {
    await _store.clear();
    _session = null;
    _message = reason;
    notifyListeners();
  }

  /// Chamado quando a API responde 401: a sessão deixa de valer e o usuário volta ao login.
  Future<void> expire() =>
      logout(reason: 'Sua sessão expirou. Entre novamente.');
}
