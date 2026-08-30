import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'screen_api.dart';
import 'screen_models.dart';

/// Coordena a tela corrente e o ciclo de cada callback.
class ScreenController extends ChangeNotifier {
  ScreenController(this._api, this._entryUri);

  final ScreenApi _api;
  final Uri _entryUri;

  AppScreen? _screen;
  bool _loading = false;
  String? _errorMessage;
  Uri? _lastUri;
  Map<String, Object?>? _lastBody;
  bool _disposed = false;

  AppScreen? get screen => _screen;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInitial() => _send(_entryUri);

  Future<void> submit(
    ScreenAction action, {
    Map<String, Object?> inputValues = const {},
  }) {
    return _send(action.url, body: action.payloadWith(inputValues));
  }

  Future<void> retry() {
    return _send(_lastUri ?? _entryUri, body: _lastBody);
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
