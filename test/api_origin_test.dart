import 'package:coopvote_app/session/api_origin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final origin = ApiOrigin(
    Uri.parse('https://api.coop.example/api/v1/mobile'),
    allowInsecureHttp: false,
  );

  CallbackRejection? reject(String url) =>
      origin.rejectCallback(Uri.parse(url));

  test('aceita callback da mesma origem sob o fluxo mobile', () {
    expect(reject('https://api.coop.example/api/v1/mobile'), isNull);
    expect(reject('https://api.coop.example/api/v1/mobile/agendas/1'), isNull);
    expect(reject('https://API.COOP.EXAMPLE:443/api/v1/mobile'), isNull);
  });

  test('recusa outra origem, porta, esquema e domínio parecido', () {
    expect(
      reject('https://evil.example/api/v1/mobile'),
      CallbackRejection.origin,
    );
    expect(
      reject('https://api.coop.example:8443/api/v1/mobile'),
      CallbackRejection.origin,
    );
    expect(
      reject('http://api.coop.example/api/v1/mobile'),
      CallbackRejection.origin,
    );
    expect(
      reject('https://api.coop.example.attacker.test/api/v1/mobile'),
      CallbackRejection.origin,
    );
    expect(
      reject('https://api-coop.example/api/v1/mobile'),
      CallbackRejection.origin,
    );
    expect(
      reject('ftp://api.coop.example/api/v1/mobile'),
      CallbackRejection.scheme,
    );
  });

  test('recusa credenciais na URL, caminho fora do fluxo e traversal', () {
    expect(
      reject('https://user:pass@api.coop.example/api/v1/mobile'),
      CallbackRejection.userInfo,
    );
    expect(
      reject('https://api.coop.example/api/v1/auth/login'),
      CallbackRejection.path,
    );
    expect(
      reject('https://api.coop.example/api/v1/mobileX'),
      CallbackRejection.path,
    );
    expect(
      reject('https://api.coop.example/api/v1/mobile/../admin'),
      CallbackRejection.path,
    );
    expect(
      reject('https://api.coop.example/api/v1/mobile/%2e%2e/admin'),
      CallbackRejection.path,
    );
    expect(reject('/api/v1/mobile'), CallbackRejection.notAbsolute);
  });

  test('HTTP sem TLS só é aceito quando a compilação permite', () {
    final local = ApiOrigin(
      Uri.parse('http://10.0.2.2:8080/api/v1/mobile'),
      allowInsecureHttp: true,
    );
    expect(
      local.rejectCallback(Uri.parse('http://10.0.2.2:8080/api/v1/mobile')),
      isNull,
    );
    final strict = ApiOrigin(
      Uri.parse('http://10.0.2.2:8080/api/v1/mobile'),
      allowInsecureHttp: false,
    );
    expect(
      strict.rejectCallback(Uri.parse('http://10.0.2.2:8080/api/v1/mobile')),
      CallbackRejection.insecure,
    );
  });

  test('resolve caminhos da própria API', () {
    expect(
      origin.resolve('/api/v1/auth/login').toString(),
      'https://api.coop.example/api/v1/auth/login',
    );
  });
}
