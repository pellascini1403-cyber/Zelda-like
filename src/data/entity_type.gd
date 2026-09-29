class_name EntityType
extends Resource
## Data definition of any living entity (player, enemy, animal, NPC, boss).
##
## Gameplay (collider, stats, AI, attacks, loot) and presentation (placeholder
## color/shape or a final model scene) live side by side here but are consumed
## by different nodes. Swapping `model` for a final asset never touches the
## gameplay fields. See docs/ASSETS.md.

enum Kind { PLAYER, ENEMY, ANIMAL, NPC, BOSS }

@export var id: StringName
@export var name_key: String
@export var kind: Kind = Kind.ENEMY

# --- Presentation (replaceable) -----------------------------------------
@export var placeholder_color: Color = Color.WHITE
## One of: humanoid, quadruped, blob, orb, giant.
@export var placeholder_shape: StringName = &"humanoid"
## Final model scene. Empty = use placeholder.
@export var model: String = ""
@export var model_scale: float = 1.0
@export var model_offset: Vector3 = Vector3.ZERO
## Maps logical animation states (idle, move, run, attack, hit, die...) to
## clip names inside the final model's AnimationPlayer.
@export var anim_map: Dictionary = {}
## Visual profile from data/visuals.json (family, rank, species, chibi
## variation...). Filled by DB; presentation only, gameplay never reads it.
@export var visual: Dictionary = {}

# --- Gameplay body (never derived from the visual) ------------------------
@export var collider_radius: float = 0.4
@export var collider_height: float = 1.8
@export var flying: bool = false

# --- Stats ---------------------------------------------------------------
@export var max_health: float = 50.0
@export var defense: float = 0.0
@export var poise: float = 10.0
@export var walk_speed: float = 2.0
@export var run_speed: float = 5.0
@export var turn_speed: float = 8.0
@export var mass: float = 70.0
## element -> damage multiplier (fire: 1.5 means weak to fire)
@export var element_mult: Dictionary = {}

# --- Behaviour -----------------------------------------------------------
@export var ai: Dictionary = {}
@export var attacks: Array[AttackData] = []
@export var loot_table: StringName
## any | day | night
@export var active_period: StringName = &"any"
@export var dialogue: Dictionary = {}
## Rideable creatures: speeds, spur stamina, taming difficulty, seat height.
@export var mount: Dictionary = {}


static func from_dict(d: Dictionary) -> EntityType:
	var e := EntityType.new()
	e.id = StringName(d.get("id", ""))
	e.name_key = d.get("name_key", "")
	e.kind = Kind.get(String(d.get("kind", "ENEMY")).to_upper(), Kind.ENEMY)
	e.placeholder_color = Color(d.get("placeholder_color", "#ffffff"))
	e.placeholder_shape = StringName(d.get("placeholder_shape", "humanoid"))
	e.model = d.get("model", "")
	e.model_scale = d.get("model_scale", 1.0)
	var off: Array = d.get("model_offset", [0, 0, 0])
	e.model_offset = Vector3(off[0], off[1], off[2])
	e.anim_map = d.get("anim_map", {})
	var col: Dictionary = d.get("collider", {})
	e.collider_radius = col.get("radius", 0.4)
	e.collider_height = col.get("height", 1.8)
	e.flying = d.get("flying", false)
	var s: Dictionary = d.get("stats", {})
	e.max_health = s.get("max_health", 50.0)
	e.defense = s.get("defense", 0.0)
	e.poise = s.get("poise", 10.0)
	e.walk_speed = s.get("walk_speed", 2.0)
	e.run_speed = s.get("run_speed", 5.0)
	e.turn_speed = s.get("turn_speed", 8.0)
	e.mass = s.get("mass", 70.0)
	e.element_mult = d.get("element_mult", {})
	e.ai = d.get("ai", {})
	for a in d.get("attacks", []):
		e.attacks.append(AttackData.from_dict(a))
	e.loot_table = StringName(d.get("loot_table", ""))
	e.active_period = StringName(d.get("active_period", "any"))
	e.dialogue = d.get("dialogue", {})
	e.mount = d.get("mount", {})
	return e


func ai_value(key: String, default_value: Variant) -> Variant:
	return ai.get(key, default_value)
