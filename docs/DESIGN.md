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
| Confín Solquemado (desierto) | dunas, mesetas, oasis, tormentas de arena | calor, orientación sin referencias, comercio |
| Confines del Velo (sobrenatural) | cráter, lago inmóvil, islas flotantes, levedad | habilidades de movimiento, combate avanzado |

**Lugares (data/world.json):** Aldea del Brezo · Templo de las Terrazas de Nube · Santuarios del Camino y del Brezo · Paso de Jade (puente) · Salón Hundido (ruinas) · Cámara del Eco y Cripta del Musgo (laberintos con puzzle) · Campamento Colmillo · Las Agujas · Árbol Anciano · Mirador del Viento · Cumbre de Cendal · Naufragio del Alba · Torre Rota (pagoda en ruinas) · Guarida Espinosa · Oasis Solquemado · Cripta del Sol · Hondonada de Vidrio · Anclas Norte/Este/Oeste · Islas a la Deriva · Corazón Quieto.

Las **estructuras de desafío son laberintos con cofres**, ahora con un puzzle ligero en el corazón (braseros o placas que deshacen un sello de viento). Tienen cofres pequeños en los callejones sin salida y un cofre grande en el corazón con recompensas importantes (una reliquia, una semilla de vida, el hilo de corriente, los guantes de escalador). Sus muros se pueden escalar, y eso es intencional: la creatividad se premia.

## Historia (original)
Los vientos de Veloria se debilitan: las cometas caen y las piedras antiguas zumban de noche. Oren, el cartógrafo, mentor del protagonista, subió a cartografiar las cumbres de Cendal y no volvió. Algo bajo la isla, **la Quietud**, contiene el aliento y el viento "olvida su camino". Los *guardianes del viento* construyeron anillos de piedra y torres para mantenerlo vivo.

La historia se cuenta sobre todo por el entorno (estelas, laberintos, la torre rota, el diario de Oren en la cumbre) y con pocos diálogos (Tamsin, Brask, aldeanos). El protagonista es un aprendiz sin nombre de género fijo.

**Tres actos (misiones principales):** *El Camino del Aprendiz* (Tamsin → Mirador → Templo → Centinela Espinazo; premio: Paso de Ráfaga) · *Voces en la Arena* (desierto → oasis → Saffa → Cripta del Sol → Matriarca de Vidrio; premio: Peldaño de Jade) · *El Corazón Quieto* (Velo → tres anclas → Guardián de la Quietud; premio: Quietud y final). Misiones secundarias: guiso de Brask, espinillos, cintas del camino (Vista del Viento), ecos, salón hundido, el Zancaviento (montura), agua de la caravana.

## Progresión (sin niveles)
Semillas de vida (+vida máx.), flores de aguante (+aguante máx.), equipo con propiedades (abrigo, escalada, amuleto contra rayos, velocidad), la Vela y su mejora, recetas descubiertas y conocimiento del mapa. Puedes llegar a zonas para las que no estás preparado (el frío de la cumbre sin comida caliente).

## Estado y siguientes pasos
Implementado: misiones con diario, tres jefes con arenas y fases, montura, desierto y zona sobrenatural, cinco habilidades, puzzles, comercio, eventos dinámicos. Siguientes pasos recomendados:
1. **Validar en dispositivos** (rendimiento real y sensación táctil) y ajustar presupuestos por preset.
2. **Integrar tus modelos finales** siguiendo ASSETS.md (protagonista y jefes primero).
3. Más contenido sobre los sistemas existentes (misiones y POIs son datos).
4. Cinemáticas de jefe con cámara dedicada y voz.
