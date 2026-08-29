import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'screen_models.dart';

/// Executa callbacks e converte suas respostas em telas.
class ScreenApi {
  ScreenApi({http.Client? client, this.timeout = const Duration(seconds: 15)})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  /// Envia um callback `POST` e interpreta a próxima tela.
  Future<AppScreen> post(Uri url, {Map<String, Object?>? body}) async {
    _validateCallbackUrl(url);

    try {
      final response = await _client
          .post(
            url,
            headers: <String, String>{
              'Accept': 'application/json',
              if (body != null) 'Content-Type': 'application/json',
            },
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _requestException(response);
      }

      try {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return AppScreen.fromJson(json);
      } on FormatException catch (error) {
        throw ScreenProtocolException(
          'A API retornou um JSON inválido: ${error.message}.',
        );
      }
    } on TimeoutException {
      throw const ScreenRequestException(
        'A API demorou demais para responder. Tente novamente.',
      );
    } on http.ClientException catch (error) {
      throw ScreenRequestException(
        'Não foi possível conectar à API: ${error.message}.',
      );
    }
  }

  /// Libera o cliente HTTP criado internamente.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  void _validateCallbackUrl(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      throw const ScreenRequestException(
        'A API informou uma URL de callback inválida.',
      );
    }
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw const ScreenRequestException(
        'A URL de callback deve usar HTTP ou HTTPS.',
      );
    }
  }

  ScreenRequestException _requestException(http.Response response) {
    String? detail;
    String? code;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map) {
        detail = json['detail']?.toString() ?? json['message']?.toString();
        code = json['code']?.toString();
      }
    } on FormatException {
      // A mensagem padrão abaixo cobre respostas de erro sem JSON.
    }

    return ScreenRequestException(
      detail?.trim().isNotEmpty == true
          ? detail!.trim()
          : 'A API recusou a operação (${response.statusCode}).',
      statusCode: response.statusCode,
      code: code,
    );
  }
}

/// Falha de transporte ou resposta HTTP não bem-sucedida.
final class ScreenRequestException implements Exception {
  const ScreenRequestException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}
