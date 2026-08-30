# CoopVote App

Cliente Flutter server-driven para a CoopVote API. O aplicativo recebe descrições de tela em JSON, renderiza os componentes suportados e envia as ações de volta à URL definida pelo servidor.

O projeto implementa integralmente os dois tipos de tela descritos no contrato:

- `FORMULARIO`, com `TEXTO`, `INPUT_TEXTO`, `INPUT_NUMERO` e `INPUT_DATA`;
- `SELECAO`, com uma lista de ações;
- callbacks por `POST`, com o `body` da ação acrescido dos valores informados pelo usuário.

## Requisitos

- Flutter 3.47.2 ou compatível;
- Dart 3.13.2 ou compatível;
- CoopVote API em execução;
- Android SDK para executar ou gerar APK;
- macOS e Xcode somente para gerar o aplicativo iOS.

## Execução rápida

O endereço padrão aponta para a máquina hospedeira a partir do emulador Android:

```text
http://10.0.2.2:8080/api/v1/mobile
```

Antes de iniciar o backend para esse cenário, configure a base dos callbacks:

```powershell
$env:CALLBACK_BASE_URL='http://10.0.2.2:8080'
docker compose up --build
```

Em seguida, na raiz deste projeto:

```powershell
flutter pub get
flutter run
```

Para usar outro ambiente, informe a URL de entrada durante a compilação:

```powershell
flutter run --dart-define=COOPVOTE_ENTRY_URL=https://api.exemplo.com/api/v1/mobile
```

As URLs retornadas pelo backend também precisam ser alcançáveis pelo dispositivo. Em aparelho físico, use o IP da máquina na rede local tanto em `CALLBACK_BASE_URL` quanto em `COOPVOTE_ENTRY_URL`. Em produção, use HTTPS.

## Qualidade

```powershell
flutter analyze
flutter test --coverage
flutter build web --dart-define=COOPVOTE_ENTRY_URL=https://api.exemplo.com/api/v1/mobile
flutter build apk --debug
```

A versão web serve como validação adicional. Para executá-la contra outro domínio, a API precisa autorizar a origem do navegador por CORS.

## Organização

```text
lib/
  config/          configuração de ambiente
  screen_flow/     protocolo, HTTP, estado e composição da tela
    widgets/       renderização dos tipos de tela
test/              testes unitários, de integração HTTP e de widgets
docs/              arquitetura, protocolo, decisões e fluxo Git
```

O app não replica regras de pauta, sessão ou voto. Ele conhece somente o protocolo de apresentação e deixa o backend comandar o fluxo. Consulte [Arquitetura](docs/ARCHITECTURE.md), [Protocolo](docs/PROTOCOL.md), [Decisões e pontos catalogados](docs/DECISIONS.md), [Validação](docs/VALIDATION.md) e [Fluxo Git](docs/GIT_WORKFLOW.md).

## Segurança de transporte

- Android de desenvolvimento permite HTTP local; o manifesto principal mantém somente a permissão de internet.
- iOS permite descoberta da rede local; ambientes publicados devem utilizar HTTPS.
- A URL de callback é validada e aceita somente os esquemas `http` e `https`.
- Autenticação não foi adicionada porque o escopo considera as interfaces autorizadas.

## APK publicado

O aplicativo Android apontando para a API em `https://coopvote-api.onrender.com` está em
[`dist/coopvote-app-0.1.2.apk`](dist/coopvote-app-0.1.2.apk).

SHA-256:

```text
99715DF45F4D586663CEB4E5766DEF1FBC8CA13D4B8B8303F446549417835EAF
```

Instale o arquivo no aparelho (permitir fontes desconhecidas) ou no emulador. A primeira abertura
pode levar cerca de dois minutos se o ambiente publicado estiver inativo.

Para gerar novamente:

```powershell
flutter build apk --release --dart-define=COOPVOTE_ENTRY_URL=https://coopvote-api.onrender.com/api/v1/mobile
python scripts/verify_apk.py build/app/outputs/flutter-apk/app-release.apk
```

O release local é assinado com a chave de depuração do Android para permitir instalação direta.

## Versão

A versão atual é `0.1.5+5`. Mudanças publicadas são registradas em [CHANGELOG.md](CHANGELOG.md).
