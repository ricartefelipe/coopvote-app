# Validação da versão 0.1.0

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

O APK local é gerado em:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

O artefato de desenvolvimento da validação possui SHA-256:

```text
6CDDE33500B737A7F06C7E94A08C93F717CAD84B9D8D515CE5B382CBDF9269A3
```

O diretório `build` não é versionado. O checksum deve ser recalculado sempre que o aplicativo for recompilado.

## Escopo por plataforma

- Android: compilado como APK de desenvolvimento no Windows;
- web: compilado como verificação adicional do código compartilhado;
- iOS: código e metadados preparados, mas a compilação requer macOS e Xcode;
- Android de publicação: requer configuração da chave privada do responsável pela entrega.
