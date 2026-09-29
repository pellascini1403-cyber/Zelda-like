class_name StructureKit
extends RefCounted
## Accumulates architecture pieces into ONE vertex-colored mesh (one draw
## call per structure) plus matching box colliders in ONE static body.

var b := MeshKit.Builder.new()
var shapes: Array = []   # [Transform3D, Shape3D]
var rng := RandomNumberGenerator.new()
var glow := MeshKit.Builder.new()
var has_glow := false


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


## Axis-aligned (optionally yaw-rotated) solid block with collision.
func block(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0, collide: bool = true, jitter: float = 0.06) -> void:
	var c := color * (1.0 + rng.randf_range(-jitter, jitter))
	c.a = 1.0
	if yaw == 0.0:
		b.box(center, size, c)
	else:
		var tmp := MeshKit.Builder.new()
		tmp.box(Vector3.ZERO, size, c)
		_append_transformed(tmp, Transform3D(Basis(Vector3.UP, yaw), center))
	if collide:
		var s := BoxShape3D.new()
		s.size = size
		shapes.append([Transform3D(Basis(Vector3.UP, yaw), center), s])


## Wall from a to b (on the ground plane), built from stone courses.
func wall(a: Vector3, bb: Vector3, height: float, thickness: float, color: Color) -> void:
	var dir := bb - a
	dir.y = 0.0
	var length := dir.length()
	var yaw := atan2(dir.x, dir.z)
	var mid := (a + bb) * 0.5
	var courses := maxi(1, int(height / 0.9))
	var ch := height / courses
	var basis := Basis(Vector3.UP, yaw)
	for i in courses:
		# Running bond: each course is split at a staggered joint, stones get
		# their own tint, lower courses gather moss.
		var moss_k := clampf(1.0 - float(i) / 2.5, 0.0, 1.0) * rng.randf_range(0.2, 0.55)
		var split := clampf(0.5 + (0.22 if i % 2 == 0 else -0.22) + rng.randf_range(-0.08, 0.08), 0.15, 0.85)
		var y := ch * (i + 0.5)
		var z0 := -length * 0.5
		for part in 2:
			var seg_len := length * (split if part == 0 else 1.0 - split)
			var seg_mid := z0 + seg_len * 0.5
			z0 += seg_len
			var col := (color * rng.randf_range(0.88, 1.08)).lerp(Color(0.36, 0.45, 0.26), moss_k)
			col.a = 1.0
			var inset := rng.randf_range(0.0, 0.04)
			var tmp := MeshKit.Builder.new()
			tmp.box(Vector3.ZERO, Vector3(thickness - inset, ch * 0.96, seg_len - 0.06), col)
			_append_transformed(tmp, Transform3D(basis, mid + basis * Vector3(0, y, seg_mid)))
	var s := BoxShape3D.new()
	s.size = Vector3(thickness, height, length)
	shapes.append([Transform3D(Basis(Vector3.UP, yaw), mid + Vector3(0, height * 0.5, 0)), s])


func pillar(base: Vector3, height: float, radius: float, color: Color, sides: int = 8) -> void:
	b.cylinder(base, height, radius, radius * 0.92, sides, color, color * 1.08, 0.05, rng.randi())
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	shapes.append([Transform3D(Basis(), base + Vector3(0, height * 0.5, 0)), s])


## Pitched roof (visual only, with a thin collision slab).
func roof(center: Vector3, width: float, depth: float, rise: float, color: Color, yaw: float = 0.0) -> void:
	var tmp := MeshKit.Builder.new()
	var hw := width * 0.5 + 0.3
	var hd := depth * 0.5 + 0.3
	var ridge_a := Vector3(0, rise, -hd)
	var ridge_b := Vector3(0, rise, hd)
	var c2 := color * 0.85
	c2.a = 1.0
	# Roof faces are emitted with both windings: thin surfaces seen from
	# inside the house must not disappear.
	var faces := [
		[Vector3(-hw, 0, -hd), ridge_a, ridge_b, Vector3(-hw, 0, hd), color],
		[ridge_a, Vector3(hw, 0, -hd), Vector3(hw, 0, hd), ridge_b, c2],
	]
	for f in faces:
		tmp.quad(f[0], f[1], f[2], f[3], f[4])
		tmp.quad(f[3], f[2], f[1], f[0], f[4] * 0.8)
	for g in [[Vector3(-hw, 0, hd), Vector3(hw, 0, hd), ridge_b], [Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd), ridge_a]]:
		tmp.tri(g[0], g[1], g[2], color * 0.7)
		tmp.tri(g[2], g[1], g[0], color * 0.7)
	_append_transformed(tmp, Transform3D(Basis(Vector3.UP, yaw), center))
	var s := BoxShape3D.new()
	s.size = Vector3(width + 0.6, 0.3, depth + 0.6)
	shapes.append([Transform3D(Basis(Vector3.UP, yaw), center + Vector3(0, rise * 0.5, 0)), s])


func cone_roof(center: Vector3, radius: float, rise: float, color: Color) -> void:
	b.cylinder(center, rise, radius, 0.0, 9, color, color * 1.15)


func rock(center: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	b.blob(center, size, color, color * 0.72, 1, 0.18, rng.randi())
	if collide:
		var s := SphereShape3D.new()
		s.radius = (size.x + size.z) * 0.42
		shapes.append([Transform3D(Basis(), center), s])


func rune(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	has_glow = true
	var tmp := MeshKit.Builder.new()
	tmp.box(Vector3.ZERO, size, Color(1, 1, 1))
	var mesh := tmp.commit()
	var arrays := mesh.surface_get_arrays(0)
	var xf := Transform3D(Basis(Vector3.UP, yaw), center)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(0, verts.size(), 3):
		glow.tri(xf * verts[i], xf * verts[i + 1], xf * verts[i + 2], Color(1, 1, 1))


func _append_transformed(tmp: MeshKit.Builder, xf: Transform3D) -> void:
	var mesh := tmp.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(0, verts.size(), 3):
		b.tri(xf * verts[i], xf * verts[i + 1], xf * verts[i + 2], cols[i])


## Finalize into a node: mesh + collision (+ emissive rune mesh).
func build(parent: Node3D, node_name: String, vis_range: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = WorldMaterials.get_mat(&"vertex_color")
	if vis_range > 0.0:
		mi.visibility_range_end = vis_range
	root.add_child(mi)
	if has_glow:
		var gi := MeshInstance3D.new()
		gi.mesh = glow.commit()
		gi.material_override = WorldMaterials.get_mat(&"glow_rune")
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gi)
	if not shapes.is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		for sh in shapes:
			var cs := CollisionShape3D.new()
			cs.shape = sh[1]
			cs.transform = sh[0]
			body.add_child(cs)
		root.add_child(body)
	return root
