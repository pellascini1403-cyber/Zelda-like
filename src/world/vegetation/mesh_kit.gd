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

	## Displaced icosphere (subdivision 0 or 1). Smooth-shaded when `smooth`
	## (soft painterly canopies) instead of faceted (rocks).
	var _group := 0

	func blob(center: Vector3, radius: Vector3, col: Color, col_bottom: Color, subdiv: int, displace: float, seed_value: int, smooth: bool = false) -> void:
		if smooth:
			_group += 1
			st.set_smooth_group(_group)
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
		if smooth:
			st.set_smooth_group(-1)

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

	## Tapered cylinder between two arbitrary points (branches, curved trunks).
	func limb(a: Vector3, bb: Vector3, r0: float, r1: float, sides: int, col: Color, col_top: Color = Color(-1, 0, 0)) -> void:
		var top_col := col if col_top.r < 0.0 else col_top
		var axis := (bb - a).normalized()
		var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
		var u := axis.cross(ref).normalized()
		var v := axis.cross(u).normalized()
		var ring0: Array[Vector3] = []
		var ring1: Array[Vector3] = []
		for i in sides:
			var ang := TAU * i / sides
			var dir := u * cos(ang) + v * sin(ang)
			ring0.append(a + dir * r0)
			ring1.append(bb + dir * r1)
		for i in sides:
			var j := (i + 1) % sides
			var shade := 0.86 + 0.14 * sin(TAU * i / sides)
			var out := ((ring0[i] + ring0[j]) * 0.5 - a).normalized()
			# Godot front faces are clockwise: the face normal is -cross(b-a, c-a).
			var fn := -(ring0[j] - ring0[i]).cross(ring1[j] - ring0[i])
			if fn.dot(out) >= 0.0:
				quad(ring0[i], ring0[j], ring1[j], ring1[i], col.lerp(top_col, 0.5) * shade)
			else:
				quad(ring1[i], ring1[j], ring0[j], ring0[i], col.lerp(top_col, 0.5) * shade)

	## Two-sided quad (leaves, fronds, strands, cloth).
	func quad2(a: Vector3, bb: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		quad(a, bb, c, d, col)
		quad(d, c, bb, a, col * 0.85)

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
## Tree species: full mesh, LOD mesh, trunk collider [radius, height].
const TREES := {
	&"pine": [&"pine", &"pine_lod", 0.38, 2.4],
	&"broadleaf": [&"broadleaf", &"broadleaf_lod", 0.4, 4.2],
	&"cloud_pine": [&"cloud_pine", &"cloud_pine_lod", 0.36, 3.2],
	&"blossom": [&"blossom", &"blossom_lod", 0.3, 2.6],
	&"willow": [&"willow", &"willow_lod", 0.42, 3.4],
	&"bamboo": [&"bamboo", &"bamboo_lod", 0.8, 5.0],
	&"palm": [&"palm", &"palm_lod", 0.3, 5.5],
	&"deadtree": [&"deadtree", &"deadtree", 0.3, 3.0],
	&"crystal": [&"crystal", &"crystal_lod", 0.5, 4.0],
}
## Undergrowth kinds (no collision).
const SHRUBS := [&"bush", &"fern", &"reeds", &"cactus", &"flower", &"grass", &"rock_moss"]


## Raw arrays of vegetation meshes, cached on the main thread so worker
## threads can bake sector batches without touching the RenderingServer.
static var _arrays: Dictionary = {}
const BATCH_SHRUBS := [&"bush", &"fern", &"reeds", &"cactus"]


static func warm_arrays() -> void:
	for sp in TREES:
		if sp == &"crystal":
			continue
		_cache_arrays(TREES[sp][1])
	for k in BATCH_SHRUBS:
		_cache_arrays(k)


static func _cache_arrays(key: StringName) -> void:
	if _arrays.has(key):
		return
	var m := get_mesh(key) as ArrayMesh
	if m == null or m.get_surface_count() == 0:
		return
	var a := m.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	_arrays[key] = [verts, norms, cols, idx]


static func arrays(key: StringName) -> Array:
	return _arrays.get(key, [])


static func get_mesh(key: StringName) -> Mesh:
	if _cache.has(key):
		return _cache[key]
	var m: Mesh
	match key:
		&"pine": m = _pine(false)
		&"pine_lod": m = _pine(true)
		&"broadleaf": m = _broadleaf(false)
		&"broadleaf_lod": m = _broadleaf(true)
		&"cloud_pine": m = _cloud_pine(false)
		&"cloud_pine_lod": m = _cloud_pine(true)
		&"blossom": m = _blossom(false)
		&"blossom_lod": m = _blossom(true)
		&"willow": m = _willow(false)
		&"willow_lod": m = _willow(true)
		&"bamboo": m = _bamboo(false)
		&"bamboo_lod": m = _bamboo(true)
		&"palm": m = _palm(false)
		&"palm_lod": m = _palm(true)
		&"deadtree": m = _deadtree()
		&"crystal": m = _crystal(false)
		&"crystal_lod": m = _crystal(true)
		&"bush": m = _bush()
		&"fern": m = _fern()
		&"reeds": m = _reeds()
		&"cactus": m = _cactus()
		&"rock": m = _rock(1, false)
		&"rock_lod": m = _rock(0, false)
		&"rock_moss": m = _rock(1, true)
		&"grass": m = _grass()
		&"flower": m = _flower()
		_: push_error("MeshKit: unknown mesh " + key)
	_cache[key] = m
	return m


const BARK := Color(0.33, 0.25, 0.2)
const JADE_TOP := Color(0.36, 0.56, 0.3)
const JADE_UNDER := Color(0.12, 0.24, 0.16)


static func _pine(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	b.cylinder(Vector3.ZERO, 2.4, 0.32, 0.22, 5 if lod else 6, BARK)
	var dark := Color(0.1, 0.23, 0.17)
	var light := Color(0.22, 0.38, 0.27)
	if lod:
		b.cylinder(Vector3(0, 1.6, 0), 8.0, 2.4, 0.0, 6, dark, light)
	else:
		var tiers := [[1.6, 3.6, 2.6], [3.6, 3.4, 2.1], [5.5, 3.2, 1.55], [7.3, 2.6, 0.95]]
		for i in tiers.size():
			var t: Array = tiers[i]
			b.cylinder(Vector3(0, t[0], 0), t[1], t[2], 0.0, 7, dark.lerp(light, i * 0.2), light.lerp(Color(0.36, 0.5, 0.36), i * 0.15), 0.12, i + 3)
	return b.commit()


static func _broadleaf(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	b.cylinder(Vector3.ZERO, 3.6, 0.42, 0.26, 5 if lod else 7, BARK, BARK * 1.1, 0.1, 1)
	if lod:
		b.blob(Vector3(0, 5.4, 0), Vector3(3.4, 2.4, 3.2), JADE_TOP, JADE_UNDER, 0, 0.12, 5, true)
	else:
		b.limb(Vector3(0, 3.0, 0), Vector3(1.5, 4.8, 0.5), 0.2, 0.08, 5, BARK)
		b.limb(Vector3(0, 3.3, 0), Vector3(-1.3, 5.0, -0.8), 0.2, 0.08, 5, BARK)
		var pads := [[Vector3(0, 5.9, 0), Vector3(2.5, 1.9, 2.5)], [Vector3(1.9, 5.0, 0.6), Vector3(1.8, 1.4, 1.7)],
			[Vector3(-1.7, 5.3, -0.9), Vector3(1.9, 1.5, 1.8)], [Vector3(0.3, 7.1, -0.4), Vector3(1.6, 1.2, 1.6)],
			[Vector3(-0.4, 4.7, 1.5), Vector3(1.5, 1.2, 1.4)]]
		for i in pads.size():
			b.blob(pads[i][0], pads[i][1], JADE_TOP * (1.0 + i * 0.03), JADE_UNDER, 1, 0.16, 5 + i, true)
	return b.commit()


## Windswept "cloud pine": a leaning, twisting trunk with flat, layered
## canopy pads — the silhouette that reads from across a valley.
static func _cloud_pine(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	var pts := [Vector3(0, 0, 0), Vector3(0.3, 1.4, 0.1), Vector3(0.1, 2.6, 0.5), Vector3(0.8, 3.6, 0.6), Vector3(1.6, 4.4, 0.4)]
	for i in pts.size() - 1:
		b.limb(pts[i], pts[i + 1], 0.34 - i * 0.06, 0.28 - i * 0.06, 5 if lod else 6, BARK * (1.0 - i * 0.04))
	var pad_top := Color(0.24, 0.42, 0.3)
	var pad_under := Color(0.08, 0.18, 0.14)
	var pads := [[Vector3(1.9, 4.7, 0.4), Vector3(2.4, 0.6, 1.9)], [Vector3(-0.9, 3.3, 0.3), Vector3(1.8, 0.5, 1.5)],
		[Vector3(0.6, 5.5, -0.3), Vector3(1.6, 0.45, 1.3)], [Vector3(2.9, 3.9, 1.1), Vector3(1.5, 0.45, 1.2)]]
	if not lod:
		b.limb(Vector3(0.1, 2.6, 0.5), Vector3(-0.9, 3.2, 0.3), 0.14, 0.07, 4, BARK)
		b.limb(Vector3(0.8, 3.6, 0.6), Vector3(2.8, 3.8, 1.1), 0.13, 0.06, 4, BARK)
		b.limb(Vector3(0.8, 3.6, 0.6), Vector3(0.6, 5.3, -0.3), 0.12, 0.06, 4, BARK)
	var count := 2 if lod else pads.size()
	for i in count:
		b.blob(pads[i][0], pads[i][1], pad_top * (1.0 + i * 0.05), pad_under, 0 if lod else 1, 0.2, 20 + i, true)
	return b.commit()


## Plum blossom: dark gnarled trunk, clouds of pale pink bloom.
static func _blossom(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	var bark := Color(0.24, 0.17, 0.15)
	b.limb(Vector3.ZERO, Vector3(0.2, 2.0, 0.1), 0.3, 0.22, 6, bark)
	var pink := Color(0.98, 0.76, 0.84)
	var pink_under := Color(0.72, 0.42, 0.52)
	if lod:
		b.blob(Vector3(0.2, 3.3, 0.1), Vector3(2.6, 1.7, 2.4), pink, pink_under, 0, 0.12, 30, true)
		return b.commit()
	var tips := [Vector3(1.6, 3.1, 0.3), Vector3(-1.3, 3.3, -0.4), Vector3(0.3, 3.9, 1.1), Vector3(-0.2, 3.6, -1.2)]
	for i in tips.size():
		b.limb(Vector3(0.2, 2.0, 0.1), tips[i], 0.14, 0.05, 4, bark)
		b.blob(tips[i] + Vector3(0, 0.3, 0), Vector3(1.3, 0.9, 1.2), pink * (1.0 + (i % 2) * 0.04), pink_under, 1, 0.22, 31 + i, true)
	b.blob(Vector3(0.2, 3.8, 0.1), Vector3(1.4, 0.9, 1.4), Color(1.0, 0.9, 0.93), pink_under, 1, 0.2, 40, true)
	return b.commit()


## Willow by the water: rounded crown, long drooping strands (two-sided).
static func _willow(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	b.limb(Vector3.ZERO, Vector3(0.2, 3.4, 0.0), 0.45, 0.3, 6, BARK)
	var green := Color(0.5, 0.64, 0.34)
	var dark := Color(0.2, 0.32, 0.18)
	b.blob(Vector3(0.2, 4.6, 0), Vector3(2.6, 1.5, 2.6), green, dark, 0 if lod else 1, 0.15, 50, true)
	if lod:
		return b.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for i in 18:
		var a := TAU * i / 18.0 + rng.randf() * 0.2
		var r := rng.randf_range(1.6, 2.5)
		var top := Vector3(cos(a) * r + 0.2, 4.4, sin(a) * r)
		var bottom := top + Vector3(cos(a) * 0.3, -rng.randf_range(2.6, 3.8), sin(a) * 0.3)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.22
		b.quad2(top - side, top + side, bottom + side * 0.4, bottom - side * 0.4, green.lerp(dark, rng.randf() * 0.5))
	return b.commit()


## Bamboo clump: segmented culms with leaf tufts.
static func _bamboo(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var culm := Color(0.46, 0.6, 0.3)
	var node := Color(0.34, 0.44, 0.22)
	var leaf := Color(0.36, 0.56, 0.3)
	var n := 4 if lod else 9
	for i in n:
		var base := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
		var h := rng.randf_range(6.0, 9.0)
		var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var segs := 2 if lod else 5
		for sgi in segs:
			var a := base + lean * (float(sgi) / segs) + Vector3(0, h * sgi / segs, 0)
			var c := base + lean * (float(sgi + 1) / segs) + Vector3(0, h * (sgi + 1) / segs, 0)
			b.limb(a, c, 0.07, 0.065, 4, culm if sgi % 2 == 0 else culm * 0.95, node)
		var top := base + lean + Vector3(0, h, 0)
		for k in (2 if lod else 4):
			var dir := Vector3(cos(k * 1.7 + i), -0.35, sin(k * 1.7 + i)).normalized()
			var side := dir.cross(Vector3.UP).normalized() * 0.18
			var p0 := top - Vector3(0, k * 0.8, 0)
			b.quad2(p0 - side * 0.3, p0 + side * 0.3, p0 + dir * 1.6 + side, p0 + dir * 1.6 - side, leaf * (0.9 + k * 0.05))
	return b.commit()


static func _palm(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	var trunk := Color(0.5, 0.4, 0.3)
	var pts := [Vector3.ZERO, Vector3(0.3, 2.0, 0), Vector3(0.9, 3.9, 0), Vector3(1.8, 5.6, 0)]
	for i in pts.size() - 1:
		b.limb(pts[i], pts[i + 1], 0.28 - i * 0.04, 0.24 - i * 0.04, 5, trunk * (1.0 - i * 0.05))
	var crown: Vector3 = pts[3]
	var frond := Color(0.3, 0.52, 0.26)
	for k in (4 if lod else 8):
		var a := TAU * k / (4 if lod else 8)
		var dir := Vector3(cos(a), 0.15, sin(a))
		var tip := crown + dir * 3.2 + Vector3(0, -1.6, 0)
		var mid := crown + dir * 1.7 + Vector3(0, 0.3, 0)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.45
		b.quad2(crown - side * 0.3, crown + side * 0.3, mid + side, mid - side, frond)
		b.quad2(mid - side, mid + side, tip + side * 0.2, tip - side * 0.2, frond * 0.9)
	return b.commit()


static func _deadtree() -> ArrayMesh:
	var b := Builder.new()
	var wood := Color(0.52, 0.45, 0.38)
	b.limb(Vector3.ZERO, Vector3(0.2, 2.2, 0), 0.3, 0.2, 5, wood)
	b.limb(Vector3(0.2, 2.2, 0), Vector3(1.4, 3.4, 0.3), 0.16, 0.05, 4, wood)
	b.limb(Vector3(0.2, 2.2, 0), Vector3(-0.8, 3.7, -0.4), 0.15, 0.04, 4, wood)
	b.limb(Vector3(0.2, 1.4, 0), Vector3(-1.1, 1.9, 0.6), 0.1, 0.03, 4, wood)
	return b.commit()


## Veil crystal growth: faceted prisms (the material makes them glow).
static func _crystal(lod: bool) -> ArrayMesh:
	var b := Builder.new()
	var c := Color(0.45, 0.95, 0.88)
	var rng := RandomNumberGenerator.new()
	rng.seed = 70
	for i in (3 if lod else 7):
		var a := rng.randf() * TAU
		var tilt := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 1.2)
		var h := rng.randf_range(2.0, 6.0)
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.8)
		b.limb(base, base + tilt + Vector3(0, h * 0.8, 0), 0.35, 0.28, 5, c * 0.7, c)
		b.limb(base + tilt + Vector3(0, h * 0.8, 0), base + tilt * 1.2 + Vector3(0, h, 0), 0.28, 0.01, 5, c, c * 1.2)
	return b.commit()


static func _bush() -> ArrayMesh:
	var b := Builder.new()
	b.blob(Vector3(0, 0.55, 0), Vector3(1.0, 0.72, 1.0), JADE_TOP, JADE_UNDER, 1, 0.2, 2, true)
	b.blob(Vector3(0.6, 0.4, 0.3), Vector3(0.65, 0.5, 0.65), JADE_TOP * 1.08, JADE_UNDER, 0, 0.15, 3, true)
	return b.commit()


static func _fern() -> ArrayMesh:
	var b := Builder.new()
	var c := Color(0.3, 0.5, 0.26)
	for i in 7:
		var a := TAU * i / 7.0
		var dir := Vector3(cos(a), 0.55, sin(a)).normalized()
		var side := Vector3(-sin(a), 0, cos(a)) * 0.13
		var mid := dir * 0.55
		var tip := Vector3(cos(a) * 1.0, 0.25, sin(a) * 1.0)
		b.quad2(Vector3.ZERO - side * 0.2, side * 0.2, mid + side, mid - side, c * (0.9 + (i % 3) * 0.06))
		b.tri(mid - side, mid + side, tip, c)
		b.tri(tip, mid + side, mid - side, c * 0.85)
	return b.commit()


static func _reeds() -> ArrayMesh:
	var b := Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	var c := Color(0.5, 0.58, 0.32)
	for i in 12:
		var base := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		var h := rng.randf_range(1.0, 1.8)
		var tip := base + Vector3(rng.randf_range(-0.2, 0.2), h, rng.randf_range(-0.2, 0.2))
		var side := Vector3(0.03, 0, 0.02)
		b.quad2(base - side, base + side, tip + side * 0.3, tip - side * 0.3, c)
		if i % 3 == 0:
			b.limb(tip - Vector3(0, 0.25, 0), tip + Vector3(0, 0.05, 0), 0.04, 0.03, 4, Color(0.45, 0.32, 0.2))
	return b.commit()


static func _cactus() -> ArrayMesh:
	var b := Builder.new()
	var c := Color(0.42, 0.55, 0.4)
	b.limb(Vector3.ZERO, Vector3(0, 2.4, 0), 0.3, 0.26, 7, c, c * 1.1)
	b.limb(Vector3(0, 1.0, 0), Vector3(0.6, 1.2, 0), 0.16, 0.16, 6, c)
	b.limb(Vector3(0.6, 1.2, 0), Vector3(0.65, 1.9, 0), 0.16, 0.13, 6, c)
	b.limb(Vector3(0, 1.4, 0), Vector3(-0.5, 1.5, 0.1), 0.14, 0.14, 6, c)
	b.limb(Vector3(-0.5, 1.5, 0.1), Vector3(-0.55, 2.0, 0.1), 0.14, 0.11, 6, c)
	return b.commit()


static func _rock(subdiv: int, mossy: bool) -> ArrayMesh:
	var b := Builder.new()
	var top := Color(0.36, 0.48, 0.3) if mossy else Color(0.56, 0.58, 0.58)
	b.blob(Vector3.ZERO, Vector3(1.0, 0.8, 1.0), top, Color(0.3, 0.32, 0.34), subdiv, 0.22, 9)
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
	var stem := Color(0.3, 0.5, 0.26)
	var petal_cols := [Color(0.98, 0.9, 0.55), Color(0.96, 0.6, 0.66), Color(0.74, 0.68, 0.98), Color(0.98, 0.98, 0.95)]
	var offs := [Vector3.ZERO, Vector3(0.18, 0, 0.05), Vector3(-0.1, 0, -0.12), Vector3(0.05, 0, 0.16)]
	for i in 4:
		var h := 0.28 + i * 0.07
		b.cylinder(offs[i], h, 0.02, 0.015, 3, stem)
		b.blob(offs[i] + Vector3(0, h + 0.03, 0), Vector3(0.08, 0.045, 0.08), petal_cols[i], petal_cols[i] * 0.8, 0, 0.1, i)
	return b.commit()
