class_name TreeKit
extends RefCounted
## Organic trees for the environment (art direction: painterly natural
## fantasy, docs/ART_DIRECTION.md "Árboles").
##
## A tree is grown, not assembled: a curving trunk with root flare splits
## into scaffold limbs and twigs (tubes swept along bent polylines, radial
## normals); foliage is a crown of leaf clumps whose normals are bent toward
## the crown's centre so light wraps softly over the whole mass, darker and
## cooler inside and underneath, warm at the sunlit top; sprays of small
## geometric leaves fray the silhouette and let light through (dappled
## shadows) without alpha testing.
##
## Every species has VARIANTS seeds (different structure, crown and tone);
## instances add scale, lean and hue, so a grove is never one tree rotated.
## Near meshes have two surfaces (0: wood + clumps, foliage shader; 1: leaf
## sprays, leaf shader: double-sided, translucent, fluttering). LOD meshes
## are one opaque surface (sector batches). Budget: ~2-2.8k triangles near,
## ~150-250 LOD; near trees are instanced per variant.

const VARIANTS := 3



class Mesher:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func add(p: Vector3, nn: Vector3, col: Color, t: Vector2 = Vector2.ZERO) -> int:
		v.append(p)
		n.append(nn)
		c.append(col)
		uv.append(t)
		return v.size() - 1

	## Triangle facing `out` (Godot front faces are clockwise).
	func tri(a: int, b: int, cc: int, out: Vector3) -> void:
		var fn := -(v[b] - v[a]).cross(v[cc] - v[a])
		if fn.dot(out) >= 0.0:
			idx.append_array([a, b, cc])
		else:
			idx.append_array([a, cc, b])

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_COLOR] = c
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_INDEX] = idx
		return a


class Grower:
	var wood := Mesher.new()
	var cards := Mesher.new()
	var rng := RandomNumberGenerator.new()
	var lod := false
	var bark := Color(0.36, 0.28, 0.22)
	var bark_dark := Color(0.2, 0.16, 0.14)
	var leaf_light := Color(0.55, 0.66, 0.3)
	var leaf_dark := Color(0.16, 0.28, 0.2)
	var crown_c := Vector3.ZERO
	var crown_r := 3.0
	var clumps: Array = []      # [center, radii(Vector3)]
	## Single-surface plants (sector-batched bushes): leaves go into the
	## opaque surface, double-sided by geometry.
	var merge_leaves := false
	## Leaf-spray density from the quality level when the mesh is first built.
	var detail := 1.0

	## Tube swept along a polyline: ring frames by parallel transport, radial
	## normals, bark tone darker at the base and in vertical furrows.
	func tube(pts: Array, radii: Array, sides: int) -> void:
		var rings: Array = []
		var p0: Vector3 = pts[0]
		var p1: Vector3 = pts[1]
		var axis := (p1 - p0).normalized()
		var u := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
		for k in pts.size():
			var pa: Vector3 = pts[maxi(k - 1, 0)]
			var pb: Vector3 = pts[mini(k + 1, pts.size() - 1)]
			var t := (pb - pa).normalized()
			u = (u - t * u.dot(t)).normalized()
			var w := t.cross(u)
			var ring: Array[int] = []
			var hk := float(k) / (pts.size() - 1)
			for i in sides:
				var a := TAU * i / sides
				var dir := u * cos(a) + w * sin(a)
				var furrow := 0.86 + 0.14 * sin(a * 3.0 + k * 0.7)
				var r: float = radii[k] * (0.94 + 0.06 * sin(a * 2.0 + k))
				var col := bark_dark.lerp(bark, 0.55 + hk * 0.45) * furrow
				ring.append(wood.add(pts[k] + dir * r, dir, col))
			rings.append(ring)
		for k in pts.size() - 1:
			var r0: Array[int] = rings[k]
			var r1: Array[int] = rings[k + 1]
			for i in sides:
				var j := (i + 1) % sides
				var out := (wood.v[r0[i]] + wood.v[r0[j]]) * 0.5 - (pts[k] as Vector3)
				wood.tri(r0[i], r0[j], r1[j], out)
				wood.tri(r0[i], r1[j], r1[i], out)

	## Bent polyline from `start` along `dir`, drifting by `bend`, pulled up by `rise`.
	func path(start: Vector3, dir: Vector3, length: float, segs: int, bend: float, rise: float) -> Array:
		var pts: Array = [start]
		var d := dir.normalized()
		for s in segs:
			var jitter := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)) * bend
			d = (d + jitter + Vector3.UP * rise).normalized()
			pts.append((pts[-1] as Vector3) + d * (length / segs))
		return pts

	func taper(count: int, r0: float, r1: float) -> Array:
		var out: Array = []
		for k in count:
			var t := float(k) / (count - 1)
			out.append(lerpf(r0, r1, pow(t, 0.8)))
		return out

	func clump(center: Vector3, radii: Vector3) -> void:
		clumps.append([center, radii])

	## Crown: soft clumps with normals bent toward the crown centre and a
	## light→dark gradient (top/outside warm and light, inside/under cool).
	func build_crown(subdiv: int, cards_per_clump: int, card_size: float, spray: Color = Color(-1, 0, 0)) -> void:
		if clumps.is_empty():
			return
		crown_c = Vector3.ZERO
		for cl in clumps:
			crown_c += cl[0]
		crown_c /= clumps.size()
		crown_r = 0.5
		for cl in clumps:
			crown_r = maxf(crown_r, (cl[0] as Vector3).distance_to(crown_c) + (cl[1] as Vector3).x)
		var geo := MeshKit.icosphere(subdiv)
		var sv: PackedVector3Array = geo[0]
		var sf: PackedInt32Array = geo[1]
		for cl in clumps:
			var cc: Vector3 = cl[0]
			var rr: Vector3 = cl[1] * (1.0 if lod else 0.85)
			var base := wood.v.size()
			var tone := rng.randf_range(0.9, 1.08)
			var seed_off := rng.randf() * 10.0
			for i in sv.size():
				var d := sv[i]
				var lump := 1.0 + 0.16 * sin(d.x * 5.1 + seed_off) * sin(d.z * 4.3 + seed_off * 0.7) + 0.08 * sin(d.y * 7.0 + seed_off)
				var p := cc + d * rr * lump
				var radial := (p - crown_c).normalized()
				var nn := (radial * 0.6 + d * 0.4).normalized()
				# The core reads as the shaded depth behind the lit leaf sprays.
				var core := _leaf_col(p) * tone
				if not lod:
					core = Color(core.r * 0.56, core.g * 0.64, core.b * 0.72)
				wood.add(p, nn, core)
			for i in range(0, sf.size(), 3):
				var a := base + sf[i]
				var b := base + sf[i + 1]
				var c := base + sf[i + 2]
				var out := (wood.v[a] + wood.v[b] + wood.v[c]) / 3.0 - cc
				wood.tri(a, b, c, out)
			if lod:
				continue
			# Leaf-spray fringe: most of the silhouette comes from the cards,
			# the clumps are the dense core that keeps the crown opaque.
			for k in int(round(cards_per_clump * detail)):
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1.0), rng.randf_range(-1, 1)).normalized()
				var p := cc + d * rr * rng.randf_range(0.85, 1.08)
				var face := (d * 0.5 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.8).normalized()
				_card(p, face, card_size * rng.randf_range(0.8, 1.25), 1.0, spray)

	func _leaf_col(p: Vector3) -> Color:
		var rel := p - crown_c
		var up := clampf(rel.y / crown_r * 0.6 + 0.5, 0.0, 1.0)
		var outer := clampf(rel.length() / crown_r, 0.0, 1.0)
		return leaf_dark.lerp(leaf_light, clampf(up * 0.8 + outer * 0.3 - 0.12, 0.0, 1.0))

	## One leaf spray: 6-8 small diamond leaves fanned around a stem point in
	## a plane, as real opaque geometry (no alpha test: tile-based mobile
	## GPUs keep hidden-surface removal, and the gaps between leaves still
	## dapple the light). `aspect` > 1 hangs the spray downward (willow).
	func _card(p: Vector3, face: Vector3, size: float, aspect: float, spray: Color) -> void:
		var t := face.cross(Vector3.UP if absf(face.y) < 0.9 else Vector3.RIGHT).normalized()
		var bt := face.cross(t).normalized()
		var base_col := _leaf_col(p) * 1.08 if spray.r < 0.0 else spray
		var nn := (p - crown_c).normalized()
		var count := 8 if aspect <= 1.0 else 10
		for k in count:
			var ang := TAU * k / count + rng.randf_range(-0.35, 0.35)
			var dir := (t * cos(ang) + bt * sin(ang))
			if aspect > 1.0:
				# Strand: leaves stacked down a hanging line.
				dir = (Vector3.DOWN + t * rng.randf_range(-0.35, 0.35)).normalized()
			var reach := size * (0.12 + 0.36 * rng.randf()) if aspect <= 1.0 else size * aspect * float(k) / count
			var root := p + dir * reach
			var leaf_dir := (dir + face * rng.randf_range(-0.3, 0.3)).normalized()
			var length := size * rng.randf_range(0.22, 0.3)
			var width := length * rng.randf_range(0.32, 0.42)
			var side := leaf_dir.cross(face).normalized() * width * 0.5
			var mid := root + leaf_dir * length * 0.45
			var tip := root + leaf_dir * length
			var col := base_col * rng.randf_range(0.85, 1.08)
			var m := wood if merge_leaves else cards
			var i0 := m.add(root, nn, col * 0.9)
			var i1 := m.add(mid + side, nn, col)
			var i2 := m.add(tip, nn, col * 1.05)
			var i3 := m.add(mid - side, nn, col)
			m.idx.append_array([i0, i1, i2, i0, i2, i3])
			if merge_leaves:
				m.idx.append_array([i0, i2, i1, i0, i3, i2])

	func commit() -> ArrayMesh:
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wood.arrays())
		m.surface_set_material(0, WorldMaterials.get_mat(&"foliage"))
		if not lod and not cards.v.is_empty():
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cards.arrays())
			m.surface_set_material(1, WorldMaterials.get_mat(&"leaf"))
		return m


## Leaf density by quality (LOW 0.55, MEDIUM 0.75, HIGH+ 1.0).
static func detail_level() -> float:
	var q: Node = Engine.get_main_loop().root.get_node_or_null("Quality") if Engine.get_main_loop() is SceneTree else null
	if q == null:
		return 1.0
	return [0.55, 0.75, 1.0, 1.0][clampi(int(q.get("level")), 0, 3)]


## Shrub: a low cluster of leafy clumps, one opaque surface (batched per
## sector by ChunkBuilder.bake_batch).
static func bush(variant: int) -> ArrayMesh:
	var t := Grower.new()
	t.merge_leaves = true
	t.detail = detail_level()
	t.rng.seed = 5150 + variant * 31
	t.leaf_light = [Color(0.48, 0.6, 0.26), Color(0.4, 0.56, 0.3), Color(0.54, 0.58, 0.27)][variant % 3]
	t.leaf_dark = Color(0.12, 0.24, 0.16)
	var n := t.rng.randi_range(3, 4)
	for i in n:
		var a := TAU * i / n + t.rng.randf_range(-0.4, 0.4)
		var r := t.rng.randf_range(0.25, 0.55)
		t.clump(Vector3(cos(a) * r, t.rng.randf_range(0.35, 0.6), sin(a) * r), Vector3(0.55, 0.42, 0.55) * t.rng.randf_range(0.85, 1.2))
	t.build_crown(1, 9, 0.7)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t.wood.arrays())
	return m


static func supports(species: StringName) -> bool:
	return species in [&"broadleaf", &"cloud_pine", &"pine", &"blossom", &"willow"]


static func build(species: StringName, variant: int, lod: bool) -> ArrayMesh:
	var t := Grower.new()
	t.lod = lod
	t.detail = detail_level()
	t.rng.seed = hash(String(species)) + variant * 7919
	match species:
		&"broadleaf": _broadleaf(t, variant)
		&"cloud_pine": _cloud_pine(t, variant)
		&"pine": _pine(t, variant)
		&"blossom": _blossom(t, variant)
		&"willow": _willow(t, variant)
	return t.commit()


## Rounded deciduous tree: flared, curving trunk; 3-5 scaffold limbs; crown
## of 7-10 clumps. Variants change height, spread, lean and leaf tone.
static func _broadleaf(t: Grower, variant: int) -> void:
	var tones := [[Color(0.46, 0.58, 0.24), Color(0.12, 0.24, 0.17)], [Color(0.36, 0.53, 0.28), Color(0.1, 0.22, 0.18)], [Color(0.52, 0.57, 0.25), Color(0.16, 0.24, 0.14)]]
	t.leaf_light = tones[variant % 3][0]
	t.leaf_dark = tones[variant % 3][1]
	var rng: RandomNumberGenerator = t.rng
	var h := rng.randf_range(3.0, 4.2)
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25))
	var trunk: Array = t.path(Vector3.ZERO, lean, h, 2 if t.lod else 4, 0.12, 0.25)
	var radii: Array = t.taper(trunk.size(), 0.4, 0.24)
	radii[0] = 0.55   # root flare
	t.tube(trunk, radii, 5 if t.lod else 8)
	var top: Vector3 = trunk[-1]
	var limbs := 3 if t.lod else rng.randi_range(3, 5)
	for i in limbs:
		var a := TAU * i / limbs + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), rng.randf_range(0.8, 1.4), sin(a))
		var length := rng.randf_range(2.0, 3.2)
		var start: Vector3 = top - Vector3(0, rng.randf_range(0.0, 0.8), 0)
		var lp: Array = t.path(start, out, length, 2 if t.lod else 3, 0.2, 0.18)
		if not t.lod:
			t.tube(lp, t.taper(lp.size(), 0.22, 0.08), 5)
			var mid: Vector3 = lp[1]
			var tw: Array = t.path(mid, out.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2)) + Vector3.UP * 0.4, length * 0.6, 2, 0.25, 0.2)
			t.tube(tw, t.taper(tw.size(), 0.1, 0.04), 4)
			t.clump(tw[-1] + Vector3.UP * 0.2, Vector3.ONE * rng.randf_range(1.2, 1.6))
		t.clump(lp[-1] + Vector3.UP * 0.25, Vector3(1.0, 0.85, 1.0) * rng.randf_range(1.6, 2.1))
	# Interior fill so the crown never reads hollow.
	t.clump(top + Vector3(0, 1.4, 0), Vector3(1.0, 0.85, 1.0) * rng.randf_range(1.5, 1.9))
	if not t.lod:
		t.clump(top + Vector3(rng.randf_range(-0.6, 0.6), 2.4, rng.randf_range(-0.6, 0.6)), Vector3.ONE * rng.randf_range(1.0, 1.3))
	t.build_crown(0 if t.lod else 1, 13, 1.8)


## Windswept "cloud pine": twisting leaning trunk, near-horizontal limbs
## ending in flat layered pads — the silhouette that reads across a valley.
static func _cloud_pine(t: Grower, variant: int) -> void:
	t.bark = Color(0.4, 0.3, 0.24)
	t.bark_dark = Color(0.2, 0.15, 0.13)
	t.leaf_light = [Color(0.36, 0.52, 0.32), Color(0.32, 0.5, 0.36), Color(0.42, 0.54, 0.3)][variant % 3]
	t.leaf_dark = Color(0.08, 0.18, 0.15)
	var rng: RandomNumberGenerator = t.rng
	var lean_a := rng.randf() * TAU
	var trunk: Array = t.path(Vector3.ZERO, Vector3(cos(lean_a) * 0.45, 1.0, sin(lean_a) * 0.45), rng.randf_range(4.4, 5.6), 3 if t.lod else 5, 0.28, 0.1)
	t.tube(trunk, t.taper(trunk.size(), 0.4, 0.14), 5 if t.lod else 7)
	var tiers := 2 if t.lod else rng.randi_range(4, 5)
	for i in tiers:
		var k := 1 + int(float(i) / tiers * (trunk.size() - 2))
		var start: Vector3 = trunk[mini(k + 1, trunk.size() - 1)]
		var a := lean_a + rng.randf_range(-2.2, 2.2)
		var out := Vector3(cos(a), rng.randf_range(0.05, 0.3), sin(a))
		var lp: Array = t.path(start, out, rng.randf_range(1.4, 2.8), 2, 0.15, 0.05)
		if not t.lod:
			t.tube(lp, t.taper(lp.size(), 0.13, 0.05), 4)
		var s := rng.randf_range(1.4, 2.2) * (1.0 - float(i) / tiers * 0.35)
		t.clump(lp[-1] + Vector3.UP * 0.2, Vector3(s, 0.42, s * 0.85))
	t.clump((trunk[-1] as Vector3) + Vector3.UP * 0.25, Vector3(1.5, 0.5, 1.3))
	t.build_crown(0 if t.lod else 1, 14, 1.6)


## Alpine conifer: straight trunk, tiers of drooping branch masses that
## narrow upward into a spire (not stacked cones).
static func _pine(t: Grower, variant: int) -> void:
	t.leaf_light = [Color(0.26, 0.42, 0.3), Color(0.3, 0.44, 0.27), Color(0.24, 0.38, 0.32)][variant % 3]
	t.leaf_dark = Color(0.06, 0.14, 0.12)
	var rng: RandomNumberGenerator = t.rng
	var h := rng.randf_range(7.5, 9.5)
	var trunk: Array = t.path(Vector3.ZERO, Vector3.UP, h, 2 if t.lod else 4, 0.04, 0.3)
	t.tube(trunk, t.taper(trunk.size(), 0.36, 0.08), 5 if t.lod else 7)
	var tiers := 3 if t.lod else 6
	for i in tiers:
		var f := float(i) / tiers
		var y := lerpf(1.8, h * 0.92, f)
		var spread := lerpf(2.6, 0.7, f) * rng.randf_range(0.9, 1.1)
		var masses := 3 if t.lod else (6 - int(f * 3.0))
		for k in masses:
			var a := TAU * k / masses + i * 0.9 + rng.randf_range(-0.3, 0.3)
			var c := Vector3(cos(a) * spread * 0.55, y - spread * 0.15, sin(a) * spread * 0.55)
			t.clump(c, Vector3(spread * 0.6, 0.5 + spread * 0.12, spread * 0.6))
	t.clump(Vector3(0, h + 0.3, 0), Vector3(0.5, 1.0, 0.5))
	t.build_crown(0, 8, 1.5, Color(0.2, 0.33, 0.25))


## Plum blossom: dark gnarled trunk, clouds of pale bloom and petal sprays.
static func _blossom(t: Grower, variant: int) -> void:
	t.bark = Color(0.28, 0.2, 0.18)
	t.bark_dark = Color(0.14, 0.1, 0.1)
	t.leaf_light = [Color(0.99, 0.82, 0.88), Color(0.98, 0.76, 0.84), Color(1.0, 0.9, 0.92)][variant % 3]
	t.leaf_dark = Color(0.66, 0.38, 0.5)
	var rng: RandomNumberGenerator = t.rng
	var trunk: Array = t.path(Vector3.ZERO, Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)), rng.randf_range(1.8, 2.4), 2 if t.lod else 4, 0.3, 0.1)
	t.tube(trunk, t.taper(trunk.size(), 0.32, 0.2), 5 if t.lod else 7)
	var top: Vector3 = trunk[-1]
	var limbs := 3 if t.lod else 5
	for i in limbs:
		var a := TAU * i / limbs + rng.randf_range(-0.5, 0.5)
		var lp: Array = t.path(top, Vector3(cos(a), rng.randf_range(0.5, 1.1), sin(a)), rng.randf_range(1.5, 2.3), 2 if t.lod else 3, 0.35, 0.1)
		if not t.lod:
			t.tube(lp, t.taper(lp.size(), 0.14, 0.04), 4)
		t.clump((lp[-1] as Vector3) + Vector3.UP * 0.2, Vector3(1.1, 0.75, 1.0) * rng.randf_range(0.9, 1.2))
	t.clump(top + Vector3(0, 1.3, 0), Vector3(1.2, 0.8, 1.2))
	t.build_crown(0 if t.lod else 1, 14, 1.3)


## Willow by the water: rounded crown, long leafy strands hanging (cards).
static func _willow(t: Grower, variant: int) -> void:
	t.leaf_light = [Color(0.62, 0.7, 0.38), Color(0.56, 0.68, 0.4), Color(0.66, 0.7, 0.36)][variant % 3]
	t.leaf_dark = Color(0.22, 0.34, 0.2)
	var rng: RandomNumberGenerator = t.rng
	var trunk: Array = t.path(Vector3.ZERO, Vector3(rng.randf_range(-0.3, 0.3), 1.0, rng.randf_range(-0.3, 0.3)), 3.4, 2 if t.lod else 4, 0.15, 0.1)
	t.tube(trunk, t.taper(trunk.size(), 0.5, 0.3), 5 if t.lod else 8)
	var top: Vector3 = trunk[-1]
	for i in (3 if t.lod else 6):
		var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		t.clump(top + Vector3(cos(a) * 1.5, rng.randf_range(0.6, 1.3), sin(a) * 1.5), Vector3(1.4, 0.9, 1.4))
	t.clump(top + Vector3(0, 1.4, 0), Vector3(1.6, 1.0, 1.6))
	t.build_crown(0 if t.lod else 1, 10, 1.5)
	if t.lod:
		return
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf() * 0.2
		var r := rng.randf_range(1.8, 2.7)
		var p := top + Vector3(cos(a) * r, rng.randf_range(0.2, 0.8), sin(a) * r)
		t._card(p, Vector3(cos(a), 0, sin(a)), 0.7, rng.randf_range(3.2, 4.6), Color(-1, 0, 0))
