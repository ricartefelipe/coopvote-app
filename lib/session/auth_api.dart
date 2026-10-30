import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_origin.dart';
import 'auth_session.dart';

/// Login do associado em `POST /api/v1/auth/login`.
final class AuthApi {
  AuthApi(
    this._origin, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const loginPath = '/api/v1/auth/login';

  final ApiOrigin _origin;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Future<AuthSession> login(String associateId, String password) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _origin.resolve(loginPath),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'associateId': associateId.trim(),
              'password': password,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AuthException(
        'A API demorou demais para responder. Tente novamente.',
      );
    } on http.ClientException catch (error) {
      throw AuthException('Não foi possível conectar à API: ${error.message}.');
    }
    if (response.statusCode == 401) {
      throw const AuthException('Identificador ou senha inválidos.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('A API recusou o login (${response.statusCode}).');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const AuthException(
        'A API retornou uma resposta de login inválida.',
      );
    }
    if (json is! Map ||
        json['accessToken'] is! String ||
        json['expiresAt'] is! String) {
      throw const AuthException(
        'A API retornou uma resposta de login inválida.',
      );
    }
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String);
    if (expiresAt == null) {
      throw const AuthException(
        'A API retornou uma resposta de login inválida.',
      );
    }
    final roles = json['roles'];
    return AuthSession(
      accessToken: json['accessToken'] as String,
      expiresAt: expiresAt.toUtc(),
      roles: roles is List
          ? roles.map((r) => r.toString()).toList(growable: false)
          : const [],
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

final class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
