class_name VeilAnchor
extends StaticBody3D
## One of the three anchors that pin the Stillwake's hush over the Veil.
## Its guardians must be driven off first; then the Apprentice releases it
## (interact) and a column of wind rises. Sets WorldState flag `flag_id`.

var flag_id := ""
var _beam: MeshInstance3D
var _prompt: AnchorInteract


func _ready() -> void:
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 3.6
	cs.shape = shape
	cs.position.y = 1.8
	add_child(cs)
	var k := StructureKit.new(flag_id.hash())
	StructureKit.prism_into(k.b, Vector3.ZERO, Vector3(0, 0.6, 0), 1.6, 1.4, 6, StructureKit.id(StructureKit.COOL_STONE * 0.6, 1.0))
	StructureKit.prism_into(k.b, Vector3(0, 0.6, 0), Vector3(0, 3.6, 0), 0.8, 0.35, 5, StructureKit.id(Color(0.3, 0.26, 0.42), StructureKit.GLAZE))
	k.rune(Vector3(0, 2.2, 0), Vector3(0.1, 1.6, 1.0))
	var n := k.build(self, "Mesh", 900.0)
	n.position = Vector3.ZERO
	_prompt = AnchorInteract.new()
	_prompt.anchor = self
	_prompt.position.y = 1.2
	add_child(_prompt)
	if is_released():
		_make_beam()


func is_released() -> bool:
	return WorldState.flags.has(flag_id)


func release() -> void:
	if is_released():
		return
	Quests.set_flag(StringName(flag_id))
	ElementFX.burst(self, global_position, &"wind", 6.0)
	Audio.play_at(&"puzzle_solved", global_position, 2.0)
	EventBus.title_card.emit(tr("ANCHOR_RELEASED"), tr("ANCHOR_" + flag_id.trim_prefix("anchor_").to_upper()))
	_make_beam()


func guardians_near() -> bool:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var c := e as Creature
		if c and not c.dead and c.global_position.distance_to(global_position) < 16.0:
			return true
	return false


func _make_beam() -> void:
	if _beam:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 1.2
	cyl.height = 60.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 12
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/wind_seal.gdshader")
	_beam = MeshInstance3D.new()
	_beam.mesh = cyl
	_beam.material_override = mat
	_beam.position.y = 30.0
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visibility_range_end = 2000.0
	add_child(_beam)


class AnchorInteract:
	extends Interactable
	var anchor: VeilAnchor

	func _ready() -> void:
		radius = 2.0
		super._ready()

	func prompt_key() -> String:
		return "PROMPT_RELEASE" if not anchor.guardians_near() else "PROMPT_ANCHOR_GUARDED"

	func can_interact() -> bool:
		return not anchor.is_released()

	func interact(_player: Player) -> void:
		if anchor.guardians_near():
			EventBus.toast.emit(tr("TOAST_ANCHOR_GUARDED"))
			return
		anchor.release()
