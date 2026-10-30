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

## Artefato Android anterior

`dist/coopvote-app-0.1.2.apk` (SHA-256 `99715DF4…5EAF`) foi gerado para a API 0.4 **sem autenticação** e
não funciona com a API 0.5.0; permanece apenas como histórico até o proprietário gerar e assinar um novo
APK (o fluxo está documentado no README).
