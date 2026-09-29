class_name PressurePlate
extends Area3D
## Floor plate pressed by the player, a creature or a heavy prop. Stays down
## while weighted (or forever once the puzzle is solved).

var puzzle_id := ""
var _count := 0
var _plate: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = (1 << 1) | (1 << 2) | (1 << 3)
	monitoring = true
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.6, 1.8)
	cs.shape = shape
	cs.position.y = 0.3
	add_child(cs)
	var k := StructureKit.new()
	StructureKit.box_into(k.b, Transform3D(Basis(), Vector3(0, 0.02, 0)), Vector3(2.1, 0.08, 2.1), StructureKit.id(StructureKit.COOL_STONE * 0.8, 1.0))
	var base := MeshInstance3D.new()
	base.mesh = k.b.commit()
	base.material_override = WorldMaterials.get_mat(&"architecture")
	add_child(base)
	var k2 := StructureKit.new()
	StructureKit.box_into(k2.b, Transform3D(), Vector3(1.6, 0.14, 1.6), StructureKit.id(StructureKit.JADE, StructureKit.GLAZE))
	_plate = MeshInstance3D.new()
	_plate.mesh = k2.b.commit()
	_plate.material_override = WorldMaterials.get_mat(&"architecture")
	_plate.position.y = 0.12
	add_child(_plate)
	body_entered.connect(func(b: Node) -> void: _on_weight(b, 1))
	body_exited.connect(func(b: Node) -> void: _on_weight(b, -1))
	var g := PuzzleGroup.find(get_tree(), puzzle_id)
	if g:
		g.register(self)


func _on_weight(b: Node, d: int) -> void:
	if b is RigidBody3D and (b as RigidBody3D).mass < 8.0:
		return
	_count = maxi(_count + d, 0)
	_plate.position.y = 0.04 if is_active() else 0.12
	if d > 0 and _count == 1:
		Audio.play_at(&"thud", global_position, -4.0)
		var g := PuzzleGroup.find(get_tree(), puzzle_id)
		if g:
			g.element_changed()


func is_active() -> bool:
	var g := PuzzleGroup.find(get_tree(), puzzle_id) if is_inside_tree() else null
	return _count > 0 or (g != null and g.is_solved())
