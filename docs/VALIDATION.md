# Validação da versão 0.1.1

## Resultado

| Verificação | Resultado |
|---|---|
| Formatação Dart | sem divergências |
| Análise estática | sem ocorrências |
| Testes automatizados | 17 aprovados |
| Cobertura de linhas | 91,27% - 345 de 378 linhas |
| Build web | concluído |
| Build APK Android de desenvolvimento | concluído |

## Artefato Android

O APK de avaliação, apontando para `https://coopvote-api.onrender.com`, está versionado em:

```text
dist/coopvote-app-0.1.1.apk
```

SHA-256:

```text
787C2D748EF87347BBF8BE5BD26800C9572EC776D51C49BCC45857E639564E0B
```

A compilação de desenvolvimento continua em `build/app/outputs/flutter-apk/`. O diretório `build`
não é versionado. O checksum do artefato em `dist/` deve ser recalculado se o aplicativo for
recompilado.

## Escopo por plataforma

- Android: compilado como APK de desenvolvimento no Windows;
- web: compilado como verificação adicional do código compartilhado;
- iOS: código e metadados preparados, mas a compilação requer macOS e Xcode;
- Android de publicação: requer configuração da chave privada do responsável pela entrega.
