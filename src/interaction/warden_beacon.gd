class_name WardenBeacon
extends Interactable
## A Warden beacon: a tall stone lantern at a region's high place. Lighting
## it sets its flag (quests wait on "beacon_*" flags) and raises a pale
## pillar of wind-light visible across the island — progress you can see
## from anywhere. Can be lit whenever the player gets there: no gating.

var flag_id := ""
var _lit := false
var _pillar: Node3D
static var _mesh: Mesh


func _ready() -> void:
	radius = 1.8
	super._ready()
	add_to_group(&"warden_beacons")
	if _mesh == null:
		var k := StructureKit.new(99)
		StructureKit.prism_into(k.b, Vector3.ZERO, Vector3(0, 0.5, 0), 1.1, 1.0, 8, StructureKit.id(StructureKit.WHITE_STONE, StructureKit.MATTE))
		StructureKit.prism_into(k.b, Vector3(0, 0.5, 0), Vector3(0, 3.2, 0), 0.45, 0.35, 8, StructureKit.id(StructureKit.COOL_STONE, StructureKit.MATTE))
		StructureKit.prism_into(k.b, Vector3(0, 3.2, 0), Vector3(0, 3.6, 0), 0.9, 0.9, 8, StructureKit.id(StructureKit.GOLD * 0.8, StructureKit.GILT))
		for i in 4:
			var a := TAU * i / 4.0
			StructureKit.prism_into(k.b, Vector3(cos(a) * 0.7, 3.6, sin(a) * 0.7), Vector3(cos(a) * 0.55, 4.6, sin(a) * 0.55), 0.08, 0.06, 4, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
		StructureKit.prism_into(k.b, Vector3(0, 4.6, 0), Vector3(0, 5.2, 0), 1.0, 0.1, 8, StructureKit.id(StructureKit.ROOF, StructureKit.GLAZE))
		_mesh = k.b.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = WorldMaterials.get_mat(&"architecture")
	mi.visibility_range_end = 1500.0
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 3.6
	cs.shape = shape
	cs.position.y = 1.8
	body.add_child(cs)
	add_child(body)
	if WorldState.flags.has(flag_id):
		_light(true)


func prompt_key() -> String:
	return "PROMPT_LIGHT_BEACON"


func can_interact() -> bool:
	return not _lit


func interact(player: Player) -> void:
	if _lit:
		return
	player.start_busy(&"interact", 0.6)
	player.visual.play_action(&"interact", 0.6)
	_light(false)
	Quests.set_flag(StringName(flag_id))
	EventBus.toast.emit(tr("TOAST_BEACON_LIT"))


func _light(silent: bool) -> void:
	_lit = true
	var fire := FireSource.new()
	fire.permanent = true
	fire.spreads = false
	fire.radius = 0.6
	add_child(fire)
	fire.position.y = 3.75
	_pillar = Cue.make("beacon")
	add_child(_pillar)
	_pillar.position.y = 5.0
	if not silent:
		ElementFX.burst(self, global_position + Vector3.UP * 4.0, &"wind", 4.0)
		Audio.play_ui(&"puzzle_solved", -1.0)
		if Game.camera_rig:
			Game.camera_rig.add_trauma(0.25)
