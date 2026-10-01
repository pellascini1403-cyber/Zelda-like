class_name FogBell
extends Interactable
## A bell on a stone post in the mist. Each has its own voice (pitch) and
## tolls now and then on the swell, so you hear them before you see them.
## Ring one and the next bell of its line answers — a toll and a flare of
## its lantern out in the white — so the line is followed by ear and eye,
## not by solving a code. The last answer comes from the sanctuary's great
## bell; when every post of the line has been rung, its flag is set.
## Each post stands on a stone plinth just above the water: the keepers set
## them for small boats and swimmers too — a place to climb out and rest.

var feature_id := ""
## The bell that answers this one ("" = none).
var next_id := ""
var pitch := 1.0
var big := false
## Flag set when the whole line has been rung and the great bell answered.
var line_flag := ""
## Every post of the line (to check the line is complete).
var line: Array = []
var _bell: Node3D
var _lamp: OmniLight3D
var _lamp_mesh: MeshInstance3D
var _idle := 0.0
var _flare := 0.0

static var _stone: StandardMaterial3D
static var _bronze: StandardMaterial3D
static var _glass: StandardMaterial3D


static func create(e: Dictionary) -> FogBell:
	var b := FogBell.new()
	b.feature_id = String(e.get("id", ""))
	b.next_id = String(e.get("next", ""))
	b.pitch = float(e.get("pitch", 1.0))
	b.big = bool(e.get("big", false))
	b.line_flag = String(e.get("line_flag", ""))
	b.line = e.get("line", [])
	b.radius = 3.2 if b.big else 2.4
	return b


static func find(id: String, tree: SceneTree) -> FogBell:
	for n in tree.get_nodes_in_group(&"fog_bells"):
		if (n as FogBell).feature_id == id:
			return n
	return null


func rung() -> bool:
	return WorldState.flags.has("bell:" + feature_id)


func prompt_key() -> String:
	return "PROMPT_RING"


func _ready() -> void:
	super._ready()
	add_to_group(&"fog_bells")
	if _stone == null:
		_stone = StandardMaterial3D.new()
		_stone.albedo_color = Color(0.42, 0.44, 0.45)
		_bronze = StandardMaterial3D.new()
		_bronze.albedo_color = Color(0.55, 0.42, 0.22)
		_bronze.metallic = 0.6
		_bronze.roughness = 0.4
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(1.0, 0.85, 0.5)
		_glass.emission_enabled = true
		_glass.emission = Color(1.0, 0.75, 0.35)
		_glass.emission_energy_multiplier = 3.0
	var s := 1.6 if big else 1.0
	var post := MeshInstance3D.new()
	post.mesh = ShapeKit.merged([
		[ShapeKit.cyl(0.55 * s, 0.8 * s, 5.0 * s, 7), Transform3D(Basis(), Vector3(0, 0.5 * s, 0))],
		[ShapeKit.box(Vector3(1.9, 0.25, 0.25) * s), Transform3D(Basis(), Vector3(0, 3.2 * s, 0))],
		[ShapeKit.box(Vector3(0.22, 1.2, 0.22) * s), Transform3D(Basis(), Vector3(-0.85 * s, 2.7 * s, 0))],
		[ShapeKit.box(Vector3(0.22, 1.2, 0.22) * s), Transform3D(Basis(), Vector3(0.85 * s, 2.7 * s, 0))],
	])
	post.material_override = _stone
	post.visibility_range_end = 700.0
	add_child(post)
	# The plinth (a resting place) and the post itself are solid.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var plinth := MeshInstance3D.new()
	plinth.mesh = ShapeKit.cyl(1.5 * s, 1.8 * s, 3.2, 8)
	plinth.position.y = -0.7
	plinth.material_override = _stone
	plinth.visibility_range_end = 500.0
	add_child(plinth)
	var pc := CollisionShape3D.new()
	var pcs := CylinderShape3D.new()
	pcs.radius = 1.6 * s
	pcs.height = 3.2
	pc.shape = pcs
	pc.position.y = -0.7
	body.add_child(pc)
	var sc := CollisionShape3D.new()
	var scs := CylinderShape3D.new()
	scs.radius = 0.6 * s
	scs.height = 3.0 * s
	sc.shape = scs
	sc.position.y = 1.5 * s
	body.add_child(sc)
	_bell = Node3D.new()
	_bell.position = Vector3(0, 3.05 * s, 0)
	add_child(_bell)
	var bell := MeshInstance3D.new()
	bell.mesh = ShapeKit.cone(0.55 * s, 0.9 * s, 10)
	bell.position = Vector3(0, -0.45 * s, 0)
	bell.material_override = _bronze
	_bell.add_child(bell)
	_lamp_mesh = MeshInstance3D.new()
	_lamp_mesh.mesh = ShapeKit.sphere(0.32 * s, 8)
	_lamp_mesh.position = Vector3(0, 3.7 * s, 0)
	_lamp_mesh.material_override = _glass
	add_child(_lamp_mesh)
	_lamp = OmniLight3D.new()
	_lamp.position = _lamp_mesh.position
	_lamp.light_color = Color(1.0, 0.8, 0.45)
	_lamp.omni_range = 14.0 * s
	_lamp.shadow_enabled = false
	_lamp.distance_fade_enabled = true
	_lamp.distance_fade_begin = 180.0
	_lamp.distance_fade_length = 60.0
	add_child(_lamp)
	_idle = randf_range(4.0, 14.0)
	_apply_lamp()


func _apply_lamp() -> void:
	# Lit once rung (and always in the mist or at night: a keeper's lamp).
	var dark := 1.0 - Clock.daylight()
	var mist: float = MistBank.density_at(global_position, get_tree())
	var e: float = (0.8 if rung() else 0.35) + dark * 0.6 + mist * 0.8 + _flare * 3.0
	_lamp.light_energy = e
	_lamp_mesh.visible = e > 0.3


func interact(player: Player) -> void:
	toll()
	player.start_busy(&"interact", 0.4)
	player.visual.play_action(&"interact", 0.4)
	if not rung():
		Quests.set_flag(StringName("bell:" + feature_id))
	var nb := FogBell.find(next_id, get_tree()) if next_id != "" else null
	if nb:
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if is_instance_valid(nb):
				nb.answer())


## Ring by itself in answer: toll + a flare of the lantern.
func answer() -> void:
	toll()
	_flare = 1.0
	Effects.splash(self, global_position + Vector3.UP * 0.2)
	if big and line_flag != "" and not WorldState.flags.has(line_flag):
		var all := true
		for id in line:
			if not WorldState.flags.has("bell:" + String(id)):
				all = false
		if all:
			Quests.set_flag(StringName(line_flag))
			EventBus.toast.emit(tr("LINE_BELLS_ANSWERED"))


func toll() -> void:
	Audio.play_tone(&"chime", global_position + Vector3.UP * 3.0, pitch * (0.7 if big else 1.0), 2.0 if big else -2.0, 320.0 if big else 220.0)
	var t := create_tween()
	t.tween_property(_bell, "rotation:z", 0.35, 0.18).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bell, "rotation:z", -0.25, 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bell, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_flare = move_toward(_flare, 0.0, delta * 0.5)
	if Engine.get_process_frames() % 12 == 0:
		_apply_lamp()
	# The swell tolls it now and then: a voice to follow in the mist.
	_idle -= delta
	if _idle <= 0.0:
		_idle = randf_range(10.0, 18.0)
		if MistBank.density_at(global_position, get_tree()) > 0.25 or Weather.wind_strength > 0.5:
			toll()
