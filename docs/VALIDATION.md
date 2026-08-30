# Validação da versão 0.1.2

## Resultado

| Verificação | Resultado |
|---|---|
| Assinatura do APK | v2 e v3 verificadas com `apksigner` |
| Instalação no emulador | `adb install` concluído |
| Teste `scripts/verify_apk.py` | APK assinado |

## Artefato Android

O APK de avaliação, apontando para `https://coopvote-api.onrender.com`, está versionado em:

```text
dist/coopvote-app-0.1.2.apk
```

SHA-256:

```text
99715DF45F4D586663CEB4E5766DEF1FBC8CA13D4B8B8303F446549417835EAF
```

A compilação de desenvolvimento continua em `build/app/outputs/flutter-apk/`. O diretório `build`
não é versionado. O checksum do artefato em `dist/` deve ser recalculado se o aplicativo for
recompilado.

O release usa a chave de depuração do Android para permitir sideload na avaliação. A publicação
em loja continua exigindo a chave privada do responsável pela entrega.

## Escopo por plataforma

- Android: APK de avaliação assinado e instalável;
- web: compilado como verificação adicional do código compartilhado;
- iOS: código e metadados preparados, mas a compilação requer macOS e Xcode.
