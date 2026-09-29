# Diseño: mundo, historia y hoja de ruta

## Pilar
*"¿Puedo llegar hasta ahí?" → casi siempre, sí.* Todo lo que se ve en el horizonte existe por una razón: una recompensa, un campamento, un mirador o una pieza de historia. Loop: **curiosidad → exploración → descubrimiento → recompensa**.

## La isla de Veloria (vertical slice)
Una región continua de ~1,8 km dividida de forma natural:

| Región | Rasgos | Qué enseña |
|---|---|---|
| Valle del Brezo | colinas con bandas de roca escalables, aldea inicial | movimiento, cámara, recolección, primeros combates |
| Bosque Umbral | árboles densos, lluvia frecuente, escupidores | combate a distancia, fuego vs. humedad |
| Altos de Cendal | macizo de ~290 m con crestas, nieve, frío | escalada larga, planeo, supervivencia térmica |
| Lago Espejo y río | agua, niebla | natación y rutas alternativas |
| Costa del Alba | playas, acantilados, naufragio | exploración de borde, viento |

**Lugares (data/world.json):** Aldea del Brezo · Cámara del Eco (laberinto) · Cripta del Musgo (laberinto) · Campamento Colmillo · Las Agujas (agujas escalables) · Árbol Anciano · Mirador del Viento (térmica) · Cumbre de Cendal · Naufragio del Alba · Torre Rota · Guarida Espinosa.

Las **estructuras de desafío son laberintos con cofres** (por decisión del brief: sin puzzles pesados). Tienen cofres pequeños en los callejones sin salida y un cofre grande en el corazón con recompensas importantes (una reliquia, una semilla de vida, el hilo de corriente, los guantes de escalador). Sus muros se pueden escalar, y eso es intencional: la creatividad se premia.

## Historia (original)
Los vientos de Veloria se debilitan: las cometas caen y las piedras antiguas zumban de noche. Oren, el cartógrafo, mentor del protagonista, subió a cartografiar las cumbres de Cendal y no volvió. Algo bajo la isla, **la Quietud**, contiene el aliento y el viento "olvida su camino". Los *guardianes del viento* construyeron anillos de piedra y torres para mantenerlo vivo.

La historia se cuenta sobre todo por el entorno (estelas, laberintos, la torre rota, el diario de Oren en la cumbre) y con pocos diálogos (Tamsin, Brask, aldeanos). El protagonista es un aprendiz sin nombre de género fijo. Antagonista previsto: el **Guardián de la Quietud** (jefe definido en datos, placeholder magenta).

## Progresión (sin niveles)
Semillas de vida (+vida máx.), flores de aguante (+aguante máx.), equipo con propiedades (abrigo, escalada, amuleto contra rayos, velocidad), la Vela y su mejora, recetas descubiertas y conocimiento del mapa. Puedes llegar a zonas para las que no estás preparado (el frío de la cumbre sin comida caliente).

## Qué queda fuera del slice (a propósito)
Quests con registro, jefes jugables (el Guardián está definido pero no tiene arena), montura o barco, desierto y zona sobrenatural, buceo, comercio con moneda (existe el material `glimmer_shard`) y puzzles con múltiples soluciones más allá del terreno.

## Hoja de ruta propuesta
1. **Validar el slice en dispositivos** (rendimiento real, sensación táctil) y ajustar.
2. **Integrar tus modelos finales** (protagonista primero) siguiendo ASSETS.md.
3. **Jefe 1 (tutorial avanzado):** arena en la Cumbre de Cendal, fases del Guardián y su cámara.
4. **Quests ligeras** basadas en descubrimiento (el diario de Oren como hilo), con registro en el menú.
5. **Montura** (una criatura propia) y comercio con Brask.
6. Nuevas regiones: **desierto** (calor, tormentas de arena) y **zona sobrenatural** (gravedad alterada).
7. Sectores hechos a mano mezclados con los procedurales (el streamer ya admite otro proveedor de datos).
