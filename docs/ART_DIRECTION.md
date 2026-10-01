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
- **Sol cálido y sombras frías, nunca negras.** El sol nunca está en el cénit (máximo unos 55°): siempre modela los volúmenes de lado. La luz de relleno es un hemisferio: cielo frío desde arriba y rebote cálido-verdoso del suelo, con poco ambiente plano.
- Amanecer y atardecer muy cálidos con sombras frías. El mediodía es luminoso con ambiente jade. La noche es azul luna, con faroles cálidos y luciérnagas.
- **Bandas de niebla**: niebla de altura + tarjetas de bruma en valles y al pie de las cascadas.
- La perspectiva aérea lleva la roca lejana a azul pálido y funde los picos con el cielo.

### Personajes (placeholders)
Los humanos usan un **maniquí anatómico estilizado** (PLACEHOLDER — diseño final pendiente): unas 7,5 cabezas, extremidades largas, cuello fino y orejas ligeramente puntiagudas. Sirve solo para validar proporciones, escala, cámara, luz y movimiento hasta que lleguen los modelos definitivos (ver `docs/CHARACTER_STYLE_GUIDE.md` §4). No hay proporciones chibi.

> **REGLA DEL PROYECTO.** Los personajes principales y los NPC humanos definitivos son **modelos 3D reales**: anatomía completa, rostro, cabello y ropa modelados, rig, materiales y animaciones. **Nunca** se construyen con primitivas generadas por código (cápsulas, cilindros, esferas, segmentos, tubos, piezas independientes). El maniquí es un placeholder técnico **congelado**: ya validó proporciones, escala, colisiones y animaciones, y no se refina más visualmente. Cómo entra un modelo real: [`docs/CHARACTER_PIPELINE.md`](CHARACTER_PIPELINE.md).

### Mundo sin máquinas
El mundo es natural y fantástico: no hay vehículos ni tecnología moderna. Los vehículos Vantrel (motos, cápsula, depósito, garaje, llamada, piezas, misiones y productos de tienda) se eliminaron; un test unitario (`test_no_machines`) impide que vuelvan por los datos.

### UI: «laca y oro»
Paneles de laca tinta con filete dorado, esquinas cortadas en chaflán, ornamento de nube-voluta en separadores, tipografía **Marcellus** (títulos) y **Philosopher** (texto), botones de acción circulares tipo disco de jade con glifo y animaciones cortas (escala y brillo al tocar).

## 4. Pasada de entorno: lenguaje pictórico (referencias 666K Art / «Pilgrimage»)

De las referencias se toma el **lenguaje**, no las escenas: sol cálido que se filtra entre las copas, sombras frías con color, hierba con sensación de trazo, flores dispersas, bruma que aclara y enfría la distancia, montañas que pierden contraste, agua brillante que refleja el cielo, paisajes monumentales y contraste entre zonas al sol y en sombra. No se copian personajes, poses ni composiciones.

Todo comparte la **misma luz, la misma paleta y la misma atmósfera**. Las reglas por elemento son estas:

| Elemento | Regla | Dónde |
|---|---|---|
| **Luz** | Sol bajo (≤ 55°), relleno de cielo frío sin sombra, rebote cálido del suelo, ambiente plano bajo de día. Los parámetros están juntos en `EnvironmentController.look` (exposición, ambiente, relleno, rebote, niebla, perspectiva aérea, contraste, saturación). | `environment_controller.gd` |
| **Bosque** | El sotobosque es más oscuro y frío, con **manchas de sol** que se mueven despacio con las hojas. En HIGH+ las hojas recortan sombras reales; en LOW/MEDIUM una sombra de dosel pintada lo sustituye. El dosel sale de una máscara del mundo (`world_masks`, 8 m/texel). | `world_light.gdshaderinc` |
| **Contacto** | Una sombra de contacto suave y fría bajo cada personaje o criatura, que se encoge al saltar o volar. La arquitectura se oscurece y se ensucia en el primer metro sobre el suelo. | `BlobShadow`, `architecture.gdshader` |
| **Silueta** | Un *rim* suave en el material placeholder (solo iluminación, sin diseño). | `placeholder.gdshader` |
| **Terreno** | Campos de tono a cuatro escalas (verde cálido / jade / verde frío / oro seco), trazos alargados de pincel cuya dirección deriva, tierra asomando, flores en **grupos**, guijarros con anillo de sombra, musgo y hojarasca bajo el bosque, humedad junto al agua y relieve de detalle procedural para que el sol bajo saque forma. | `terrain.gdshader` |
| **Rocas** | Esferas cortadas por planos: **facetas grandes y aristas** que atrapan la luz, cara superior aclarada y con musgo, panza oscura. | `MeshKit._rock`, `_stone` |
| **Árboles** | Crecen, no se ensamblan: tronco curvo con raíces, ramas principales y ramillas, y copa de racimos con normales suaves hacia el centro (oscura y fría dentro, cálida arriba). Las ramas de **hojas geométricas** deshilachan la silueta y filtran la luz. Hay **3 variantes por especie** (estructura, copa y tono), además de escala, inclinación y matiz por instancia. | `TreeKit` |
| **Suelo vivo** | Hierba en matas suaves y agrupadas (zonas densas y claros), flores en campos, guijarros donde la hierba clarea, ramas caídas, troncos con musgo y helechos en el bosque y en hondonadas húmedas. | `ChunkBuilder`, `MeshKit` |
| **Agua** | Color por profundidad (se ve el fondo en lo somero), reflejo del cielo vivo con Fresnel, **orillas reflejadas** (una muestra del mapa de alturas a lo largo del rayo reflejado), ondas en capas que se suavizan con la distancia, bandas de espuma hacia la orilla y destellos del sol. | `water.gdshader` |
| **Profundidad** | Perspectiva aérea fuerte y bruma de valle suave: los planos lejanos pierden contraste, saturación y detalle y toman el color del cielo. Sin desenfoque en el juego. | `EnvironmentController.look` |
| **Partículas** | Pocas y localizadas: hojas que caen bajo los árboles, pétalos en las arboledas en flor, motas al sol, luciérnagas de noche. Nunca una lluvia constante. | `WeatherFX` |
| **Materiales** | Piedra en sillares con juntas, tono por bloque y cara superior blanqueada; madera con veta a lo largo de la pieza; laca satinada gastada hasta la madera; yeso con manchas y regueros; tela suave y translúcida a contraluz. Todo procedural, sin texturas. | `architecture.gdshader` |

**Compatibility (Web):** ese renderer no convierte los uniformes `source_color` ni tiene perspectiva aérea. Una compensación global (`compat_gamma`) y una niebla más fina mantienen el mismo aspecto. Se valida con capturas en ambos renderers.

**Validación de esta pasada:** se comparó un antes/después en seis ambientes (aldea, zona abierta, montaña, bosque, agua y combate), además de noche, lluvia, planeo, costa y puente, en Mobile y en Compatibility. Correcciones tras las capturas:
- Sombras casi negras en el bosque → más relleno de cielo y un albedo del sotobosque más cálido.
- Manchas de sol demasiado grandes y frecuentes → más pequeñas y escasas.
- Copas con núcleo pálido → núcleo oscuro detrás de las hojas.
- Hojas como tarjetas con recorte alfa → hojas geométricas. El *alpha test* cuesta caro en las GPU móviles de tipo TBDR y además colgaba el rasterizador de software de validación.
- Matas de hierba puntiagudas → matas bajas y anchas del color del suelo.
- Helechos en prados abiertos → solo en bosque y hondonadas.
- Manchas de tierra repetitivas → más grandes y escasas.
- Agua deslumbrante → menos destellos y Fresnel acotado.
- Lavado en Compatibility → compensación de gamma y niebla.

**Límites conocidos:** no son fallos, son lo siguiente por hacer.
- Los arbustos y helechos son más simples que los árboles.
- Las cascadas y la espuma no tienen todavía partículas de salpicadura propias.
- Las estructuras de las POI del bosque (árbol hueco, pasarelas) siguen con sus formas anteriores.
- Las rocas grandes de los acantilados son terreno, con estratos en el shader, no mallas propias.

## 5. Regla de coste
Cada efecto se justifica en `docs/PERFORMANCE.md`. Sin buffers de pantalla ni volumétricos reales. Todo sale de ecuaciones de shader, geometría compartida, MultiMesh y partículas con presupuesto por calidad.

## 6. Validación por capturas (`-- --tour`)
Cada fase se revisó con capturas renderizadas y se corrigió lo detectado:
- **1.ª pasada:** cielo sepia, sendero demasiado marrón y ancho, niebla con bordes duros, copas facetadas, sotobosque oscuro → nuevo LUT, cielo más azul, sendero estrecho con adoquines, niebla suave, copas con sombreado suave.
- **2.ª pasada (arquitectura):** remates que parecían cuernos → más bajos y curvados hacia la cumbrera; muros del laberinto demasiado fríos → piedra clara con albardilla vidriada; la plataforma del templo inundaba el pozo de una cascada → los pozos se tallan después de las plataformas y el templo se movió al hombro de la montaña.
- **3.ª pasada (atmósfera):** noche demasiado azul y negra → luna menos saturada, ambiente nocturno más alto y sombras de luna translúcidas; atardecer demasiado magenta → dorado con sombras frías; bruma del alba excesiva → reducida; vetas del Velo y cintas del cielo demasiado intensas → más finas y solo en algunos campos; partículas de tormenta de arena con forma de rectángulo → sprite radial suave; cristales sobreexpuestos → emisión reducida.
- **UI:** tarjeta de título y placa de jefe se dibujaban con tamaño 0 → usan el rectángulo del viewport.

Capturas de referencia de esta etapa: aldea, templo (día y noche), puente, cascada, montaña, bosque con lluvia, desierto y tormenta de arena, el Velo de noche, combate contra jefe, HUD táctil, inventario, mapa, diario y tarjeta de título.
