# Build, exportación y QA

## Requisitos
- Godot **4.4.1** estándar y sus *export templates* (Editor → Manage Export Templates).
- Android: JDK 17, Android SDK (API 35) y un keystore de *release*. Activa *Use Gradle Build* e instala la plantilla de build de Android desde el editor.
- iOS: macOS con Xcode 16, cuenta de Apple Developer y Team ID.

## Presets (`export_presets.cfg`)
| Preset | Salida | Notas |
|---|---|---|
| Android | `build/android/vela.aab` | AAB para Google Play, solo arm64-v8a, minSdk 24 / targetSdk 35, inmersivo, permisos: internet y vibración |
| iOS | `build/ios/VELA.ipa` | iPhone + iPad, iOS 14+. Rellena `application/app_store_team_id` |
| Desktop QA (Linux) | `build/linux/vela.x86_64` | Build de pruebas con tests incluidos |

Los presets móviles excluyen `tests/`, `tools/` y `docs/`, e incluyen `data/*.json`. **Las credenciales de firma no van en el repo**: configúralas en Editor → Export (se guardan en `.godot/export_credentials.cfg`, ignorado) o con variables de entorno en la CI (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` y `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`).

```bash
godot --headless --export-release "Android" build/android/vela.aab
godot --headless --export-release "iOS" build/ios/VELA.ipa      # genera el proyecto Xcode
```

Versión: `application/config/version` (project.godot) + `version/code` (Android) / `application/version` (iOS). Súbelas en cada entrega a las tiendas.

## Generadores (cuando cambian textos o placeholders)
```bash
python3 tools/gen_localization.py   # localization/strings.csv
python3 tools/gen_icons.py          # assets/icons/*.svg
python3 tools/gen_audio.py          # assets/audio/*.wav
```

## QA antes de cada etapa
```bash
godot --headless --import
godot --headless -- --unit     # datos, traducciones, inventario, cocina, terreno, guardado…
godot --headless -- --smoke    # checklist completa del primer build
godot -- --tour /tmp/shots --quality 0   # regresión visual + costes (LOW)
godot -- --tour /tmp/shots --quality 2   # (HIGH)
```
La CI (`.github/workflows/tests.yml`) ejecuta el parse-check de todos los scripts, `--unit` y `--smoke` en cada push y PR.

Pruebas manuales en dispositivo (no automatizables aquí): controles táctiles con varios dedos, notch y safe area, pasar a segundo plano y volver (se guarda y pausa), 30–60 min de sesión (térmica), cambio de idioma CJK y presets de calidad.
