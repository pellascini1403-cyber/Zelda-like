# Rendimiento móvil

## Renderer
- **Mobile** (Vulkan en Android, Metal en iOS) con *fallback* automático a **Compatibility** (GLES3) en dispositivos sin Vulkan fiable (`rendering_device/fallback_to_opengl3`).
- Todos los shaders (terreno, follaje, hierba, agua, cielo, placeholder) evitan buffers de profundidad y pantalla: se comportan igual en ambos renderers.
- Compresión de texturas ETC2/ASTC activada.

## Cómo se abarata el mundo

| Técnica | Dónde |
|---|---|
| Streaming por sectores en hilos, aplicación con presupuesto por frame | `WorldStreamer` |
| LOD de terreno: 2 m (LOD0) → 4 m (LOD1) → baldosas de 8 m (lejos) con faldones anti-grietas | `ChunkBuilder`, `HorizonTiles` |
| HLOD de árboles por `visibility_range` (completo → simplificado → impostor lejano) | `TerrainChunk`, `HorizonTiles` |
| Vegetación con MultiMesh; hierba con encogimiento por distancia en el shader (sin alpha) | `grass.gdshader` |
| Materiales compartidos, estructuras en **1 malla + 1 cuerpo** cada una | `WorldMaterials`, `StructureKit` |
| IA por distancia: completa / reducida (1/4) / dormida | `AIManager` |
| Física dormida o congelada lejos (props a > 70 m), proyectiles por raycast (sin cuerpos) | `PhysicsProp`, `Projectile` |
| Partículas con pool y cantidad por calidad | `Effects`, `WeatherFX`, `FireSource` |
| Luces dinámicas limitadas (fuegos ≤ 4, luces nocturnas por grupo), sin sombras omni | `FireSource`, `EnvironmentController` |
| Una luz direccional con sombras (sol ↔ luna, PSSM de 2 cortes con distancia por calidad) y dos rellenos direccionales **sin sombra ni especular** (cielo y rebote del suelo) | `EnvironmentController` |
| Sombra de dosel, manchas de sol, humedad y contacto con el suelo desde **dos texturas globales de 385²** (máscaras y alturas de la isla), sin buffers de profundidad | `IslandMap`, `world_light.gdshaderinc` |
| Hojas de los árboles como **geometría opaca** (sin *alpha test*, que en GPUs TBDR anula la eliminación de superficies ocultas); 3 variantes por especie instanciadas por sector; densidad de hojas por calidad (0,55 / 0,75 / 1,0) | `TreeKit`, `leaf.gdshader` |
| Sombra de contacto: 1 quad compartido por entidad, 1 rayo cada 1–3 frames, oculta a > 45 m | `BlobShadow` |
| Cielo con radiancia incremental de 64 px; sin reflejos de cielo en LOW | `EnvironmentController` |
| LOD visual de placeholders (extremidades ocultas a > 40 m) | `EntityVisual` |
| **Lotes por sector**: todos los árboles simplificados (9 especies) en 1 malla, arbustos pequeños en 1 malla, horneados en el hilo de streaming; el shader `baked` conserva el balanceo y el tono por planta | `ChunkBuilder.bake_batch`, `foliage.gdshader` |
| Árboles impostores de cada baldosa lejana en 1 malla | `HorizonTiles` |
| **HLOD de estructuras**: malla cercana detallada + malla lejana simplificada (sin costillas, ménsulas, celosías, balaustres ni cintas), 1 material para toda la arquitectura (alfa del vértice = tipo de superficie) | `StructureKit`, `architecture.gdshader` |
| Bancos de niebla: todas las tarjetas en 1 malla con billboard por vértice | `MistBanks`, `mist.gdshader` |
| Capas de partículas de clima invisibles cuando no emiten | `WeatherFX` |
| Jefes, monturas y eventos solo existen cerca del jugador (streaming propio) | `BossManager`, `MountManager`, `WorldEventDirector` |
| Telegrafías y anillos de impacto en pool (quads aditivos) | `Telegraph`, `ElementFX` |

## Calidad adaptativa (`Quality`)

| | LOW | MEDIUM | HIGH | ULTRA |
|---|---|---|---|---|
| Escala de render | 0,70 | 0,80 | 0,90 | 1,0 |
| Sombras (distancia / atlas) | 35 m / 1024 | 55 m / 2048 | 80 m / 2048 | 120 m / 4096 |
| Anillos LOD0 / LOD1 | 1 / 2 | 1 / 3 | 2 / 3 | 2 / 4 |
| Vegetación (densidad / distancia) | 0,35 / 35 m | 0,6 / 45 m | 0,85 / 55 m | 1,0 / 70 m |
| Partículas | 35 % | 60 % | 85 % | 100 % |
| IA completa / reducida | 40 / 90 m | 50 / 110 m | 60 / 130 m | 70 / 150 m |

- **Detección automática:** familia de GPU (Adreno, Mali, Immortalis, Xclipse, PowerVR), núcleos y modelo de iPhone/iPad. Siempre se puede elegir a mano en Ajustes.
- **Resolución dinámica:** si la media de frames supera el presupuesto en un 12 % durante 1 s, baja la escala un 7 % (mínimo 0,72); la recupera despacio tras 4 s con margen.
- **Gobernador térmico:** usa el estado térmico del SO si hay plugin (`VelaThermal`). Si no, trata como *throttling* ≥ 20 s seguidos de frames lentos a escala mínima y baja un preset. Prioriza estabilidad durante 30–60 min.
- **FPS:** 60 por defecto; 30 con ahorro de batería o estado térmico serio. 30 estables es preferible a 60 inestables.

## Mediciones (capturas de referencia, 1600×900)

Renderer Mobile por software (llvmpipe). Los conteos son del frame completo, **sombras incluidas**. Sirven para comparar, no son tiempos de dispositivo.

| Escena | HIGH etapa 1 | HIGH etapa 2 | LOW etapa 1 | LOW etapa 2 |
|---|---|---|---|---|
| Aldea, mañana | 275 / 292k | 323 / 497k | 201 / 209k | 242 / 341k |
| Vista a la montaña | 229 / 277k | 276 / 410k | 157 / 165k | 201 / 258k |
| Agujas de roca | 217 / 222k | 277 / 360k | 129 / 158k | 166 / 220k |
| Bosque con lluvia | 288 / 330k | 355 / 510k | 153 / 172k | 184 / 232k |
| Lago al atardecer | 116 / 226k | 164 / 299k | 75 / 117k | 104 / 191k |
| Campamento de noche | 177 / 219k | 314 / 444k | 138 / 157k | 213 / 262k |
| Planeando sobre el macizo | 140 / 155k | 207 / 305k | 90 / 113k | 140 / 241k |
| Puente (nuevo) | — | 180 / 311k | — | 116 / 205k |
| Jefe en su arena (nuevo, con HUD) | — | 366 / 376k | — | 294 / 269k |

Formato: draw calls / primitivas. La etapa 2 añade arquitectura con aleros, 9 especies de árbol, bancos de niebla, cascadas, partículas de ambiente y jefes. El sobrecoste frente a la etapa 1 (+15–25 % en draw calls en la mayoría de escenas) se contuvo sin quitar detalle: lotes de vegetación por sector y por baldosa (−10 %), niebla en una malla y capas de partículas ociosas ocultas (−5 %). Los *objects* mayores que los draw calls en escenas con HUD corresponden a elementos 2D.

Antes de las optimizaciones de HLOD y baldosas, la escena del bosque costaba 768 draw calls y 598k primitivas.

### Etapa 3: pasada de entorno (árboles orgánicos, suelo vivo, luz y agua)

| Escena | HIGH antes | HIGH después | MEDIUM antes | MEDIUM después | LOW después |
|---|---|---|---|---|---|
| Aldea, mañana | 557 / 508k | 557 / 764k | 475 / 418k | 482 / 543k | 455 / 409k |
| Bosque (vista del suelo) | 333 / 438k | 342 / 1000k | 362 / 337k | 362 / 466k | 319 / 371k |
| Vista a la montaña | 309 / 400k | 350 / 719k | — | — | — |
| Combate en la aldea (HUD) | 680 / 473k | 682 / 627k | — | — | — |

Formato: draw calls / primitivas, Mobile por software, 1600×900.
- **Draw calls:** prácticamente iguales. Las variantes de árbol añaden como mucho 2 MultiMesh por especie y sector, compensados por los lotes.
- **Primitivas:** suben entre un +30 y un +40 % en MEDIUM (el preset por defecto en móviles de gama media) y entre un +50 y un +130 % en HIGH dentro del bosque. Las causas son las hojas geométricas, las matas de hierba más llenas y los objetos nuevos del suelo.
- **Palancas si un dispositivo no llega:** densidad de hojas por calidad (`TreeKit.detail_level`), `vegetation_density` y `vegetation_distance` del preset, y las hojas por mata de hierba (`MeshKit._grass`). Ninguna requiere tocar el diseño.

**Pendiente de medir en dispositivos reales** (no hay hardware móvil en este entorno): FPS sostenido, tiempo de GPU y temperatura en un Android de gama baja (Adreno 610 / Mali-G52), un Android de gama media, un iPhone 12 o posterior y un iPad. Usa la consola de debug (`fps`) y el perfilador remoto del editor.

## Herramientas
- Overlay de debug: FPS, frame time, draw calls, primitivas, memoria (estática, vídeo, texturas), física, sectores y trabajos, POIs, fuegos, IA por nivel con su coste en ms, escala de render y estado térmico.
- `--tour <dir> --quality N` renderiza las escenas de referencia e imprime sus costes.

## Checklist para contenido nuevo
¿Coste de CPU, GPU y memoria? ¿Tiene que ejecutarse siempre? ¿Puede depender de la distancia, usar pool o LOD, o simplificarse fuera de cámara? ¿El jugador nota la diferencia?
