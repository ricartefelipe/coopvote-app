/// Origem confiável da API, derivada da URL de entrada. Só ela recebe o token.
final class ApiOrigin {
  ApiOrigin(Uri entry, {required this.allowInsecureHttp})
    : scheme = entry.scheme,
      host = entry.host,
      port = entry.hasPort ? entry.port : (entry.scheme == 'https' ? 443 : 80) {
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError.value(entry, 'entry', 'deve usar HTTP ou HTTPS');
    }
  }

  static const mobilePathPrefix = '/api/v1/mobile';
  static const apiPathPrefix = '/api/v1/';

  final String scheme;
  final String host;
  final int port;
  final bool allowInsecureHttp;

  /// Monta uma URL da API a partir de um caminho absoluto conhecido.
  Uri resolve(String path) =>
      Uri(scheme: scheme, host: host, port: port, path: path);

  /// Um callback só é aceito se for exatamente desta origem (esquema, host e porta), sem
  /// credenciais na URL, sob `/api/v1/mobile`, e com TLS quando a compilação exige.
  CallbackRejection? rejectCallback(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return CallbackRejection.notAbsolute;
    }
    if (url.scheme != 'http' && url.scheme != 'https') {
      return CallbackRejection.scheme;
    }
    if (url.userInfo.isNotEmpty) {
      return CallbackRejection.userInfo;
    }
    final urlPort = url.hasPort ? url.port : (url.scheme == 'https' ? 443 : 80);
    if (url.scheme != scheme ||
        url.host.toLowerCase() != host.toLowerCase() ||
        urlPort != port) {
      return CallbackRejection.origin;
    }
    if (url.scheme == 'http' && !allowInsecureHttp) {
      return CallbackRejection.insecure;
    }
    final path = Uri.decodeComponent(url.path);
    if (path != mobilePathPrefix && !path.startsWith('$mobilePathPrefix/')) {
      return CallbackRejection.path;
    }
    if (path.contains('/../') || path.endsWith('/..')) {
      return CallbackRejection.path;
    }
    return null;
  }
}

enum CallbackRejection {
  notAbsolute('A API informou uma URL de callback inválida.'),
  scheme('A URL de callback deve usar HTTP ou HTTPS.'),
  userInfo('A URL de callback não pode conter credenciais.'),
  origin('A URL de callback não pertence à API configurada.'),
  insecure('A URL de callback exige HTTPS nesta compilação.'),
  path('A URL de callback está fora do fluxo de telas da API.');

  const CallbackRejection(this.message);

  final String message;
}
