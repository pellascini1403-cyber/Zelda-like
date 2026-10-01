class_name MannequinBuilder
extends RefCounted
## ============================================================================
##  PLACEHOLDER — DISEÑO FINAL PENDIENTE (final design pending)
## ============================================================================
## FROZEN TECHNICAL PLACEHOLDER. Do not refine its look: final characters are
## real rigged 3D models (docs/CHARACTER_PIPELINE.md, CharacterModel), never
## code primitives. This builder only keeps proportions, scale, collisions and
## animation testable until those models arrive.
##
## Anatomy mannequin for the human family (player and NPCs). It exists ONLY
## to validate proportions, silhouette, scale, camera distance, light on the
## body and motion until the definitive character models arrive. It is not a
## character design: no face, no clothes, no costume details. When a real
## model is delivered (EntityType.model), EntityVisual uses it instead
## and this builder is no longer involved.
##
## Anatomy rule (docs/CHARACTER_STYLE_GUIDE.md §4, data/art_style.json
## "mannequin"): slim, athletic and long-limbed. About 7.5 heads tall, hips at
## half height, long neck, narrow torso, arms reaching mid-thigh, defined
## hands and feet, subtly pointed ears. Never chibi, never round.
##
## Limbs are tapered lofts with elliptical sections (thigh → knee → calf →
## ankle), not capsules, and they bend at the elbow and knee (EntityVisual
## animates "forearm_*" and "shin_*" when they exist).
## Colour blocking only: skin, the entity's placeholder colour as a plain
## base layer (so NPCs stay distinguishable) and darker hair.

const MARK := "PLACEHOLDER_Mannequin"

static var _meshes: Dictionary = {}


static func build(v: EntityVisual, h: float, _r: float) -> void:
	var p: Dictionary = v.type.visual
	var st: Dictionary = DB.art_style.get("mannequin", {})
	var age := String(p.get("age", "adult"))
	var bw := float(DB.art_style.get("builds", {}).get(String(p.get("build", "average")), 1.0))
	var wk := lerpf(1.0, bw, 0.6)   # width factor: builds change mass, not height
	var c := v.type.placeholder_color
	var base := ArtStyle.solid(c)
	var skin := ArtStyle.solid(c.lightened(0.38))
	var hair := ArtStyle.solid(c.darkened(0.5))

	var rig := v.add_rig()
	rig.name = "rig"
	rig.set_meta(&"placeholder", MARK)
	var sc := float(p.get("scale", 1.0))
	var head_k := 1.0
	if age == "child":
		sc *= 0.72
		head_k = 1.18   # children: a slightly larger head, still not chibi
	rig.scale = Vector3.ONE * sc
	v.rest_scale = rig.scale

	var f := func(key: String, def: float) -> float: return float(st.get(key, def)) * h
	var head_h: float = f.call("head_height", 0.133) * head_k
	var hip_y: float = f.call("hip_height", 0.5)
	var thigh: float = f.call("thigh_length", 0.22)
	var shin: float = f.call("shin_length", 0.245)
	var waist_y: float = f.call("waist_height", 0.6)
	var neck_y: float = f.call("neck_base_height", 0.84)
	var neck_len: float = f.call("neck_length", 0.045)
	var shoulder_x: float = f.call("shoulder_half_width", 0.102) * wk
	var shoulder_y: float = f.call("shoulder_height", 0.815)
	var upper_arm: float = f.call("upper_arm_length", 0.19)
	var forearm: float = f.call("forearm_length", 0.16)
	var hand_len: float = f.call("hand_length", 0.1)
	var foot_len: float = f.call("foot_length", 0.14)
	var hip_x: float = f.call("hip_half_width", 0.05) * wk

	# Pelvis (pivot at hip-joint height) and torso (pivot at the waist).
	var hips := v._part("hips", _loft("pelvis", [[0.0, 0.074, 0.055, 0.0], [0.55, 0.088, 0.064, 0.0], [1.0, 0.05, 0.05, 0.004]], waist_y - hip_y + h * 0.03, h, wk), base, rig, Vector3(0, hip_y, 0), Vector3(0, waist_y - hip_y, 0))
	var torso_len := neck_y - waist_y
	var torso := v._part("torso", _loft("torso", [
			[0.0, 0.085, 0.052, -0.004], [0.18, 0.074, 0.05, -0.004], [0.48, 0.088, 0.058, -0.006],
			[0.72, 0.1, 0.06, -0.004], [0.9, 0.094, 0.056, 0.0], [1.0, 0.04, 0.036, 0.004]], torso_len, h, wk, true),
			base, hips, Vector3(0, waist_y - hip_y, 0), Vector3(0, 0, 0))
	if age == "elder":
		v.torso_pitch = -0.22
	# Neck and head (head pivot at the top of the neck).
	v.deco(torso, _loft("neck", [[0.0, 0.031, 0.031, 0.006], [1.0, 0.027, 0.029, 0.002]], neck_len, h, 1.0, true), skin, Vector3(0, torso_len - h * 0.005, 0))
	var head := v._part("head", _head(head_h), skin, torso, Vector3(0, torso_len + neck_len, -h * 0.004))
	_ears(v, head, head_h, skin)
	_hair(v, head, head_h, String(p.get("hair", "short")), hair)

	# Arms: shoulder pivot → upper arm; elbow pivot → forearm + hand.
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var arm := v._part("arm_" + s, _loft("upper_arm", [[0.0, 0.042, 0.04, 0.0], [0.35, 0.037, 0.035, 0.0], [1.0, 0.028, 0.027, 0.0]], upper_arm, h, sqrt(wk)), skin,
				torso, Vector3(side * shoulder_x, shoulder_y - waist_y, 0), Vector3.ZERO)
		var fore := v._part("forearm_" + s, _loft("forearm", [[0.0, 0.028, 0.026, 0.0], [0.3, 0.031, 0.027, 0.0], [1.0, 0.02, 0.016, 0.0]], forearm, h, sqrt(wk)), skin,
				arm, Vector3(0, -upper_arm, 0), Vector3.ZERO)
		v.deco(fore, _hand(hand_len, side), skin, Vector3(0, -forearm, 0))
		# Joint volumes hide the segment caps: deltoid, elbow, hip, knee.
		v.deco(arm, ShapeKit.sphere(h * 0.035 * sqrt(wk), 10), skin, Vector3(side * h * 0.002, -h * 0.014, 0), Vector3.ZERO, Vector3(1.0, 1.2, 0.95))
		v.deco(fore, ShapeKit.sphere(h * 0.017 * sqrt(wk), 8), skin, Vector3.ZERO)
		var leg := v._part("leg_" + s, _loft("thigh", [[0.0, 0.066, 0.064, 0.0], [0.3, 0.06, 0.058, -0.004], [1.0, 0.036, 0.038, 0.0]], thigh, h, sqrt(wk)), base,
				rig, Vector3(side * hip_x, hip_y, 0), Vector3.ZERO)
		var sh := v._part("shin_" + s, _loft("shin", [[0.0, 0.036, 0.038, 0.0], [0.28, 0.042, 0.044, 0.008], [0.85, 0.022, 0.024, 0.0], [1.0, 0.02, 0.022, 0.0]], shin, h, sqrt(wk)), skin,
				leg, Vector3(0, -thigh, 0), Vector3.ZERO)
		v.deco(sh, _foot(foot_len), skin, Vector3(0, -shin, 0))
		v.deco(leg, ShapeKit.sphere(h * 0.062 * sqrt(wk), 10), base, Vector3(0, -h * 0.01, 0), Vector3.ZERO, Vector3(1.0, 0.9, 1.0))
		v.deco(sh, ShapeKit.sphere(h * 0.022 * sqrt(wk), 8), skin, Vector3(0, 0, -h * 0.004))
		v.deco(sh, ShapeKit.sphere(h * 0.012, 6), skin, Vector3(0, -shin, 0))

	var hand_socket := Node3D.new()
	hand_socket.name = "socket_hand_r"
	hand_socket.position = Vector3(0, -forearm - hand_len * 0.45, 0)
	v.part(&"forearm_r").add_child(hand_socket)
	v.set_socket(&"hand_r", hand_socket)
	var back := Node3D.new()
	back.name = "socket_back"
	back.position = Vector3(0, torso_len * 0.7, h * 0.06)
	torso.add_child(back)
	v.set_socket(&"back", back)


## Tapered loft along -Y from the pivot (or +Y when `up`). Profile rows:
## [t along the length 0..1, half-width x, half-depth z, z offset] in units
## of the body height `h`; `wk` widens x and z (build). Cached per shape.
static func _loft(id: String, profile: Array, length: float, h: float, wk: float, up: bool = false) -> ArrayMesh:
	var key := "%s|%.3f|%.3f|%.3f|%s" % [id, length, h, wk, up]
	if _meshes.has(key):
		return _meshes[key]
	const SIDES := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	var rings: Array = []
	for row in profile:
		var y: float = row[0] * length * (1.0 if up else -1.0)
		var ring: Array[Vector3] = []
		for i in SIDES:
			var a := TAU * i / SIDES
			ring.append(Vector3(cos(a) * row[1] * h * wk, y, sin(a) * row[2] * h * wk + row[3] * h))
		rings.append(ring)
	_skin(st, rings)
	st.generate_normals()
	var m := st.commit()
	_meshes[key] = m
	return m


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Triangle facing away from `inside` (Godot front faces are clockwise: the
## face normal is -cross(b - a, c - a)).
static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := -(b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) >= 0.0:
		_tri(st, a, b, c)
	else:
		_tri(st, a, c, b)


static func _ring_center(ring: Array) -> Vector3:
	var center := Vector3.ZERO
	for p: Vector3 in ring:
		center += p
	return center / ring.size()


## Side walls between consecutive rings plus flat caps, all facing out.
static func _skin(st: SurfaceTool, rings: Array) -> void:
	var n := (rings[0] as Array).size()
	for k in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		var mid := (_ring_center(r0) + _ring_center(r1)) * 0.5
		for i in n:
			var j := (i + 1) % n
			# Inside point on the axis at the height of this quad.
			var ax0 := _ring_center(r0)
			var ax1 := _ring_center(r1)
			var inside := (ax0 + ax1) * 0.5 if mid.is_finite() else mid
			_tri_out(st, r0[i], r0[j], r1[j], inside)
			_tri_out(st, r0[i], r1[j], r1[i], inside)
	for idx in [0, rings.size() - 1]:
		var ring: Array = rings[idx]
		var c := _ring_center(ring)
		var other := _ring_center(rings[1 if idx == 0 else rings.size() - 2])
		for i in n:
			_tri_out(st, c, ring[i], ring[(i + 1) % n], other)


## Head: a narrow ovoid (crown → temples → cheekbones → jaw → chin), the
## chin slightly forward; no facial features (final design pending), only a
## small nose ridge so the facing reads.
static func _head(hh: float) -> ArrayMesh:
	var key := "head|%.3f" % hh
	if _meshes.has(key):
		return _meshes[key]
	# Built bottom (chin) to top (crown) around the head pivot at the jaw.
	var w := hh * 0.66
	var d := hh * 0.8
	var prof := [
		[0.0, 0.18, 0.22, -0.22], [0.12, 0.36, 0.4, -0.16], [0.3, 0.46, 0.5, -0.06],
		[0.5, 0.5, 0.56, 0.0], [0.72, 0.48, 0.56, 0.04], [0.9, 0.36, 0.44, 0.06], [1.0, 0.12, 0.16, 0.06]]
	const SIDES := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	var rings: Array = []
	for row in prof:
		var ring: Array[Vector3] = []
		for i in SIDES:
			var a := TAU * i / SIDES
			ring.append(Vector3(cos(a) * row[1] * w * 2.0 * 0.5, row[0] * hh, sin(a) * row[2] * d * 2.0 * 0.5 + row[3] * hh))
		rings.append(ring)
	_skin(st, rings)
	st.generate_normals()
	# Nose ridge (flat-shaded wedge) on the face (-Z).
	var nst := SurfaceTool.new()
	nst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, hh * 0.52, -d * 0.5)
	var tip := Vector3(0, hh * 0.36, -d * 0.62)
	var bl := Vector3(-hh * 0.05, hh * 0.33, -d * 0.52)
	var br := Vector3(hh * 0.05, hh * 0.33, -d * 0.52)
	for t in [[top, tip, bl], [top, br, tip], [bl, tip, br]]:
		_tri_out(nst, t[0], t[1], t[2], Vector3(0, hh * 0.45, 0))
	nst.generate_normals()
	var m := st.commit()
	nst.commit(m)
	_meshes[key] = m
	return m


## Subtly pointed ears: a flattened, swept-back leaf on each side.
static func _ears(v: EntityVisual, head: Node3D, hh: float, mat: Material) -> void:
	var key := "ear|%.3f" % hh
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base_f := Vector3(0, 0, -hh * 0.06)
		var base_b := Vector3(0, 0, hh * 0.08)
		var low := Vector3(0, -hh * 0.16, 0.0)
		var tip := Vector3(hh * 0.05, hh * 0.2, hh * 0.13)
		var thick := Vector3(hh * 0.025, 0, 0)
		for t in [[base_f, tip, base_b], [base_f, base_b, low], [base_f + thick, base_b + thick, tip], [base_f + thick, low, base_b + thick]]:
			_tri(st, t[0], t[1], t[2])
			_tri(st, t[0], t[2], t[1])   # two-sided: the mirrored ear stays solid
		st.generate_normals()
		var m := st.commit()
		_meshes[key] = m
	for side: int in [-1, 1]:
		var ear := v.deco(head, _meshes[key], mat, Vector3(side * hh * 0.32, hh * 0.5, hh * 0.04), Vector3(0, 0, 0), Vector3(float(side), 1, 1))
		ear.set_meta(&"placeholder", MARK)


## Hair as volume only (no strands, no styling): a cap over the cranium and
## a hint of the profile's style (tail, knot, long back) for the silhouette.
static func _hair(v: EntityVisual, head: Node3D, hh: float, style: String, m: Material) -> void:
	if style == "bald":
		return
	v.deco(head, ShapeKit.sphere(hh * 0.36, 12), m, Vector3(0, hh * 0.8, hh * 0.1), Vector3(-14, 0, 0), Vector3(1.0, 0.7, 1.1))
	match style:
		"ponytail":
			v.deco(head, _loft("tail", [[0.0, 0.02, 0.02, 0.0], [0.3, 0.026, 0.022, 0.0], [1.0, 0.006, 0.006, 0.0]], hh * 1.6, 1.0, 1.0), m, Vector3(0, hh * 0.7, hh * 0.42), Vector3(25, 0, 0))
		"long":
			v.deco(head, _loft("long", [[0.0, 0.22, 0.08, 0.0], [1.0, 0.18, 0.04, 0.0]], hh * 1.3, hh, 1.0), m, Vector3(0, hh * 0.62, hh * 0.3), Vector3(8, 0, 0))
		"bun", "topknot":
			v.deco(head, ShapeKit.sphere(hh * 0.14, 8), m, Vector3(0, hh * (1.02 if style == "topknot" else 0.82), hh * (0.08 if style == "topknot" else 0.38)))
		"swept", "spiky", "wild":
			v.deco(head, _loft("lock", [[0.0, 0.05, 0.03, 0.0], [1.0, 0.004, 0.004, 0.0]], hh * 0.55, hh, 1.0), m, Vector3(hh * 0.08, hh * 0.92, -hh * 0.2), Vector3(-70, 0, -20))


## Hand: a flattened, tapering paddle with a thumb (fingers are not modelled).
static func _hand(hl: float, side: int) -> ArrayMesh:
	var key := "hand|%.3f|%d" % [hl, side]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	var palm := _loft("palm", [[0.0, 0.2, 0.09, 0.0], [0.5, 0.26, 0.1, 0.0], [1.0, 0.16, 0.06, 0.0]], hl, hl, 1.0)
	var arr := palm.surface_get_arrays(0)
	st.create_from_arrays(arr)
	var thumb := _loft("thumb", [[0.0, 0.07, 0.06, 0.0], [1.0, 0.04, 0.04, 0.0]], hl * 0.45, hl, 1.0)
	var xf := Transform3D(Basis(Vector3.FORWARD, side * 0.6), Vector3(side * hl * 0.2, -hl * 0.15, -hl * 0.04))
	st.append_from(thumb, 0, xf)
	var m := st.commit()
	_meshes[key] = m
	return m


## Foot: a long, low wedge pointing forward (-Z).
static func _foot(fl: float) -> ArrayMesh:
	var key := "foot|%.3f" % fl
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	var foot := _loft("footbody", [[0.0, 0.16, 0.14, 0.0], [0.4, 0.2, 0.13, 0.0], [0.85, 0.18, 0.08, 0.0], [1.0, 0.1, 0.05, 0.0]], fl, fl, 1.0, true)
	# Rotate the loft to lie along -Z, heel under the ankle.
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -fl * 0.12, fl * 0.2))
	st.append_from(foot, 0, xf)
	var m := st.commit()
	_meshes[key] = m
	return m
