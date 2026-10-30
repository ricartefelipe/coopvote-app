# Decisões e pontos catalogados

## Decisões

| Tema | Decisão | Motivo |
|---|---|---|
| Plataforma | Flutter | Uma base atende Android, iOS e uma validação web sem duplicar o protocolo. |
| Estado | `ChangeNotifier` do SDK | O fluxo possui uma única tela corrente e não justifica biblioteca adicional. |
| Navegação | Substituição da tela atual | O servidor já determina o próximo estado por callback. |
| Validação | Estrutural no app, de negócio no backend | O protocolo não declara obrigatoriedade ou limites dos campos. |
| Datas | `dd/MM/yyyy` | É o formato apresentado no anexo. |
| Erros | Mensagem visível, log e repetição manual | Preserva contexto e evita repetição automática de operações mutáveis. |
| Transporte | HTTP local apenas no desenvolvimento Android; HTTPS para ambientes publicados | Mantém o desenvolvimento simples sem enfraquecer a configuração de produção. |

## Pontos não definidos pelo contrato

1. Não há indicador de campo obrigatório. O app omite valores vazios e o backend aplica as regras de negócio.
2. Não há definição para identificadores duplicados. O app rejeita a tela para evitar sobrescrita silenciosa.
3. Não há regra explícita de precedência quando `body` e um campo têm a mesma chave. O valor informado pelo usuário prevalece, acompanhando a regra de que os campos são adicionados ao corpo no momento da ação.
4. Não há contrato de erro. O app entende `detail`, `message` e `code`, além de possuir mensagem padrão.
5. Não há mecanismo de idempotência genérico para callbacks. As repetições são manuais; para o voto, o app consulta o recibo antes de repetir e a API garante a unicidade por constraint.
6. Não há formato definido para URL relativa. O app exige URLs absolutas, como nos exemplos e na orientação de domínio configurável.
7. Não há estado definido para `SELECAO` sem itens. O app apresenta um estado vazio estável.
8. O anexo limita o FORMULARIO a no máximo dois botões e não define histórico. O app não adiciona Voltar no cliente e segue somente os callbacks do servidor.

9. Identidade: a API passou a exigir login (contrato 1.0.0). O app guarda o token no armazenamento seguro da plataforma, envia-o só à origem configurada e volta ao login em `401`; não há refresh token (tokens curtos, novo login ao expirar). Na web a sessão fica em memória.
10. Callbacks: o app só aceita a origem exata da API e o prefixo `/api/v1/mobile`; não segue redirecionamentos; HTTP sem TLS só com `COOPVOTE_ALLOW_HTTP=true` (padrão em depuração).
11. Modalidade do voto: identificável, conforme a API; o app não promete anonimato.
12. Votação offline não existe: sem rede o envio falha e o estado é "pendente" até a API responder.

## Restrições de plataforma

- a geração de iOS depende de macOS e Xcode; assinatura e envio às lojas são do proprietário;
- o APK local depende do Android SDK com licenças aceitas pelo responsável; a CI do GitHub gera o APK de depuração no runner;
- o APK de avaliação é assinado com a chave de depuração do Android para sideload; a publicação em loja requer chave própria;
- a versão web depende de CORS configurado no backend;
- dispositivos físicos precisam alcançar o host informado nas URLs de callback.
