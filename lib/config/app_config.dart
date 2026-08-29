/// Configuração de ambiente definida durante a compilação.
class AppConfig {
  AppConfig._();

  static const String entryUrl = String.fromEnvironment(
    'COOPVOTE_ENTRY_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1/mobile',
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
    return uri;
  }
}
