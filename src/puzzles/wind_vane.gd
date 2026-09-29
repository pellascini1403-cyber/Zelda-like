class_name WindVane
extends StaticBody3D
## Wind-catcher puzzle element: a silk-sailed vane on a stone post. A Gust
## Step through it (or a thermal from fire below) sets it spinning, which
## latches it for good — used by quest puzzles and shrines to ask for the
## wind ability instead of a key.

var puzzle_id := ""
var spinning := false
var _rotor: Node3D
var _speed := 0.0
var _heat_check := 0.0


func _ready() -> void:
	add_to_group(&"wind_vanes")
	collision_layer = 1 | (1 << 3)
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 2.6
	cs.shape = shape
	cs.position.y = 1.3
	add_child(cs)
	var k := StructureKit.new(get_instance_id())
	StructureKit.prism_into(k.b, Vector3.ZERO, Vector3(0, 0.3, 0), 0.55, 0.5, 6, StructureKit.id(StructureKit.WHITE_STONE, StructureKit.MATTE))
	StructureKit.prism_into(k.b, Vector3(0, 0.3, 0), Vector3(0, 2.6, 0), 0.12, 0.09, 6, StructureKit.id(StructureKit.INK_WOOD, StructureKit.MATTE))
	var post := MeshInstance3D.new()
	post.mesh = k.b.commit()
	post.material_override = WorldMaterials.get_mat(&"architecture")
	add_child(post)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 2.5, 0.16)
	add_child(_rotor)
	var r := StructureKit.new(7)
	for i in 4:
		var a := TAU * i / 4.0
		var d := Vector3(cos(a), sin(a), 0)
		var side := Vector3(-sin(a), cos(a), 0) * 0.22
		StructureKit.qf(r.b, Vector3.ZERO, d * 1.1 + side, d * 1.1 - side * 0.2, d * 0.2, StructureKit.id(StructureKit.CINNABAR_LIGHT if i % 2 == 0 else StructureKit.PAPER, StructureKit.CLOTH), Vector3(0, 0, 1))
		StructureKit.qf(r.b, Vector3.ZERO, d * 1.1 + side, d * 1.1 - side * 0.2, d * 0.2, StructureKit.id(StructureKit.GOLD, StructureKit.CLOTH), Vector3(0, 0, -1))
	var rotor := MeshInstance3D.new()
	rotor.mesh = r.b.commit()
	rotor.material_override = WorldMaterials.get_mat(&"architecture")
	_rotor.add_child(rotor)
	var g := PuzzleGroup.find(get_tree(), puzzle_id)
	if g:
		g.register(self)
		if g.is_solved():
			spinning = true
			_speed = 6.0


func is_active() -> bool:
	return spinning


## Called by the Gust Step when its wind passes through.
func on_gust(_dir: Vector3) -> void:
	_spin()


func _spin() -> void:
	if spinning:
		_speed = 12.0
		return
	spinning = true
	_speed = 14.0
	ElementFX.burst(self, global_position + Vector3.UP * 2.5, &"wind", 1.4)
	Audio.play_at(&"gust", global_position, 0.0)
	var g := PuzzleGroup.find(get_tree(), puzzle_id)
	if g:
		g.element_changed()


func _process(delta: float) -> void:
	_speed = move_toward(_speed, 5.0 if spinning else 0.0, delta * 2.0)
	_rotor.rotate_z(_speed * delta)
	if spinning:
		return
	# A fire lit under the vane makes a thermal strong enough to turn it.
	_heat_check -= delta
	if _heat_check <= 0.0:
		_heat_check = 0.5
		for n in get_tree().get_nodes_in_group(&"heat_source"):
			if (n as Node3D).global_position.distance_to(global_position) < 2.8:
				_spin()
				return
