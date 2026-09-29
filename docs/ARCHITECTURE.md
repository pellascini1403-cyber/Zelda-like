# Arquitectura

## Principios

1. **Gameplay y representación separados.** Colisión, IA, combate y stats nunca dependen de la malla visual. `EntityVisual` es la única capa que sabe cómo se ve una entidad.
2. **Data-driven.** Todo el contenido vive en `data/*.json`, se carga en clases tipadas (`ItemData`, `EntityType`, `RegionData`, `AttackData`) y se valida con `DB.validate()` (lo ejecutan los tests).
3. **Desacoplado por eventos.** Los sistemas emiten en `EventBus` y la UI, el audio y el guardado escuchan. Las referencias globales (jugador, mundo, cámara) se obtienen por `Game`.
4. **Mobile-first desde la arquitectura.** Streaming por sectores, LOD, rangos de visibilidad, simulación por distancia, pooling y presupuestos por calidad forman parte del diseño, no son parches.
5. **Sin archivos gigantes.** Un sistema por archivo; los estados (jugador e IA) son clases pequeñas.

## Capas

```
┌──────────────────────── UI (src/ui) ─────────────────────────┐
│ HUD · TouchControls · PauseMenu · CookingPanel · Dialogue    │
└──────────────▲───────────────────────────────▲───────────────┘
               │ EventBus (señales)            │ lecturas
┌──────────────┴──────── Gameplay ─────────────┴───────────────┐
│ Player (estados + Combat + Vitals + Interactor)              │
│ Creature → Enemy / Animal / NPC  (AIBrain + estados)         │
│ Interactables · PhysicsProp · FireSource · Projectile        │
│ Crafting · Cooking                                           │
└──────────────▲───────────────────────────────▲───────────────┘
               │                               │
┌──────────────┴──────── Mundo ────────────────┴───────────────┐
│ GameWorld → WorldStreamer (hilos) → TerrainChunk             │
│           → HorizonTiles · WaterSurface · PoiManager         │
│           → SpawnDirector · AIManager · Environment · Weather│
└──────────────▲───────────────────────────────────────────────┘
               │
┌──────────────┴──────── Autoloads (servicios) ────────────────┐
│ EventBus DB Settings Quality InputRouter Game Clock Weather  │
│ PlayerData WorldState SaveSystem Audio Platform Debug        │
└──────────────────────────────────────────────────────────────┘
```

## Autoloads

| Autoload | Responsabilidad |
|---|---|
| `EventBus` | Señales globales (daño, objetos, descubrimientos, clima, UI…) |
| `DB` | Carga y valida `data/*.json`; `roll_loot()` |
| `Settings` | Preferencias en `user://settings.cfg`; idioma |
| `Quality` | Presets LOW–ULTRA, detección de dispositivo, resolución dinámica, gobernador térmico, FPS |
| `InputRouter` | Unifica táctil, teclado/ratón y mando en acciones + vector de movimiento + delta de cámara |
| `Game` | Flujo (menú, carga, juego, pausa), referencias, *flag* de combate, *hitstop* y cámara lenta |
| `Clock` | Hora del mundo, periodos (amanecer/día/atardecer/noche) |
| `Weather` | Simulación del clima por región, viento, humedad y rayos (solo estado) |
| `PlayerData` | Ficha persistente: inventario, equipo, vitales, buffs, recetario |
| `WorldState` | Hechos persistentes del mundo: recolectado, abierto, derrotado, descubierto, niebla del mapa |
| `SaveSystem` | Guardado atómico + backup, autosave, migraciones |
| `Audio` | Música con crossfade, capas de ambiente, SFX con pooling |
| `Platform` | Fachada iOS/Android/escritorio (IAP, anuncios, analítica, térmica) |
| `Debug` | Herramientas de desarrollo; inerte en builds release |

## Secuencia de carga (`GameWorld._start`)

1. `IslandMap` (hilo): campo de alturas de 257² (cacheado en `user://`) + mapa pintado.
2. `HorizonTiles` (hilo): 8×8 baldosas de 256 m + árboles impostores.
3. Agua, entorno (sol/luna, cielo, niebla) y FX de clima.
4. Streamer, spawns, POIs y gestor de IA.
5. Estado global desde el guardado (o partida nueva).
6. Jugador + cámara; HUD.
7. Espera a que haya colisión bajo el jugador → lo coloca sobre el suelo → `PLAYING`.

## Cómo añadir contenido (sin tocar sistemas)

| Quiero añadir… | Edita |
|---|---|
| Un arma, armadura, comida, material u objeto | `data/items.json` (+ nombre y descripción en `tools/loc_items.py`) |
| Una especie de enemigo o animal | `data/entities.json` (color placeholder único, collider, stats, IA, ataques, botín) |
| Dónde aparece | `data/regions.json` (`enemy_spawns`, `animal_spawns`, `resources`) |
| Un recurso recolectable | `data/resource_nodes.json` + tabla en `data/loot.json` |
| Una receta | `data/crafting.json` (fabricación) o `data/cooking.json` (especiales / etiquetas) |
| Un lugar (laberinto, campamento…) | `data/world.json` → `pois` (tipos existentes en `StructureBuilder`) |
| Un tipo de clima | `data/weather.json` y pesos en las regiones |
| Textos | `tools/loc_*.py` → `python3 tools/gen_localization.py` |

`godot --headless -- --unit` valida referencias cruzadas y traducciones tras cualquier cambio.
