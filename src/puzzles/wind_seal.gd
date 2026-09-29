class_name WindSeal
extends StaticBody3D
## A barrier of spinning wind around a reward: impassable until its puzzle
## is solved, then it unravels. Cylindrical collider + one shader cylinder.

var puzzle_id := ""
var radius := 1.6
var height := 3.0
var _mesh: MeshInstance3D
var _opening := -1.0


func _ready() -> void:
	add_to_group(&"puzzle_seals")
	collision_layer = 1
	collision_mask = 0
	if WorldState.flags.has("puzzle_" + puzzle_id):
		queue_free()
		return
	# Ring of thin boxes approximates a cylinder wall (hollow).
	for i in 10:
		var a := TAU * i / 10.0
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(radius * 0.7, height, 0.3)
		cs.shape = b
		cs.position = Vector3(cos(a) * radius, height * 0.5, sin(a) * radius)
		cs.rotation.y = -a + PI * 0.5
		add_child(cs)
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 20
	cyl.rings = 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/wind_seal.gdshader")
	_mesh = MeshInstance3D.new()
	_mesh.mesh = cyl
	_mesh.material_override = mat
	_mesh.position.y = height * 0.5
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func open() -> void:
	if _opening >= 0.0:
		return
	_opening = 0.0
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	ElementFX.burst(self, global_position, &"wind", radius * 2.0)
	Audio.play_at(&"gust", global_position, 0.0)


func _process(delta: float) -> void:
	if _opening < 0.0 or _mesh == null:
		return
	_opening += delta
	_mesh.scale = Vector3(1.0 + _opening * 2.0, maxf(1.0 - _opening, 0.01), 1.0 + _opening * 2.0)
	if _opening >= 1.0:
		queue_free()
