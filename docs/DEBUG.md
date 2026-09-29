# Herramientas de debug

Disponibles **solo en builds de depuración** (`OS.is_debug_build()`). En *release*, el autoload `Debug` desactiva su proceso, no crea UI y sus *flags* (`god_mode`, `infinite_stamina`…) quedan en falso. Los scripts de `tests/` se excluyen de los presets móviles.

Abrir: **F1** o **`** en escritorio; **toque con 3 dedos** en el dispositivo.

| Comando | Efecto |
|---|---|
| `help` | lista de comandos |
| `tp x z` / `tp <poi_id>` | teletransporte (p. ej. `tp needles`, `tp cendal_summit`) |
| `spawn <ENTITY_ID> [n]` | aparece una entidad delante (p. ej. `spawn ENEMY_BULWARK`, `spawn BOSS_STILLWAKE_WARDEN`) |
| `give <item_id> [n]` | añade objetos |
| `weather <id>` | clear, cloudy, rain, storm, fog, windy, snow |
| `time <hora>` | fija la hora (0–24) |
| `god` / `stamina` | invulnerable / aguante infinito |
| `map` | revela el mapa completo |
| `kill` / `heal` | mata a los enemigos cercanos / cura |
| `quality 0-3` | cambia el preset |
| `ents` | etiquetas de entidad: id, estado de IA, HP y objetivo |
| `fps` | overlay de rendimiento |
| `touch` | fuerza los controles táctiles en escritorio |
| `save` / `load` | guarda / recarga desde el guardado |

**Overlay:** FPS, frame time y objetivo · draw calls, primitivas y objetos · memoria · física · preset, escala de render y térmica · sectores, trabajos, POIs y fuegos · IA por nivel con su coste · posición, estado, región y periodo. También se activa con *Ajustes → Mostrar FPS*.

**Automatización:** `-- --unit`, `-- --smoke` y `-- --tour <dir>` (ver BUILD.md). `Debug.run("<comando>")` se usa desde los tests.
