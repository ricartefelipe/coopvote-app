# Changelog

As mudanças relevantes deste projeto são registradas neste arquivo.

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
