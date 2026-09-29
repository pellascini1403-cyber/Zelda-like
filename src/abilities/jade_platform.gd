class_name JadePlatform
extends StaticBody3D
## Temporary jade slab conjured by the Jade Platform ability: stand on it in
## mid-air, bridge gaps, climb higher. Grows in, flickers before it fades.

var lifetime := 9.0
var _t := 0.0
var _mesh: MeshInstance3D
var _size := Vector3(2.6, 0.35, 2.6)
static var _mat: ShaderMaterial
static var _box: BoxMesh


static func create(size: Vector3, life: float) -> JadePlatform:
	var j := JadePlatform.new()
	j._size = size
	j.lifetime = life
	return j


func _ready() -> void:
	add_to_group(&"jade_platforms")
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _size
	cs.shape = shape
	add_child(cs)
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://assets/shaders/jade.gdshader")
		_box = BoxMesh.new()
	_mesh = MeshInstance3D.new()
	var m := _box.duplicate() as BoxMesh
	m.size = _size
	_mesh.mesh = m
	_mesh.material_override = _mat
	_mesh.scale = Vector3(0.1, 0.1, 0.1)
	add_child(_mesh)
	ElementFX.burst(self, global_position, &"jade", maxf(_size.x, _size.z) * 0.8)
	Audio.play_at(&"jade", global_position, -2.0)


func _physics_process(delta: float) -> void:
	_t += delta
	var grow := minf(_t / 0.15, 1.0)
	var fade := 1.0
	if _t > lifetime - 1.5:
		fade = 0.5 + 0.5 * signf(sin(_t * 30.0))
	_mesh.scale = Vector3.ONE * grow
	_mesh.visible = fade > 0.4
	if _t >= lifetime:
		ElementFX.burst(self, global_position, &"jade", 1.5)
		queue_free()
