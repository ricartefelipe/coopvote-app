import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../session/api_origin.dart';
import 'screen_models.dart';

/// Executa callbacks e converte suas respostas em telas.
///
/// Só fala com a origem configurada da API: callbacks de outra origem, com credenciais na URL,
/// fora de `/api/v1/mobile` ou sem TLS (quando exigido) são recusados antes de qualquer rede. O
/// token nunca é enviado a outro destino, redirecionamentos não são seguidos e o corpo da
/// resposta é limitado antes de ser montado em memória.
class ScreenApi {
  ScreenApi(
    this.origin, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.maxBodyBytes = defaultMaxBodyBytes,
    String? Function()? token,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _token = token ?? (() => null);

  static const int defaultMaxBodyBytes = 256 * 1024;
  static final RegExp _voteCallback = RegExp(
    r'^/api/v1/mobile/agendas/([0-9a-fA-F-]{36})/votes/?$',
  );

  final ApiOrigin origin;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final int maxBodyBytes;
  final String? Function() _token;

  /// Envia um callback `POST` e interpreta a próxima tela.
  Future<AppScreen> post(Uri url, {Map<String, Object?>? body}) async {
    final rejection = origin.rejectCallback(url);
    if (rejection != null) {
      throw ScreenRequestException(rejection.message);
    }
    final request = _request('POST', url);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _send(request);
    if (response.statusCode == 401) {
      throw const SessionExpiredException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _requestException(response);
    }
    try {
      return AppScreen.fromJson(jsonDecode(_decodeBody(response)));
    } on FormatException catch (error) {
      throw ScreenProtocolException(
        'A API retornou um JSON inválido: ${error.message}.',
      );
    }
  }

  /// Identifica a pauta quando o callback é o registro de voto.
  static String? voteAgendaId(Uri url) =>
      _voteCallback.firstMatch(url.path)?.group(1);

  /// Consulta o recibo do voto do associado autenticado: `true` se já existe,
  /// `false` se ainda não há voto. Usado antes de repetir um envio cuja
  /// resposta se perdeu.
  Future<bool> hasVoteReceipt(String agendaId) async {
    final request = _request(
      'GET',
      origin.resolve('/api/v1/agendas/$agendaId/votes/me'),
    );
    final response = await _send(request);
    return switch (response.statusCode) {
      200 => true,
      404 => false,
      401 => throw const SessionExpiredException(),
      _ => throw _requestException(response),
    };
  }

  http.Request _request(String method, Uri url) {
    final request = http.Request(method, url)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    final token = _token();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return request;
  }

  Future<http.Response> _send(http.Request request) async {
    try {
      final streamed = await _client.send(request).timeout(timeout);
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        throw const ScreenRequestException(
          'A API tentou redirecionar a requisição; redirecionamentos não são seguidos.',
        );
      }
      final declared = streamed.contentLength;
      if (declared != null && declared > maxBodyBytes) {
        throw const ScreenProtocolException(
          'A resposta da API excede o tamanho permitido.',
        );
      }
      final bytes = await _readLimited(streamed.stream).timeout(timeout);
      return http.Response.bytes(
        bytes,
        streamed.statusCode,
        headers: streamed.headers,
        request: request,
      );
    } on TimeoutException {
      throw const ScreenTimeoutException();
    } on http.ClientException catch (error) {
      throw ScreenRequestException(
        'Não foi possível conectar à API: ${error.message}.',
      );
    }
  }

  /// Lê o corpo até o limite mesmo sem Content-Length, sem acumular além dele.
  Future<List<int>> _readLimited(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maxBodyBytes) {
        throw const ScreenProtocolException(
          'A resposta da API excede o tamanho permitido.',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// JSON da API é UTF-8; respostas sem charset válido caem em Latin-1 para não perder a
  /// mensagem de erro.
  static String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return latin1.decode(response.bodyBytes);
    }
  }

  /// Libera o cliente HTTP criado internamente.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  ScreenRequestException _requestException(http.Response response) {
    String? detail;
    String? code;
    try {
      final json = jsonDecode(_decodeBody(response));
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

/// A API não respondeu no prazo: o efeito pode ou não ter acontecido.
final class ScreenTimeoutException extends ScreenRequestException {
  const ScreenTimeoutException()
    : super('A API demorou demais para responder. Tente novamente.');
}

/// A API respondeu 401: o token deixou de valer.
final class SessionExpiredException implements Exception {
  const SessionExpiredException();
}
