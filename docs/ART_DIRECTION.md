# Dirección artística — «Jade, Cinabrio y Niebla de Tinta»

## 1. Qué enseñan las referencias (y qué NO tomamos)

### Ilustración de fantasía china
| Observación | Principio que extraemos |
|---|---|
| Profundidad en **planos separados por bandas de niebla** (primer plano oscuro → torre media → picos nevados pálidos) | Separación de planos por niebla de altura + perspectiva aérea fuerte y azulada |
| Paleta **verde jade / turquesa fría** en la naturaleza con **acentos cálidos rojo cinabrio** solo en la arquitectura | La naturaleza es fría y el ser humano cálido: el ojo encuentra las estructuras |
| Arquitectura con **aleros curvados hacia arriba**, cubiertas oscuras verde-azuladas, columnas rojas, terrazas de piedra clara con balaustradas y escalinatas | Gramática arquitectónica propia (ver §3), nunca un edificio reconocible |
| Pinos retorcidos que se inclinan sobre el vacío, cascadas finas, rocas cubiertas de musgo | Árboles con silueta (no esferas), agua vertical, musgo en caras superiores |
| Cielo muy luminoso con nubes suaves; picos nevados que se funden con las nubes | Horizonte claro y cálido-frío, la montaña disuelta en la bruma |

### Vídeo del otro proyecto (referencia de **nivel de ejecución**, no de diseño)
| Observación | Lo que significa para nosotros |
|---|---|
| Etalonaje de color decidido (sombras moradas/azules, luces cálidas, *bloom* suave) | Grading intencional: sombra fría + luz cálida + tonemapping filmico |
| Vegetación con volumen y variedad de siluetas; el suelo nunca es plano de un color | Capas de vegetación con alturas y colores distintos; variación de terreno |
| Rastros de color al volar, líneas de velocidad, partículas (brasas, luciérnagas) | *Feedback* de movimiento y ambiente con partículas baratas |
| Tarjetas de título al descubrir o completar (tipografía serif, línea ornamental) | Momentos de descubrimiento con presentación cinematográfica |
| Placa de nombre de jefe con título y subtítulo; jefe con líneas emisivas | Jefes con identidad y lectura clara de fases y telegrafías |
| HUD mínimo y elegante: corazones, brújula con iconos, consumibles en esquina | HUD sobrio con jerarquía; tipografía con carácter |

**No se copia:** ningún personaje, edificio, símbolo, UI, textura, arma, efecto concreto ni composición de las referencias. Tampoco nada de Breath of the Wild.

## 2. Auditoría del primer build: por qué se veía genérico
1. **Luz neutra y plana**: sol blanco, ambiente gris y sombras sin color. Sin *grading*.
2. **Paleta sin intención**: verde lima saturado en todo el terreno y gris neutro en la roca.
3. **Vegetación tipo "bola"**: dos especies de árbol, copas esféricas iguales y sin siluetas.
4. **Arquitectura de caja**: casas cúbicas con techo a dos aguas; nada cuenta la cultura del mundo.
5. **Atmósfera débil**: niebla uniforme, sin bandas de bruma y con poca separación de planos.
6. **Agua sin vida**: sin brillos, sin cascadas y sin orillas húmedas.
7. **Terreno sin historia**: sin caminos, sin musgo y sin zonas húmedas.
8. **UI de prototipo**: rectángulos redondeados, fuente por defecto y botones solo con texto.
9. **Combate silencioso a la vista**: chispas mínimas, sin estelas, sin reacción visible.

## 3. Lenguaje visual original de Veloria

### Paleta
| Uso | Colores |
|---|---|
| Jade (vegetación) | `#2f5a45` `#4f8a63` `#7fb38a` `#b9d6a8` |
| Esmalte de tejado | `#24474d` `#35646a` |
| Cinabrio (arquitectura) | `#a8352b` `#c9543b` |
| Oro (detalle) | `#d8b25a` |
| Piedra clara | `#e3dccb` · roca fría `#6f7e88` |
| Tinta (sombras / UI) | `#12171c` `#1d252c` |
| Bruma | `#cfdde0` → `#9fb7c2` |
| Luz | sol `#ffdcaa` · luna `#9fb6ff` · faroles `#ffae5a` |

### Gramática arquitectónica: «los Guardianes del Viento»
Cultura original de la isla, construida en torno al viento y las velas:
- **Aleros de doble curva** con las esquinas elevadas. Cada cumbrera termina en un **remate con forma de vela**, firma propia de esta cultura.
- **Cintas de viento**: mástiles y aleros con cintas de tela que ondean con `wind_vec`.
- Columnas cinabrio con capitel jade y cubiertas de esmalte verde oscuro.
- **Terrazas de piedra clara** con balaustres redondeados y escalinatas anchas: la arquitectura se asienta en la montaña.
- **Faroles-cometa** hexagonales (luz cálida de noche).
- Torres escalonadas de 3 a 5 cuerpos abiertos (miradores), pabellones hexagonales, **puertas del viento** (pórticos de dos columnas con dintel de vela), puentes en arco.

### Luz y atmósfera
- Amanecer y atardecer muy cálidos con sombras frías. El mediodía es luminoso con ambiente jade. La noche es azul luna, con faroles cálidos y luciérnagas.
- **Bandas de niebla**: niebla de altura + tarjetas de bruma en valles y al pie de las cascadas.
- La perspectiva aérea lleva la roca lejana a azul pálido y funde los picos con el cielo.

### Personajes (placeholders)
Siguen siendo sólidos y sin detalle. Mejoran solo en **movimiento** (anticipación, inercia, inclinación, aterrizaje) y en **lectura** (telegrafías, reacciones).

### UI: «laca y oro»
Paneles de laca tinta con filete dorado, esquinas cortadas en chaflán, ornamento de nube-voluta en separadores, tipografía **Marcellus** (títulos) y **Philosopher** (texto), botones de acción circulares tipo disco de jade con glifo y animaciones cortas (escala y brillo al tocar).

## 4. Regla de coste
Cada efecto se justifica en `docs/PERFORMANCE.md`. Sin buffers de pantalla ni volumétricos reales. Todo sale de ecuaciones de shader, geometría compartida, MultiMesh y partículas con presupuesto por calidad.
