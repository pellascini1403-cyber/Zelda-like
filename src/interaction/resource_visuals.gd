class_name ResourceVisuals
extends RefCounted
## Procedural looks for gatherables, driven by data ("visual" block in
## data/resource_nodes.json). Replace with a model path via "model".

static var _mesh_cache: Dictionary = {}


static func build(def: Dictionary) -> Node3D:
	if def.has("model") and ResourceLoader.exists(def["model"]):
		return (load(def["model"]) as PackedScene).instantiate()
	var v: Dictionary = def.get("visual", {})
	var shape: String = v.get("shape", "plant")
	var color := Color(v.get("color", "#6fa84a"))
	var key := shape + color.to_html()
	var mesh: Mesh = _mesh_cache.get(key)
	if mesh == null:
		mesh = _make(shape, color)
		_mesh_cache[key] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = WorldMaterials.get_mat(&"vertex_color")
	mi.rotation.y = randf() * TAU
	mi.visibility_range_end = 90.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _make(shape: String, c: Color) -> Mesh:
	var b := MeshKit.Builder.new()
	var leaf := Color(0.3, 0.52, 0.22)
	match shape:
		"bush":
			b.blob(Vector3(0, 0.5, 0), Vector3(0.75, 0.55, 0.75), leaf * 1.1, leaf * 0.6, 1, 0.15, 11)
			for i in 6:
				var a := TAU * i / 6.0
				b.blob(Vector3(cos(a) * 0.55, 0.55 + (i % 2) * 0.25, sin(a) * 0.55), Vector3(0.12, 0.13, 0.12), c, c * 0.8, 0, 0.05, i)
		"mushroom":
			for i in 3:
				var off := Vector3(i * 0.18 - 0.18, 0, (i % 2) * 0.15)
				var h := 0.18 + i * 0.07
				b.cylinder(off, h, 0.04, 0.035, 5, Color(0.9, 0.87, 0.78))
				b.blob(off + Vector3(0, h, 0), Vector3(0.14, 0.07, 0.14), c, c * 0.7, 0, 0.05, i)
		"ore":
			b.blob(Vector3(0, 0.45, 0), Vector3(0.95, 0.7, 0.9), Color(0.45, 0.43, 0.41), Color(0.33, 0.32, 0.31), 1, 0.2, 21)
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				b.blob(Vector3(cos(a) * 0.6, 0.45 + sin(a * 2.0) * 0.2, sin(a) * 0.55), Vector3(0.16, 0.2, 0.16), c, c * 0.7, 0, 0.1, i + 30)
		"log":
			var bark := Color(0.4, 0.29, 0.19)
			var basis := Basis(Vector3.FORWARD, PI * 0.5)
			var st := MeshKit.Builder.new()
			st.cylinder(Vector3(0, -0.9, 0), 1.8, 0.3, 0.26, 7, bark, bark * 1.1, 0.08, 4)
			var mesh := st.commit()
			var tool := MeshDataTool.new()
			tool.create_from_surface(mesh, 0)
			for i in tool.get_vertex_count():
				tool.set_vertex(i, basis * tool.get_vertex(i) + Vector3(0, 0.3, 0))
				tool.set_vertex_normal(i, basis * tool.get_vertex_normal(i))
			var out := ArrayMesh.new()
			tool.commit_to_surface(out)
			return out
		"hive":
			b.cylinder(Vector3(0, 0, 0), 1.2, 0.08, 0.06, 5, Color(0.4, 0.3, 0.2))
			b.blob(Vector3(0, 1.1, 0), Vector3(0.28, 0.36, 0.28), c, c * 0.75, 1, 0.08, 3)
		"flower":
			for i in 4:
				var off := Vector3(cos(i * 1.7) * 0.2, 0, sin(i * 1.7) * 0.2)
				b.cylinder(off, 0.35, 0.02, 0.015, 3, leaf)
				b.blob(off + Vector3(0, 0.38, 0), Vector3(0.09, 0.06, 0.09), c, c * 0.8, 0, 0.05, i)
		"pepper":
			b.blob(Vector3(0, 0.3, 0), Vector3(0.35, 0.3, 0.35), leaf, leaf * 0.6, 0, 0.15, 2)
			for i in 4:
				var a := TAU * i / 4.0
				b.cylinder(Vector3(cos(a) * 0.25, 0.25, sin(a) * 0.25), 0.18, 0.05, 0.0, 5, c)
		"crystal":
			for i in 4:
				var a := TAU * i / 4.0
				b.cylinder(Vector3(cos(a) * 0.15, 0, sin(a) * 0.15), 0.5 + i * 0.12, 0.08, 0.0, 5, c, c * 1.3)
		"grass":
			for i in 7:
				var a := TAU * i / 7.0
				var d := Vector3(cos(a), 0, sin(a))
				b.tri(d * 0.1 + d.cross(Vector3.UP) * 0.05, d * 0.1 - d.cross(Vector3.UP) * 0.05, d * 0.35 + Vector3(0, 0.75, 0), c)
				b.tri(d * 0.1 - d.cross(Vector3.UP) * 0.05, d * 0.1 + d.cross(Vector3.UP) * 0.05, d * 0.35 + Vector3(0, 0.75, 0), c * 0.85)
		_:
			for i in 5:
				var a := TAU * i / 5.0
				b.blob(Vector3(cos(a) * 0.15, 0.2, sin(a) * 0.15), Vector3(0.12, 0.25, 0.12), c, c * 0.7, 0, 0.1, i)
	return b.commit()
