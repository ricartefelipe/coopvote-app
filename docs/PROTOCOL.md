# Protocolo de telas

## Regras gerais

- toda resposta bem-sucedida deve ser um objeto JSON;
- `tipo` aceita `FORMULARIO` ou `SELECAO`;
- toda ação contém `texto` e uma `url` absoluta HTTP ou HTTPS;
- o acionamento sempre produz uma requisição `POST`;
- `body` é opcional e não é enviado quando não existe e não há valores de entrada;
- valores informados nos campos são adicionados pelo `id` e prevalecem em caso de colisão com uma chave do `body`.

## FORMULARIO

```json
{
  "tipo": "FORMULARIO",
  "titulo": "Nova pauta",
  "itens": [
    { "tipo": "TEXTO", "texto": "Informe os dados." },
    { "tipo": "INPUT_TEXTO", "id": "title", "titulo": "Título" },
    { "tipo": "INPUT_NUMERO", "id": "duration", "titulo": "Duração", "valor": 1 },
    { "tipo": "INPUT_DATA", "id": "date", "titulo": "Data", "valor": "28/08/2026" }
  ],
  "botaoOk": {
    "texto": "Salvar",
    "url": "https://api.exemplo.com/mobile/agendas",
    "body": { "source": "mobile" }
  },
  "botaoCancelar": {
    "texto": "Cancelar",
    "url": "https://api.exemplo.com/mobile"
  }
}
```

`botaoOk` é obrigatório e `botaoCancelar` é opcional. Campos vazios são omitidos. Números são enviados como valores JSON numéricos e datas usam `dd/MM/yyyy`.

## SELECAO

```json
{
  "tipo": "SELECAO",
  "titulo": "Pautas",
  "itens": [
    {
      "texto": "Cadastrar nova pauta",
      "url": "https://api.exemplo.com/mobile/agendas/new"
    },
    {
      "texto": "Pauta 1",
      "url": "https://api.exemplo.com/mobile/agendas/1",
      "body": { "source": "list" }
    }
  ]
}
```

Uma lista vazia é válida e produz o estado visual `Nenhuma opção disponível`.

## Erros

Respostas fora de `2xx` não substituem a tela válida. Quando a API retorna um objeto de problema, o app usa `detail` e preserva `code` para diagnóstico. Se esses campos não existirem, apresenta uma mensagem baseada no status HTTP.

Resposta `2xx` com JSON inválido ou estrutura desconhecida é tratada como violação do protocolo e oferece repetição manual.
