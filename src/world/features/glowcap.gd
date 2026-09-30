class_name Glowcap
extends Interactable
## Forest rule #1 — the night caps. By day a pale, shut cluster of
## mushrooms. At night they open and glow, marking paths through the wood;
## brushing past them dusts you in spores that muffle your steps and blur
## you to anything watching ("spored": noise ×0.35, sight ×0.5), and an
## open cap can be picked (a glowcap: offering, cooking, crafting).

const SPORE_RADIUS := 2.4
const SPORE_TIME := 40.0

var feature_id := ""
var _caps: Array[MeshInstance3D] = []
var _open := -1
var _t := 0.0
var _puff := 0.0

static var _mat_day: StandardMaterial3D
static var _mat_night: StandardMaterial3D
static var _mat_stem: StandardMaterial3D


static func create(id: String) -> Glowcap:
	var g := Glowcap.new()
	g.feature_id = id
	g.radius = 1.1
	return g


func _ready() -> void:
	super._ready()
	add_to_group(&"glowcaps")
	_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(feature_id)
	var stems: Array = []
	var caps: Array = []
	for i in rng.randi_range(3, 5):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.1, 0.7)
		var h := rng.randf_range(0.3, 0.75)
		stems.append([ShapeKit.cyl(0.06, 0.08, h, 5), Transform3D(Basis(), Vector3(cos(a) * d, h * 0.5, sin(a) * d))])
		var r := rng.randf_range(0.16, 0.3)
		caps.append([ShapeKit.sphere(r, 8), Transform3D(Basis().scaled(Vector3(1.3, 0.55, 1.3)), Vector3(cos(a) * d, h, sin(a) * d))])
	# Two draw calls per cluster (stems, caps), faded out at distance.
	var sm := MeshInstance3D.new()
	sm.mesh = ShapeKit.merged(stems)
	sm.material_override = _mat_stem
	sm.visibility_range_end = 90.0
	add_child(sm)
	var cm := MeshInstance3D.new()
	cm.mesh = ShapeKit.merged(caps)
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cm.visibility_range_end = 140.0
	add_child(cm)
	_caps.append(cm)
	_update(true)


static func _mats() -> void:
	if _mat_day:
		return
	_mat_day = StandardMaterial3D.new()
	_mat_day.albedo_color = Color(0.78, 0.8, 0.7)
	_mat_night = StandardMaterial3D.new()
	_mat_night.albedo_color = Color(0.55, 1.0, 0.85)
	_mat_night.emission_enabled = true
	_mat_night.emission = Color(0.4, 1.0, 0.75)
	_mat_night.emission_energy_multiplier = 5.0
	_mat_stem = StandardMaterial3D.new()
	_mat_stem.albedo_color = Color(0.86, 0.84, 0.76)


func is_open() -> bool:
	return Clock.is_night()


func picked() -> bool:
	return WorldState.is_harvested(feature_id)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_update(false)
	_puff -= delta
	if _open == 1 and Game.player and _puff <= 0.0:
		var p := Game.player as Player
		if p.global_position.distance_squared_to(global_position) < SPORE_RADIUS * SPORE_RADIUS:
			_puff = 2.5
			var had := p.health.has_status(&"spored")
			p.health.add_status(&"spored", SPORE_TIME)
			Effects.sparks(self, global_position + Vector3.UP * 0.5, Color(0.5, 1.0, 0.8), 0.4)
			if not had:
				EventBus.toast.emit(tr("TOAST_SPORED"))


func _update(force: bool) -> void:
	var o := 1 if is_open() and not picked() else 0
	if o == _open and not force:
		return
	_open = o
	for c in _caps:
		c.material_override = _mat_night if o == 1 else _mat_day
		c.scale = Vector3(1.2, 1.1, 1.2) if o == 1 else Vector3(0.75, 0.9, 0.75)


func prompt_key() -> String:
	return "PROMPT_PICK_GLOWCAP"


func can_interact() -> bool:
	return is_open() and not picked()


func interact(player: Player) -> void:
	if not can_interact():
		return
	player.start_busy(&"gather", 0.45)
	player.visual.play_action(&"gather", 0.45)
	var added := PlayerData.inventory.add(&"glowcap", 1)
	if added > 0:
		EventBus.item_acquired.emit(&"glowcap", added)
	WorldState.mark_harvested(feature_id, 20.0)
	Audio.play_at(&"gather", global_position, -3.0)
	_update(true)
