class_name StructureKit
extends RefCounted
## Architecture kit of the "Wind Wardens" (see docs/ART_DIRECTION.md §4).
##
## Accumulates pieces into TWO vertex-coloured meshes — a detailed near mesh
## and a simplified far mesh (structure HLOD: no ribs, brackets, lattices,
## balusters, ribbons) — plus colliders in ONE static body. One draw call per
## structure per LOD, both drawn with assets/shaders/architecture.gdshader.
##
## Vertex alpha encodes the surface type (read by the shader):
##   1.0 matte (stone, wood, plaster) · 0.8 glazed tile · 0.6 gilded
##   0.4 cloth (sways in the wind; sway weight in UV.x) · 0.2 lamp (night glow)
## Colours are authored in sRGB (the shader linearises them).

const MATTE := 1.0
const GLAZE := 0.8
const GILT := 0.6
const CLOTH := 0.4
const LAMP := 0.2

const ROOF := Color(0.141, 0.278, 0.302)
const ROOF_LIGHT := Color(0.208, 0.392, 0.416)
const CINNABAR := Color(0.659, 0.208, 0.169)
const CINNABAR_LIGHT := Color(0.788, 0.329, 0.231)
const GOLD := Color(0.847, 0.698, 0.353)
const WHITE_STONE := Color(0.890, 0.863, 0.796)
const COOL_STONE := Color(0.553, 0.592, 0.612)
const INK_WOOD := Color(0.227, 0.165, 0.133)
const JADE := Color(0.310, 0.541, 0.388)
const PLASTER := Color(0.925, 0.898, 0.831)
const LATTICE := Color(0.420, 0.227, 0.165)
const PAPER := Color(0.965, 0.875, 0.659)

var b := MeshKit.Builder.new()      # near mesh
var far := MeshKit.Builder.new()    # far mesh (HLOD)
var shapes: Array = []              # [Transform3D, Shape3D]
var rng := RandomNumberGenerator.new()
var glow := MeshKit.Builder.new()
var has_glow := false
var has_far := false
## Distance at which the detailed mesh hands over to the far mesh.
var near_range := 170.0
## World-space positions of lamps (callers may add a few real lights).
var lamps: Array[Vector3] = []


## Colliders of this kit give no grip to climbers (see Player.probe_wall).
var slick := false


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value
	# UV.x carries the cloth sway weight: the format must be declared before
	# the first vertex.
	b.st.set_uv(Vector2.ZERO)


# --- Low-level emitters ---------------------------------------------------------------------------

static func id(col: Color, mat: float) -> Color:
	return Color(col.r, col.g, col.b, mat)


static func _sh(col: Color, k: float) -> Color:
	return Color(minf(col.r * k, 1.0), minf(col.g * k, 1.0), minf(col.b * k, 1.0), col.a)


## Quad emitted so that its front face points along `n` (either winding in).
static func qf(t: MeshKit.Builder, a: Vector3, bb: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
	if -(bb - a).cross(c - a).dot(n) >= 0.0:
		t.quad(a, bb, c, d, col)
	else:
		t.quad(d, c, bb, a, col)


static func box_into(t: MeshKit.Builder, xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for p in [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
			Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]:
		c.append(xf * p)
	t.quad(c[4], c[5], c[6], c[7], col)
	t.quad(c[3], c[2], c[1], c[0], _sh(col, 0.62))
	t.quad(c[7], c[6], c[2], c[3], _sh(col, 0.93))
	t.quad(c[5], c[4], c[0], c[1], _sh(col, 0.88))
	t.quad(c[6], c[5], c[1], c[2], _sh(col, 0.96))
	t.quad(c[4], c[7], c[3], c[0], _sh(col, 0.85))


## Prism / tapered cylinder between two points, faces oriented outward.
static func prism_into(t: MeshKit.Builder, a: Vector3, bb: Vector3, r0: float, r1: float, sides: int, col: Color, caps: bool = true) -> void:
	var axis := (bb - a).normalized()
	var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u).normalized()
	var r0s: Array[Vector3] = []
	var r1s: Array[Vector3] = []
	for i in sides:
		var ang := TAU * (i + 0.5) / sides
		var dir := u * cos(ang) + v * sin(ang)
		r0s.append(a + dir * r0)
		r1s.append(bb + dir * r1)
	for i in sides:
		var j := (i + 1) % sides
		var out := ((r0s[i] + r0s[j]) * 0.5 - a).normalized()
		qf(t, r0s[i], r0s[j], r1s[j], r1s[i], _sh(col, 0.9 + 0.1 * sin(TAU * i / sides)), out)
	if caps:
		for i in sides:
			var j := (i + 1) % sides
			if r1 > 0.001:
				_tri_f(t, bb, r1s[i], r1s[j], col, axis)
			_tri_f(t, a, r0s[i], r0s[j], _sh(col, 0.7), -axis)


static func _tri_f(t: MeshKit.Builder, a: Vector3, bb: Vector3, c: Vector3, col: Color, n: Vector3) -> void:
	if -(bb - a).cross(c - a).dot(n) >= 0.0:
		t.tri(a, bb, c, col)
	else:
		t.tri(c, bb, a, col)


func _both_box(xf: Transform3D, size: Vector3, col: Color, far_too: bool = true) -> void:
	box_into(b, xf, size, col)
	if far_too:
		box_into(far, xf, size, col)
		has_far = true


func _collide_box(xf: Transform3D, size: Vector3) -> void:
	var s := BoxShape3D.new()
	s.size = size
	shapes.append([xf, s])


func _collide_cyl(base: Vector3, height: float, radius: float) -> void:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	shapes.append([Transform3D(Basis(), base + Vector3(0, height * 0.5, 0)), s])


# --- Generic pieces (kept API) ---------------------------------------------------------------------

## Solid block (optionally yaw-rotated) with collision.
func block(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0, collide: bool = true, jitter: float = 0.06, mat: float = MATTE, far_too: bool = true) -> void:
	var c := id(_sh(color, 1.0 + rng.randf_range(-jitter, jitter)), mat)
	var xf := Transform3D(Basis(Vector3.UP, yaw), center)
	_both_box(xf, size, c, far_too)
	if collide:
		_collide_box(xf, size)


## Block with an arbitrary basis (bridge decks, fallen beams).
func block_xf(xf: Transform3D, size: Vector3, color: Color, collide: bool = true, mat: float = MATTE, far_too: bool = true) -> void:
	_both_box(xf, size, id(color, mat), far_too)
	if collide:
		_collide_box(xf, size)


## Wall from a to b (ground plane), stone courses in running bond with moss
## gathering low. Far mesh gets one slab.
func wall(a: Vector3, bb: Vector3, height: float, thickness: float, color: Color, coping: bool = false) -> void:
	var dir := bb - a
	dir.y = 0.0
	var length := dir.length()
	var yaw := atan2(dir.x, dir.z)
	var mid := (a + bb) * 0.5
	var courses := maxi(1, int(height / 0.9))
	var ch := height / courses
	var basis := Basis(Vector3.UP, yaw)
	for i in courses:
		var moss_k := clampf(1.0 - float(i) / 2.5, 0.0, 1.0) * rng.randf_range(0.15, 0.45)
		var split := clampf(0.5 + (0.22 if i % 2 == 0 else -0.22) + rng.randf_range(-0.08, 0.08), 0.15, 0.85)
		var y := ch * (i + 0.5)
		var z0 := -length * 0.5
		for part in 2:
			var seg_len := length * (split if part == 0 else 1.0 - split)
			var seg_mid := z0 + seg_len * 0.5
			z0 += seg_len
			var col := _sh(color, rng.randf_range(0.9, 1.06)).lerp(Color(0.33, 0.45, 0.3), moss_k)
			col.a = MATTE
			var inset := rng.randf_range(0.0, 0.04)
			box_into(b, Transform3D(basis, mid + basis * Vector3(0, y, seg_mid)), Vector3(thickness - inset, ch * 0.96, seg_len - 0.06), col)
	box_into(far, Transform3D(basis, mid + Vector3(0, height * 0.5, 0)), Vector3(thickness, height, length), id(color, MATTE))
	has_far = true
	if coping:
		# Glazed tile coping: a small pitched cap with pale tile ends.
		var cap_xf := Transform3D(basis, mid + Vector3(0, height, 0))
		_gable_cap(cap_xf, thickness + 0.5, length + 0.2, 0.45)
	_collide_box(Transform3D(basis, mid + Vector3(0, height * 0.5, 0)), Vector3(thickness, height, length))


func _gable_cap(xf: Transform3D, w: float, length: float, rise: float) -> void:
	var hw := w * 0.5
	var hl := length * 0.5
	var col := id(ROOF, GLAZE)
	for t in [b, far]:
		qf(t, xf * Vector3(-hw, 0, -hl), xf * Vector3(0, rise, -hl), xf * Vector3(0, rise, hl), xf * Vector3(-hw, 0, hl), col, xf.basis * Vector3(-1, 1, 0))
		qf(t, xf * Vector3(hw, 0, -hl), xf * Vector3(0, rise, -hl), xf * Vector3(0, rise, hl), xf * Vector3(hw, 0, hl), _sh(col, 0.92), xf.basis * Vector3(1, 1, 0))
		for e in [-hl, hl]:
			_tri_f(t, xf * Vector3(-hw, 0, e), xf * Vector3(hw, 0, e), xf * Vector3(0, rise, e), id(WHITE_STONE, MATTE), xf.basis * Vector3(0, 0, signf(e)))
	box_into(b, xf * Transform3D(Basis(), Vector3(0, rise + 0.05, 0)), Vector3(0.18, 0.14, length + 0.1), id(ROOF_LIGHT, GLAZE))


func pillar(base: Vector3, height: float, radius: float, color: Color, sides: int = 8) -> void:
	prism_into(b, base, base + Vector3(0, height, 0), radius, radius * 0.92, sides, id(color, MATTE))
	prism_into(far, base, base + Vector3(0, height, 0), radius, radius * 0.92, mini(sides, 5), id(color, MATTE))
	has_far = true
	_collide_cyl(base, height, radius)


## Plain pitched roof (tents, sheds).
func roof(center: Vector3, width: float, depth: float, rise: float, color: Color, yaw: float = 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), center)
	var hw := width * 0.5 + 0.3
	var hd := depth * 0.5 + 0.3
	var col := id(color, MATTE)
	for t in [b, far]:
		for side in [-1.0, 1.0]:
			var n: Vector3 = xf.basis * Vector3(side, 1, 0)
			var q := [xf * Vector3(side * hw, 0, -hd), xf * Vector3(0, rise, -hd), xf * Vector3(0, rise, hd), xf * Vector3(side * hw, 0, hd)]
			qf(t, q[0], q[1], q[2], q[3], col, n)
			qf(t, q[0], q[1], q[2], q[3], _sh(col, 0.7), -n)
		for e in [-hd, hd]:
			var tri := [xf * Vector3(-hw, 0, e), xf * Vector3(hw, 0, e), xf * Vector3(0, rise, e)]
			_tri_f(t, tri[0], tri[1], tri[2], _sh(col, 0.75), xf.basis * Vector3(0, 0, signf(e)))
			_tri_f(t, tri[0], tri[1], tri[2], _sh(col, 0.6), xf.basis * Vector3(0, 0, -signf(e)))
	has_far = true
	_collide_box(Transform3D(xf.basis, center + Vector3(0, rise * 0.5, 0)), Vector3(width + 0.6, 0.3, depth + 0.6))


func cone_roof(center: Vector3, radius: float, rise: float, color: Color) -> void:
	poly_roof(center, radius, 8, rise, color, 0.0)


func rock(center: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	var c := id(color, MATTE)
	var dark := id(_sh(color, 0.72), MATTE)
	var seed_value := rng.randi()
	b.blob(center, size, c, dark, 1, 0.18, seed_value)
	far.blob(center, size, c, dark, 0, 0.18, seed_value)
	has_far = true
	if collide:
		var s := SphereShape3D.new()
		s.radius = (size.x + size.z) * 0.42
		shapes.append([Transform3D(Basis(), center), s])


## Tapered drum stack helper for rock needles (both LODs).
func drum(base: Vector3, height: float, r0: float, r1: float, sides: int, col: Color) -> void:
	prism_into(b, base, base + Vector3(0, height, 0), r0, r1, sides, id(col, MATTE))
	prism_into(far, base, base + Vector3(0, height, 0), r0, r1, maxi(sides - 2, 4), id(col, MATTE))
	has_far = true


func canopy(center: Vector3, radius: Vector3, col: Color, col_bottom: Color, seed_value: int) -> void:
	b.blob(center, radius, id(col, MATTE), id(col_bottom, MATTE), 1, 0.18, seed_value, true)
	far.blob(center, radius, id(col, MATTE), id(col_bottom, MATTE), 0, 0.18, seed_value, true)
	has_far = true


func rune(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	has_glow = true
	box_into(glow, Transform3D(Basis(Vector3.UP, yaw), center), size, Color(1, 1, 1))


# --- Roofs ------------------------------------------------------------------------------------------

## Height profile of a roof slope: steep near the ridge, flattening to the
## eave (t = 0 at the eave, 1 at the ridge).
static func _profile(t: float) -> float:
	return 0.3 * t + 0.7 * pow(t, 1.9)


## One roof slope between an eave edge (ea→eb, y = 0) and a ridge edge
## (ra→rb, y = rise). Corners (s = 0/1) curl up and out.
func _roof_face(xf: Transform3D, ea: Vector3, eb: Vector3, ra: Vector3, rb: Vector3, rise: float, lift: float, col: Color, under: Color, ns: int, nt: int, t: MeshKit.Builder, ribs: bool) -> void:
	var grid: Array = []
	for j in nt + 1:
		var row: Array[Vector3] = []
		var tt := float(j) / nt
		for i in ns + 1:
			var s := float(i) / ns
			var e := ea.lerp(eb, s)
			var r := ra.lerp(rb, s)
			var p := e.lerp(r, tt)
			var cs := pow(absf(2.0 * s - 1.0), 5.0)
			var curl := pow(1.0 - tt, 3.0)
			p.y = rise * _profile(tt) + lift * (cs * 0.85 + 0.15) * curl
			var out := Vector3(e.x, 0, e.z).normalized()
			p += out * lift * 0.45 * cs * curl
			row.append(p)
		grid.append(row)
	var thick := 0.16
	for j in nt:
		for i in ns:
			var a: Vector3 = xf * grid[j][i]
			var bb: Vector3 = xf * grid[j][i + 1]
			var c: Vector3 = xf * grid[j + 1][i + 1]
			var d: Vector3 = xf * grid[j + 1][i]
			var tone := 1.0
			if ribs:
				tone = 1.0 if i % 2 == 0 else 0.84
			tone *= 0.9 + 0.12 * float(j) / nt
			qf(t, a, bb, c, d, _sh(col, tone), Vector3.UP)
			var dn := Vector3(0, -thick, 0)
			qf(t, a + dn, bb + dn, c + dn, d + dn, under, Vector3.DOWN)
	# Eave fascia with pale tile ends.
	for i in ns:
		var a: Vector3 = xf * grid[0][i]
		var bb: Vector3 = xf * grid[0][i + 1]
		var out := xf.basis * Vector3((grid[0][i] + grid[0][i + 1]).x, 0, (grid[0][i] + grid[0][i + 1]).z).normalized()
		qf(t, a, bb, bb + Vector3(0, -thick, 0), a + Vector3(0, -thick, 0), id(WHITE_STONE * 0.92, MATTE) if ribs and i % 2 == 0 else id(_sh(WHITE_STONE, 0.75), MATTE), out)
	if ribs:
		# Hip ridge along the s = 0 edge (the s = 1 edge is the next face's s = 0).
		var prev: Vector3 = xf * (grid[0][0] + Vector3(0, 0.08, 0))
		for j in range(1, nt + 1):
			var cur: Vector3 = xf * (grid[j][0] + Vector3(0, 0.08, 0))
			prism_into(t, prev, cur, 0.11, 0.11, 4, id(ROOF_LIGHT, GLAZE), false)
			prev = cur


## Hip roof (rectangular footprint w × d, w along local X) with lifted corners,
## tile ribs, dark rafters, hip ridges, a glazed ridge beam and sail finials.
func hip_roof(center: Vector3, w: float, d: float, rise: float, yaw: float, col: Color = ROOF, lift: float = -1.0) -> void:
	if d > w:
		var tmp := w
		w = d
		d = tmp
		yaw += PI * 0.5
	var xf := Transform3D(Basis(Vector3.UP, yaw), center)
	var hw := w * 0.5
	var hd := d * 0.5
	var lift_v := rise * 0.32 if lift < 0.0 else lift
	var rx := maxf(hw - hd, 0.0)
	var faces := [
		[Vector3(-hw, 0, hd), Vector3(hw, 0, hd), Vector3(-rx, rise, 0), Vector3(rx, rise, 0)],
		[Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd), Vector3(rx, rise, 0), Vector3(-rx, rise, 0)],
		[Vector3(hw, 0, hd), Vector3(hw, 0, -hd), Vector3(rx, rise, 0), Vector3(rx, rise, 0)],
		[Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd), Vector3(-rx, rise, 0), Vector3(-rx, rise, 0)],
	]
	var c := id(col, GLAZE)
	var under := id(_sh(CINNABAR, 0.55), MATTE)
	for f in faces:
		var edge_len := (f[1] as Vector3).distance_to(f[0])
		_roof_face(xf, f[0], f[1], f[2], f[3], rise, lift_v, c, under, clampi(int(edge_len / 1.1), 4, 14), 5, b, true)
		_roof_face(xf, f[0], f[1], f[2], f[3], rise, lift_v, c, under, 2, 2, far, false)
	has_far = true
	# Ridge beam + sail finials curling inward.
	var ridge_len := rx * 2.0 + 0.5
	box_into(b, xf * Transform3D(Basis(), Vector3(0, rise + 0.12, 0)), Vector3(ridge_len, 0.34, 0.42), id(ROOF_LIGHT, GLAZE))
	box_into(far, xf * Transform3D(Basis(), Vector3(0, rise + 0.12, 0)), Vector3(ridge_len, 0.34, 0.42), id(ROOF_LIGHT, GLAZE))
	for sx in [-1.0, 1.0]:
		_sail_finial(xf, Vector3(sx * (rx + 0.1), rise + 0.2, 0), Vector3(sx, 0, 0), rise * 0.16 + 0.35)
	_collide_box(Transform3D(xf.basis, center + Vector3(0, rise * 0.45, 0)), Vector3(w * 0.85, rise * 0.9, d * 0.85))


## Polygonal roof (pavilions, pagoda tops) with a gilded apex spire.
func poly_roof(center: Vector3, radius: float, sides: int, rise: float, col: Color = ROOF, yaw: float = 0.0, lift: float = -1.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), center)
	var lift_v := rise * 0.3 if lift < 0.0 else lift
	var c := id(col, GLAZE)
	var under := id(_sh(CINNABAR, 0.55), MATTE)
	var apex := Vector3(0, rise, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var ea := Vector3(cos(a0), 0, sin(a0)) * radius
		var eb := Vector3(cos(a1), 0, sin(a1)) * radius
		_roof_face(xf, ea, eb, apex, apex, rise, lift_v, c, under, clampi(int(ea.distance_to(eb) / 1.1), 3, 10), 5, b, true)
		_roof_face(xf, ea, eb, apex, apex, rise, lift_v, c, under, 1, 2, far, false)
	has_far = true
	spire(center + Vector3(0, rise - 0.1, 0), rise * 0.45 + 0.6)
	_collide_cyl(center, rise * 0.8, radius * 0.8)


## Gilded spire of stacked rings (roof apex, pagoda crown).
func spire(base: Vector3, height: float) -> void:
	var g := id(GOLD, GILT)
	prism_into(b, base, base + Vector3(0, height, 0), 0.16, 0.04, 6, g)
	var rings := 3
	for i in rings:
		var y := height * (0.2 + 0.2 * i)
		prism_into(b, base + Vector3(0, y, 0), base + Vector3(0, y + 0.1, 0), 0.34 - i * 0.07, 0.34 - i * 0.07, 8, g)
	b.blob(base + Vector3(0, height + 0.1, 0), Vector3(0.18, 0.24, 0.18), g, g, 0, 0.0, 1)
	prism_into(far, base, base + Vector3(0, height, 0), 0.2, 0.04, 4, g)


## "Sail" finial: a horn that rises and curls back toward the ridge — the
## Wind Wardens' signature silhouette.
func _sail_finial(xf: Transform3D, p: Vector3, outward: Vector3, size: float) -> void:
	var pts := [p, p + outward * size * 0.35 + Vector3(0, size * 0.45, 0), p + outward * size * 0.3 + Vector3(0, size * 0.85, 0), p - outward * size * 0.05 + Vector3(0, size * 1.0, 0)]
	var col := id(ROOF_LIGHT, GLAZE)
	for i in 3:
		var r0 := 0.2 * (1.0 - i * 0.28)
		prism_into(b, xf * pts[i], xf * pts[i + 1], r0, r0 * 0.72, 5, col if i < 2 else id(GOLD, GILT))
	prism_into(far, xf * pts[0], xf * pts[2], 0.2, 0.08, 4, col)


# --- Timber frame pieces ----------------------------------------------------------------------------

## Cinnabar column on a pale stone drum with a jade capital.
func column(base: Vector3, height: float, radius: float = 0.3, col: Color = CINNABAR) -> void:
	prism_into(b, base, base + Vector3(0, 0.35, 0), radius * 1.55, radius * 1.4, 8, id(WHITE_STONE, MATTE))
	prism_into(b, base + Vector3(0, 0.35, 0), base + Vector3(0, height - 0.3, 0), radius, radius * 0.94, 8, id(col, MATTE))
	box_into(b, Transform3D(Basis(), base + Vector3(0, height - 0.15, 0)), Vector3(radius * 2.4, 0.3, radius * 2.4), id(JADE, MATTE))
	prism_into(far, base, base + Vector3(0, height, 0), radius * 1.1, radius, 4, id(col, MATTE))
	has_far = true
	_collide_cyl(base, height, radius * 1.2)


## Row of bracket blocks under an eave (abstracted, alternating jade/gold).
func brackets(a: Vector3, bb: Vector3, count: int) -> void:
	var dir := bb - a
	var yaw := atan2(dir.x, dir.z)
	for i in count:
		var p := a.lerp(bb, (i + 0.5) / count)
		var c := JADE if i % 2 == 0 else GOLD
		box_into(b, Transform3D(Basis(Vector3.UP, yaw), p), Vector3(0.5, 0.28, 0.34), id(c, GILT if i % 2 else MATTE))
		box_into(b, Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.22, 0)), Vector3(0.7, 0.16, 0.42), id(CINNABAR_LIGHT, MATTE))


## Wall panel between two columns: plaster with a lattice window (or a lattice
## door when `door`), framed in dark wood.
func panel(a: Vector3, bb: Vector3, h: float, door: bool = false, window: bool = true) -> void:
	var dir := bb - a
	dir.y = 0.0
	var length := dir.length()
	var yaw := atan2(dir.x, dir.z)
	var basis := Basis(Vector3.UP, yaw)
	var mid := (a + bb) * 0.5
	var thick := 0.22
	var xf := Transform3D(basis, mid + Vector3(0, h * 0.5, 0))
	var fill := LATTICE if door else PLASTER
	box_into(b, xf, Vector3(thick, h, length), id(fill, MATTE))
	box_into(far, xf, Vector3(thick, h, length), id(fill, MATTE))
	has_far = true
	_collide_box(xf, Vector3(thick, h, length))
	# Sill + frame
	box_into(b, Transform3D(basis, mid + Vector3(0, 0.12, 0)), Vector3(thick + 0.08, 0.24, length), id(INK_WOOD, MATTE))
	if door or window:
		var wy := h * (0.5 if door else 0.58)
		var wh := h * (0.8 if door else 0.38)
		var ww := length * (0.8 if door else 0.55)
		for side in [-1.0, 1.0]:
			var off := basis * Vector3(side * (thick * 0.5 + 0.02), 0, 0)
			var o := mid + off + Vector3(0, wy, 0)
			box_into(b, Transform3D(basis, o), Vector3(0.05, wh, ww), id(PAPER * 0.9 if not door else PAPER * 0.75, MATTE))
			# Lattice grid
			var nx := 4 if door else 3
			for k in nx + 1:
				var z := -ww * 0.5 + ww * k / nx
				box_into(b, Transform3D(basis, o + basis * Vector3(side * 0.03, 0, z)), Vector3(0.05, wh, 0.07), id(LATTICE, MATTE))
			for k in 4:
				var y := -wh * 0.5 + wh * k / 3.0
				box_into(b, Transform3D(basis, o + basis * Vector3(side * 0.03, y, 0)), Vector3(0.05, 0.07, ww), id(LATTICE, MATTE))


# --- Ground pieces ------------------------------------------------------------------------------------

## Pale stone balustrade along a→b: posts with round caps, top and bottom rails.
func balustrade(a: Vector3, bb: Vector3, h: float = 0.95) -> void:
	var length := a.distance_to(bb)
	if length < 0.2:
		return
	var dir := (bb - a) / length
	var yaw := atan2(dir.x, dir.z)
	var basis := Basis(Vector3.UP, yaw)
	var posts := maxi(1, int(length / 1.6))
	for i in posts + 1:
		var p := a.lerp(bb, float(i) / posts)
		box_into(b, Transform3D(basis, p + Vector3(0, h * 0.5, 0)), Vector3(0.24, h, 0.24), id(WHITE_STONE, MATTE))
		b.blob(p + Vector3(0, h + 0.1, 0), Vector3(0.15, 0.13, 0.15), id(WHITE_STONE, MATTE), id(_sh(WHITE_STONE, 0.85), MATTE), 0, 0.0, i)
	var mid := (a + bb) * 0.5
	box_into(b, Transform3D(basis, mid + Vector3(0, h - 0.08, 0)), Vector3(0.16, 0.16, length), id(WHITE_STONE, MATTE))
	box_into(b, Transform3D(basis, mid + Vector3(0, 0.12, 0)), Vector3(0.2, 0.2, length), id(_sh(WHITE_STONE, 0.9), MATTE))
	# Panels between rails
	box_into(b, Transform3D(basis, mid + Vector3(0, h * 0.45, 0)), Vector3(0.08, h * 0.5, length - 0.2), id(_sh(WHITE_STONE, 0.94), MATTE))
	box_into(far, Transform3D(basis, mid + Vector3(0, h * 0.5, 0)), Vector3(0.18, h, length), id(WHITE_STONE, MATTE))
	has_far = true
	_collide_box(Transform3D(basis, mid + Vector3(0, h * 0.5, 0)), Vector3(0.25, h, length))


## Straight stair flight climbing `height` toward local -Z of `yaw`, starting
## at `foot` (ground level). Collision is a smooth ramp (mobile-friendly
## character movement), visuals are steps with side cheeks.
func stairs(foot: Vector3, yaw: float, width: float, height: float, rails: bool = true) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var run := height * 1.6
	var steps := maxi(2, int(ceil(height / 0.24)))
	for i in steps:
		var y := height * (i + 0.5) / steps
		var z := -run * (i + 0.5) / steps
		var col := _sh(WHITE_STONE, 0.9 + 0.08 * (i % 2))
		box_into(b, Transform3D(basis, foot + basis * Vector3(0, y * 0.5, z)), Vector3(width, y, run / steps), id(col, MATTE))
	# Far: one wedge-ish block
	var ang := atan2(height, run)
	var slope_len := sqrt(height * height + run * run)
	var ramp_xf := Transform3D(basis * Basis(Vector3.RIGHT, ang), foot + basis * Vector3(0, height * 0.5 - 0.12, -run * 0.5))
	box_into(far, ramp_xf, Vector3(width, 0.3, slope_len), id(WHITE_STONE, MATTE))
	has_far = true
	_collide_box(ramp_xf, Vector3(width, 0.3, slope_len))
	if rails:
		for sx in [-1.0, 1.0]:
			var a := foot + basis * Vector3(sx * (width * 0.5 + 0.15), 0, 0)
			var e := foot + basis * Vector3(sx * (width * 0.5 + 0.15), height, -run)
			prism_into(b, a + Vector3(0, 0.5, 0), e + Vector3(0, 0.5, 0), 0.16, 0.16, 4, id(WHITE_STONE, MATTE))
			box_into(b, Transform3D(basis, a + Vector3(0, 0.5, 0)), Vector3(0.36, 1.0, 0.36), id(WHITE_STONE, MATTE))


## Terrace: pale stone platform (sunk into the slope) with a coping slab,
## balustrade around the rim and a stair flight on the front (+Z) side.
## Returns the top surface height (local).
func terrace(center: Vector3, w: float, d: float, h: float, yaw: float, stair_sides: Array = [0], rails: bool = true, sink: float = 3.0) -> float:
	var basis := Basis(Vector3.UP, yaw)
	var body_h := h + sink
	var xf := Transform3D(basis, center + Vector3(0, h - body_h * 0.5, 0))
	_both_box(xf, Vector3(w, body_h, d), id(COOL_STONE, MATTE))
	_collide_box(xf, Vector3(w, body_h, d))
	var top := center.y + h
	block_xf(Transform3D(basis, Vector3(center.x, top + 0.1, center.z)), Vector3(w + 0.35, 0.2, d + 0.35), WHITE_STONE, true)
	top += 0.2
	# Course lines on the body for scale.
	for k in range(1, int(h / 0.8) + 1):
		var y := top - 0.2 - k * 0.8
		if y < center.y - 0.3:
			break
		box_into(b, Transform3D(basis, Vector3(center.x, y, center.z)), Vector3(w + 0.06, 0.08, d + 0.06), id(_sh(COOL_STONE, 0.8), MATTE))
	# Sides: 0 front (+Z), 1 right (+X), 2 back (-Z), 3 left (-X)
	var stair_w := minf(3.2, w * 0.4)
	var edges := [
		[Vector3(-w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, d * 0.5)],
		[Vector3(w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, -d * 0.5)],
		[Vector3(w * 0.5, 0, -d * 0.5), Vector3(-w * 0.5, 0, -d * 0.5)],
		[Vector3(-w * 0.5, 0, -d * 0.5), Vector3(-w * 0.5, 0, d * 0.5)],
	]
	for side in 4:
		var ea: Vector3 = edges[side][0]
		var eb: Vector3 = edges[side][1]
		var inward := -Vector3((ea + eb).x, 0, (ea + eb).z).normalized() * 0.2
		var pa := Vector3(center.x, top, center.z) + basis * (ea + inward)
		var pb := Vector3(center.x, top, center.z) + basis * (eb + inward)
		if side in stair_sides:
			var mid := (ea + eb) * 0.5
			var out_dir := Vector3(mid.x, 0, mid.z).normalized()
			var s_yaw := yaw + atan2(out_dir.x, out_dir.z)
			var foot := Vector3(center.x, center.y, center.z) + basis * (mid + out_dir * (h + 0.2) * 1.6)
			stairs(foot, s_yaw, stair_w, h + 0.2, rails)
			if rails:
				var g := stair_w * 0.5 + 0.2
				var edge_len := ea.distance_to(eb)
				balustrade(pa, pa.lerp(pb, 0.5 - g / edge_len), 0.95)
				balustrade(pa.lerp(pb, 0.5 + g / edge_len), pb, 0.95)
		elif rails:
			balustrade(pa, pb, 0.95)
	return top - center.y


# --- Composite buildings -----------------------------------------------------------------------------

## Hall: cinnabar columns on the perimeter, plaster/lattice walls, bracket band,
## eave roof. `front_open` leaves the middle front bay open as the entrance.
func hall(center: Vector3, w: float, d: float, h: float, yaw: float, roof_col: Color = ROOF, double_eave: bool = false, walls: bool = true) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var bays_w := maxi(1, int(round(w / 2.8)))
	var bays_d := maxi(1, int(round(d / 2.8)))
	var hw := w * 0.5
	var hd := d * 0.5
	var ring: Array[Vector3] = []
	for i in bays_w + 1:
		ring.append(Vector3(-hw + w * i / bays_w, 0, hd))
	for i in range(1, bays_d + 1):
		ring.append(Vector3(hw, 0, hd - d * i / bays_d))
	for i in range(1, bays_w + 1):
		ring.append(Vector3(hw - w * i / bays_w, 0, -hd))
	for i in range(1, bays_d):
		ring.append(Vector3(-hw, 0, -hd + d * i / bays_d))
	for p in ring:
		column(center + basis * p, h, 0.3)
	if walls:
		for i in ring.size():
			var a: Vector3 = ring[i]
			var e: Vector3 = ring[(i + 1) % ring.size()]
			var front := i < bays_w
			var mid_bay := int(bays_w / 2.0)
			if front and i == mid_bay:
				continue
			panel(center + basis * a, center + basis * e, h - 0.3, front, true)
	# Lintel beams + bracket band
	var ly := h + 0.12
	for i in ring.size():
		var a: Vector3 = center + basis * ring[i] + Vector3(0, ly, 0)
		var e: Vector3 = center + basis * ring[(i + 1) % ring.size()] + Vector3(0, ly, 0)
		var dir := e - a
		box_into(b, Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), (a + e) * 0.5), Vector3(0.36, 0.36, dir.length() + 0.3), id(CINNABAR, MATTE))
		box_into(far, Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), (a + e) * 0.5), Vector3(0.36, 0.36, dir.length() + 0.3), id(CINNABAR, MATTE))
		brackets(a + Vector3(0, 0.3, 0), e + Vector3(0, 0.3, 0), maxi(2, int(dir.length() / 0.9)))
	var roof_y := h + 0.8
	var over := 1.6
	if double_eave:
		hip_roof(center + Vector3(0, roof_y, 0), w + over * 2.0, d + over * 2.0, d * 0.22, yaw, roof_col)
		var up := center + Vector3(0, roof_y + d * 0.2, 0)
		for p in [Vector3(-hw * 0.7, 0, hd * 0.7), Vector3(hw * 0.7, 0, hd * 0.7), Vector3(hw * 0.7, 0, -hd * 0.7), Vector3(-hw * 0.7, 0, -hd * 0.7)]:
			column(up + basis * p, 1.6, 0.24)
		block_xf(Transform3D(basis, up + Vector3(0, 0.9, 0)), Vector3(w * 0.7 + 0.2, 1.4, d * 0.7 + 0.2), PLASTER, false)
		brackets(up + basis * Vector3(-hw * 0.7, 1.75, hd * 0.7), up + basis * Vector3(hw * 0.7, 1.75, hd * 0.7), maxi(3, int(w * 0.7 / 0.9)))
		hip_roof(up + Vector3(0, 1.9, 0), w * 0.7 + over * 2.0, d * 0.7 + over * 2.0, d * 0.38, yaw, roof_col)
	else:
		hip_roof(center + Vector3(0, roof_y, 0), w + over * 2.0, d + over * 2.0, d * 0.42, yaw, roof_col)
	# Floor
	block_xf(Transform3D(basis, center + Vector3(0, 0.06, 0)), Vector3(w + 0.4, 0.12, d + 0.4), _sh(WHITE_STONE, 0.85), false)


## Tiered tower (pagoda): each storey shrinks and carries its own eave roof.
## Returns the top height (local).
func pagoda(center: Vector3, levels: int, base_w: float, yaw: float, broken_from: int = 99) -> float:
	var basis := Basis(Vector3.UP, yaw)
	var y := center.y
	var w := base_w
	for l in levels:
		var h := 3.4 if l == 0 else 2.6
		var c := Vector3(center.x, y, center.z)
		if l >= broken_from:
			# Ruined storeys: stubs of columns and a tilted roof fragment.
			for p in [Vector3(-w * 0.5, 0, w * 0.5), Vector3(w * 0.5, 0, -w * 0.5), Vector3(-w * 0.5, 0, -w * 0.5)]:
				column(c + basis * p, h * rng.randf_range(0.35, 0.9), 0.28)
			var frag := Transform3D(basis * Basis(Vector3(1, 0, 1).normalized(), 0.35), c + Vector3(w * 0.4, h * 0.4, 0))
			block_xf(frag, Vector3(w * 0.8, 0.3, w * 0.9), ROOF, false, GLAZE)
			return y - center.y + h
		# Storey body: corner columns + panels with windows (door on ground floor front)
		var hw := w * 0.5
		var corners := [Vector3(-hw, 0, hw), Vector3(hw, 0, hw), Vector3(hw, 0, -hw), Vector3(-hw, 0, -hw)]
		for i in 4:
			column(c + basis * corners[i], h, 0.26 if l > 0 else 0.32)
		for i in 4:
			var door := l == 0 and i == 0
			if door:
				var a: Vector3 = c + basis * corners[0]
				var e: Vector3 = c + basis * corners[1]
				panel(a, a.lerp(e, 0.3), h - 0.3, false, false)
				panel(a.lerp(e, 0.7), e, h - 0.3, false, false)
				box_into(b, Transform3D(basis, (a + e) * 0.5 + Vector3(0, h - 0.6, 0)), Vector3(w * 0.42, 0.5, 0.26), id(GOLD, GILT))
			else:
				panel(c + basis * corners[i], c + basis * corners[(i + 1) % 4], h - 0.3, false, true)
		# Floor slab
		block_xf(Transform3D(basis, c + Vector3(0, 0.08, 0)), Vector3(w + 0.3, 0.16, w + 0.3), WHITE_STONE, true)
		# Bracket band on all four sides
		for i in 4:
			brackets(c + basis * corners[i] + Vector3(0, h + 0.2, 0), c + basis * corners[(i + 1) % 4] + Vector3(0, h + 0.2, 0), maxi(3, int(w / 0.9)))
		var over := 1.5 - l * 0.12
		var rise := w * 0.32
		hip_roof(c + Vector3(0, h + 0.55, 0), w + over * 2.0, w + over * 2.0, rise, yaw)
		y += h + 0.55 + rise * 0.55
		w *= 0.8
	spire(Vector3(center.x, y - 0.2, center.z), 3.2)
	return y - center.y + 3.2


## Open pavilion on n columns with bench rails and a polygonal roof.
func pavilion(center: Vector3, r: float, sides: int, h: float, yaw: float, open_side: int = 0) -> void:
	prism_into(b, center + Vector3(0, -1.5, 0), center + Vector3(0, 0.45, 0), r + 0.8, r + 0.7, sides, id(WHITE_STONE, MATTE))
	prism_into(far, center + Vector3(0, -1.5, 0), center + Vector3(0, 0.45, 0), r + 0.8, r + 0.7, sides, id(WHITE_STONE, MATTE))
	var s := CylinderShape3D.new()
	s.radius = r + 0.75
	s.height = 1.95
	shapes.append([Transform3D(Basis(), center + Vector3(0, -0.525, 0)), s])
	var base := center + Vector3(0, 0.45, 0)
	var pts: Array[Vector3] = []
	for i in sides:
		var a := yaw + TAU * i / sides
		pts.append(base + Vector3(cos(a), 0, sin(a)) * r)
	for p in pts:
		column(p, h, 0.24)
	for i in sides:
		var a: Vector3 = pts[i]
		var e: Vector3 = pts[(i + 1) % sides]
		var dir := e - a
		var yw := atan2(dir.x, dir.z)
		box_into(b, Transform3D(Basis(Vector3.UP, yw), (a + e) * 0.5 + Vector3(0, h + 0.1, 0)), Vector3(0.3, 0.3, dir.length()), id(CINNABAR, MATTE))
		# Hanging lattice frieze
		box_into(b, Transform3D(Basis(Vector3.UP, yw), (a + e) * 0.5 + Vector3(0, h - 0.35, 0)), Vector3(0.08, 0.4, dir.length() - 0.5), id(LATTICE, MATTE))
		if i != open_side:
			var inward := -Vector3(((a + e) * 0.5 - base).x, 0, ((a + e) * 0.5 - base).z).normalized()
			box_into(b, Transform3D(Basis(Vector3.UP, yw), (a + e) * 0.5 + inward * 0.25 + Vector3(0, 0.45, 0)), Vector3(0.5, 0.1, dir.length() - 0.5), id(INK_WOOD, MATTE))
			box_into(b, Transform3D(Basis(Vector3.UP, yw), (a + e) * 0.5 + Vector3(0, 0.75, 0)), Vector3(0.12, 0.12, dir.length() - 0.4), id(CINNABAR, MATTE))
	poly_roof(base + Vector3(0, h + 0.3, 0), r + 1.3, sides, r * 0.85, ROOF, yaw)


## Wind gate: two columns, tie beam, gilded plaque, glazed cap roof with sail
## finials, ribbons streaming from the beam ends.
func wind_gate(center: Vector3, span: float, h: float, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var l := center + basis * Vector3(-span * 0.5, 0, 0)
	var r := center + basis * Vector3(span * 0.5, 0, 0)
	for p in [l, r]:
		prism_into(b, p + Vector3(0, -1.0, 0), p + Vector3(0, 0.6, 0), 0.75, 0.62, 6, id(WHITE_STONE, MATTE))
		column(p + Vector3(0, 0.6, 0), h, 0.36)
	var beam_y := h * 0.78
	block_xf(Transform3D(basis, center + Vector3(0, beam_y, 0)), Vector3(span + 1.6, 0.42, 0.42), CINNABAR, true)
	block_xf(Transform3D(basis, center + Vector3(0, h + 0.5, 0)), Vector3(span + 2.2, 0.48, 0.5), CINNABAR_LIGHT, true)
	block_xf(Transform3D(basis, center + Vector3(0, (beam_y + h + 0.5) * 0.5, 0)), Vector3(span * 0.35, (h + 0.5 - beam_y) * 0.7, 0.14), GOLD, false, GILT)
	brackets(center + basis * Vector3(-span * 0.5, h + 0.85, 0), center + basis * Vector3(span * 0.5, h + 0.85, 0), maxi(3, int(span / 0.8)))
	hip_roof(center + Vector3(0, h + 1.15, 0), span + 3.4, 1.9, 1.0, yaw)
	for p in [l, r]:
		var end: Vector3 = p + basis * Vector3(signf((p - center).dot(basis.x)) * 0.8, beam_y - 0.2, 0)
		ribbon(end, 2.8, 0.22, CINNABAR_LIGHT if p == l else JADE)


## Hanging hexagonal lantern (paper glows at night) on a dark wood post with
## a crooked arm. Registers the lamp position in `lamps`.
func lantern_post(foot: Vector3, yaw: float = 0.0, h: float = 2.8) -> void:
	var basis := Basis(Vector3.UP, yaw)
	prism_into(b, foot, foot + Vector3(0, h, 0), 0.1, 0.08, 5, id(INK_WOOD, MATTE))
	prism_into(far, foot, foot + Vector3(0, h, 0), 0.1, 0.08, 3, id(INK_WOOD, MATTE))
	var arm_end := foot + Vector3(0, h, 0) + basis * Vector3(0.7, 0.15, 0)
	prism_into(b, foot + Vector3(0, h - 0.1, 0), arm_end, 0.06, 0.05, 4, id(INK_WOOD, MATTE))
	lantern(arm_end + Vector3(0, -0.65, 0))
	_collide_cyl(foot, h, 0.15)


func lantern(center: Vector3, scale: float = 1.0) -> void:
	var r := 0.26 * scale
	var hh := 0.5 * scale
	prism_into(b, center - Vector3(0, hh * 0.5, 0), center + Vector3(0, hh * 0.5, 0), r, r, 6, id(PAPER, LAMP))
	prism_into(b, center + Vector3(0, hh * 0.5, 0), center + Vector3(0, hh * 0.5 + 0.12 * scale, 0), r * 1.15, r * 0.5, 6, id(CINNABAR, MATTE))
	prism_into(b, center - Vector3(0, hh * 0.5 + 0.08 * scale, 0), center - Vector3(0, hh * 0.5, 0), r * 0.6, r * 1.1, 6, id(CINNABAR, MATTE))
	prism_into(b, center - Vector3(0, hh * 0.5 + 0.08 * scale, 0), center - Vector3(0, hh * 0.5 + 0.45 * scale, 0), 0.03, 0.01, 3, id(CINNABAR_LIGHT, CLOTH))
	box_into(far, Transform3D(Basis(), center), Vector3(r * 2.0, hh, r * 2.0), id(PAPER, LAMP))
	has_far = true
	lamps.append(center)


## Cloth ribbon hanging from `top`, drifting with the wind (shader sway).
func ribbon(top: Vector3, length: float, width: float, col: Color, yaw: float = 0.0) -> void:
	var segs := 5
	var side := Basis(Vector3.UP, yaw) * Vector3(width * 0.5, 0, 0)
	var c := id(col, CLOTH)
	for i in segs:
		var y0 := -length * i / segs
		var y1 := -length * (i + 1) / segs
		var w0 := float(i) / segs
		var w1 := float(i + 1) / segs
		var p0 := top + Vector3(0, y0, 0)
		var p1 := top + Vector3(0, y1, 0)
		var n := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
		for face in [n, -n]:
			var tone := 1.0 if face == n else 0.8
			var q := [p0 - side, p0 + side, p1 + side, p1 - side]
			var ws := [w0, w0, w1, w1]
			var order := [0, 1, 2, 3]
			if -(q[1] - q[0]).cross(q[2] - q[0]).dot(face) < 0.0:
				order = [3, 2, 1, 0]
			var tri_idx := [order[0], order[1], order[2], order[0], order[2], order[3]]
			for k in tri_idx:
				b.st.set_uv(Vector2(ws[k], 0.0))
				b.st.set_color(_sh(c, tone))
				b.st.add_vertex(q[k])
	b.st.set_uv(Vector2.ZERO)


# --- Finalize -----------------------------------------------------------------------------------------

## Builds the node: near mesh + far mesh (HLOD) + collision (+ runes).
func build(parent: Node3D, node_name: String, vis_range: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var mat := WorldMaterials.get_mat(&"architecture")
	var mi := MeshInstance3D.new()
	mi.name = "Near"
	mi.mesh = b.commit()
	mi.material_override = mat
	var hand_over := near_range if has_far and (vis_range <= 0.0 or vis_range > near_range) else 0.0
	if hand_over > 0.0:
		mi.visibility_range_end = hand_over
		mi.visibility_range_end_margin = 8.0
	elif vis_range > 0.0:
		mi.visibility_range_end = vis_range
	root.add_child(mi)
	if hand_over > 0.0:
		var fi := MeshInstance3D.new()
		fi.name = "Far"
		fi.mesh = far.commit()
		fi.material_override = mat
		fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fi.visibility_range_begin = hand_over
		fi.visibility_range_begin_margin = 8.0
		if vis_range > 0.0:
			fi.visibility_range_end = vis_range
		root.add_child(fi)
	if has_glow:
		var gi := MeshInstance3D.new()
		gi.mesh = glow.commit()
		gi.material_override = WorldMaterials.get_mat(&"glow_rune")
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_range > 0.0:
			gi.visibility_range_end = minf(vis_range, 400.0)
		root.add_child(gi)
	if not shapes.is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		if slick:
			body.set_meta(&"no_climb", true)
		for sh in shapes:
			var cs := CollisionShape3D.new()
			cs.shape = sh[1]
			cs.transform = sh[0]
			body.add_child(cs)
		root.add_child(body)
	return root
