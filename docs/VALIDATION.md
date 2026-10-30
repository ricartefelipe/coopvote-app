# Validação da versão 0.2.0

Executada em 29/10/2026 com Flutter 3.47.9 (Dart 3.13.7), em Linux.

| Verificação | Resultado |
|---|---|
| `flutter analyze` | sem problemas |
| `dart format --set-exit-if-changed lib test` | sem diferenças |
| `flutter test --exclude-tags contract` | **38 testes aprovados** (origem de callback: outra origem, porta, esquema, domínio parecido, credenciais na URL, caminho fora do fluxo, traversal; API: token só à origem da API, sem redirecionamentos, 401 → sessão expirada, corpo limitado com e sem `Content-Length`, timeout como resultado incerto; sessão: login, credencial inválida, expiração na retomada, logout; controlador: timeout de voto → recibo existente não reenvia / recibo ausente reenvia uma vez, dois envios simultâneos → uma requisição; widgets: login, 401 no fluxo volta ao login sem transferir sessão, Sair, fonte 2× em tela de 320 px, fluxo de telas e formulário) |
| Contrato contra a CoopVote API real (`test/contract`, `COOPVOTE_API_URL`) | **aprovado** contra a API 0.5.0 (imagem final, seed local, `CALLBACK_BASE_URL` igual à origem usada pelo app): login errado recusado, gestora cadastra pauta e abre sessão pelas telas, eleitor não recebe ações de gestão, formulário de voto sem campo de identificação, voto registrado, recibo presente, segundo envio `409 DUPLICATE_VOTE`, parcial oculta ao eleitor, token forjado → sessão expirada |
| `flutter build web --release` | concluído (41 MB em `build/web`) |
| `flutter build apk --debug` | **não executado nesta máquina**: não há Android SDK instalado e aceitar as licenças do SDK é decisão do responsável; a CI (`.github/workflows/ci.yml`, job `quality`) gera o APK de depuração no runner do GitHub |
| iOS | não gerado: exige macOS e Xcode |

A API só é confiável se anunciar callbacks na origem exata que o app usa (`CALLBACK_BASE_URL`);
qualquer outra origem é recusada antes de enviar o token. Publicação em lojas, assinatura com chave
própria e deploy continuam com o proprietário.

## Validação da versão 0.2.1 (30/10/2026)

Toolchain isolada: Flutter 3.47.9 stable (Dart 3.13.7), Android SDK 36 (build-tools 36.0.0, platform-tools,
emulador, imagem `android-36;google_apis;x86_64`), OpenJDK 21, Linux com KVM.

| Verificação | Resultado |
|---|---|
| `flutter pub get --enforce-lockfile`, `flutter analyze`, `dart format --set-exit-if-changed lib test integration_test` | sem problemas |
| `flutter test --exclude-tags contract` | 38 testes aprovados |
| `flutter build apk --release --dart-define=COOPVOTE_ENTRY_URL=https://coopvote-api.onrender.com/api/v1/mobile --dart-define=COOPVOTE_ALLOW_HTTP=false` | **concluído**; `app-release.apk` com **assinatura de teste** (`signingConfigs.debug` do `build.gradle.kts`), não é a assinatura oficial de loja; SHA-256 `31d33ac107c243391df09ba9d7f5152cc66fbb11d33f3f6453deebdbf476fe48` |
| Jornada móvel real (`tool/journey/run.sh`, emulador Android 16 x86_64, API real no Compose isolado com seed sintético) | **aprovada, 10 passos**: (1) login e lista de pautas; (2) eleitor sem ação de gestão e `403` da API ao forçá-la; (3) voto pelas telas com recibo confirmado pelo servidor (`GET /agendas/{id}/votes/me` 200); (4) toque duplo no botão de voto → uma só requisição, sem `DUPLICATE_VOTE`; (5) API pausada → timeout → "Conferir recibo": recibo existente não reenvia (mesmo id de antes); API derrubada antes de processar a fila → recibo ausente → um único reenvio; (6) HOME e retomada pelo sistema (ciclo `paused → resumed`) com a tela preservada; (7) segredo do token rotacionado no servidor → `401` → login com "Sua sessão expirou", entrada com outra conta sem herdar o voto da anterior; (8) pauta encerrada pelo relógio do servidor: sem "Votar", apuração "Sessão: Encerrada", `409 VOTING_SESSION_CLOSED` no domínio e sem recibo; (9) API reconfigurada com callbacks em outra origem → "A URL de callback não pertence à API configurada." e zero requisições ao destino estranho; (10) `font_scale` 2.0 do sistema → login, pautas, ações e volta sem overflow |

Publicação em loja, assinatura com chave própria e deploy continuam com o proprietário.

## Artefato Android anterior

`dist/coopvote-app-0.1.2.apk` (SHA-256 `99715DF4…5EAF`) foi gerado para a API 0.4 **sem autenticação** e
não funciona com a API 0.5.0; permanece apenas como histórico até o proprietário gerar e assinar um novo
APK (o fluxo está documentado no README).
