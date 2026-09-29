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

## Misiones — `Quests` (autoload), `data/quests.json`
Una misión es una lista de **etapas**; una etapa termina cuando todos sus **objetivos** se cumplen. Estados: bloqueada (faltan `requires`) → disponible → activa → completada. `start`: `auto`, `talk:<NPC>` (ofrece la misión al hablar) o `event` (empieza sola al cumplirse su primer objetivo, p. ej. descubrir un lugar).
Tipos de objetivo: `talk, discover, kill, collect, open_chest, boss, flag, ability, region, reach, cook, mount`. Todos escuchan `EventBus` (nadie más conoce las misiones) salvo `reach`, que sondea la posición cada 0,5 s. Al entrar en una etapa se re-evalúa el estado actual (objetos ya en la mochila, lugares ya descubiertos, jefes ya vencidos).
Recompensas: objetos, destellos (moneda), habilidad, flag, +aguante, +vida. Diálogos por etapa (`talk_lines`, `hint_lines`, `offer_lines`). UI: rastreador en el HUD, diamante dorado en brújula y mapa (`tracked_target()`), pestaña **Diario** (activas/completadas, objetivos, recompensas, "Seguir") y tarjetas de título al empezar/terminar. Guardado: sección `quests` (versión de guardado 2, migración desde la 1).

## Jefes — `Boss`, `BossBrain`, `BossManager`, `data/bosses.json`
El cuerpo del jefe es una entidad normal (`entities.json`: stats, collider, ataques); `bosses.json` añade arena (centro, radio, casa), fases (umbral de vida, ataques permitidos, velocidad, onda de choque, invocaciones, clima), elemento y recompensas. Flujo: **latente** hasta que el jugador entra en la arena → **intro** (rugido, tarjeta de título, placa de vida, música de jefe) → combate → cambio de fase (invulnerable 1,8 s, onda que aparta, invocaciones) → derrota (flag `boss_<ID>`, cofre en el centro, tarjeta). Salir de la arena (1,7× radio) reinicia el combate. `BossManager` crea el jefe solo a <180 m y lo libera a >260 m si no está en combate (streaming).
Tres jefes: **Centinela Espinazo** (Templo de las Terrazas de Nube; 2 fases), **Matriarca de Vidrio** (Hondonada de Vidrio, desierto; 3 fases, tormenta de arena), **Guardián de la Quietud** (Corazón Quieto, isla en el lago del Velo; 3 fases).
Ataques nuevos disponibles para cualquier criatura: `charge` (embestida en línea), `volley` (abanico de proyectiles), `eruption` (círculos bajo el jugador que estallan tras un retardo), `summon`. Los ataques pesados muestran **telegrafías** en el suelo (`Telegraph`: disco, línea o cono que se llena hasta el impacto; pool de 12 quads aditivos).

## Habilidades — `PlayerAbilities`, `data/abilities.json`
Se obtienen por misiones y se usan con la acción `ability` (V / gatillo derecho / botón táctil con glifo y barrido de enfriamiento); `cycle_ability` cambia. **Paso de Ráfaga** (dash aéreo con invulnerabilidad breve; recupera el salto aéreo), **Peldaño de Jade** (losa temporal bajo los pies en el aire o un escalón delante; máx. 2), **Vista del Viento** (revela cofres, recursos y lugares no descubiertos con glifos a través de paredes), **Quietud** (`Game.enemy_time_scale` ralentiza IA y proyectiles hostiles; el jugador no), **Llamada del Zancaviento** (silbato de montura). Coste de aguante y enfriamiento por datos.

## Montura — `Mount`, `RideState`, `MountManager`
El Zancaviento salvaje pace en manada (`world.json → mounts`) y huye si lo asustas. Monta sin que te vea: corcovea 3 s y consume tu aguante; si aguantas, queda domado (flag `mount_windstrider`, misión, tarjeta). Montado: caminar/trote/galope, espuelas limitadas que se regeneran (sprint), salto, bajar con interactuar; un golpe fuerte te derriba. La montura domada persiste (posición guardada), no la libera el streaming y acude al silbato (si está lejos aparece fuera de cámara). Los números de juego están en `entities.json → mount`.

## Puzzles — `src/puzzles/`
`PuzzleGroup` coordina elementos (`Brazier`, `PressurePlate`, `VeilAnchor`) por `puzzle_id`; cuando todos están activos se guarda `puzzle_<id>` y los `WindSeal` (barreras de viento alrededor de la recompensa) se deshacen. Braseros: se encienden con cualquier fuego (armas de fuego, hierba ardiendo, explosiones) o con pedernal. Placas: se pulsan con jugador, criaturas o cajas pesadas. Los laberintos declaran su puzzle en datos (`"puzzle": {"type": "braziers"|"plates", "count": n}`). Las anclas del Velo exigen expulsar antes a sus guardianes.

## Comercio — `ShopPanel`, `data/shops.json`
Los fragmentos de destello son la moneda (van a la bolsa, no al inventario). Cada tienda tiene NPC, stock limitado persistente, precios y tasa de venta; algunos objetos aparecen tras hitos (`requires_flag`). Se abre con el botón **Comerciar** del diálogo.

## Eventos dinámicos — `WorldEventDirector`, `data/world_events.json`
Cada hora de juego se tira por evento si el jugador está en sus regiones y el periodo coincide. *Recompensa*: grieta de viento / estrella caída (baliza visible a distancia, marcador en brújula y mapa; alcanzarla paga). *Aparición*: emboscada nocturna, enjambre de arena, oleada del Velo. Todo se libera al terminar o al alejarse.

## Regiones nuevas
**Confín Solquemado (desierto):** dunas, mesetas escalonadas, oasis; 38 °C de día (calor: ropa y platos frescos), tormentas de arena (niebla cálida, partículas, visibilidad), correplayas, cactus y afloramientos de vidrio; Oasis Solquemado (caravana, tienda), Cripta del Sol (laberinto de arenisca con 4 braseros), Hondonada de Vidrio (jefe). **Confines del Velo (sobrenatural):** cráter con lago inmóvil que brilla de noche, vetas de jade en el suelo, cintas en el cielo, sombras calladas y fuegos fatuos, cristales, **Islas a la Deriva** (espiral flotante con **campo de levedad** que reduce la gravedad), tres anclas y el Corazón Quieto. Istmos de tierra los unen a la isla principal: se llega caminando.

## Arquitectura — `StructureKit`, `assets/shaders/architecture.gdshader`
Gramática original de los "Guardianes del Viento" (ver ART_DIRECTION): tejados a cuatro aguas con perfil cóncavo y esquinas alzadas, remates en forma de vela, costillas de teja vidriada, aleros claros, columnas bermellón sobre tambores de piedra con capiteles de jade, ménsulas, paneles con celosía, terrazas con balaustrada y escalinatas (colisión en rampa), pagodas, pabellones hexagonales, puertas del viento, puentes en arco, farolillos hexagonales y cintas de tela que ondean con el viento (shader). Cada estructura son **2 draw calls** (malla cercana + malla lejana simplificada = HLOD de estructura) y un único cuerpo estático. El alfa del color de vértice codifica el material (mate, vidriado, dorado, tela, farol), así un solo material cubre todo.

## Feedback de combate
Estela del arma (cinta aditiva), anillos de impacto por elemento, onda de parada, *afterimages* al esquivar a tiempo y con Paso de Ráfaga, disolución de las criaturas al morir, telegrafías, sacudida de cámara y hit-stop existentes. Todo en pools.

## Animación
`EntityVisual.LOGICAL` enumera todos los estados lógicos (incluye `land`, `ledge_climb`, `parry`, `ride`, `roar`); `FALLBACK` define a qué clip recurrir si el modelo no tiene uno. Soporta `AnimationPlayer` o un `AnimationTree` con máquina de estados (`travel`) y parámetro `speed`. Los maniquíes tienen inclinación en giros, respiración, aplastamiento al aterrizar y poses de trepar cornisa, parada, montar y rugido.

## Localización
`tools/loc_ui.py`, `loc_content.py`, `loc_items.py`, `loc_world2.py` y `loc_quests.py` → `gen_localization.py` → `localization/strings.csv` (en, es, pt, fr, de, ja, ko, zh). CJK usa `SystemFont` como fallback. Ningún texto está escrito en el código: un test verifica que toda clave usada existe en los 8 idiomas.
