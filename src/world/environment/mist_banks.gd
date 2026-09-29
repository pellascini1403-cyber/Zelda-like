class_name MistBanks
extends Node3D
## Places the mist cards that separate depth planes: around the massif,
## over the lake, at waterfall feet and in the Veil. Positions come from
## data/world.json "mist" (x, z, height offset above ground, width, height,
## intensity). LOW quality keeps half of them at lower opacity.
##
## All cards live in ONE mesh (one draw call): each quad carries its centre
## (UV2 = x, z; CUSTOM0.x = y), width, seed and intensity (CUSTOM0.yzw); the
## shader billboards every card around its own centre.


func build(gen: WorldGen) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/mist.gdshader")
	mat.set_shader_parameter("noise_tex", WorldMaterials.noise_texture())
	var low := Quality.level == Quality.Level.LOW
	mat.set_shader_parameter("intensity", 0.28 if low else 0.42)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom := PackedFloat32Array()
	var i := 0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for m in DB.world.get("mist", []):
		i += 1
		if low and i % 2 == 0:
			continue
		var x: float = m[0]
		var z: float = m[1]
		var y := maxf(gen.height(x, z), 0.0) + float(m[2])
		var w: float = m[3]
		var h: float = m[4]
		var inten: float = m[5] if m.size() > 5 else 1.0
		var c := Vector3(x, y, z)
		var corners := [Vector2(-0.5, 0.0), Vector2(0.5, 0.0), Vector2(0.5, 1.0), Vector2(-0.5, 1.0)]
		for k in [0, 1, 2, 0, 2, 3]:
			var q: Vector2 = corners[k]
			verts.append(c + Vector3(q.x * w, q.y * h, 0.0))
			uvs.append(Vector2(q.x + 0.5, 1.0 - q.y))
			uv2s.append(Vector2(x, z))
			custom.append_array([y, w, float(i) * 0.137, inten])
		lo = lo.min(c - Vector3(w, 0, w))
		hi = hi.max(c + Vector3(w, h, w))
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	var mesh := ArrayMesh.new()
	# CUSTOM0 as full floats: (centre y, width, seed, intensity).
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.custom_aabb = AABB(lo, hi - lo)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
