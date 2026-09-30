class_name Bellcap
extends StaticBody3D
## Forest rule #2 — the rain caps. A broad mushroom that lies limp and
## leathery when dry. Rain soaks it: it swells taut and springy, and
## anything landing on it is flung high (reach knot-holes, ledges, the
## Hollow Tree's side door). Dry weather: just a mushroom.

const BOUNCE := 15.5

var feature_id := ""
var size := 1.4
var _cap: MeshInstance3D
var _wet := -1.0
var _cool := 0.0

static var _mat_dry: StandardMaterial3D
static var _mat_wet: StandardMaterial3D


static func create(id: String, cap_size: float = 1.4) -> Bellcap:
	var b := Bellcap.new()
	b.feature_id = id
	b.size = cap_size
	return b


static func is_wet() -> bool:
	return Weather.rain > 0.3 or Weather.wetness > 0.45


func _ready() -> void:
	add_to_group(&"bellcaps")
	collision_layer = 1
	collision_mask = 0
	if _mat_dry == null:
		_mat_dry = StandardMaterial3D.new()
		_mat_dry.albedo_color = Color(0.58, 0.46, 0.4)
		_mat_dry.roughness = 0.95
		_mat_wet = StandardMaterial3D.new()
		_mat_wet.albedo_color = Color(0.36, 0.52, 0.72)
		_mat_wet.roughness = 0.15
		_mat_wet.metallic_specular = 0.9
	var stem := MeshInstance3D.new()
	stem.mesh = ShapeKit.cyl(size * 0.22, size * 0.3, size * 0.9, 8)
	stem.position.y = size * 0.45
	stem.material_override = _mat_dry
	add_child(stem)
	_cap = MeshInstance3D.new()
	_cap.mesh = ShapeKit.sphere(size, 12)
	_cap.position.y = size * 0.9
	add_child(_cap)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = size
	cyl.height = 0.5
	cs.shape = cyl
	cs.position.y = size * 1.05
	add_child(cs)
	_apply(true)


func _physics_process(delta: float) -> void:
	_cool -= delta
	if Engine.get_physics_frames() % 20 == 0:
		_apply(false)
	if _wet < 0.5 or _cool > 0.0 or Game.player == null:
		return
	var p := Game.player as Player
	var top := global_position.y + size * 1.3
	var flat := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if flat < size * 1.05 and p.global_position.y > top - 0.5 and p.global_position.y < top + 0.7 and p.velocity.y <= 0.5:
		_cool = 0.6
		p.velocity.y = BOUNCE
		p.change_state(&"air")
		Audio.play_at(&"jump", global_position, 2.0, 0.3)
		Effects.splash(self, global_position + Vector3.UP * top)
		var t := create_tween()
		t.tween_property(_cap, "scale", Vector3(1.25, 0.25, 1.25), 0.08)
		t.tween_property(_cap, "scale", Vector3(1.0, 0.55, 1.0), 0.25)


func _apply(force: bool) -> void:
	var w := 1.0 if is_wet() else 0.0
	if w == _wet and not force:
		return
	_wet = w
	_cap.material_override = _mat_wet if w > 0.5 else _mat_dry
	var target := Vector3(1.0, 0.55, 1.0) if w > 0.5 else Vector3(0.8, 0.22, 0.8)
	if force:
		_cap.scale = target
	else:
		create_tween().tween_property(_cap, "scale", target, 2.0)
