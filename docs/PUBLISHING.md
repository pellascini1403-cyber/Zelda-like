# Publicación (App Store / Google Play)

## Estado de preparación

| Elemento | Estado |
|---|---|
| Presets de exportación iOS/Android | ✅ listos (faltan Team ID y keystore) |
| Icono | ⚠️ `icon.svg` provisional; entrega 1024×1024 (iOS) y adaptativo 432×432 fore/background (Android) |
| Splash | ✅ color de marca sin imagen (el juego muestra su propia carga) |
| Localización (8 idiomas) | ✅ UI, historia y objetos; revisión nativa pendiente |
| Guardado seguro / pausa en segundo plano | ✅ |
| Capa de plataforma (IAP, anuncios, analítica, crash, térmica) | ✅ fachada; ⚠️ faltan los plugins nativos |
| Metadatos, capturas y política de privacidad | ⚠️ por redactar (borrador abajo) |

## Monetización (sin pay-to-win)
- Catálogo (`PlatformBackend.PRODUCTS`): `remove_ads`, `supporter_pack` (cosmético) y `expansion_1` (contenido adicional).
- **Nunca** se vende poder, armas necesarias ni progreso esencial.
- Anuncios **solo con recompensa y opcionales**. `Platform.can_show_ad()` los bloquea durante combate, cinemáticas, escalada, planeo, natación, caída y muerte. La lógica vive en la fachada, no en quien la llama.
- Integración: añade el plugin de Google Play Billing y el de StoreKit (godot-ios-plugins) al export. `AndroidBackend` e `IOSBackend` ya los detectan por `Engine.has_singleton`.

## Privacidad
- Analítica **opt-in** (`Settings.analytics_consent`, apagada por defecto). Sin consentimiento no se envía nada.
- Sin cuentas, sin datos personales y sin rastreo entre apps. En iOS no hace falta ATT mientras no haya anuncios con IDFA. Si se añaden, pide ATT antes de inicializar el SDK.
- Datos locales: `user://save_0*.json` (progreso), `user://settings.cfg` y `user://cache/` (terreno regenerable).
- **Google Play Data safety / App Privacy:** hoy se declara "no recopila datos". Si activas analítica o crash reporting: diagnósticos y uso de la app, no vinculados a la identidad, opcionales.

## Borrador de metadatos
- **Nombre:** VELA (provisional) · **Subtítulo:** *Todo horizonte es alcanzable*
- **Descripción corta:** Explora una isla abierta: escala cualquier pared, planea con tu vela y descubre qué esconde cada ruina.
- **Categoría:** Juegos → Aventura · **Clasificación orientativa:** 10+ / PEGI 7 (violencia de fantasía leve)

## Antes de enviar
1. Modelos finales integrados (ver ASSETS.md) y audio final.
2. Pruebas en dispositivos (ver PERFORMANCE.md → pendiente de medir).
3. Crash reporting: plugin nativo (p. ej. Firebase Crashlytics) conectado a `Platform.report_error`.
4. Revisión de textos por hablantes nativos (ja, ko y zh en especial).
5. Subir `version/code` y `application/version`.
