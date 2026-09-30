class_name FlagGate
extends StaticBody3D
## A sealed door (stone disc, moon gate, sluice) that opens for good once a
## world flag is set — by an offering, a puzzle, a bell sequence.

var flag := ""
var size := Vector3(2.6, 3.0, 0.5)
var color := Color(0.72, 0.72, 0.8)
var round_gate := false
var _mesh: MeshInstance3D
var _open := false


static func create(flag_id: String, gate_size: Vector3, col: Color, is_round: bool = false) -> FlagGate:
	var g := FlagGate.new()
	g.flag = flag_id
	g.size = gate_size
	g.color = col
	g.round_gate = is_round
	return g


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if round_gate:
		_mesh.mesh = ShapeKit.cyl(size.y * 0.5, size.y * 0.5, size.z, 24)
		_mesh.rotation.x = PI * 0.5
	else:
		_mesh.mesh = ShapeKit.box(size)
	_mesh.material_override = m
	_mesh.position.y = size.y * 0.5
	add_child(_mesh)
	if WorldState.flags.has(flag):
		_set_open(false)
	else:
		EventBus.flag_set.connect(_on_flag)


func _on_flag(f: StringName) -> void:
	if String(f) == flag and not _open:
		_set_open(true)


func _set_open(animate: bool) -> void:
	_open = true
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	if animate:
		Audio.play_at(&"slam", global_position, -4.0)
		Effects.dust(self, global_position + Vector3.UP * size.y * 0.5, 1.5)
		var t := create_tween()
		if round_gate:
			t.tween_property(_mesh, "position:x", size.x * 1.05, 2.0).set_trans(Tween.TRANS_SINE)
		else:
			t.tween_property(_mesh, "position:y", -size.y * 0.5, 2.0).set_trans(Tween.TRANS_SINE)
	else:
		_mesh.visible = false
