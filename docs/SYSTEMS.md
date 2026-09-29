# Sistemas

Cada sección: **propósito · dependencias · uso · extensión**.

## Streaming del mundo — `src/world/terrain/`
- **Propósito:** mundo continuo sin cargarlo entero. Sectores de 64 m en anillos: LOD0 (rejilla de 2 m, colisión, vegetación completa, contenido jugable) y LOD1 (4 m, árboles simplificados). Más allá, `HorizonTiles` (8 m + árboles impostores).
- **Dependencias:** `WorldGen` (muestreador determinista y thread-safe), `ChunkBuilder` (datos en hilos), `Quality` (radios).
- **Uso:** `GameWorld` crea `WorldStreamer` y le asigna `focus`. Los resultados se aplican con presupuesto por frame (≈1,8 ms). El LOD viejo permanece hasta que llega el nuevo, así nunca hay huecos. La baldosa lejana se oculta cuando sus 16 sectores están cubiertos.
- **Extensión:** para sectores hechos a mano, sustituye `ChunkBuilder.build` por un proveedor que devuelva los mismos arrays (malla, colisión, vegetación, slots). `WorldGen` define la geografía: montaña, meseta, lago, río y plataformas de POI.

## Jugador — `src/player/`
- **Propósito:** movimiento con peso y respuesta. Estados: `ground`, `air`, `climb`, `glide`, `swim`, `dodge`, `busy`, `dead`, cada uno en su propio archivo.
- **Dependencias:** `InputRouter`, `CameraRig`, `PlayerData`, `PlayerVitals`, `PlayerCombat`, `Interactor`.
- **Uso:** los estados devuelven el siguiente estado. Los helpers compartidos (`probe_wall`, `find_ledge_top`, `apply_horizontal`…) están en `Player`. Guarda de streaming: si el suelo aún no tiene colisión, el jugador se queda quieto.
- **Extensión:** añade un `PlayerState`, regístralo en `Player._ready`, y los efectos se integran solos (animación vía `anim()`, guardado vía `save_state`).

## Escalada — `climb_state.gd`
Cualquier superficie con normal.y < 0,6 (acantilados, agujas, troncos, muros). Consume aguante al moverse y poco al estar quieto. El salto de escalada cuesta un bloque de aguante. Trepa al borde automáticamente. Con lluvia (`Weather.wetness`) resbala periódicamente. A 0 de aguante, suelta.

## Planeador (Vela de Brisa) — `glide_state.gd`
Se abre saltando en el aire con al menos 2,6 m de altura libre. Tiene inercia en los giros, deriva con `Weather.wind` y gana sustentación en grupos `updraft` (`UpdraftZone` en miradores y cualquier `FireSource`). El hilo de corriente reduce el consumo un 40 %.

## Combate — `src/player/player_combat.gd`, `src/combat/`
- Consultas de arco y esfera contra cuerpos (no hitboxes animadas), para que cambiar modelos o animaciones no rompa el combate.
- `DamageInfo` transporta daño, elemento, empuje, poise, bloqueable y tipo. `Health` gestiona poise y estados (`burning`, `wet`, `shocked`, `chilled`).
- Parry: bloquear ≤0,2 s antes del golpe aturde al atacante y refleja proyectiles. Esquiva perfecta: golpe recibido en la ventana temprana de la esquiva → cámara lenta y aguante.
- Durabilidad: −1 por golpe conectado. Aviso al 25 %. Al romperse se equipa automáticamente la mejor arma restante. Las reliquias se mellan (mitad de daño) en vez de romperse.

## IA — `src/ai/`
- `Creature` (cuerpo común) → `Enemy`, `Animal`, `NPC`. `AIBrain` + estados en `src/ai/states/`.
- `Perception`: vista (rango, FOV, línea de visión, reducida de noche, con niebla o dormido) y oído (`EventBus.noise_emitted`). La consciencia crece de forma gradual: permite sigilo y ataque sorpresa x2.
- `AIManager`: FULL (cada frame), REDUCED (cada 4 frames con delta acumulado) y DORMANT (sin tick, animación pausada) según la distancia de `Quality`.
- **Extensión:** una especie nueva se define solo con datos (ataques, rangos, huida, sueño, periodo activo). Un comportamiento nuevo = un `AIState` nuevo más su registro en el cerebro.

## Mundo vivo — `SpawnDirector`, `PoiManager`, `AnimalBrain`, `NPCBrain`
- Cada sector tiene 7 *slots* deterministas. Según la región se convierten en recursos, manadas, grupos enemigos o props. Lo recolectado y lo derrotado se recuerda con temporizador de reaparición.
- Los POIs se construyen a ≤650 m para que su silueta atraiga desde lejos. Sus criaturas se activan a ≤110 m y se descubren al entrar en su radio.
- Las criaturas que pelean cuando su sector se descarga quedan "huérfanas" hasta calmarse.

## Sandbox sistémico — `src/physics/`, `data/elements.json`
| Regla | Implementación |
|---|---|
| Fuego + madera/hierba | `FireSource` quema vecinos, se propaga por hierba seca (límite global de 18), madera arde y se rompe |
| Fuego → aire | Térmica para el planeador (`lift_at`) |
| Lluvia / agua → fuego | Vida del fuego acelerada; se apaga en el agua; no prende con lluvia |
| Electricidad + mojado | Daño x2 |
| Electricidad + metal | Conduce a criaturas cercanas |
| Tormenta + metal equipado | Aviso visual y háptico, rayo 2,6 s después (el amuleto de magnetita lo evita) |
| Viento | Deriva del planeador, proyectiles lanzados, hierba y árboles, lluvia |
| Explosión | Daño con caída, impulso físico, fuego, ruido que alerta a la IA |

## Clima y día/noche — `Weather`, `Clock`, `EnvironmentController`, `WeatherFX`
El estado (simulación) está separado de la presentación. Una sola luz direccional (sol o luna), un `Environment` y un cielo por shader; las luces nocturnas van por grupo. Parámetros globales de shader: `wetness`, `snow_amount`, `wind_vec` y `player_pos`.

## Inventario, equipo y progresión — `PlayerData`, `Inventory`, `ItemStack`
Categorías con capacidad. Los *stacks* llevan datos por instancia (durabilidad, potencia del plato). Espacios de equipo: arma, cabeza, cuerpo, piernas y accesorio. Los sets dan bonus (`world.json → armor_sets`). La progresión no usa niveles: semillas de vida y flores de aguante (cofres de POIs), equipo con propiedades, conocimiento de recetas y mejoras de la Vela.

## Cocina y fabricación — `src/crafting/`
`Cooking.resolve()` es una función pura: aplica recetas especiales, luego la etiqueta dominante, y una etiqueta rival fuerte arruina el plato. La potencia tiene tope. El recetario registra lo descubierto. `Crafting` admite estaciones (`campfire`).

## Guardado — `SaveSystem`
Autosave cada 90 s fuera de combate, al pasar a segundo plano o cerrar. Guardado manual. JSON versionado, escritura temporal seguida de renombrado y backup rotativo; si el principal está corrupto, se usa el backup. Nunca guarda una posición en el aire (usa el último suelo seguro).

## Audio — `Audio`
La música la elige `GameWorld` (combate > noche > altura > día) con crossfade de 3,5 s. Hay 4 capas de ambiente mezcladas por clima y hora, y SFX 3D con un pool de 16 voces. Todo se resuelve por id → `assets/audio/<id>.ogg|wav`.

## Localización
`tools/loc_ui.py`, `loc_content.py` y `loc_items.py` → `gen_localization.py` → `localization/strings.csv` (en, es, pt, fr, de, ja, ko, zh). CJK usa `SystemFont` como fallback. Ningún texto está escrito en el código: un test verifica que toda clave usada existe en los 8 idiomas.
