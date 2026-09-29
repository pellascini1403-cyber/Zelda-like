# Controles

## Táctil (diseño principal)

- **Mitad izquierda:** joystick flotante que aparece donde apoyas el pulgar. Si lo empujas más allá del anillo, esprintas (el anillo se vuelve verde).
- **Resto de la pantalla:** arrastra para mover la cámara.
- **Grupo contextual derecho.** Los botones aparecen, desaparecen o cambian de nombre según la situación:

| Situación | Botones |
|---|---|
| En el suelo | Atacar (mantener = cargado) · Saltar · Esquivar · Objeto · Usar (solo con algo interactuable delante) · Cambiar arma (si llevas más de una) |
| Con enemigos cerca | + Bloquear (pulsar justo antes del golpe = parry) · Fijar |
| En el aire | Saltar → **Vela** (si puedes planear) · Atacar = ataque en picado |
| Escalando | Saltar → **Impulso** · Soltar |
| Planeando | Saltar → **Plegar** |
| Nadando | Saltar (sale del agua) · el joystick al máximo = bracear rápido |

- **Arriba a la derecha:** Mapa · Bolsa · Pausa. Arriba en el centro: brújula. Arriba a la izquierda: vida, temperatura y estados.
- **Multi-touch real:** cada dedo se rastrea por índice (joystick + cámara + botón a la vez).
- **Adaptación:** respeta el *safe area* (notch, Dynamic Island, barra de inicio), escala con el lado corto (teléfono o tablet) y admite modo zurdo, tamaño y opacidad de botones.
- **Vibración:** golpes, parry, avisos (desactivable).

## Teclado y ratón (pruebas en escritorio)

| Acción | Tecla |
|---|---|
| Mover | WASD |
| Cámara | ratón (clic para capturar) / flechas |
| Saltar / Vela / Impulso | Espacio |
| Sprint / bracear | Shift |
| Atacar (mantener = cargado) | Clic izq. / J |
| Bloquear / parry | Clic der. / K |
| Esquivar | Q / Ctrl |
| Interactuar | E |
| Usar objeto rápido | R |
| Cambiar arma / objeto | F / G |
| Soltar (escalada) | C |
| Fijar objetivo | Tab / clic central |
| Bolsa / Mapa / Menú | I / M / Esc |
| Consola de debug | F1 o ` |

## Mando
Stick izquierdo: mover · stick derecho: cámara · A: saltar · X: atacar · B: esquivar · Y: interactuar · LB: bloquear · RB: objeto · L3: sprint · R3: fijar · cruceta: armas, objetos, bolsa y soltar · Start: menú · Back: mapa.

Todas las fuentes de entrada terminan en las mismas acciones de `InputMap` (registradas en `InputRouter`). El gameplay nunca lee la entrada en bruto.
