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
5. Não há mecanismo de idempotência para callbacks. As repetições são sempre manuais; se a resposta de uma operação mutável for perdida, cabe ao backend impedir duplicidade quando isso for necessário.
6. Não há formato definido para URL relativa. O app exige URLs absolutas, como nos exemplos e na orientação de domínio configurável.
7. Não há estado definido para `SELECAO` sem itens. O app apresenta um estado vazio estável.
8. O anexo não define histórico ou ação de voltar. O app segue somente os callbacks fornecidos pelo servidor.

## Restrições de plataforma

- a geração de iOS depende de macOS e Xcode;
- a publicação Android requer uma chave de assinatura própria;
- a versão web depende de CORS configurado no backend;
- dispositivos físicos precisam alcançar o host informado nas URLs de callback.
