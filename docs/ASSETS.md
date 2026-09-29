# Assets y placeholders

## Estado actual (intencional)

| Entidad | Placeholder | Color |
|---|---|---|
| Protagonista | maniquí humanoide | **blanco** `#ffffff` |
| Espinoso (enemigo 1) | cuadrúpedo | rojo `#d63a2f` |
| Baluarte (enemigo 2) | humanoide gigante | azul `#2f5fd6` |
| Escupidor (enemigo 3) | masa (blob) | verde `#2fa84f` |
| Fatuo (enemigo 4, nocturno) | orbe volador | amarillo `#f2d22e` |
| Guardián de la Quietud (jefe, definido) | gigante | magenta `#d62fb4` |
| Cuernolana (animal) | cuadrúpedo | naranja `#e8892e` |
| Saltamadrigueras (criatura pequeña) | cuadrúpedo pequeño | turquesa `#3fc1b0` |
| Tamsin (NPC de misión) | humanoide | celeste `#8ec1f0` |
| Brask (mercader) | humanoide | ámbar `#e0a84a` |
| Aldeano | humanoide | gris `#9a9a9a` |

Material uniforme de color sólido, sin texturas, patrones, caras ni accesorios (`assets/shaders/placeholder.gdshader`). El único efecto es `flash`, que es feedback de gameplay (golpe recibido, aviso de ataque), no decoración. Un test comprueba que el jugador es blanco y que cada tipo tiene un color único.

## Reemplazar un placeholder por tu modelo final

1. Importa el modelo (`.glb` / `.gltf` / `.fbx`) en `assets/models/` y guárdalo como escena (`.tscn`), o usa el `.glb` directamente.
2. En `data/entities.json`, en la entidad correspondiente:
   ```json
   "model": "res://assets/models/thornling.glb",
   "model_scale": 1.0,
   "model_offset": [0, 0, 0],
   "anim_map": {"idle": "Idle", "walk": "Walk", "run": "Run", "attack_1": "Bite", "hit": "Hit", "die": "Death"}
   ```
3. Listo. **No cambies** `collider`, `stats`, `ai`, `attacks` ni `loot_table`: siguen siendo las mismas reglas de juego.

Qué hace `EntityVisual` con tu modelo:
- Lo instancia con la escala y el desplazamiento indicados. La orientación esperada es: frente hacia −Z y origen en los pies.
- Busca un `AnimationPlayer` en el modelo y traduce los estados lógicos a tus clips mediante `anim_map` (si un clip no existe, se ignora).
- **Sockets:** los nodos cuyo nombre empieza por `socket_` se registran (`socket_hand_r`, `socket_back`, `socket_head`, `socket_center`). Si el modelo no los trae, se crean posiciones por defecto a partir del collider. Las armas se enganchan en `hand_r` y la Vela en `back`.
- Los *flashes* de golpe usan `set_instance_shader_parameter("flash")`. Si tu material no declara ese parámetro de instancia, simplemente no se verá el flash; opcionalmente añade `instance uniform float flash;` a tu shader.

Estados lógicos que el gameplay reproduce: `idle, walk, run, sprint, jump, fall, climb, climb_idle, glide, swim, block, attack, attack_1, attack_2, attack_3, windup, lunge, slam, spin, thrust, charge, throw, dodge, hit, die, interact, gather, eat`.

### Protagonista
Igual que arriba, en la entidad `PLAYER`. Collider del gameplay: radio 0,35 y altura 1,75 (origen en los pies). Si tu modelo tiene otras proporciones, ajusta `model_scale`, no el collider.

### Armas, Vela, recursos
- Armas: campo `"model"` en `data/items.json`. Se enganchan en `socket_hand_r`. El alcance jugable sigue viniendo de `weapon.reach`.
- Vela de Brisa: crea `res://assets/models/vela.tscn` y se usa automáticamente.
- Recursos recolectables: campo `"model"` en `data/resource_nodes.json`.

### Iconos, UI, audio
- Iconos: sustituye cualquier `assets/icons/<nombre>.svg` (o apunta `icon` a tu PNG) sin cambiar código.
- Tema de UI: si existe `res://assets/ui/theme.tres`, reemplaza el tema generado.
- Fondo del título: `res://assets/ui/title_background.png`.
- Audio: deja `assets/audio/<id>.ogg` con el mismo id (el `.ogg` tiene prioridad sobre el `.wav` generado). Los ids están en `tools/gen_audio.py`.

## Presupuestos recomendados para los assets finales (móvil)

| Tipo | Triángulos LOD0 | Texturas | Materiales |
|---|---|---|---|
| Protagonista | ≤ 15k | 1× 2048 (atlas) | 1–2 |
| Enemigo común | ≤ 6k | 1× 1024 | 1 |
| Jefe | ≤ 25k | 1–2× 2048 | 1–2 |
| NPC / animal | ≤ 5k | 1× 1024 | 1 |
| Arma | ≤ 1,5k | 512 | 1 |

Incluye LOD1/LOD2 (el importador de Godot puede generarlos) y usa esqueletos de ≤ 60 huesos para personajes. Comprime las texturas con ETC2/ASTC (ya activado en el proyecto).

## Generadores de placeholders
- `tools/gen_icons.py`: iconos SVG de glifo blanco (se tiñen por categoría).
- `tools/gen_audio.py`: SFX, ambiente y música sintetizados (22 kHz mono).
- `tools/gen_localization.py`: tabla de textos.
