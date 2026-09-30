class_name CreatureBuilder
extends RefCounted
## Enemy family placeholder ("corrupted creatures"): any species, one visual
## language — near-black faceted bodies, pointed forms (spikes, horns, claws,
## plates), violet energy that is part of the anatomy (eyes, cracks, horn
## fire, cores, crystals) and a rank ladder common → elite → mini-boss → boss.
## The species silhouette always comes first: a scorpion reads as a scorpion.
## Also builds the neutral wildlife family (round, soft, no violet).
## Data: data/visuals.json (species, rank, features), data/art_style.json.

const FACETS := 6   # enemies are faceted/angular; humans and animals are smooth


static func build_enemy(v: EntityVisual, h: float, r: float) -> void:
	var t := v.type
	var sp := String(t.visual.get("species", "beast"))
	var c := {
		"b": ArtStyle.enemy_body(t),
		"e": ArtStyle.energy_mat("violet_core", 2.2),
		"eye": ArtStyle.energy_mat("violet_core", 3.2),
		"rk": ArtStyle.rank(t),
	}
	match sp:
		"beast", "boar", "dragon":
			_beast(v, h, r, c, sp)
		"scorpion", "crab", "spider":
			_crawler(v, h, r, c, sp)
		"beetle":
			_beetle(v, h, r, c)
		"bat":
			_bat(v, h, r, c)
		"jelly":
			_jelly(v, h, r, c)
		"toad":
			_toad(v, h, r, c)
		"wisp":
			_wisp(v, h, r, c)
		"raptor":
			_raptor(v, h, r, c)
		"serpent":
			_serpent(v, h, r, c)
		_:
			_biped(v, h, r, c, sp)
	var rk: Dictionary = c["rk"]
	var aura := int(rk.get("aura", 0))
	if aura > 0:
		var fl := ArtStyle.flames(aura, Vector3(r * 0.9, h * 0.25, r * 0.9), clampf(h * 0.12, 0.25, 1.4), h * 0.6)
		fl.position.y = h * 0.3
		v.part(&"rig").add_child(fl)
	if t.visual.get("rank", "") == "boss":
		var light := OmniLight3D.new()
		light.light_color = ArtStyle.palette("violet_glow")
		light.light_energy = 1.4
		light.omni_range = h * 1.6
		light.position.y = h * 0.5
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 60.0
		light.distance_fade_length = 20.0
		v.part(&"rig").add_child(light)


static func _has(v: EntityVisual, f: String) -> bool:
	return ArtStyle.has_feature(v.type, f)


static func _n(c: Dictionary, base: float) -> int:
	return maxi(1, roundi(base * float(c["rk"].get("spikes", 1.0))))


# --- Shared anatomy ------------------------------------------------------------------------
## Narrow glowing slits: the family's eyes.
static func _eyes(v: EntityVisual, head: Node3D, pos: Vector3, spread: float, size: float, c: Dictionary, count: int = 2) -> void:
	var s := size * float(c["rk"].get("eye", 1.0))
	for i in count:
		var row := i / 2
		var sx := -1.0 if i % 2 == 0 else 1.0
		v.deco(head, ShapeKit.sphere(s, 6), c["eye"], pos + Vector3(sx * spread * (1.0 - row * 0.4), row * s * 2.2, row * s), Vector3(0, 0, sx * -18.0), Vector3(1.5, 0.55, 0.6), true)


## A row of spikes from `a` to `b`, leaning back by `tilt` degrees.
static func _spikes(v: EntityVisual, parent: Node3D, a: Vector3, b: Vector3, n: int, size: float, tilt: float, mat: Material) -> void:
	for i in n:
		var f := float(i) / maxf(n - 1, 1)
		var sz := size * (0.75 + 0.5 * sin(f * PI))
		v.deco(parent, ShapeKit.cone(sz * 0.3, sz, 4), mat, a.lerp(b, f) + Vector3(0, sz * 0.35, 0), Vector3(tilt, 0, 0))


static func _horns(v: EntityVisual, head: Node3D, pos: Vector3, size: float, c: Dictionary, spread: float = 30.0) -> void:
	for sx: int in [-1, 1]:
		var base := pos + Vector3(sx * size * 0.35, 0, 0)
		v.deco(head, ShapeKit.cone(size * 0.2, size, 4), c["b"], base + Vector3(sx * size * 0.2, size * 0.4, size * 0.1), Vector3(22, 0, -sx * spread))
		var tip := base + Vector3(sx * size * 0.5, size * 0.9, size * 0.3)
		v.deco(head, ShapeKit.cone(size * 0.09, size * 0.32, 4), c["e"], tip, Vector3(22, 0, -sx * spread), Vector3.ONE, true)
		if c["rk"].get("horn_fire", false):
			var fl := ArtStyle.flames(5, Vector3.ONE * size * 0.06, size * 0.35, size * 1.5)
			fl.position = tip
			head.add_child(fl)


static func _flame_at(parent: Node3D, pos: Vector3, amount: int, size: float) -> void:
	var fl := ArtStyle.flames(amount, Vector3.ONE * size * 0.25, size, size * 3.0)
	fl.position = pos
	parent.add_child(fl)


static func _claws(v: EntityVisual, limb: Node3D, tip: Vector3, size: float, mat: Material, down: bool = false) -> void:
	for i in 3:
		var x := (i - 1) * size * 0.35
		var rot := Vector3(-150 if down else -90, 0, (i - 1) * 12.0)
		v.deco(limb, ShapeKit.cone(size * 0.14, size, 4), mat, tip + Vector3(x, 0, -size * 0.3), rot)


static func _wings(v: EntityVisual, body: Node3D, at: Vector3, span: float, c: Dictionary) -> void:
	for sx: int in [-1, 1]:
		var s := "l" if sx < 0 else "r"
		var w := Node3D.new()
		w.name = "wing_" + s
		w.position = at + Vector3(sx * span * 0.08, 0, 0)
		body.add_child(w)
		v.wings.append(w)
		# Three angular blades fanning out: the membrane read of a wing.
		for i in 3:
			var ln := span * (1.0 - i * 0.22)
			var ang := -sx * (90.0 - i * 22.0)
			var off := Vector3(sx * ln * 0.45 * cos(deg_to_rad(i * 22.0)), ln * 0.45 * sin(deg_to_rad(i * 22.0)), i * span * 0.07)
			v.deco(w, ShapeKit.cone(span * 0.14, ln, 3), c["b"], off, Vector3(0, 0, ang), Vector3(1, 1, 0.18))
		v.deco(w, ShapeKit.cone(span * 0.03, span * 0.2, 4), c["e"], Vector3(sx * span * 0.92, 0, 0), Vector3(0, 0, -sx * 90.0), Vector3.ONE, true)


static func _rig(v: EntityVisual, kind: StringName) -> Node3D:
	v.rig_kind = kind
	return v.add_rig()


static func _mouth(v: EntityVisual, head: Node3D, pos: Vector3) -> void:
	var m := Node3D.new()
	m.name = "socket_hand_r"
	m.position = pos
	head.add_child(m)
	v.set_socket(&"hand_r", m)


# --- Species ---------------------------------------------------------------------------------
## Four-legged hunters: thorn beasts (wolf-like), boars, dragons.
static func _beast(v: EntityVisual, h: float, r: float, c: Dictionary, sp: String) -> void:
	var boar := sp == "boar"
	var rig := _rig(v, &"legged")
	var leg := h * (0.3 if boar else 0.42)
	var body_r := h * (0.34 if boar else 0.24)
	var body_len := r * (2.2 if boar else 2.6)
	var torso := v._part("torso", ShapeKit.capsule(body_r, body_len), c["b"], rig, Vector3(0, leg + body_r * 0.6, 0))
	(torso.get_child(0) as Node3D).rotation_degrees = Vector3(84, 0, 0)
	var neck_z := -body_len * 0.5
	var head_pos := Vector3(0, body_r * (0.2 if boar else 0.55), neck_z - h * 0.08)
	if _has(v, "long_neck") or sp == "dragon":
		v.deco(torso, ShapeKit.capsule(body_r * 0.45, h * 0.6), c["b"], Vector3(0, body_r + h * 0.15, neck_z - h * 0.05), Vector3(-40, 0, 0))
		head_pos = Vector3(0, body_r + h * 0.4, neck_z - h * 0.3)
	var hs := h * (0.2 if boar else 0.18)
	var head := v._part("head", ShapeKit.sphere(hs, FACETS), c["b"], torso, head_pos)
	head.scale = Vector3(0.9, 0.85, 1.15)
	if boar:
		v.deco(head, ShapeKit.cyl(hs * 0.45, hs * 0.55, hs * 0.8, FACETS), c["b"], Vector3(0, -hs * 0.2, -hs * 0.95), Vector3(-90, 0, 0))
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.cone(hs * 0.12, hs * 0.9, 4), c["b"], Vector3(sx * hs * 0.45, -hs * 0.05, -hs * 1.1), Vector3(-35, 0, -sx * 25))
	else:
		v.deco(head, ShapeKit.cone(hs * 0.5, hs * 1.3, 4), c["b"], Vector3(0, -hs * 0.2, -hs * 1.05), Vector3(-90, 45, 0))
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.cone(hs * 0.1, hs * 0.5, 4), c["b"], Vector3(sx * hs * 0.2, -hs * 0.55, -hs * 1.2), Vector3(-160, 0, 0))
	if _has(v, "ears"):
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.cone(hs * 0.22, hs * 0.8, 3), c["b"], Vector3(sx * hs * 0.55, hs * 0.75, hs * 0.2), Vector3(15, 0, -sx * 22))
	_eyes(v, head, Vector3(0, hs * 0.12, -hs * 0.82), hs * 0.4, hs * 0.13, c)
	if _has(v, "horns") or sp == "dragon":
		_horns(v, head, Vector3(0, hs * 0.55, hs * 0.1), hs * 1.4, c, 28.0)
	if _has(v, "spine_spikes"):
		_spikes(v, torso, Vector3(0, body_r * 0.85, -body_len * 0.3), Vector3(0, body_r * 0.7, body_len * 0.45), _n(c, 4), h * (0.28 if boar else 0.2), 35.0, c["b"])
	if _has(v, "mane_spikes"):
		for i in _n(c, 4):
			var a := lerpf(-70.0, 70.0, float(i) / maxf(_n(c, 4) - 1, 1))
			v.deco(torso, ShapeKit.cone(h * 0.05, h * 0.3, 4), c["b"], Vector3(sin(deg_to_rad(a)) * body_r * 0.9, cos(deg_to_rad(a)) * body_r * 0.9, -body_len * 0.32), Vector3(40, 0, -a))
	if _has(v, "cracks") or float(c["rk"].get("energy", 0)) >= 0.75:
		v.deco(torso, ShapeKit.sphere(body_r * 0.35, FACETS), c["e"], Vector3(0, body_r * 0.2, -body_len * 0.45), Vector3.ZERO, Vector3(1.2, 0.5, 0.4), true)
	if _has(v, "tail") or sp == "dragon":
		var tail := v.sway_part(torso, "tail", Vector3(0, body_r * 0.4, body_len * 0.55))
		var tl := h * (0.9 if sp == "dragon" else 0.5)
		v.deco(tail, ShapeKit.cone(body_r * 0.35, tl, 4), c["b"], Vector3(0, tl * 0.2, tl * 0.45), Vector3(70, 0, 0))
		if sp == "dragon":
			_spikes(v, tail, Vector3(0, tl * 0.15, tl * 0.2), Vector3(0, tl * 0.35, tl * 0.8), 3, h * 0.12, 60.0, c["b"])
	if _has(v, "wings") or sp == "dragon":
		_wings(v, torso, Vector3(0, body_r * 0.9, -body_len * 0.1), h * 1.1, c)
	var i := 0
	for fz: int in [-1, 1]:
		for sx: int in [-1, 1]:
			var lg := v._part("leg_%d" % i, ShapeKit.capsule(h * (0.09 if boar else 0.065), leg + body_r * 0.4), c["b"], rig, Vector3(sx * body_r * 0.6, leg + body_r * 0.2, fz * body_len * 0.34), Vector3(0, -(leg + body_r * 0.4) * 0.5, 0))
			v.legs.append(lg)
			if _has(v, "claws") or sp == "dragon":
				_claws(v, lg, Vector3(0, -leg - body_r * 0.2, 0), h * 0.1, c["b"], true)
			i += 1
	_mouth(v, head, Vector3(0, -hs * 0.2, -hs * 1.3))


## Many-legged crawlers: scorpions, crabs, spiders.
static func _crawler(v: EntityVisual, h: float, r: float, c: Dictionary, sp: String) -> void:
	var rig := _rig(v, &"legged")
	var leg := h * 0.45
	var y := leg * 0.85
	var torso: Node3D
	if sp == "spider":
		torso = v._part("torso", ShapeKit.sphere(r * 0.95, FACETS + 2), c["b"], rig, Vector3(0, y + r * 0.3, r * 0.55))
		torso.scale = Vector3(1.0, 0.85, 1.15)
	elif sp == "crab":
		torso = v._part("torso", ShapeKit.sphere(r * 0.95, FACETS + 2), c["b"], rig, Vector3(0, y, 0))
		(torso.get_child(0) as Node3D).scale = Vector3(1.45, 0.55, 1.1)
	else:
		torso = v._part("torso", ShapeKit.capsule(r * 0.55, r * 2.2), c["b"], rig, Vector3(0, y * 0.8, 0))
		(torso.get_child(0) as Node3D).rotation_degrees = Vector3(90, 0, 0)
		(torso.get_child(0) as Node3D).scale = Vector3(1.4, 1.0, 0.55)
	var hs := r * (0.5 if sp == "spider" else 0.4)
	var head_z := -r * (1.25 if sp == "spider" else 1.05)
	var head := v._part("head", ShapeKit.sphere(hs, FACETS), c["b"], torso, Vector3(0, 0, head_z))
	if sp == "crab":
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.cyl(hs * 0.08, hs * 0.1, hs * 0.9, 4), c["b"], Vector3(sx * hs * 0.4, hs * 0.5, 0))
		_eyes(v, head, Vector3(0, hs * 1.0, 0), hs * 0.4, hs * 0.18, c)
	elif sp == "spider":
		_eyes(v, head, Vector3(0, hs * 0.2, -hs * 0.85), hs * 0.32, hs * 0.13, c, 6)
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.cone(hs * 0.14, hs * 0.7, 4), c["b"], Vector3(sx * hs * 0.25, -hs * 0.6, -hs * 0.7), Vector3(-160, 0, sx * 10))
	else:
		_eyes(v, head, Vector3(0, hs * 0.3, -hs * 0.8), hs * 0.35, hs * 0.14, c)
	# Legs splay out and down; gait swings them on X only.
	var pairs := 4 if sp == "spider" else 3
	var i := 0
	for k in pairs:
		var fz := lerpf(-r * 0.6, r * 0.6, float(k) / maxf(pairs - 1, 1)) + (r * 0.45 if sp == "spider" else 0.0) - (r * 0.2 if sp == "spider" else 0.0)
		for sx: int in [-1, 1]:
			var lg := v._part("leg_%d" % i, ShapeKit.capsule(h * 0.045, leg * 1.35), c["b"], rig, Vector3(sx * r * 0.7, y, fz), Vector3(0, -leg * 0.6, 0))
			lg.rotation.z = sx * deg_to_rad(58.0 if sp == "spider" else 50.0)
			lg.rotation.y = sx * deg_to_rad(lerpf(25.0, -25.0, float(k) / maxf(pairs - 1, 1)))
			v.deco(lg, ShapeKit.cone(h * 0.05, leg * 0.5, 4), c["b"], Vector3(0, -leg * 1.35, 0), Vector3(180, 0, 0))
			v.legs.append(lg)
			i += 1
	if _has(v, "pincers") or sp == "crab":
		var big := 1.5 if sp == "crab" else 1.0
		for sx: int in [-1, 1]:
			var s := "l" if sx < 0 else "r"
			var arm := v._part("arm_" + s, ShapeKit.capsule(r * 0.13 * big, r * 1.0 * big), c["b"], torso, Vector3(sx * r * 0.55, 0, head_z + r * 0.2), Vector3(sx * r * 0.2, 0, -r * 0.45 * big))
			(arm.get_child(0) as Node3D).rotation_degrees = Vector3(90, 0, 0)
			var claw := Vector3(sx * r * 0.2, 0, -r * 1.0 * big)
			v.deco(arm, ShapeKit.cone(r * 0.2 * big, r * 0.75 * big, 4), c["b"], claw + Vector3(sx * r * 0.08, 0, -r * 0.2), Vector3(-90, 0, -sx * 18))
			v.deco(arm, ShapeKit.cone(r * 0.12 * big, r * 0.55 * big, 4), c["b"], claw + Vector3(-sx * r * 0.1, 0, -r * 0.15), Vector3(-90, 0, sx * 25))
	if _has(v, "stinger"):
		var tail := v.sway_part(torso, "tail", Vector3(0, r * 0.25, r * 1.05))
		var seg := r * 0.3
		var p := Vector3.ZERO
		for k in 4:
			p += Vector3(0, seg * 1.3, seg * (0.6 - k * 0.55))
			v.deco(tail, ShapeKit.sphere(seg * (1.0 - k * 0.1), FACETS), c["b"], p)
		v.deco(tail, ShapeKit.cone(seg * 0.45, seg * 1.8, 4), c["e"], p + Vector3(0, seg * 0.2, -seg * 1.0), Vector3(-120, 0, 0), Vector3.ONE, true)
	if _has(v, "back_plates"):
		for k in 3:
			v.deco(torso, ShapeKit.box(Vector3(r * 1.2, r * 0.12, r * 0.6)), c["b"], Vector3(0, r * 0.32, -r * 0.5 + k * r * 0.55), Vector3(14, 0, 0))
	if _has(v, "crystal_back"):
		for k in _n(c, 3):
			var a := float(k) / maxf(_n(c, 3) - 1, 1) * 2.0 - 1.0
			v.deco(torso, ShapeKit.cone(r * 0.14, r * 0.9, 4), c["e"], Vector3(a * r * 0.55, r * 0.6, a * a * r * 0.2), Vector3(12, 0, -a * 28), Vector3.ONE, true)
	if _has(v, "crown"):
		_spikes(v, torso, Vector3(-r * 0.7, r * 0.4, head_z * 0.55), Vector3(r * 0.7, r * 0.4, head_z * 0.55), _n(c, 3), r * 0.7, -15.0, c["b"])
	_mouth(v, head, Vector3(0, 0, -hs))


## Armoured beetle: a high domed shell that hides the head from the front
## (the front_armor read), a ram horn, stubby legs. Belly glows when flipped.
static func _beetle(v: EntityVisual, h: float, r: float, c: Dictionary) -> void:
	var rig := _rig(v, &"legged")
	var leg := h * 0.3
	var torso := v._part("torso", ShapeKit.sphere(r * 1.0, FACETS + 2), c["b"], rig, Vector3(0, leg + r * 0.35, 0))
	(torso.get_child(0) as Node3D).scale = Vector3(1.05, 0.72, 1.25)
	# Shell plates: two wing cases split down the back.
	for sx: int in [-1, 1]:
		v.deco(torso, ShapeKit.sphere(r * 0.9, FACETS), c["b"], Vector3(sx * r * 0.35, r * 0.35, r * 0.1), Vector3(0, 0, sx * 8.0), Vector3(0.62, 0.55, 1.3))
	v.deco(torso, ShapeKit.box(Vector3(r * 0.06, r * 0.08, r * 2.0)), c["e"], Vector3(0, r * 0.72, r * 0.1), Vector3.ZERO, Vector3.ONE, true)
	# Front shield + horn.
	var head := v._part("head", ShapeKit.sphere(r * 0.45, FACETS), c["b"], torso, Vector3(0, -r * 0.05, -r * 1.05))
	v.deco(head, ShapeKit.box(Vector3(r * 1.5, r * 0.9, r * 0.14)), c["b"], Vector3(0, r * 0.15, -r * 0.15), Vector3(-12, 0, 0))
	v.deco(head, ShapeKit.cone(r * 0.2, r * 1.1, 4), c["b"], Vector3(0, r * 0.5, -r * 0.45), Vector3(-55, 0, 0))
	_eyes(v, head, Vector3(0, -r * 0.05, -r * 0.3), r * 0.28, r * 0.08, c)
	v.deco(torso, ShapeKit.sphere(r * 0.6, FACETS), c["e"], Vector3(0, -r * 0.55, 0), Vector3.ZERO, Vector3(1.2, 0.2, 1.4), true)
	if _has(v, "back_spikes"):
		_spikes(v, torso, Vector3(0, r * 0.7, -r * 0.5), Vector3(0, r * 0.6, r * 0.9), _n(c, 4), r * 0.5, 30.0, c["b"])
	var i := 0
	for k in 3:
		var fz := lerpf(-r * 0.6, r * 0.7, k / 2.0)
		for sx: int in [-1, 1]:
			var lg := v._part("leg_%d" % i, ShapeKit.capsule(h * 0.06, leg * 1.4), c["b"], rig, Vector3(sx * r * 0.85, leg * 0.9, fz), Vector3(0, -leg * 0.55, 0))
			lg.rotation.z = sx * deg_to_rad(40.0)
			v.legs.append(lg)
			i += 1
	_mouth(v, head, Vector3(0, 0, -r * 0.5))


## Bat: a small hunched body under two huge ragged wings, ears, fangs.
static func _bat(v: EntityVisual, h: float, r: float, c: Dictionary) -> void:
	var rig := _rig(v, &"float")
	var torso := v._part("torso", ShapeKit.capsule(r * 0.45, r * 1.3), c["b"], rig, Vector3(0, h * 0.5, 0))
	var hs := r * 0.42
	var head := v._part("head", ShapeKit.sphere(hs, FACETS), c["b"], torso, Vector3(0, r * 0.75, -r * 0.2))
	for sx: int in [-1, 1]:
		v.deco(head, ShapeKit.cone(hs * 0.3, hs * 1.3, 3), c["b"], Vector3(sx * hs * 0.5, hs * 0.9, 0), Vector3(0, 0, -sx * 20))
		v.deco(head, ShapeKit.cone(hs * 0.08, hs * 0.4, 4), c["b"], Vector3(sx * hs * 0.2, -hs * 0.7, -hs * 0.6), Vector3(-170, 0, 0))
	_eyes(v, head, Vector3(0, hs * 0.1, -hs * 0.8), hs * 0.4, hs * 0.16, c)
	_wings(v, torso, Vector3(0, r * 0.4, 0), h * 1.5, c)
	_mouth(v, head, Vector3(0, -hs * 0.3, -hs))


## Veil jelly: a translucent bell, a violet core and hanging tendrils that
## sway. Reads as calm and wrong at the same time.
static func _jelly(v: EntityVisual, h: float, r: float, c: Dictionary) -> void:
	var rig := _rig(v, &"float")
	var bell := v._part("torso", ShapeKit.sphere(r * 1.0, FACETS + 4), c["b"], rig, Vector3(0, h * 0.72, 0))
	bell.scale = Vector3(1.0, 0.62, 1.0)
	v.deco(bell, ShapeKit.sphere(r * 0.42, FACETS), c["e"], Vector3(0, -r * 0.1, 0), Vector3.ZERO, Vector3.ONE, true)
	var head := v._part("head", ShapeKit.torus(r * 0.75, r * 1.0), c["b"], bell, Vector3(0, -r * 0.35, 0))
	_eyes(v, bell, Vector3(0, -r * 0.05, -r * 0.92), r * 0.3, r * 0.1, c)
	for k in 6:
		var a := TAU * k / 6.0
		var tend := v.sway_part(bell, "tend_%d" % k, Vector3(cos(a) * r * 0.6, -r * 0.5, sin(a) * r * 0.6))
		v.deco(tend, ShapeKit.cone(r * 0.07, h * 0.55, 3), c["b"] if k % 2 == 0 else c["e"], Vector3(0, -h * 0.27, 0), Vector3(180, 0, 0), Vector3.ONE, k % 2 == 1)
	_mouth(v, head, Vector3(0, -r * 0.5, 0))


## Squat spitter: toad-like sac with a spout, back spikes, glowing throat.
static func _toad(v: EntityVisual, h: float, r: float, c: Dictionary) -> void:
	var rig := _rig(v, &"float")
	var body := v._part("torso", ShapeKit.sphere(r * 1.05, FACETS + 2), c["b"], rig, Vector3(0, h * 0.42, 0))
	body.scale = Vector3(1.1, 0.82, 1.1)
	var spout := v._part("head", ShapeKit.cyl(r * 0.25, r * 0.45, h * 0.35, FACETS), c["b"], body, Vector3(0, r * 0.55, -r * 0.65))
	spout.rotation_degrees = Vector3(-55, 0, 0)
	v.deco(spout, ShapeKit.torus(r * 0.18, r * 0.3), c["e"], Vector3(0, h * 0.18, 0), Vector3.ZERO, Vector3.ONE, true)
	_eyes(v, body, Vector3(0, r * 0.62, -r * 0.62), r * 0.42, r * 0.13, c)
	if _has(v, "back_spikes"):
		for k in _n(c, 5):
			var a := (float(k) / maxf(_n(c, 5) - 1, 1) - 0.5) * 2.4
			v.deco(body, ShapeKit.cone(r * 0.12, r * 0.55, 4), c["b"], Vector3(sin(a) * r * 0.75, r * 0.85, cos(a) * r * 0.45 + r * 0.25), Vector3(35, 0, -rad_to_deg(a) * 0.6))
	if _has(v, "sac_glow"):
		v.deco(body, ShapeKit.sphere(r * 0.45, FACETS), c["e"], Vector3(0, -r * 0.3, -r * 0.72), Vector3.ZERO, Vector3(1.2, 0.8, 0.5), true)
	for sx: int in [-1, 1]:
		v.deco(body, ShapeKit.capsule(r * 0.16, r * 0.8), c["b"], Vector3(sx * r * 0.7, -r * 0.7, -r * 0.35), Vector3(20, 0, sx * 25))
	var m := Node3D.new()
	m.name = "socket_hand_r"
	m.position = Vector3(0, h * 0.2, 0)
	spout.add_child(m)
	v.set_socket(&"hand_r", m)


## Floating wisp: a dark core in violet flame, orbiting shards.
static func _wisp(v: EntityVisual, h: float, r: float, c: Dictionary) -> void:
	var rig := _rig(v, &"float")
	var core := v._part("torso", ShapeKit.sphere(r * 0.7, FACETS), c["b"], rig, Vector3(0, h * 0.5, 0))
	_eyes(v, core, Vector3(0, r * 0.1, -r * 0.62), r * 0.25, r * 0.12, c)
	if _has(v, "core_flame"):
		_flame_at(core, Vector3.ZERO, 14, r * 0.9)
	var ring := v._part("head", ShapeKit.sphere(0.01, 4), c["b"], rig, Vector3(0, h * 0.5, 0))
	v.spin_parts.append(ring)
	if _has(v, "shards"):
		for k in 4:
			var a := TAU * k / 4.0
			v.deco(ring, ShapeKit.cone(r * 0.16, r * 0.7, 3), c["b"], Vector3(cos(a), 0, sin(a)) * r * 1.35, Vector3(0, -rad_to_deg(a), -90))


## Flying raptor: angular wings, beak, crest, talons.
static func _raptor(v: EntityVisual, h: float, r: float, c: Dictionary) -> void:
	var rig := _rig(v, &"float")
	var torso := v._part("torso", ShapeKit.capsule(r * 0.45, r * 1.9), c["b"], rig, Vector3(0, h * 0.5, 0))
	(torso.get_child(0) as Node3D).rotation_degrees = Vector3(75, 0, 0)
	var hs := r * 0.38
	var head := v._part("head", ShapeKit.sphere(hs, FACETS), c["b"], torso, Vector3(0, r * 0.35, -r * 0.95))
	v.deco(head, ShapeKit.cone(hs * 0.35, hs * 1.5, 4), c["b"], Vector3(0, -hs * 0.15, -hs * 1.1), Vector3(-110, 0, 0))
	_eyes(v, head, Vector3(0, hs * 0.2, -hs * 0.7), hs * 0.45, hs * 0.16, c)
	if _has(v, "crest"):
		_spikes(v, head, Vector3(0, hs * 0.7, -hs * 0.2), Vector3(0, hs * 0.5, hs * 0.8), _n(c, 3), hs * 1.2, 60.0, c["b"])
	_wings(v, torso, Vector3(0, r * 0.3, -r * 0.2), h * 1.6, c)
	for k in 3:
		v.deco(torso, ShapeKit.cone(r * 0.15, r * 1.1, 3), c["b"], Vector3((k - 1) * r * 0.25, 0, r * 1.3), Vector3(95, (k - 1) * 20.0, 0), Vector3(1, 1, 0.3))
	if _has(v, "talons"):
		for sx: int in [-1, 1]:
			_claws(v, torso, Vector3(sx * r * 0.25, -r * 0.55, 0), r * 0.35, c["b"], true)
	_mouth(v, head, Vector3(0, 0, -hs * 1.5))


## Serpent: a chain of shrinking segments that sways; hooded, fanged head.
static func _serpent(v: EntityVisual, h: float, r: float, c: Dictionary) -> void:
	var rig := _rig(v, &"serpent")
	var torso := v._part("torso", ShapeKit.sphere(r * 0.55, FACETS), c["b"], rig, Vector3(0, r * 0.55, 0))
	var prev := torso
	for k in 7:
		var seg := v.sway_part(prev, "seg_%d" % k, Vector3(0, 0, r * 0.75 * (1.0 - k * 0.07)))
		v.deco(seg, ShapeKit.sphere(r * 0.5 * (1.0 - k * 0.1), FACETS), c["b"], Vector3.ZERO)
		if k % 2 == 0:
			v.deco(seg, ShapeKit.cone(r * 0.1, r * 0.5, 4), c["b"], Vector3(0, r * 0.45 * (1.0 - k * 0.1), 0), Vector3(40, 0, 0))
		prev = seg
	var head := v._part("head", ShapeKit.sphere(r * 0.55, FACETS), c["b"], torso, Vector3(0, h * 0.45, -r * 0.4))
	head.scale = Vector3(1.1, 0.7, 1.3)
	v.deco(torso, ShapeKit.capsule(r * 0.35, h * 0.5), c["b"], Vector3(0, h * 0.22, -r * 0.2))
	for sx: int in [-1, 1]:
		v.deco(head, ShapeKit.cone(r * 0.35, r * 1.2, 3), c["b"], Vector3(sx * r * 0.6, 0, r * 0.2), Vector3(0, 0, -sx * 80), Vector3(1, 1, 0.25))
		v.deco(head, ShapeKit.cone(r * 0.06, r * 0.4, 4), c["b"], Vector3(sx * r * 0.2, -r * 0.35, -r * 0.35), Vector3(-160, 0, 0))
	_eyes(v, head, Vector3(0, r * 0.15, -r * 0.4), r * 0.28, r * 0.1, c)
	_mouth(v, head, Vector3(0, 0, -r * 0.55))


## Two-legged corrupted: brutes (ogre-like), golems, wraiths, goblins, demons.
static func _biped(v: EntityVisual, h: float, r: float, c: Dictionary, sp: String) -> void:
	var rig := _rig(v, &"biped")
	var cfg: Array = {
		"brute": [0.34, 0.32, 1.15, 0.1, 0.46, 0.3, -0.28],
		"golem": [0.36, 0.33, 1.25, 0.1, 0.42, 0.34, -0.12],
		"wraith": [0.42, 0.3, 0.75, 0.1, 0.5, 0.12, -0.1],
		"goblin": [0.3, 0.26, 0.72, 0.17, 0.3, 0.14, -0.22],
		"demon": [0.38, 0.3, 1.05, 0.1, 0.44, 0.22, -0.05],
	}.get(sp, [0.4, 0.3, 0.9, 0.1, 0.42, 0.2, -0.1])
	var leg := h * float(cfg[0])
	var tl := h * float(cfg[1])
	var sw := r * float(cfg[2])
	var hs := h * float(cfg[3])
	var arm_len := h * float(cfg[4])
	var arm_r := r * float(cfg[5])
	v.torso_pitch = float(cfg[6])
	var hips := v._part("hips", ShapeKit.capsule(sw * 0.6, h * 0.1), c["b"], rig, Vector3(0, leg, 0))
	var torso: Node3D
	if sp == "golem":
		torso = v._part("torso", ShapeKit.box(Vector3(sw * 2.0, tl, sw * 1.3)), c["b"], hips, Vector3(0, 0.02, 0), Vector3(0, tl * 0.5, 0))
	else:
		torso = v._part("torso", ShapeKit.capsule(sw * 0.72, tl * 1.1), c["b"], hips, Vector3(0, 0.02, 0), Vector3(0, tl * 0.5, 0))
		(torso.get_child(0) as Node3D).scale = Vector3(1.25 if sp != "wraith" else 1.0, 1.0, 0.85)
	var head_y := tl + hs * (0.4 if sp in ["brute", "golem"] else 0.9)
	var head_z := -sw * (0.35 if sp in ["brute", "goblin"] else 0.1)
	var head: Node3D
	if sp == "golem":
		head = v._part("head", ShapeKit.box(Vector3(hs * 1.6, hs * 1.4, hs * 1.6)), c["b"], torso, Vector3(0, head_y, head_z))
	else:
		head = v._part("head", ShapeKit.sphere(hs, FACETS), c["b"], torso, Vector3(0, head_y, head_z))
		if sp == "wraith":
			head.scale = Vector3(0.85, 1.25, 1.0)
	_eyes(v, head, Vector3(0, 0, -hs * 0.85), hs * 0.38, hs * 0.14, c)
	if sp == "goblin":
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.cone(hs * 0.25, hs * 1.4, 3), c["b"], Vector3(sx * hs * 1.1, hs * 0.2, 0), Vector3(0, 0, -sx * 100), Vector3(1, 1, 0.4))
		v.deco(head, ShapeKit.cone(hs * 0.2, hs * 0.6, 4), c["b"], Vector3(0, -hs * 0.1, -hs * 1.0), Vector3(-100, 0, 0))
	if _has(v, "horns") or sp == "demon":
		_horns(v, head, Vector3(0, hs * 0.5, 0), hs * (2.6 if sp == "demon" else 1.8), c, 34.0)
	if _has(v, "crown"):
		for k in _n(c, 3):
			var a := lerpf(-50.0, 50.0, float(k) / maxf(_n(c, 3) - 1, 1))
			v.deco(head, ShapeKit.cone(hs * 0.12, hs * 1.1, 4), c["e"], Vector3(sin(deg_to_rad(a)) * hs * 0.8, hs * 0.95, cos(deg_to_rad(a)) * hs * 0.3), Vector3(-8, 0, -a), Vector3.ONE, true)
	if _has(v, "halo"):
		var halo := v.deco(torso, ShapeKit.torus(hs * 2.2, hs * 2.45), c["e"], Vector3(0, head_y + hs * 0.3, head_z + hs * 1.2), Vector3(90, 0, 0), Vector3.ONE, true)
		halo.visibility_range_end = EntityVisual.BODY_VISIBLE_RANGE
	if _has(v, "head_flame"):
		_flame_at(head, Vector3(0, hs * 0.9, hs * 0.2), 8, hs * 1.2)
	if _has(v, "shoulder_spikes"):
		for sx: int in [-1, 1]:
			for k in _n(c, 2):
				v.deco(torso, ShapeKit.cone(sw * 0.16, sw * 0.8, 4), c["b"], Vector3(sx * sw * (0.85 + k * 0.12), tl * (0.95 - k * 0.15), k * sw * 0.2), Vector3(15, 0, -sx * (35 + k * 20)))
	if _has(v, "wings"):
		_wings(v, torso, Vector3(0, tl * 0.8, sw * 0.6), h * 0.8, c)
	if _has(v, "sack"):
		# A bulging loot sack: thieves read as thieves from afar.
		v.deco(torso, ShapeKit.sphere(sw * 0.9, FACETS), c["b"], Vector3(0, tl * 0.75, sw * 0.95), Vector3.ZERO, Vector3(1.0, 1.1, 0.9))
		v.deco(torso, ShapeKit.sphere(sw * 0.25, FACETS), c["e"], Vector3(0, tl * 1.25, sw * 0.9), Vector3.ZERO, Vector3.ONE, true)
	if _has(v, "cracks"):
		v.deco(torso, ShapeKit.sphere(sw * 0.3, FACETS), c["e"], Vector3(0, tl * 0.62, -sw * 0.6), Vector3.ZERO, Vector3(1, 1.2, 0.35), true)
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var arm := v._part("arm_" + s, ShapeKit.capsule(arm_r, arm_len), c["b"], torso, Vector3(side * sw * 0.95, tl * 0.88, 0), Vector3(0, -arm_len * 0.5, 0))
		var tip := Vector3(0, -arm_len, 0)
		if _has(v, "big_fists"):
			if sp == "golem":
				v.deco(arm, ShapeKit.box(Vector3.ONE * arm_r * 2.6), c["b"], tip)
			else:
				v.deco(arm, ShapeKit.sphere(arm_r * 1.5, FACETS), c["b"], tip)
				_spikes(v, arm, tip + Vector3(-arm_r * 0.6, 0, -arm_r * 1.2), tip + Vector3(arm_r * 0.6, 0, -arm_r * 1.2), 3, arm_r * 0.9, -90.0, c["b"])
		if _has(v, "long_claws"):
			_claws(v, arm, tip, h * 0.14, c["b"], true)
		var lg := v._part("leg_" + s, ShapeKit.capsule(r * (0.3 if sp in ["brute", "golem"] else 0.18), leg), c["b"], rig, Vector3(side * sw * 0.45, leg, 0), Vector3(0, -leg * 0.5, 0))
		if sp in ["brute", "demon", "goblin"]:
			_claws(v, lg, Vector3(0, -leg, -r * 0.1), r * 0.3, c["b"])
	if _has(v, "tatters"):
		for k in 6:
			var a := TAU * k / 6.0
			v.deco(hips, ShapeKit.cone(sw * 0.35, leg * 1.1, 3), c["b"], Vector3(cos(a) * sw * 0.55, -leg * 0.45, sin(a) * sw * 0.45), Vector3(180 + sin(a) * 12.0, 0, cos(a) * 12.0))
	if sp == "goblin":
		var arm_r_node := v.part(&"arm_r")
		v.deco(arm_r_node, ShapeKit.box(Vector3(0.05, h * 0.35, 0.12)), c["b"], Vector3(0, -arm_len - h * 0.12, -0.08))
		v.deco(arm_r_node, ShapeKit.box(Vector3(0.02, h * 0.3, 0.03)), c["e"], Vector3(0, -arm_len - h * 0.12, -0.15), Vector3.ZERO, Vector3.ONE, true)
	var hand := Node3D.new()
	hand.name = "socket_hand_r"
	hand.position = Vector3(0, -arm_len, 0)
	v.part(&"arm_r").add_child(hand)
	v.set_socket(&"hand_r", hand)


# --- Wildlife (neutral family) ----------------------------------------------------------
## Round, soft and calm: the visual opposite of the enemy family. Solid
## placeholder colour, dark eyes, no violet.
static func build_wildlife(v: EntityVisual, h: float, r: float) -> void:
	var t := v.type
	var c := t.placeholder_color
	var main := ArtStyle.solid(c)
	var dark := ArtStyle.solid(c.darkened(0.35))
	var eye := ArtStyle.solid(ArtStyle.palette("wildlife_eye"))
	var sp := String(t.visual.get("species", "grazer"))
	if sp == "wader":
		_wader(v, h, r, main, dark, eye)
		return
	if sp == "shellfolk":
		_shellfolk(v, h, r, main, dark, eye)
		return
	var rig := _rig(v, &"legged")
	var leg := h * 0.45
	var body_len := r * 2.6
	var body := v._part("torso", ShapeKit.capsule(h * 0.3, body_len), main, rig, Vector3(0, leg + h * 0.18, 0))
	(body.get_child(0) as Node3D).rotation_degrees = Vector3(90, 0, 0)
	var head_pos := Vector3(0, h * 0.18, -body_len * 0.55)
	if _has(v, "long_neck"):
		v.deco(body, ShapeKit.capsule(h * 0.1, h * 0.5), main, Vector3(0, h * 0.3, -body_len * 0.45), Vector3(-30, 0, 0))
		head_pos = Vector3(0, h * 0.5, -body_len * 0.6)
	var hs := h * 0.22
	var head := v._part("head", ShapeKit.sphere(hs, 12), main, body, head_pos)
	for sx: int in [-1, 1]:
		v.deco(head, ShapeKit.sphere(hs * 0.14, 6), eye, Vector3(sx * hs * 0.5, hs * 0.2, -hs * 0.75))
	if _has(v, "long_ears"):
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.capsule(hs * 0.18, hs * 1.4), main, Vector3(sx * hs * 0.35, hs * 1.1, hs * 0.2), Vector3(-10, 0, -sx * 12))
	if _has(v, "curled_horns"):
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.torus(hs * 0.28, hs * 0.5), dark, Vector3(sx * hs * 0.8, hs * 0.4, hs * 0.1), Vector3(0, 0, 90))
	if _has(v, "antlers"):
		# Veil creatures carry the light in their antlers, not on the body.
		var am: Material = ArtStyle.solid(c.lightened(0.55)) if _has(v, "veil") else dark
		for sx: int in [-1, 1]:
			var base := Vector3(sx * hs * 0.4, hs * 0.7, hs * 0.1)
			v.deco(head, ShapeKit.capsule(hs * 0.07, hs * 1.6), am, base + Vector3(sx * hs * 0.3, hs * 0.6, 0), Vector3(0, 0, -sx * 25), Vector3.ONE, _has(v, "veil"))
			for k in 3:
				v.deco(head, ShapeKit.capsule(hs * 0.05, hs * 0.7), am, base + Vector3(sx * hs * (0.35 + k * 0.18), hs * (0.55 + k * 0.35), -hs * 0.1), Vector3(-20, 0, -sx * 70))
	if _has(v, "shimmer") and not _has(v, "veil"):
		v.deco(body, ShapeKit.sphere(h * 0.1, 8), ArtStyle.solid(c.lightened(0.5)), Vector3(0, h * 0.28, 0), Vector3.ZERO, Vector3(1.4, 0.5, 2.0), true)
	if _has(v, "beard"):
		v.deco(head, ShapeKit.cone(hs * 0.2, hs * 0.7, 5), dark, Vector3(0, -hs * 0.75, -hs * 0.45), Vector3(180, 0, 0))
	if _has(v, "big_ears"):
		for sx: int in [-1, 1]:
			v.deco(head, ShapeKit.cone(hs * 0.35, hs * 1.0, 4), main, Vector3(sx * hs * 0.5, hs * 0.85, hs * 0.1), Vector3(0, 0, -sx * 18))
	if _has(v, "fleece"):
		for k in 5:
			v.deco(body, ShapeKit.sphere(h * 0.2, 8), main, Vector3((k % 2 - 0.5) * h * 0.2, h * 0.22, -body_len * 0.35 + k * body_len * 0.17))
	if _has(v, "mane"):
		v.deco(body, ShapeKit.box(Vector3(h * 0.06, h * 0.25, body_len * 0.5)), dark, Vector3(0, h * 0.35, -body_len * 0.35), Vector3(-25, 0, 0))
	if _has(v, "tail"):
		var tail := v.sway_part(body, "tail", Vector3(0, h * 0.1, body_len * 0.55))
		v.deco(tail, ShapeKit.capsule(h * 0.06, h * 0.6), dark, Vector3(0, -h * 0.2, h * 0.12), Vector3(30, 0, 0))
	var i := 0
	for fz: int in [-1, 1]:
		for sx: int in [-1, 1]:
			v.legs.append(v._part("leg_%d" % i, ShapeKit.capsule(h * 0.07, leg), main, rig, Vector3(sx * h * 0.2, leg, fz * body_len * 0.32), Vector3(0, -leg * 0.5, 0)))
			i += 1
	_mouth(v, head, Vector3(0, 0, -hs))


## Wading bird (herons): stilt legs, a long S neck, a dagger beak.
static func _wader(v: EntityVisual, h: float, r: float, main: Material, dark: Material, eye: Material) -> void:
	var rig := _rig(v, &"legged")
	var leg := h * 0.48
	var body := v._part("torso", ShapeKit.capsule(r * 0.55, r * 1.9), main, rig, Vector3(0, leg + r * 0.3, 0))
	(body.get_child(0) as Node3D).rotation_degrees = Vector3(70, 0, 0)
	v.deco(body, ShapeKit.capsule(h * 0.05, h * 0.38), main, Vector3(0, r * 0.7, -r * 0.55), Vector3(-15, 0, 0))
	var hs := h * 0.07
	var head := v._part("head", ShapeKit.sphere(hs, 10), main, body, Vector3(0, r * 0.7 + h * 0.2, -r * 0.7))
	v.deco(head, ShapeKit.cone(hs * 0.35, hs * 3.2, 5), dark, Vector3(0, -hs * 0.1, -hs * 1.8), Vector3(-90, 0, 0))
	for sx: int in [-1, 1]:
		v.deco(head, ShapeKit.sphere(hs * 0.2, 6), eye, Vector3(sx * hs * 0.6, hs * 0.2, -hs * 0.4))
	var tail := v.sway_part(body, "tail", Vector3(0, 0, r * 0.95))
	v.deco(tail, ShapeKit.cone(r * 0.35, r * 0.8, 4), dark, Vector3(0, 0, r * 0.3), Vector3(100, 0, 0), Vector3(1, 1, 0.3))
	for sx: int in [-1, 1]:
		v.legs.append(v._part("leg_%d" % (0 if sx < 0 else 1), ShapeKit.capsule(h * 0.022, leg), dark, rig, Vector3(sx * r * 0.2, leg, 0), Vector3(0, -leg * 0.5, 0)))
	_mouth(v, head, Vector3(0, 0, -hs * 3.0))


## Shore crabs (wildlife, not corrupted): round shell, raised eyes, one big
## claw — comic, not threatening.
static func _shellfolk(v: EntityVisual, h: float, r: float, main: Material, dark: Material, eye: Material) -> void:
	var rig := _rig(v, &"legged")
	var shell := v._part("torso", ShapeKit.sphere(r * 0.9, 12), main, rig, Vector3(0, h * 0.45, 0))
	(shell.get_child(0) as Node3D).scale = Vector3(1.35, 0.55, 1.0)
	var head := v._part("head", ShapeKit.sphere(r * 0.1, 6), main, shell, Vector3(0, r * 0.2, -r * 0.7))
	for sx: int in [-1, 1]:
		v.deco(head, ShapeKit.capsule(r * 0.04, r * 0.35), dark, Vector3(sx * r * 0.18, r * 0.15, 0))
		v.deco(head, ShapeKit.sphere(r * 0.07, 6), eye, Vector3(sx * r * 0.18, r * 0.35, 0))
		var big := 1.6 if sx > 0 else 0.9
		v.deco(shell, ShapeKit.sphere(r * 0.22 * big, 8), dark, Vector3(sx * r * 0.95, 0, -r * 0.55), Vector3.ZERO, Vector3(1, 0.7, 1.3))
	var i := 0
	for k in 3:
		for sx: int in [-1, 1]:
			var lg := v._part("leg_%d" % i, ShapeKit.capsule(h * 0.05, h * 0.5), dark, rig, Vector3(sx * r * 0.9, h * 0.35, lerpf(-r * 0.3, r * 0.4, k / 2.0)), Vector3(0, -h * 0.2, 0))
			lg.rotation.z = sx * deg_to_rad(55.0)
			v.legs.append(lg)
			i += 1
	_mouth(v, head, Vector3(0, 0, -r * 0.2))
