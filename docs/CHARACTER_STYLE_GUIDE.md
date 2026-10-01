# Guía de estilo de personajes, NPCs y enemigos

Objetivo: cualquier enemigo, de cualquier especie, se reconoce como **"esto pertenece a este juego"**, y cualquier humano como **"estos personajes pertenecen al mismo mundo"**.

Prioridad: **coherencia visual, originalidad, siluetas fuertes, identidad y legibilidad en móvil.**

Datos: `data/art_style.json` (tokens) y `data/visuals.json` (perfil por entidad).

Código:
- `src/data/art_style.gd` (materiales, colores, validación).
- `src/entities/mannequin_builder.gd` (PLACEHOLDER — diseño final pendiente).
- `src/entities/creature_builder.gd`.

Capturas desde la cámara de juego: `docs/captures/characters/`.

---

## 1. Qué tomamos de las referencias (y qué no)

Las referencias se analizaron para extraer **reglas**. No se copió ningún personaje, criatura, armadura, arma, símbolo, pose ni efecto.

| Referencia | Qué es | Reglas que extraemos | Lo que NO tomamos |
|---|---|---|---|
| 1 · Monstruos de sombra | Lenguaje de enemigos | Oscuridad dominante; formas agudas y angulares; extremidades afiladas; energía sobrenatural alrededor del cuerpo (fuego, humo, partículas); contraste negro/brillo; presencia amenazante; criaturas "corrompidas" | Diseños, siluetas reconocibles, armaduras, armas, escenas, efectos concretos, la paleta exacta |
| 2–5 · Personajes chibi | Proporción y volumen de humanos | Cabeza grande; cuerpo compacto; extremidades cortas y estilizadas; manos y pies grandes; siluetas limpias; 3D de juego moderno y atractivo | Personajes, ropa, colores, peinados, accesorios, identidad, logos |

**Nuestra síntesis** es otra cosa: nuestro mundo (fantasía china del viento y del Stillwake) + nuestra paleta + nuestro diseño de criaturas + nuestro chibi. El violeta es la energía del Stillwake, el silencio que corrompe. No es "aura de sombras".

---

## 2. Familias

| Familia | Quién | Forma | Color |
|---|---|---|---|
| `human` | jugador, NPCs | estilizado y esbelto (maniquí placeholder) | color sólido propio del placeholder (piel más clara, pelo/cuero más oscuro) |
| `enemy` | todos los enemigos y jefes | facetado, angular, puntiagudo | **negro + violeta** |
| `wildlife` | fauna y monturas | redondo, tranquilo | color sólido propio, **sin violeta** |

Las familias se contraponen a propósito. Redondo y suave significa amigo. Facetado, negro y violeta significa amenaza. La fauna nunca usa violeta, así el jugador aprende el código.

---

## 3. Enemigos: reglas

### 3.1 Negro como elemento principal

El cuerpo es negro, carbón o gris muy oscuro (`enemy_body` / `enemy_body_hi`), pero **nunca negro plano**. El volumen sale de:
- variación tonal;
- rugosidad 0.4 con brillo especular (reflejos);
- facetas visibles;
- un **borde violeta** (fresnel) que separa la silueta de fondos oscuros.

El color único de la especie sobrevive como un matiz del 10 % (`species_tint`). Sirve para distinguir en debug, no para leer la especie.

### 3.2 Violeta: la energía sobrenatural

Se usa en ojos, grietas y venas, puntas de cuernos, fuego en cuernos, núcleos, cristales, aura, ataques, proyectiles, telegraphs, disolución al morir y la luz del jefe.
- Materiales: `enemy_energy.gdshader` (auto-iluminado, pulsa) y `ArtStyle.flames()` (llamas violetas).
- **Los elementos conservan su color de gameplay:** un ataque de fuego sigue siendo naranja. El violeta es el ataque "propio" de la corrupción.

> **PALETA VIOLETA PROVISIONAL.** Los tokens `violet_deep / violet_glow / violet_core / violet_hot` de `data/art_style.json` son un marcador hasta que lleguen las referencias de color. Cambiar esos 4 hex recolorea todo (cuerpos, ojos, llamas, telegraphs, proyectiles, muertes) sin tocar código.

### 3.3 Formas puntiagudas (recurrentes, no en todo)

Pinchos, cuernos, garras, colmillos, placas, crestas y alas en cuchilla.
- Son conos de 3–4 lados, así que los enemigos son facetados por construcción.
- La cantidad escala con el rango (`spikes`).
- Una criatura puede tener pocas: el sapo tiene pinchos en el lomo y nada más.

### 3.4 La energía es parte del diseño

La energía está en la anatomía: ojos-rendija, grietas del cuerpo, núcleo del wisp, garganta del sapo, aguijón, cristales del lomo, cuernos encendidos, halo del jefe. No es una bola de partículas pegada encima. **Criterio:** los comunes casi no llevan partículas; el aura aparece desde élite.

### 3.5 Especie reconocible + familia consistente

La silueta de la especie manda: la araña parece araña y el lobo parece lobo. La familia se añade encima con color, facetas, puntas y energía.

| Especie (`species`) | Silueta base | Uso actual |
|---|---|---|
| `beast` | cuadrúpedo cazador, hocico, orejas | Thornling, Thorn Chief |
| `boar` | cuadrúpedo pesado, colmillos | Thornback (jefe) |
| `scorpion` | 6 patas, pinzas, cola-aguijón | Scuttler, Glass Stalker |
| `crab` | cuerpo ancho, pinzas enormes, ojos en tallo | Glass Matriarch (jefe) |
| `spider` | 8 patas, 6 ojos, quelíceros | ejemplo (sin datos de gameplay aún) |
| `toad` | saco agachado, boquilla | Spitter |
| `wisp` | núcleo flotante en llamas, esquirlas | Wisp |
| `raptor` | alas en cuchilla, pico, cresta | Crag Harrier |
| `dragon` | cuello largo, alas, cuernos, cola | ejemplo |
| `serpent` | cadena de segmentos, capucha | ejemplo |
| `brute` | ogro encorvado, puños con pinchos | Bulwark |
| `golem` | bloques, cristales | Stoneward |
| `wraith` | alto, harapos, garras largas | Shade, Hollow Shade |
| `goblin` | pequeño, orejas, arma tosca | ejemplo |
| `demon` | gigante con cuernos, halo, alas | Stillwake Warden (jefe final) |

### 3.6 Jerarquía por rango (`ranks` en `art_style.json`)

| Rango | Energía (grietas) | Pinchos | Aura (partículas) | Ojos | Extra |
|---|---|---|---|---|---|
| común | 0.25 | ×1.0 | 0 | ×1.0 | simple, silueta limpia |
| élite | 0.5 | ×1.4 | 8 | ×1.2 | más detalle y energía |
| mini-jefe | 0.75 | ×1.8 | 16 | ×1.35 | fuego en los cuernos, más grande y complejo |
| jefe | 1.0 | ×2.2 | 30 | ×1.5 | corona, halo, alas, luz violeta propia, siluetas memorables |

---

## 4. Humanos: anatomía estilizada (maniquí PLACEHOLDER)

> **REGLA DEL PROYECTO.** Los personajes principales y los NPC humanos definitivos son **modelos 3D reales**: anatomía completa, rostro, cabello y ropa modelados, rig, materiales y animaciones. **Nunca** se construyen con primitivas generadas por código (cápsulas, cilindros, esferas, segmentos, tubos, piezas independientes). El maniquí es un placeholder técnico **congelado**: ya validó proporciones, escala, colisiones y animaciones, y no se refina más visualmente. Cómo entra un modelo real: [`docs/CHARACTER_PIPELINE.md`](CHARACTER_PIPELINE.md).

> **PLACEHOLDER — DISEÑO FINAL PENDIENTE.** Los humanos se dibujan hoy con un maniquí anatómico (`MannequinBuilder`) que solo sirve para validar proporciones, silueta, escala, distancia de cámara, luz sobre el cuerpo y movimiento. No es un diseño de personaje: no tiene rostro, ni ropa, ni peinado definitivos. Cuando lleguen los modelos finales, se integran con el mismo rig y sockets y el maniquí deja de usarse.

**Regla anatómica común** (fracción de la altura del collider, `mannequin` en `art_style.json`; jugador 1,75 m):
- unas **7,5 cabezas** de alto (cabeza 0,133); cadera a media altura (0,5);
- **cuello largo y fino**, torso estrecho con cintura marcada y hombros naturales (semiancho 0,102);
- **piernas largas**: muslo 0,22 y tibia 0,245, con rodilla articulada; pies largos y definidos (0,14);
- **brazos largos**: brazo 0,19, antebrazo 0,16 y mano 0,1, de modo que la punta de los dedos llega a medio muslo; codo articulado;
- **orejas ligeramente puntiagudas**, en forma de hoja hacia atrás, nunca de elfo caricaturesco;
- cabeza ovoide estrecha con mandíbula y mentón definidos.

**Nunca:** cabezones, brazos o piernas cortos, manos diminutas, torso ancho, cuerpos redondos, siluetas infantiles, proporciones chibi o aspecto de muñeco.

**Variación** (misma regla para todos, distinto cuerpo):

| Eje | Valores |
|---|---|
| complexión (`build`) | slim, average, stout, broad (cambia la masa, no la altura) |
| edad (`age`) | child (más bajo, cabeza algo mayor sin ser chibi), young, adult, elder (encorvado) |
| escala (`scale`) | ±8 % de altura |
| pelo (`hair`) | solo como volumen: casquete y una pista del estilo (coleta, moño, largo, mechón) |

La ropa, los tocados y los accesorios del sistema anterior **no** se dibujan sobre el maniquí: pertenecían al diseño chibi y el diseño definitivo está pendiente. Los perfiles de `visuals.json` se conservan como datos para los modelos finales.

**Color:** bloques lisos (piel, una capa base del color propio de cada entidad para distinguir NPCs, pelo más oscuro). El jugador sigue siendo blanco.

**Protagonista:** usa el mismo maniquí hasta tener su diseño. Sockets libres: `hand_r` (armas, en la mano del antebrazo) y `back` (planeador).

---

## 5. Animación

Contrato: `EntityVisual.LOGICAL` + `FALLBACK`. Los placeholders se animan de forma procedural según `rig_kind` (`biped`, `legged`, `float`, `serpent`).
- **Humanos:** claros, expresivos, algo exagerados. Anticipación en ataques (`_ease_strike`), inclinación en curvas, squash al aterrizar. Capas y bufandas se balancean. Los ancianos van encorvados.
- **Enemigos:**
  - windup visible, con telegraph y flash **violeta**;
  - pose fuerte y retroceso;
  - trote en diagonal para cuadrúpedos y ondulación delante-atrás para crawlers;
  - las pinzas cierran al atacar, las alas baten, colas y segmentos ondulan;
  - las esquirlas del wisp giran más rápido al atacar.
- **Jefes:** usan las mismas reglas con más masa (alas, halo, luz). Sus fases y ataques únicos ya están en `bosses.json`. Los modelos finales deben dar a `roar`, `slam` y `windup` clips propios y memorables.

---

## 6. Legibilidad móvil

- Nada de micro-detalle: cada pieza mide al menos ~8 % del cuerpo.
- Manda la silueta, luego el contraste y luego el color de la energía.
- Los enemigos negros se separan del terreno verde o arena por valor. El borde violeta los separa de fondos oscuros (noche, Velo).
- Las piezas pequeñas desaparecen a 40 m (escalado por tamaño: los cuernos de un jefe se ven desde más lejos). Cuerpo y cabeza siguen visibles hasta 180 m.
- Las partículas se escalan con `Quality.particle_amount`.
- Mallas y materiales compartidos (`ShapeKit`, caché de `ArtStyle`).
- **Coste medido:** unas 25 piezas por maniquí cercano. Si el presupuesto lo exige, el siguiente paso es fusionar los adornos estáticos por pieza en una sola malla.

---

## 7. Checklists de consistencia

**Enemigo nuevo:**
1. ¿Silueta clara?
2. ¿Especie reconocible?
3. ¿Pertenece a la familia visual?
4. ¿Usa correctamente el negro (con volumen, no plano)?
5. ¿Usa correctamente el violeta (tokens de la paleta, sin inventar tonos)?
6. ¿Tiene formas angulares o puntiagudas donde corresponde?
7. ¿La energía forma parte de su identidad (no es un pegote de partículas)?
8. ¿Se lee bien desde la cámara de juego?
9. ¿Tiene personalidad propia?
10. ¿Es claramente original?

**Humano nuevo:**
1. ¿Sigue la regla anatómica común (7,5 cabezas, extremidades largas, orejas sutilmente puntiagudas)?
2. ¿Pertenece a la misma familia?
3. ¿Tiene silueta propia (oficio legible)?
4. ¿Se ve atractivo y legible?
5. ¿Es original?
6. ¿Funciona desde la cámara de juego?
7. ¿Se puede animar (sockets, piezas separadas)?

---

## 8. Originalidad

No se usan logos, símbolos, armas, criaturas ni personajes de ninguna obra existente. Cada especie parte de un animal o arquetipo genérico, y se le aplica nuestra gramática: facetas, puntas, energía violeta del Stillwake y rango. Si un diseño recuerda demasiado a algo concreto, se cambia la silueta, no solo el color.

---

## 9. Contrato con tus modelos finales

Gameplay y representación siguen separados:
- **Gameplay** (`entities.json`): identidad, collider, estadísticas, IA, ataques, drops, periodo, diálogo.
- **Representación**: `model`, `model_scale`, `model_offset`, `anim_map` (en `entities.json`) y el perfil de `visuals.json` (familia, rango, especie, variación).
- Si `model` apunta a tu escena, se instancia **tal cual**: sin cambiar proporciones ni añadir piezas. El perfil solo **elige** entre las variantes que trae el modelo (`outfit_*`, `hair_*`, `headwear_*`, `acc_*`), y solo se recolorea si la entidad declara `model_options.palette`.
- Los efectos de familia siguen funcionando con tu modelo porque no dependen de la malla: telegraphs, proyectiles, flash de windup y disolución violeta.
- Sockets: se unen solos a los huesos del rig (`RightHand`, `UpperChest`, `Head`, `Hips`); un nodo `socket_<name>` en tu escena tiene prioridad. Detalles en [`docs/CHARACTER_PIPELINE.md`](CHARACTER_PIPELINE.md).
- Añadir una especie nueva significa una entrada en `entities.json` (gameplay) y otra en `visuals.json` (look). Un test valida que toda entidad tiene perfil, que la familia coincide con su tipo y que el placeholder se construye.
