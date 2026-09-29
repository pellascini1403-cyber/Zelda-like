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
| Una sola luz direccional (sol ↔ luna), sombras PSSM de 2 cortes con distancia por calidad | `EnvironmentController` |
| Cielo con radiancia incremental de 64 px; sin reflejos de cielo en LOW | `EnvironmentController` |
| LOD visual de placeholders (extremidades ocultas a > 40 m) | `EntityVisual` |

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

| Escena | HIGH draw calls / primitivas | LOW draw calls / primitivas |
|---|---|---|
| Aldea, mañana | 275 / 292k | 201 / 209k |
| Vista a la montaña | 229 / 277k | 157 / 165k |
| Agujas de roca | 217 / 222k | 129 / 158k |
| Bosque con lluvia | 288 / 330k | 153 / 172k |
| Lago al atardecer | 116 / 226k | 75 / 117k |
| Campamento de noche | 177 / 219k | 138 / 157k |
| Planeando sobre el macizo | 140 / 155k | 90 / 113k |
| Combate con 4 criaturas placeholder | 336 / 297k | 263 / 218k |

Antes de las optimizaciones de HLOD y baldosas, la escena del bosque costaba 768 draw calls y 598k primitivas.

**Pendiente de medir en dispositivos reales** (no hay hardware móvil en este entorno): FPS sostenido, tiempo de GPU y temperatura en un Android de gama baja (Adreno 610 / Mali-G52), un Android de gama media, un iPhone 12 o posterior y un iPad. Usa la consola de debug (`fps`) y el perfilador remoto del editor.

## Herramientas
- Overlay de debug: FPS, frame time, draw calls, primitivas, memoria (estática, vídeo, texturas), física, sectores y trabajos, POIs, fuegos, IA por nivel con su coste en ms, escala de render y estado térmico.
- `--tour <dir> --quality N` renderiza las escenas de referencia e imprime sus costes.

## Checklist para contenido nuevo
¿Coste de CPU, GPU y memoria? ¿Tiene que ejecutarse siempre? ¿Puede depender de la distancia, usar pool o LOD, o simplificarse fuera de cámara? ¿El jugador nota la diferencia?
