# Changelog

As mudanças relevantes deste projeto são registradas neste arquivo.

## [0.2.0] - 2026-10-29

### Adicionado

- login do associado (`POST /api/v1/auth/login`, contrato 1.0.0 da CoopVote API) com sessão guardada no
  Keychain/Keystore (`flutter_secure_storage`), expiração respeitada, logout e retorno ao login em `401`;
- `Authorization: Bearer` em todos os callbacks; o eleitor é o sujeito do token, sem campo no formulário;
- recibo do voto consultado antes de repetir um envio que expirou (`GET /api/v1/agendas/{id}/votes/me`);
- CI no GitHub Actions: formatação, análise, testes, build web, APK de depuração e teste de contrato
  contra a API real;
- testes de origem de callback, sessão, controlador (timeout/recibo, duplo envio, 401), login e fonte
  ampliada em tela estreita.

### Alterado

- callbacks só são aceitos na origem exata da API (esquema, host e porta), sem credenciais na URL, sob
  `/api/v1/mobile`, sem redirecionamentos e com HTTPS obrigatório fora de desenvolvimento
  (`COOPVOTE_ALLOW_HTTP`);
- corpo das respostas limitado a 256 KiB mesmo sem `Content-Length`; telas limitadas a 200 itens e textos a
  2.000 caracteres;
- formulário de voto sem identificador do associado.

## [0.1.5] - 2026-08-30

### Removido

- a versão 0.1.3 deixa de ser entrega: o anexo limita o FORMULARIO a dois botões, então Voltar no cliente não entra no produto.

## [0.1.4] - 2026-08-30

### Removido

- navegação Voltar do cliente (barra, rodapé e histórico local). O anexo limita o FORMULARIO a dois botões; o fluxo volta a seguir somente os callbacks da API.

## [0.1.2] - 2026-08-30

### Corrigido

- APK de avaliação assinado para instalação no emulador e em aparelho.

## [0.1.1] - 2026-08-30

### Adicionado

- APK Android de avaliação em `dist/coopvote-app-0.1.1.apk`, compilado contra a API publicada.

## [0.1.0] - 2026-08-29

### Adicionado

- interpretação das telas `FORMULARIO` e `SELECAO`;
- componentes de texto, entrada textual, numérica e de data;
- callbacks `POST` com composição de corpo e valores de entrada;
- configuração da URL inicial por `COOPVOTE_ENTRY_URL`;
- tratamento de timeout, conectividade, erros HTTP e violações do protocolo;
- testes unitários, HTTP e de fluxo de widgets;
- documentação de arquitetura, protocolo, execução e fluxo Git.
