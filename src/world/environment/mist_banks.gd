class_name MistBanks
extends Node3D
## Places the mist cards that separate depth planes: around the massif,
## over the lake, at waterfall feet and in the Veil. Positions come from
## data/world.json "mist" (x, z, height offset above ground, width, height).
## LOW quality keeps half of them at lower opacity.

var _mat: ShaderMaterial
var _quad: QuadMesh


func build(gen: WorldGen) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/mist.gdshader")
	_mat.set_shader_parameter("noise_tex", WorldMaterials.noise_texture())
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_quad.center_offset = Vector3(0, 0.5, 0)
	var low := Quality.level == Quality.Level.LOW
	var i := 0
	for m in DB.world.get("mist", []):
		i += 1
		if low and i % 2 == 0:
			continue
		var x: float = m[0]
		var z: float = m[1]
		var y := maxf(gen.height(x, z), 0.0) + float(m[2])
		var mi := MeshInstance3D.new()
		mi.mesh = _quad
		var mat := _mat.duplicate() as ShaderMaterial
		mat.set_shader_parameter("seed", float(i) * 0.137)
		mat.set_shader_parameter("intensity", (0.28 if low else 0.42) * float(m[5] if m.size() > 5 else 1.0))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(float(m[3]), float(m[4]), 1.0)
		mi.visibility_range_end = 1800.0
		# Billboard: make the AABB generous so culling never pops it.
		mi.extra_cull_margin = float(m[3]) * 0.6
		add_child(mi)
		mi.global_position = Vector3(x, y, z)
