# Pipeline de personajes 3D reales

> **REGLA DEL PROYECTO — personajes**
> Los personajes principales y los NPC humanos definitivos **son modelos 3D reales**: anatomía completa, rostro modelado, orejas, manos, pies, cabello con geometría real, ropa con volumen y pliegues, accesorios, texturas, materiales, rig, huesos y animaciones.
> **Nunca** se construyen con primitivas generadas por código, como cápsulas, cilindros, esferas, segmentos elípticos, tubos, piezas independientes o *procedural mesh* simple.
> El maniquí procedural (`MannequinBuilder`) es solo un **placeholder técnico congelado**. Sirvió para validar proporciones, escala, colisiones y animaciones, y **no se refina más visualmente**.
> La fórmula del personaje definitivo es: modelo 3D completo + rig + materiales + iluminación + animación. No vale «cilindro + subdivisión + material».
> El entorno (iluminación, materiales, vegetación, agua, terreno, atmósfera, arquitectura, efectos) sí sigue desarrollándose en código.

Este documento explica cómo entra un modelo real en el juego sin rehacer el sistema de personajes. El código está en:
- `src/entities/character_model.gd`: convenciones, sockets por hueso, variantes, paleta, chequeo.
- `src/entities/spring_bone_chain.gd`: física secundaria.
- `src/entities/entity_visual.gd`: ruta `_build_model`.

Las pruebas unitarias (`test_character_pipeline`) lo validan con un rig de prueba que nunca se distribuye.

---

## 1. Formato de importación recomendado

| | Recomendación |
|---|---|
| **Formato** | **glTF 2.0 binario (`.glb`)**. FBX también funciona (Godot 4.4 lo importa con ufbx), pero glb es el camino probado y estándar. |
| **Unidades** | Metros, escala 1, transformaciones aplicadas (*Apply All Transforms* en Blender). |
| **Ejes** | +Y arriba. En Godot el personaje debe mirar a **−Z**; en Blender, eso es mirando hacia **+Y**. Si llega girado, corrígelo en la escena heredada (`.tscn` que hereda del `.glb`), no en código. |
| **Origen** | Entre los pies, a la altura del suelo. `--check-model` avisa si no es así. |
| **Pose de reposo** | T-pose o A-pose, la misma en todos los personajes que compartan animaciones. |
| **Pesos** | Como máximo 4 influencias por vértice (el importador lo limita) y pesos normalizados. |
| **Texturas** | PNG embebidas o al lado del `.glb`. Godot las comprime en ETC2/ASTC (ya activado en el proyecto). |
| **Ubicación** | `assets/models/characters/<id>/<id>.glb`. Las animaciones compartidas van en `assets/models/characters/_anim/`. |

**Ajustes del diálogo de importación (doble clic sobre el `.glb`):**
1. **Skeleton3D → Retarget → Bone Map:** crea un `BoneMap` con perfil **SkeletonProfileHumanoid**. Godot autodetecta Mixamo, Rigify, UE y VRM. Esto renombra los huesos a los nombres de la sección 3, que son los que usa el juego.
2. **Rest Fixer:** activa *Overwrite Axis* y *Fix Silhouette* si las animaciones vienen de otro rig.
3. **Meshes → Generate LODs:** activado. **Shadow Meshes:** activado.
4. **Animation:** marca *Loop* en idle, walk, run, swim, climb y glide (o nómbralos con sufijo `-loop`). Usa *Save to File* para guardar una `AnimationLibrary` compartible.
5. **No** uses sufijos `-col`, `-colonly` ni `-rigid` en mallas de personaje: crearían colisiones físicas que el gameplay no espera (ver sección 8).

## 2. Organización del rig

```
<id>.glb
└─ Root (Node3D)                         origen en los pies, frente −Z
   ├─ Skeleton3D                         un solo esqueleto
   │   ├─ Body            (MeshInstance3D, skinned)   cuerpo base: piel, rostro, ojos
   │   ├─ outfit_<id>     (MeshInstance3D, skinned)   una por traje
   │   ├─ hair_<id>       (MeshInstance3D, skinned)   una por peinado
   │   ├─ headwear_<id>   (opcional)
   │   ├─ acc_<id>        (opcional)                  bolsa, bufanda, collar...
   │   └─ socket_<name>   (opcional, BoneAttachment3D) solo si se quiere afinar un socket
   └─ AnimationPlayer                    clips (o AnimationTree, sección 4)
```

- La jerarquía de huesos tiene como raíz `Hips` (o `Root` → `Hips` si se quiere *root motion*; el juego **no** usa root motion, porque el movimiento lo da el `CharacterBody3D`).
- No pongas claves de escala en los huesos. Usa las mismas longitudes de hueso en todos los cuerpos que compartan clips, o retargetea con el `BoneMap`.
- Las cadenas de pelo y tela se nombran `spring_<algo>_1`, `_2`… como hijas del hueso donde nacen (`Head`, `UpperChest`, `Hips`). Detalles en la sección 10.
- Las expresiones faciales son opcionales: *blend shapes* (`blink`, `smile`, `a`, `o`…) o huesos `Jaw`, `LeftEye` y `RightEye`. Usa como máximo unas 8 blend shapes en móvil.

## 3. Huesos

Los nombres son los de **SkeletonProfileHumanoid**: el `BoneMap` los produce y `CharacterModel.REQUIRED_BONES` los exige.

| Obligatorios (17) | Opcionales |
|---|---|
| `Hips`, `Spine`, `Chest`, `Neck`, `Head` | `Root`, `UpperChest` |
| `LeftUpperArm`, `LeftLowerArm`, `LeftHand` | `LeftShoulder`, `RightShoulder` (clavículas; muy recomendables para hombros integrados) |
| `RightUpperArm`, `RightLowerArm`, `RightHand` | `LeftToes`, `RightToes` |
| `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot` | Dedos del perfil (`LeftThumbMetacarpal`… `RightLittleDistal`) |
| `RightUpperLeg`, `RightLowerLeg`, `RightFoot` | `Jaw`, `LeftEye`, `RightEye` |
| | Cadenas `spring_*` (pelo, mangas, faldones, cintas) |

**Sockets de gameplay**, unidos automáticamente a huesos mediante `BoneAttachment3D`:

| Socket | Hueso | Uso |
|---|---|---|
| `hand_r` | `RightHand` | arma equipada, estela del arma |
| `hand_l` | `LeftHand` | objetos secundarios |
| `back` | `UpperChest` → `Chest` → `Spine` | Vela de Brisa (planeador), arma enfundada |
| `head` | `Head` | efectos, marcadores |
| `center` | `Hips` | efectos de impacto |

Si el modelo trae un nodo `socket_<name>`, ese nodo tiene prioridad. Así se ajusta, por ejemplo, el punto exacto de agarre de la mano.

## 4. Cómo se conectan las animaciones actuales

El gameplay **no** cambia: el jugador y los NPC siguen llamando a `set_locomotion(velocidad, estado)` y a `play_action(acción, duración)`. `EntityVisual` traduce cada estado lógico a un clip de tu modelo:

1. Busca en `anim_map` (`data/entities.json`) el clip asociado al estado.
2. Si el clip no existe, sigue la cadena `FALLBACK`; por ejemplo, `sprint → run → move → idle`, `attack_2 → attack` o `parry → block`.
3. Lo reproduce con 0,15 s de mezcla, o hace `travel` en un `AnimationTree`.

| Estado lógico | Cuándo lo pide el gameplay | Clip sugerido |
|---|---|---|
| `idle`, `walk`, `run`, `sprint` | locomoción | `Idle`, `Walk`, `Run`, `Sprint` (en bucle) |
| `move` | locomoción genérica (NPC y criaturas) | `Walk` o `Run` |
| `jump`, `fall`, `land` | salto y caída | `Jump`, `Fall` (bucle), `Land` |
| `climb`, `climb_idle`, `ledge_climb` | escalada | `Climb` (bucle), `ClimbIdle`, `LedgeClimb` |
| `glide`, `swim` | Vela y agua | `Glide`, `Swim` (bucles) |
| `dodge` | esquiva | `Dodge` |
| `attack_1..3`, `charge`, `spin`, `thrust` | combo y ataques del jugador | `Attack1..3`, `Charge`, `Spin`, `Thrust` |
| `block`, `parry` | defensa | `Block`, `Parry` |
| `hit`, `die` | daño y muerte (`die` mantiene la última pose) | `Hit`, `Death` |
| `interact`, `gather`, `throw`, `eat` | acciones del mundo | `Interact`, `Gather`, `Throw`, `Eat` |
| `ride` | sobre montura | `Ride` (bucle) |

La lista completa está en `EntityVisual.LOGICAL`. Con solo `idle`, `move`, `attack`, `hit` y `die` el personaje ya funciona; el resto se va añadiendo.

**AnimationTree (opcional, recomendado para el protagonista):** pon un `AnimationTree` con una máquina de estados en la raíz del modelo. Cada estado lógico hace `travel` al nodo del mismo nombre (o al indicado en `anim_map`). Si existe `parameters/speed`, recibe la velocidad normalizada (0–1+), lo que permite un *BlendSpace1D* walk/run sin pies que patinan.

**Animaciones compartidas:** guarda los clips en una `AnimationLibrary` (`assets/models/characters/_anim/humanoid.res`) y añádela al `AnimationPlayer` de cada NPC en su escena heredada. Todos los cuerpos con el mismo `BoneMap` la reproducen.

## 5. Reemplazar el placeholder por un modelo real

1. Copia el `.glb` en `assets/models/characters/<id>/` y ajusta la importación (sección 1).
2. Valídalo:
   ```
   godot --headless -- --check-model res://assets/models/characters/hero/hero.glb PLAYER
   ```
   El informe incluye altura, huesos, triángulos, materiales, clips, mallas de variante y cadenas `spring_*`. Marca como **ERROR** la falta de esqueleto, de huesos obligatorios o de `AnimationPlayer`. Marca como **WARN** los presupuestos superados, el origen fuera de los pies, una altura distinta del collider y los estados básicos sin clip.
3. En `data/entities.json`, en la entidad (`PLAYER`, `NPC_…`):
   ```json
   "model": "res://assets/models/characters/hero/hero.glb",
   "model_options": {"fit_height": true},
   "anim_map": {"idle": "Idle", "walk": "Walk", "run": "Run", "move": "Run",
                "attack_1": "Attack1", "attack_2": "Attack2", "attack_3": "Attack3",
                "dodge": "Dodge", "hit": "Hit", "die": "Death", "glide": "Glide", "swim": "Swim"}
   ```
4. Listo. El maniquí deja de construirse para esa entidad. No se toca `collider`, `stats`, `ai`, `attacks`, sockets de armas, Vela, cámara ni controles.

## 6. Materiales: piel, cabello, tela…

Cada superficie tiene un **material con nombre de slot**, que es el nombre del material en Blender:

| Slot | Recomendación para móvil (Mobile y Compatibility) |
|---|---|
| `skin` | `StandardMaterial3D` con albedo, normal y ORM. El *subsurface scattering* real es caro en móvil: usa un *rim* suave y un albedo cálido en las zonas finas (orejas, nariz, dedos). En High/Ultra se puede activar SSS. |
| `hair` | Mechones de geometría real y tarjetas con **alpha scissor** (nunca alpha blend: ordena mal y es caro). Activa *backlight* suave para el contraluz. |
| `eyes` | Material propio sin sombra de contacto y con algo de *specular*. |
| `cloth_a`, `cloth_b` | Tela principal y secundaria, con normal de pliegues horneada. Roughness alta (0,7–0,9). |
| `leather`, `metal` | Cuero y metal de accesorios, con ORM. El metal debe ser sutil: este mundo no tiene tecnología. |

- **Texturas:** atlas de 2048 para el protagonista y de 1024 para los NPC. Empaqueta ORM (occlusion, roughness, metallic) en una sola textura.
- **Recoloreado:** los modelos **no se recolorean** salvo que se pida. Si un NPC necesita otra paleta, se declara en `model_options.palette` (sección 7) y solo se tiñen esos slots. Con `StandardMaterial3D` se tiñe `albedo_color`; con un `ShaderMaterial` se usa el parámetro `tint`.
- **Flash de golpe:** funciona sin tocar tus materiales, porque `FlashOverlay` añade un `material_overlay` aditivo mientras dura el destello.

## 7. Muchos NPC con el mismo sistema

- **Cuerpos base:** unos pocos `.glb` por complexión y edad (por ejemplo `adult_slim`, `adult_stout`, `elder`, `child`), cada uno con varias mallas `outfit_*`, `hair_*`, `headwear_*` y `acc_*`.
- **Perfil visual:** el perfil de `data/visuals.json` que ya tiene cada NPC (`outfit`, `hair`, `headwear`, `accessories`, `scale`) elige qué mallas se ven. Las demás se ocultan. Si un grupo no tiene la variante pedida, se muestra la primera. `scale` del perfil da variedad de estatura sin tocar el collider.
- **Paleta opcional por entidad:**
  ```json
  "model_options": {"fit_height": true, "palette": {"cloth_a": "#3a5f8a", "hair": "#2b211c"}}
  ```
  Los NPC con la misma paleta **comparten** el material teñido. Por ejemplo, 20 aldeanos con 4 paletas cuestan 4 materiales.
- **Personajes con nombre** (Tamsin, Brask, Saffa…) pueden tener su propio `.glb` completo con rostro único. Los aldeanos reutilizan cuerpos base.
- **Animaciones:** la misma `AnimationLibrary` humanoide para todos (sección 4).

## 8. Colisiones

- La colisión jugable **no viene del modelo**. Es el `CapsuleShape3D` del cuerpo, con radio y altura de `collider` en `entities.json`; el protagonista usa 0,35 × 1,75 m.
- El modelo se adapta al collider, no al revés: `fit_height: true` escala el modelo para que mida exactamente la altura del collider, y si no se usa, se ajusta con `model_scale`. `--check-model` avisa si la diferencia supera el 15 %.
- Hurtboxes, alcance de armas (`weapon.reach`), escalada, nado y monturas siguen siendo gameplay. No dependen de la malla.
- No añadas colisiones físicas dentro del `.glb` de un personaje.

## 9. Mantener las animaciones existentes

- El contrato del gameplay (`set_locomotion`, `play_action`, `set_flash`, `set_fade`, `get_socket`) no cambia, así que todos los estados actuales (combate, combo, esquiva, escalada, planeo, nado, montura, recolección, muerte) disparan clips sin tocar código de gameplay.
- La animación procedural del maniquí se apaga automáticamente con un modelo real. Las animaciones definitivas son clips hechos a mano o capturados.
- La duración que el gameplay pasa a `play_action` (por ejemplo, el tiempo de un ataque en `AttackData`) es la ventana de la acción. El clip debería durar parecido, y si no, se ajusta su velocidad en el `AnimationTree`.
- `die` mantiene la última pose. El resto de acciones vuelven al estado de locomoción al terminar.

## 10. Física secundaria: cabello y ropa

- **Convención:** cualquier hueso cuyo nombre empiece por `spring_` y cuyo padre no lo sea es la raíz de una cadena. Por ejemplo `spring_hair_1 → _2 → _3`, `spring_sleeve_l_1…` o `spring_sash_1…`. También se pueden declarar raíces con otro nombre:
  ```json
  "model_options": {"spring_bones": ["Ponytail1"], "spring": {"stiffness": 0.18, "damping": 0.12, "gravity": 4.0}}
  ```
- **Implementación:** `SpringBoneChain` (un `SkeletonModifier3D`) usa un punto Verlet por hueso. El hueso vuelve hacia la pose animada (`stiffness`), se retrasa con el movimiento del cuerpo, cuelga con `gravity` y amortigua con `damping`. No usa colisionadores ni *solver* de tela, por eso es barato en móvil.
- **Coste y LOD:** solo se activa a menos de 22 m y con calidad Media o superior. Más lejos, el hueso conserva la pose animada.
- **Futuro:** Godot 4.5+ trae `SpringBoneSimulator3D`, con colisiones contra el cuerpo. La convención `spring_*` se migra 1:1 cuando el proyecto actualice el motor.
- **Evita:** `SoftBody3D` y tela simulada en móvil. Los pliegues grandes deben estar modelados; la física solo añade el movimiento de mechones, cintas, faldones y mangas.

## 11. Rendimiento en iOS y Android

Estos presupuestos están en `CharacterModel.BUDGET`; `--check-model` avisa si se superan.

| Tipo | Triángulos LOD0 | Huesos | Materiales | Texturas |
|---|---|---|---|---|
| Protagonista | ≤ 20k | ≤ 75 (con dedos y springs) | ≤ 4 | 1–2 × 2048 |
| NPC | ≤ 10k | ≤ 65 | ≤ 3 | 1 × 1024 |
| Enemigo | ≤ 8k | ≤ 60 | ≤ 2 | 1 × 1024 |
| Jefe | ≤ 30k | ≤ 90 | ≤ 4 | 1–2 × 2048 |
| Animal | ≤ 6k | ≤ 50 | ≤ 2 | 1 × 1024 |

**Lo que ya hace el código:**
- `visibility_range_end` en todas las mallas del modelo.
- Animación desactivada a más de 70 m (la escala crece con el tamaño de la criatura).
- Springs desactivados a más de 22 m y en calidad Baja.
- Los materiales teñidos se comparten.

**Lo que debe traer el asset:**
- LODs generados al importar.
- Pocas mallas y materiales por personaje: cada par malla × material es una *draw call*, y las variantes ocultas no se dibujan.
- Atlas de texturas.
- Máximo 4 pesos por vértice.
- *Blend shapes* faciales solo en personajes con primer plano.

**Objetivo de escena:** con unos 15 NPC visibles en un pueblo, mantener 60 fps en gama media. Se mide con el *tour* (`--tour`) y `docs/PERFORMANCE.md`.
