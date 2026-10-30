import 'package:flutter/foundation.dart';

/// Configuração de ambiente definida durante a compilação.
class AppConfig {
  AppConfig._();

  static const String entryUrl = String.fromEnvironment(
    'COOPVOTE_ENTRY_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1/mobile',
  );

  /// HTTP sem TLS só é aceito quando pedido explicitamente (padrão: builds de depuração).
  static const bool allowInsecureHttp = bool.fromEnvironment(
    'COOPVOTE_ALLOW_HTTP',
    defaultValue: kDebugMode,
  );

  /// URL inicial do fluxo de telas.
  static Uri get entryUri {
    final uri = Uri.tryParse(entryUrl);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError(
        'COOPVOTE_ENTRY_URL deve conter uma URL HTTP ou HTTPS absoluta.',
      );
    }
    if (uri.scheme == 'http' && !allowInsecureHttp) {
      throw StateError(
        'COOPVOTE_ENTRY_URL usa HTTP; esta compilação exige HTTPS '
        '(defina COOPVOTE_ALLOW_HTTP=true apenas para desenvolvimento).',
      );
    }
    return uri;
  }
}
