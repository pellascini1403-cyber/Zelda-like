class_name Kelp
extends MultiMeshInstance3D
## A kelp bed: tall strands rising from the bottom to near the surface,
## one MultiMesh (a single draw call). Divers weave through it; fish school
## in it; it hides wreck parts and chests from above.

var radius := 10.0
var count := 36


static func create(r: float, n: int) -> Kelp:
	var k := Kelp.new()
	k.radius = r
	k.count = n
	return k


## Built on the first frame: the spawner positions features after adding
## them, and the strands need to know how deep the bed is.
func _process(_delta: float) -> void:
	set_process(false)
	_build()


func _build() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ShapeKit.box(Vector3(0.35, 1.0, 0.06))
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13.0 + global_position.z * 7.0)
	var bed := global_position.y
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var h := maxf(WorldGen.SEA_LEVEL - 0.8 - bed, 1.0) * rng.randf_range(0.55, 1.0)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, h, 1)), Vector3(cos(a) * d, h * 0.5, sin(a) * d))
		mm.set_instance_transform(i, xf)
	multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.24, 0.45, 0.24)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 120.0
