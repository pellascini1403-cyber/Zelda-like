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
| Centinela Espinazo (jefe 1) | cuadrúpedo | bronce `#7a5c1e` |
| Matriarca de Vidrio (jefe 2) | masa | cian `#46d6e8` |
| Correplaya (enemigo del desierto) | cuadrúpedo | ocre `#b8860b` |
| Sombra Callada (enemigo del Velo) | humanoide | carbón `#263238` |
| Saffa (caravanera) | humanoide | siena `#a0522d` |
| Zancaviento (montura) | cuadrúpedo | índigo `#5d4ea8` |

Los placeholders siguen la dirección artística de personajes (`docs/CHARACTER_STYLE_GUIDE.md`), elegida por el perfil visual de cada entidad en `data/visuals.json`:
- **Humanos (jugador y NPCs):** chibi (`ChibiBuilder`), color sólido propio en todas sus piezas (más claro para piel, más oscuro para pelo/cuero). El jugador sigue siendo blanco.
- **Enemigos:** familia corrupta negro + violeta (`CreatureBuilder`, `assets/shaders/enemy_body.gdshader`); el color único de la especie queda como un matiz sutil del cuerpo negro.
- **Fauna:** formas redondas, color sólido, sin violeta.

`flash` sigue siendo solo feedback de gameplay. Un test comprueba que el jugador es blanco, que cada tipo tiene un color único y que cada entidad tiene perfil visual de su familia. Tus modelos finales **nunca** se recolorean ni se modifican: el perfil visual solo afecta a los placeholders.

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

Estados lógicos que el gameplay reproduce (`EntityVisual.LOGICAL`): `idle, walk, run, sprint, move, jump, fall, land, climb, climb_idle, ledge_climb, glide, swim, dodge, attack_1, attack_2, attack_3, attack, charge, spin, thrust, slam, lunge, windup, block, parry, hit, die, interact, gather, throw, eat, ride, roar`. No hace falta tenerlos todos: si falta un clip se usa el de `FALLBACK` (p. ej. `sprint → run → move → idle`, `parry → block`, `ledge_climb → climb`).

**AnimationTree:** si tu modelo trae un `AnimationTree` con una máquina de estados en la raíz, se usa en lugar del `AnimationPlayer`: cada estado lógico viaja (`travel`) al nodo con ese nombre (o el mapeado en `anim_map`), y si existe el parámetro `parameters/speed` recibe la velocidad normalizada (0–1+) para blend spaces de locomoción.

**Monturas:** mismo proceso en `MOUNT_WINDSTRIDER`. La altura del asiento se ajusta en `mount.seat_height`; no cambies el collider.

### Protagonista
Igual que arriba, en la entidad `PLAYER`. Collider del gameplay: radio 0,35 y altura 1,75 (origen en los pies). Si tu modelo tiene otras proporciones, ajusta `model_scale`, no el collider.

### Armas, Vela, recursos
- Armas: campo `"model"` en `data/items.json`. Se enganchan en `socket_hand_r`. El alcance jugable sigue viniendo de `weapon.reach`.
- Vela de Brisa: crea `res://assets/models/vela.tscn` y se usa automáticamente.
- Recursos recolectables: campo `"model"` en `data/resource_nodes.json`.

### Arquitectura
Las estructuras procedurales (`StructureKit`) son placeholders de *layout*: sus colisiones, escaleras-rampa, cofres, NPCs y puzzles son gameplay. Para sustituir un edificio por tu modelo: instancia tu escena en el mismo `root` del POI dentro del builder correspondiente de `StructureBuilder` y elimina la llamada del kit equivalente (p. ej. `k.hall(...)`), conservando `k.terrace(...)`/colisiones si tu modelo no trae las suyas. Paleta y gramática de referencia en ART_DIRECTION.md.

### Iconos, UI, audio
- Iconos: sustituye cualquier `assets/icons/<nombre>.svg` (o apunta `icon` a tu PNG) sin cambiar código.
- Tema de UI: si existe `res://assets/ui/theme.tres`, reemplaza el tema generado. Fuentes: `assets/fonts/` (Marcellus para títulos, Philosopher para texto; ambas OFL, licencias incluidas). Los glifos de botones son dibujos procedurales en `src/ui/ui_art.gd` (`UIArt.glyph`).
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
