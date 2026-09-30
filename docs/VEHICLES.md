# Vehículos premium: Vantrel Works

Hay tres máquinas raras, difíciles de conseguir y opcionales, todas de la misma marca ficticia. **Vantrel Works** es una casa de ingenieros antiguos cuyas máquinas sobrevivieron a sus creadores. En el mundo aparecen como tecnología avanzada que lleva décadas funcionando, no como ciencia ficción recién salida de fábrica.

Capturas en `docs/captures/vehicles/`:
- `studio_family.png`: las tres juntas.
- Vistas de estudio de cada una.
- `studio_bellhull_water_mode.png`: la cápsula en modo agua.
- Tomas desde la cámara de juego: conducción, salto, lago, noche, garaje y depósito.

## 1. Análisis de referencias (qué se toma y qué no)

| Ref. | Qué tomamos (función) | Qué tomamos (silueta) | Qué NO se copia |
|---|---|---|---|
| 1 · moto futurista de anime | la moto terrestre más rápida, pesada y estable a alta velocidad | ancha, baja, larga, agresiva, rueda trasera grande | el carenado que encierra la rueda delantera, la joroba del asiento con cola, faros, colores, calcomanías, logotipos, proporciones y paneles concretos |
| 2 · moto de juguete a escala | ligera, ágil, suspensión visible, divertida | compacta, horquillas altas, ruedas de tacos, faro cuadrado | la caja, el diseño del juguete, el asiento naranja y la marca |
| 3 · cápsula robot | compacta, rueda grande, ventana frontal, transformación | cuerpo vertical tipo huevo, un solo punto de apoyo | la cabeza del robot, las patas, los números, la antena y el visor concretos |

**La Longwake es una reinterpretación, no una recreación.** Casco bala bajo entre las ruedas, joroba que sube detrás del asiento hasta una cola facetada con dos aletas en flecha, pontones laterales a lo largo de la rueda trasera, y un **pico largo y facetado sobre una rueda delantera expuesta**. No hay carenado envolvente y la geometría es otra.

## 2. Identidad de marca (común a las tres)

- **Plata desgastada** como material principal (`assets/shaders/vehicle_metal.gdshader`):
  - variaciones de tono y zonas opacas;
  - rayones finos y escasos;
  - polvo de camino acumulado en la parte baja;
  - bordes gastados.
  
  No es cromo. El nivel de desgaste va por datos (`wear`).
- **Ruedas negras**: goma más buje de hierro hollín con cinco tornillos. Nunca plateadas.
- **Cristal negro**: casi negro y brillante; solo se leen los reflejos. Nada de azul sci-fi.
- **Hierro hollín** en horquillas, suspensión y mecánica.
- **Detalles de marca recurrentes**:
  - insignia de *disco cortado* (disco de hollín partido por un chevrón plateado);
  - tríos de tornillos hexagonales;
  - tres ranuras finas de panel;
  - un único piloto ámbar pequeño;
  - faro cálido detrás de cristal oscuro.
  
  Sin neón, sin hologramas y sin exceso de LED.
- Las piezas estáticas se fusionan por material (`VehicleVisual.add` y `_commit`), así que cada vehículo cuesta unas 15 llamadas de dibujo.

## 3. Las tres máquinas

| | Velocidad | Agilidad | Saltos | Combate | Agua |
|---|---|---|---|---|---|
| **01 Longwake** (moto pesada) | ★★★★★ 30 m/s (36 con impulso) | ★★★ | ★ | — | — |
| **02 Sparrow** (moto ligera) | ★★★ 19 m/s | ★★★★★ | ★★★★★ | — | — |
| **03 Bellhull** (cápsula anfibia) | ★★ 11 m/s (8,5 en agua) | ★★ | — | ★★★★ | ★★★★★ |

Las velocidades están medidas en la prueba de sistemas. Los valores viven en `data/vehicles.json` (`handling`).

- **Longwake**:
  - acelera fuerte y su giro se abre con la velocidad (curvas amplias);
  - tiene un medidor de impulso que se agota y se regenera;
  - al embestir a enemigos les hace un daño leve y la moto frena;
  - pierde agarre con lluvia o nieve y velocidad en tormentas de arena;
  - no entra en agua profunda.
- **Sparrow**:
  - salto con carga: mantener para agacharse, soltar para saltar (unos 5 m);
  - control en el aire;
  - un aterrizaje limpio da un impulso;
  - las pendientes naturales sirven de rampa.
- **Bellhull**: cambio real entre `land_mode` y `water_mode` (`Vehicle._update_mode`).
  - **Tierra → agua**:
    - detecta agua bajo el casco, con profundidad mayor que `WATER_ENTER_DEPTH`;
    - cambia de modo, lo que emite `EventBus.vehicle_mode_changed`;
    - la rueda se recoge y aparecen el flotador y la hélice;
    - pasa a flotar en su línea de agua, con balanceo;
    - la conducción cambia a inercia, arrastre y giro de barco;
    - la cámara se ajusta;
    - el audio cambia (bucle `hull_water`, salpicadura y transformación) y aparece la estela.
  - **Agua → tierra**: al detectar orilla bajo el casco o delante, vuelve a `land_mode`, despliega la rueda y sale del agua.
  - **Arma**:
    - cañones de barbilla integrados;
    - apuntado asistido hacia el objetivo fijado o el enemigo más cercano en un cono;
    - calor y sobrecalentamiento, y mitad de daño contra jefes.
  - **Casco blindado** (140): los golpes van al casco, no al conductor. Si se rompe, expulsa al conductor y no se puede invocar durante 60 s.

## 4. Cómo se consiguen (difícil, tarde, nunca obligatorio)

Cada máquina se restaura en el **banco del Depósito Vantrel**, un taller de la marca en el desierto profundo (POI `vantrel_depot`, tipo `depot`). La restauración pide el **esquema** y el **núcleo** que da su cadena de misiones, más materiales y destellos. Materiales y piezas se consumen al restaurar.

| Máquina | Misión (requisito) | Qué exige | Coste en banco |
|---|---|---|---|
| Sparrow | `vq_sparrow` (tras `mq_heights_beacon`) | escalar las Agujas por encima de 76 m y volar la línea de pruebas en menos de 26 s | 3 lingotes de hierro, 4 filamentos de fuego fatuo, 500 destellos |
| Longwake | `vq_longwake` (tras `mq_glass_matriarch`) | encontrar el depósito, resistir 80 s oleadas de arena con élites y abrir la nave sellada | 6 lingotes, 6 fragmentos de vidrio, 700 destellos |
| Bellhull | `vq_bellhull` (tras `mq_veil_edge`) | nadar hasta el casco hundido, derrotar 5 sombras y resistir 75 s en el Anillo Hueco | 4 lingotes, 5 esencias de sombra, 900 destellos |

La primera máquina enseña **Llamada Vantrel** (`vehicle_call`, habilidad invocable también desde el botón táctil). Obtener una máquina lanza una fanfarria y la tarjeta de título, la máquina aparece a tu lado al volver al mundo, y en el garaje la vista previa hace un giro de presentación.

## 5. Premium, sin pay-to-win

- Los productos `vehicle_longwake`, `vehicle_sparrow` y `vehicle_bellhull` están en `data/products.json`. Es el catálogo de datos del sistema de monetización existente: `Platform` → `PlatformBackend`, con ids de tienda por plataforma.
- La propiedad es de la cuenta. `Platform.apply_entitlements()` la aplica a cualquier partida al cargar o empezar. Hay **Restaurar compras** en el garaje. No existe un sistema de compra paralelo.
- **Reglas, verificadas en las pruebas:**
  - ninguna misión principal requiere un vehículo;
  - las misiones de vehículos no están en la ruta crítica;
  - las tres máquinas se pueden ganar jugando;
  - el arma de la cápsula es de apoyo (≈ 14 de daño sostenido por segundo) y hace ×0,5 contra jefes;
  - **ninguna máquina entra en un combate contra un jefe**: al empezarlo se baja al conductor y no se puede invocar.
- En el garaje, la compra está rotulada como opcional y se explica que todo el juego es completable sin ella. Si no hay tienda, se indica que todo se restaura jugando.
- Pruebas sin dispositivo: `Platform.backend.sandbox = true`, solo en builds de depuración, simula la tienda.

## 6. Garaje

- Pestaña **Garaje** en el menú de pausa. Desde el banco se abre con la restauración habilitada.
- Lista de máquinas con su estado (bloqueada, en propiedad o equipada) y vista previa 3D giratoria en un soporte con luz de estudio.
- Rol, descripción y cinco características con rombos.
- Estado de propiedad: restaurada o de tienda.
- Checklist de **cómo conseguirla**: misión, piezas y materiales con tengo/necesito, y destellos.
- Botones: equipar, invocar, restaurar (solo en el banco), obtener en tienda y restaurar compras.
- Estilo: el marco, los botones y los colores de la UI del juego. No es una interfaz sci-fi genérica.

## 7. Invocación y mundo abierto

`VehicleManager` es el nodo del mundo:
- **Invocación**:
  - una sola máquina fuera a la vez;
  - nunca hay vehículos aparcados por el mapa;
  - si se deja lejos (más de 320 m), se guarda.
- **Lugar seguro**: se prueban 8 puntos alrededor del jugador y se descartan los que:
  - tienen pendiente excesiva;
  - están en agua (salvo la cápsula);
  - no tienen colisión cargada (streaming);
  - solapan terreno, estructuras, props, criaturas u otros vehículos;
  - tienen NPCs o criaturas a menos de 2,2 m.

  Si ninguno sirve, aparece el aviso "sin espacio".
- **Llegada**: llega una ráfaga de viento y la máquina cae suavemente sobre la suspensión, con polvo y sonido. Es el lenguaje del mundo, no un portal.
- **Mundo**:
  - terreno y pendientes: se alinea al suelo y respeta el límite de subida;
  - agua;
  - obstáculos (choques);
  - clima (agarre y velocidad);
  - día y noche (faro cálido y lente brillante);
  - enemigos: son capa del jugador, reciben sus golpes y proyectiles, y se les puede embestir;
  - NPCs: frena, sin daño;
  - streaming: se detiene sin colisión cargada;
  - respawn y teletransporte: bajan al conductor.
- **Salida**: por el lado con espacio libre; si está en agua, pasa a nadar.

## 8. Móvil

- Física arcade: sin ruedas simuladas ni rigid bodies; un solo `CharacterBody3D` y dos consultas de altura por fotograma para la inclinación.
- Mallas fusionadas por material, materiales compartidos y cacheados, y LOD: detalles a 45 m, cuerpo a 220 m.
- La estela y las partículas escalan con `Quality`. El faro existe solo con calidad media o alta y no proyecta sombras.
- Audio: un bucle de motor por vehículo, con el tono ligado a la velocidad.

## 9. Audio

Se genera con `python3 tools/gen_audio.py --vehicles`; cualquier `.ogg` o `.wav` con el mismo nombre lo reemplaza.

| Sonido | Carácter |
|---|---|
| `engine_heavy` | bicilíndrico grave e irregular con retumbo |
| `engine_light` | monocilíndrico rápido y brillante |
| `engine_capsule` | zumbido electromecánico con tic de engranajes |
| `hull_water` | chapoteo y motor bajo |
| `capsule_transform` | servo, golpe seco y siseo |
| `capsule_fire` | golpe sordo de aire, no un láser |
| `capsule_overheat` | siseo de sobrecalentamiento |
| `vehicle_summon` | ráfaga y golpe metálico |
| `vehicle_jump` | muelle |
| `vehicle_land` | impacto |
| `vehicle_start` | arranque |
| `vehicle_unlock` | fanfarria |

## 10. Contrato para tus modelos finales

En `data/vehicles.json`, por vehículo:
- `model`: tu escena `.tscn` o `.glb`; se instancia **tal cual**;
- `model_scale`, `model_offset`;
- `anim_map`.

Nodos opcionales que el juego anima si existen:

| Nodo | Qué hace el juego |
|---|---|
| `wheel_front`, `wheel_rear`, `wheel_main` | giran con la velocidad |
| `steer` | gira con la dirección |
| `wheel_assembly` | se recoge en agua |
| `float_collar` | se despliega en agua |
| `propeller` | se muestra y gira en agua |
| `socket_seat` | asiento del conductor |
| `socket_muzzle_*` | bocas del arma |

La jugabilidad (colisión, velocidades, arma, modos) está en `handling`, `collider` y `weapon`, y nunca depende del modelo. Reemplazar el modelo no cambia cómo se conduce.

## 11. Pruebas

- **Unit**:
  - roles y jerarquía de velocidades;
  - solo la cápsula tiene arma y es anfibia;
  - límite de daño por segundo;
  - productos no consumibles;
  - fuera de la ruta crítica;
  - marca: plata, goma, cristal negro y hierro;
  - sin vehículos en el mapa.
- **Systems**, en el mundo real:
  - restaurar en el banco;
  - comprar con la tienda simulada;
  - invocar al lado y entrar;
  - velocidades medidas, impulso y salto con carga;
  - cápsula: la más lenta, dispara, calienta;
  - bloqueo en combate contra jefe;
  - invocar nadando, `water_mode` y línea de flotación;
  - volver a la orilla en `land_mode`;
  - puntos de invocación bloqueados;
  - persistencia de propiedad;
  - la compra se reaplica a una partida nueva y lo ganado no.
- **Revisión de arte**: `godot -- --studio <dir> [--water]` renderiza vistas de las tres máquinas; las tomas 36–41 del tour las muestran desde la cámara de juego.

## 8. Builds de prueba: las tres máquinas ya en la cuenta

Los presets de exportación que llevan la marca `preview` (hoy, **Web Preview**) activan la tienda simulada y marcan como propios los tres productos de vehículo (`PlatformServices._enable_preview_entitlements`). Sirve para probarlos sin conseguirlos. Solo en builds de depuración, solo en memoria (no se escribe la caché de compras) y sin efecto en el juego normal ni en los tests. La primera máquina aparece al empezar; el resto se equipan desde el Garaje (pausa → Garaje) y se invocan con Llamada Vantrel.
