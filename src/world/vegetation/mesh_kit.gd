class_name MeshKit
extends RefCounted
## Tiny procedural modelling toolkit used for environment meshes and
## placeholder entities. Produces faceted low-poly geometry with vertex colors.
## Meshes are cached by key: every tree of a kind shares one mesh.

static var _cache: Dictionary = {}


class Builder:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		st.set_color(col)
		st.add_vertex(a)
		st.set_color(col)
		st.add_vertex(b)
		st.set_color(col)
		st.add_vertex(c)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		tri(a, b, c, col)
		tri(a, c, d, col)

	## Tapered cylinder / cone (r1 = 0) along +Y.
	func cylinder(base: Vector3, height: float, r0: float, r1: float, sides: int, col: Color, col_top: Color = Color(-1, 0, 0), jitter: float = 0.0, seed_value: int = 0) -> void:
		var top_col := col if col_top.r < 0.0 else col_top
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ring0: Array[Vector3] = []
		var ring1: Array[Vector3] = []
		for i in sides:
			var a := TAU * i / sides
			var dir := Vector3(cos(a), 0, sin(a))
			ring0.append(base + dir * r0 * (1.0 + rng.randf_range(-jitter, jitter)))
			ring1.append(base + Vector3(0, height, 0) + dir * r1 * (1.0 + rng.randf_range(-jitter, jitter)))
		for i in sides:
			var j := (i + 1) % sides
			var shade := 0.88 + 0.12 * sin(TAU * i / sides)
			if r1 <= 0.001:
				tri(ring0[j], ring0[i], ring1[i], col.lerp(top_col, 0.5) * shade)
			else:
				quad(ring0[j], ring0[i], ring1[i], ring1[j], col.lerp(top_col, 0.5) * shade)
		# caps
		var top_c := base + Vector3(0, height, 0)
		if r1 > 0.001:
			for i in sides:
				tri(top_c, ring1[(i + 1) % sides], ring1[i], top_col)
		for i in sides:
			tri(base, ring0[i], ring0[(i + 1) % sides], col * 0.6)

	## Displaced icosphere (subdivision 0 or 1).
	func blob(center: Vector3, radius: Vector3, col: Color, col_bottom: Color, subdiv: int, displace: float, seed_value: int) -> void:
		var geo := MeshKit.icosphere(subdiv)
		var v: PackedVector3Array = geo[0]
		var f: PackedInt32Array = geo[1]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var disp := PackedFloat32Array()
		disp.resize(v.size())
		for i in v.size():
			disp[i] = 1.0 + rng.randf_range(-displace, displace)
		for i in range(0, f.size(), 3):
			var p: Array[Vector3] = []
			var avg_y := 0.0
			for k in 3:
				var vi := f[i + k]
				p.append(center + v[vi] * radius * disp[vi])
				avg_y += v[vi].y
			avg_y /= 3.0
			var c := col_bottom.lerp(col, clampf(avg_y * 0.5 + 0.5, 0.0, 1.0))
			tri(p[0], p[1], p[2], c)

	func box(center: Vector3, size: Vector3, col: Color) -> void:
		var h := size * 0.5
		var c := [
			center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
			center + Vector3(h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, h.z),
			center + Vector3(-h.x, h.y, -h.z), center + Vector3(h.x, h.y, -h.z),
			center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
		]
		quad(c[4], c[5], c[6], c[7], col)          # top
		quad(c[3], c[2], c[1], c[0], col * 0.6)    # bottom
		quad(c[7], c[6], c[2], c[3], col * 0.9)    # +z
		quad(c[5], c[4], c[0], c[1], col * 0.85)   # -z
		quad(c[6], c[5], c[1], c[2], col * 0.95)   # +x
		quad(c[4], c[7], c[3], c[0], col * 0.8)    # -x

	func commit() -> ArrayMesh:
		st.generate_normals()
		return st.commit()


## Icosahedron (subdiv 0) or once-subdivided (subdiv 1). Returns [verts, faces].
static func icosphere(subdiv: int) -> Array:
	var key := "ico%d" % subdiv
	if _cache.has(key):
		return _cache[key]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	])
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces := PackedInt32Array([
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
	])
	for s in subdiv:
		var mids := {}
		var nf := PackedInt32Array()
		for i in range(0, faces.size(), 3):
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			var ab := _mid(verts, mids, a, b)
			var bc := _mid(verts, mids, b, c)
			var ca := _mid(verts, mids, c, a)
			nf.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		faces = nf
	# Godot front faces are clockwise: flip the (counter-clockwise) icosahedron.
	for i in range(0, faces.size(), 3):
		var tmp := faces[i + 1]
		faces[i + 1] = faces[i + 2]
		faces[i + 2] = tmp
	_cache[key] = [verts, faces]
	return _cache[key]


static func _mid(verts: PackedVector3Array, mids: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if mids.has(key):
		return mids[key]
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	mids[key] = verts.size() - 1
	return verts.size() - 1


# --- Environment meshes ----------------------------------------------------------
static func get_mesh(key: StringName) -> Mesh:
	if _cache.has(key):
		return _cache[key]
	var m: Mesh
	match key:
		&"pine": m = _pine(false)
		&"pine_lod": m = _pine(true)
		&"broadleaf": m = _broadleaf(false)
		&"broadleaf_lod": m = _broadleaf(true)
		&"bush": m = _bush()
		&"rock": m = _rock(1)
		&"rock_lod": m = _rock(0)
		&"grass": m = _grass()
		&"flower": m = _flower()
		_: push_error("MeshKit: unknown mesh " + key)
	_cache[key] = m
	return m


static func _pine(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	var bark := Color(0.36, 0.25, 0.17)
	b.cylinder(Vector3.ZERO, 2.4, 0.32, 0.22, 5 if lod else 6, bark)
	var dark := Color(0.13, 0.28, 0.17)
	var light := Color(0.24, 0.42, 0.24)
	if lod:
		b.cylinder(Vector3(0, 1.6, 0), 8.0, 2.4, 0.0, 6, dark, light)
	else:
		var tiers := [[1.6, 3.6, 2.6], [3.6, 3.4, 2.1], [5.5, 3.2, 1.55], [7.3, 2.6, 0.95]]
		for i in tiers.size():
			var t: Array = tiers[i]
			b.cylinder(Vector3(0, t[0], 0), t[1], t[2], 0.0, 7, dark.lerp(light, i * 0.2), light.lerp(Color(0.4, 0.55, 0.3), i * 0.15), 0.12, i + 3)
	return b.commit()


static func _broadleaf(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	var bark := Color(0.4, 0.3, 0.22)
	b.cylinder(Vector3.ZERO, 4.0, 0.42, 0.26, 5 if lod else 7, bark, bark * 1.1, 0.1, 1)
	var top := Color(0.36, 0.56, 0.2)
	var under := Color(0.17, 0.3, 0.12)
	if lod:
		b.blob(Vector3(0, 5.6, 0), Vector3(3.2, 2.6, 3.2), top, under, 0, 0.1, 5)
	else:
		b.blob(Vector3(0, 5.8, 0), Vector3(2.8, 2.3, 2.8), top, under, 1, 0.14, 5)
		b.blob(Vector3(1.6, 5.0, 0.6), Vector3(1.9, 1.6, 1.9), top, under, 1, 0.14, 6)
		b.blob(Vector3(-1.4, 5.2, -0.9), Vector3(2.0, 1.7, 2.0), top, under, 1, 0.14, 7)
		b.blob(Vector3(0.2, 7.0, -0.4), Vector3(1.8, 1.4, 1.8), top * 1.05, under, 1, 0.14, 8)
		# Branch stubs
		b.cylinder(Vector3(0, 3.2, 0), 1.8, 0.14, 0.05, 4, bark)
	return b.commit()


static func _bush() -> ArrayMesh:
	var b := Builder.new()
	var top := Color(0.3, 0.5, 0.2)
	var under := Color(0.14, 0.26, 0.1)
	b.blob(Vector3(0, 0.55, 0), Vector3(1.0, 0.75, 1.0), top, under, 1, 0.18, 2)
	b.blob(Vector3(0.6, 0.4, 0.3), Vector3(0.65, 0.5, 0.65), top * 1.05, under, 0, 0.15, 3)
	return b.commit()


static func _rock(subdiv: int) -> ArrayMesh:
	var b := Builder.new()
	b.blob(Vector3.ZERO, Vector3(1.0, 0.8, 1.0), Color(0.58, 0.56, 0.52), Color(0.36, 0.35, 0.33), subdiv, 0.22, 9)
	return b.commit()


static func _grass() -> ArrayMesh:
	var b := Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf() * 0.5
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.cross(Vector3.UP) * 0.04
		var root := dir * rng.randf_range(0.02, 0.15)
		var h := rng.randf_range(0.28, 0.55)
		var tip := root + dir * 0.14 + Vector3(0, h, 0)
		var mid := root + dir * 0.05 + Vector3(0, h * 0.5, 0)
		b.quad(root - side, root + side, mid + side * 0.6, mid - side * 0.6, Color.WHITE)
		b.tri(mid - side * 0.6, mid + side * 0.6, tip, Color.WHITE)
	return b.commit()


static func _flower() -> ArrayMesh:
	var b := Builder.new()
	var stem := Color(0.3, 0.5, 0.2)
	b.cylinder(Vector3.ZERO, 0.45, 0.02, 0.015, 3, stem)
	var petal_cols := [Color(0.95, 0.85, 0.3), Color(0.92, 0.45, 0.55), Color(0.62, 0.55, 0.95)]
	b.blob(Vector3(0, 0.5, 0), Vector3(0.09, 0.05, 0.09), petal_cols[0], petal_cols[0] * 0.8, 0, 0.1, 1)
	b.blob(Vector3(0.18, 0.38, 0.05), Vector3(0.08, 0.05, 0.08), petal_cols[1], petal_cols[1] * 0.8, 0, 0.1, 2)
	b.cylinder(Vector3(0.18, 0.0, 0.05), 0.35, 0.02, 0.015, 3, stem)
	b.blob(Vector3(-0.1, 0.3, -0.12), Vector3(0.07, 0.04, 0.07), petal_cols[2], petal_cols[2] * 0.8, 0, 0.1, 3)
	b.cylinder(Vector3(-0.1, 0.0, -0.12), 0.28, 0.02, 0.015, 3, stem)
	return b.commit()
