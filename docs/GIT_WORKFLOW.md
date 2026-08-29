# Fluxo Git

O repositório segue Git Flow com entregas pequenas.

## Branches

- `main`: releases estáveis e tags;
- `develop`: integração da próxima versão;
- `feature/*`: implementação isolada;
- `release/*`: estabilização, documentação e versão;
- `hotfix/*`: correções urgentes originadas em `main`.

## Commits

As mensagens seguem Conventional Commits:

```text
feat: implement server-driven screen flow
test: cover callback request payloads
docs: describe local device configuration
fix: preserve current screen after request failure
chore: prepare release 0.1.0
```

Cada commit deve representar uma mudança coerente, passar na análise estática e manter os testes verdes.

## Release

1. desenvolver em `feature/*` a partir de `develop`;
2. integrar a feature em `develop` com `--no-ff`;
3. criar `release/x.y.z` a partir de `develop`;
4. validar, atualizar versão e changelog;
5. integrar a release em `main`, criar a tag `vx.y.z` e retrointegrar em `develop`.
