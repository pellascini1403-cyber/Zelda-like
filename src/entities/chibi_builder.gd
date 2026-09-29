class_name ChibiBuilder
extends RefCounted
## Human family placeholder: chibi proportions (big head, compact body, short
## limbs, big hands and feet) with real per-character variation from
## data/visuals.json — build, age, hair, headwear, outfit, accessories.
## Every part uses the entity's own placeholder colour (lighter for skin,
## darker for hair/leather), so the one-colour-per-species rule holds.

static func build(v: EntityVisual, h: float, r: float) -> void:
	var p: Dictionary = v.type.visual
	var st: Dictionary = DB.art_style.get("chibi", {})
	var age := String(p.get("age", "adult"))
	var bw := float(DB.art_style.get("builds", {}).get(String(p.get("build", "average")), 1.0))
	var c := v.type.placeholder_color
	var main := ArtStyle.solid(c)
	var skin := ArtStyle.solid(c.lightened(0.38))
	var dark := ArtStyle.solid(c.darkened(0.42))
	var eye := ArtStyle.solid(ArtStyle.palette("human_eye"))

	var rig := v.add_rig()
	rig.scale = Vector3.ONE * float(p.get("scale", 1.0))
	v.rest_scale = rig.scale
	var leg := h * float(st.get("leg_length", 0.27))
	var torso_len := h * float(st.get("torso_length", 0.28))
	var head_r := h * float(st.get("child_head_radius" if age == "child" else "head_radius", 0.2))
	var tw := r * 0.62 * bw
	var hips := v._part("hips", ShapeKit.capsule(tw * 0.9, h * 0.1), main, rig, Vector3(0, leg, 0))
	var torso := v._part("torso", ShapeKit.capsule(tw, torso_len), main, hips, Vector3(0, 0.02, 0), Vector3(0, torso_len * 0.5, 0))
	var head := v._part("head", ShapeKit.sphere(head_r, 14), skin, torso, Vector3(0, torso_len + head_r * 0.78, -0.02))
	if age == "elder":
		v.torso_pitch = -0.22
	# Face: two dark eyes give facing at a glance (and the chibi look).
	for sx: int in [-1, 1]:
		v.deco(head, ShapeKit.sphere(head_r * 0.13, 6), eye, Vector3(sx * head_r * 0.36, -head_r * 0.08, -head_r * 0.9), Vector3.ZERO, Vector3(0.8, 1.35, 0.5))

	# Limbs: short, stubby, big hands and feet.
	var arm_len := h * float(st.get("arm_length", 0.27))
	var hand_r := r * 0.2 * float(st.get("hand_scale", 1.35))
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var arm := v._part("arm_" + s, ShapeKit.capsule(r * 0.16 * sqrt(bw), arm_len), main, torso, Vector3(side * (tw + r * 0.1), torso_len * 0.86, 0), Vector3(0, -arm_len * 0.5, 0))
		v.deco(arm, ShapeKit.sphere(hand_r, 8), skin, Vector3(0, -arm_len * 0.98, 0))
		var lg := v._part("leg_" + s, ShapeKit.capsule(r * 0.21 * sqrt(bw), leg), dark, rig, Vector3(side * tw * 0.5, leg, 0), Vector3(0, -leg * 0.5, 0))
		v.deco(lg, ShapeKit.sphere(r * 0.24 * float(st.get("foot_scale", 1.4)), 8), dark, Vector3(0, -leg * 0.95, -r * 0.12), Vector3.ZERO, Vector3(0.85, 0.55, 1.25))
	var hand := Node3D.new()
	hand.name = "socket_hand_r"
	hand.position = Vector3(0, -arm_len * 0.98, 0)
	v.part(&"arm_r").add_child(hand)
	v.set_socket(&"hand_r", hand)
	var back := Node3D.new()
	back.name = "socket_back"
	back.position = Vector3(0, torso_len * 0.6, tw * 0.95)
	torso.add_child(back)
	v.set_socket(&"back", back)

	_hair(v, head, head_r, String(p.get("hair", "short")), dark)
	_headwear(v, head, head_r, String(p.get("headwear", "none")), main, dark)
	_outfit(v, hips, torso, tw, torso_len, leg, String(p.get("outfit", "tunic")), main, dark)
	for a in p.get("accessories", []):
		_accessory(v, String(a), head, torso, head_r, tw, torso_len, arm_len, main, dark, skin)


static func _hair(v: EntityVisual, head: Node3D, hr: float, style: String, m: Material) -> void:
	if style == "bald":
		return
	var cap := Vector3(1.06, 0.72 if style != "wild" else 0.9, 1.08)
	v.deco(head, ShapeKit.sphere(hr * (1.14 if style == "wild" else 1.0), 12), m, Vector3(0, hr * 0.26, hr * 0.08), Vector3.ZERO, cap)
	match style:
		"swept":
			v.deco(head, ShapeKit.cone(hr * 0.38, hr * 0.9), m, Vector3(hr * 0.2, hr * 0.7, -hr * 0.45), Vector3(-65, 0, -25))
		"spiky", "wild":
			for i in 5:
				var a := -1.0 + i * 0.5
				v.deco(head, ShapeKit.cone(hr * 0.26, hr * 0.7), m, Vector3(a * hr * 0.55, hr * 0.85, hr * 0.15), Vector3(20, 0, -a * 35))
		"long":
			v.deco(head, ShapeKit.capsule(hr * 0.72, hr * 1.9), m, Vector3(0, -hr * 0.35, hr * 0.42), Vector3.ZERO, Vector3(1.2, 1, 0.6))
		"ponytail":
			v.deco(head, ShapeKit.capsule(hr * 0.22, hr * 1.2), m, Vector3(0, hr * 0.1, hr * 1.05), Vector3(-35, 0, 0))
		"bun":
			v.deco(head, ShapeKit.sphere(hr * 0.38, 8), m, Vector3(0, hr * 0.85, hr * 0.55))
		"pigtails":
			for sx: int in [-1, 1]:
				v.deco(head, ShapeKit.sphere(hr * 0.32, 8), m, Vector3(sx * hr * 0.98, hr * 0.05, hr * 0.3))
		"topknot":
			v.deco(head, ShapeKit.sphere(hr * 0.3, 8), m, Vector3(0, hr * 1.12, hr * 0.1))
			v.deco(head, ShapeKit.cyl(hr * 0.06, hr * 0.06, hr * 0.5, 5), m, Vector3(0, hr * 1.15, hr * 0.1), Vector3(0, 0, 90))


static func _headwear(v: EntityVisual, head: Node3D, hr: float, kind: String, main: Material, dark: Material) -> void:
	match kind:
		"hood":
			v.deco(head, ShapeKit.sphere(hr * 1.14, 12), main, Vector3(0, hr * 0.12, hr * 0.14), Vector3.ZERO, Vector3(1, 1.02, 1))
			v.deco(head, ShapeKit.cone(hr * 0.45, hr * 0.8), main, Vector3(0, hr * 0.55, hr * 0.9), Vector3(-70, 0, 0))
		"cap":
			v.deco(head, ShapeKit.sphere(hr * 1.04, 10), main, Vector3(0, hr * 0.3, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
			v.deco(head, ShapeKit.box(Vector3(hr * 1.2, hr * 0.08, hr * 0.7)), main, Vector3(0, hr * 0.42, -hr * 1.0))
		"hat_wide":
			v.deco(head, ShapeKit.cyl(hr * 1.9, hr * 1.9, hr * 0.08, 14), main, Vector3(0, hr * 0.62, 0))
			v.deco(head, ShapeKit.cyl(hr * 0.75, hr * 0.85, hr * 0.55, 12), main, Vector3(0, hr * 0.9, 0))
		"hat_cone":
			v.deco(head, ShapeKit.cyl(0.0, hr * 1.85, hr * 0.85, 14), main, Vector3(0, hr * 1.02, 0))
		"helmet":
			v.deco(head, ShapeKit.sphere(hr * 1.1, 12), dark, Vector3(0, hr * 0.22, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
			v.deco(head, ShapeKit.box(Vector3(hr * 0.16, hr * 0.5, hr * 1.6)), main, Vector3(0, hr * 1.05, 0))
		"turban":
			v.deco(head, ShapeKit.sphere(hr * 1.1, 12), main, Vector3(0, hr * 0.42, 0), Vector3.ZERO, Vector3(1.05, 0.75, 1.05))
			v.deco(head, ShapeKit.torus(hr * 0.85, hr * 1.2), main, Vector3(0, hr * 0.3, 0))
		"bandana":
			v.deco(head, ShapeKit.torus(hr * 0.92, hr * 1.1), main, Vector3(0, hr * 0.38, 0), Vector3(-8, 0, 0))
			v.deco(head, ShapeKit.cone(hr * 0.2, hr * 0.6), main, Vector3(0, hr * 0.25, hr * 1.2), Vector3(-110, 0, 0))


static func _outfit(v: EntityVisual, hips: Node3D, torso: Node3D, tw: float, tl: float, leg: float, kind: String, main: Material, dark: Material) -> void:
	match kind:
		"tunic":
			v.deco(hips, ShapeKit.cyl(tw * 0.95, tw * 1.2, leg * 0.42, 10), main, Vector3(0, -leg * 0.12, 0))
			v.deco(torso, ShapeKit.torus(tw * 0.9, tw * 1.08), dark, Vector3(0, 0.02, 0))
		"robe":
			v.deco(hips, ShapeKit.cyl(tw * 0.98, tw * 1.55, leg * 0.92, 12), main, Vector3(0, -leg * 0.4, 0))
			v.deco(torso, ShapeKit.torus(tw * 0.9, tw * 1.1), dark, Vector3(0, 0.03, 0))
		"coat":
			v.deco(torso, ShapeKit.cyl(tw * 1.08, tw * 1.35, tl + leg * 0.6, 10), main, Vector3(0, tl * 0.45 - leg * 0.3, 0))
			v.deco(torso, ShapeKit.box(Vector3(tw * 0.25, tl * 0.9, 0.02)), dark, Vector3(0, tl * 0.5, -tw * 1.05))
		"apron":
			v.deco(hips, ShapeKit.cyl(tw * 0.95, tw * 1.1, leg * 0.3, 10), dark, Vector3(0, -leg * 0.08, 0))
			v.deco(torso, ShapeKit.box(Vector3(tw * 1.3, tl + leg * 0.5, 0.04)), dark, Vector3(0, tl * 0.35 - leg * 0.25, -tw * 1.02))
		"armor":
			v.deco(torso, ShapeKit.box(Vector3(tw * 2.1, tl * 0.8, tw * 2.0)), dark, Vector3(0, tl * 0.55, 0))
			for sx: int in [-1, 1]:
				v.deco(torso, ShapeKit.sphere(tw * 0.55, 8), dark, Vector3(sx * tw * 1.1, tl * 0.92, 0), Vector3.ZERO, Vector3(1.2, 0.7, 1.1))
			v.deco(hips, ShapeKit.cyl(tw * 0.95, tw * 1.25, leg * 0.45, 8), main, Vector3(0, -leg * 0.14, 0))
		"vest":
			v.deco(torso, ShapeKit.capsule(tw * 1.08, tl * 0.95), dark, Vector3(0, tl * 0.5, tw * 0.06), Vector3.ZERO, Vector3(1, 1, 0.98))
			v.deco(hips, ShapeKit.cyl(tw * 0.95, tw * 1.08, leg * 0.3, 10), main, Vector3(0, -leg * 0.06, 0))
		"cloak":
			v.deco(torso, ShapeKit.cyl(tw * 1.12, tw * 1.7, tl + leg * 0.75, 12), main, Vector3(0, tl * 0.45 - leg * 0.38, tw * 0.08))
			v.deco(torso, ShapeKit.torus(tw * 0.95, tw * 1.25), dark, Vector3(0, tl * 0.95, 0))


static func _accessory(v: EntityVisual, a: String, head: Node3D, torso: Node3D, hr: float, tw: float, tl: float, arm: float, main: Material, dark: Material, skin: Material) -> void:
	var arm_l := v.part(&"arm_l")
	var hand_y := -arm * 0.98
	match a:
		"scarf":
			v.deco(torso, ShapeKit.torus(tw * 0.6, tw * 1.05), dark, Vector3(0, tl * 1.0, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
			var tail := v.sway_part(torso, "scarf_tail", Vector3(tw * 0.35, tl * 0.98, tw * 0.75))
			v.deco(tail, ShapeKit.box(Vector3(tw * 0.35, tl * 0.9, 0.03)), dark, Vector3(0, -tl * 0.42, 0))
		"cape":
			var cape := v.sway_part(torso, "cape", Vector3(0, tl * 0.95, tw * 0.95))
			v.deco(cape, ShapeKit.box(Vector3(tw * 2.0, tl + arm * 1.1, 0.04)), dark, Vector3(0, -(tl + arm * 1.1) * 0.5, 0))
		"backpack":
			v.deco(torso, ShapeKit.box(Vector3(tw * 1.4, tl * 0.8, tw * 0.8)), dark, Vector3(0, tl * 0.5, tw * 1.25))
		"big_pack":
			v.deco(torso, ShapeKit.box(Vector3(tw * 1.9, tl * 1.7, tw * 1.1)), dark, Vector3(0, tl * 1.0, tw * 1.45))
			v.deco(torso, ShapeKit.cyl(tw * 0.35, tw * 0.35, tw * 2.2, 8), main, Vector3(0, tl * 1.95, tw * 1.45), Vector3(0, 0, 90))
		"satchel":
			v.deco(torso, ShapeKit.box(Vector3(tw * 0.55, tl * 0.4, tw * 0.5)), dark, Vector3(tw * 1.0, tl * 0.02, -tw * 0.2))
			v.deco(torso, ShapeKit.torus(tw * 1.05, tw * 1.15), dark, Vector3(0, tl * 0.5, 0), Vector3(0, 0, 50))
		"staff", "bell":
			var len := hr * 7.0
			v.deco(arm_l, ShapeKit.cyl(0.025, 0.03, len, 6), dark, Vector3(0, hand_y + len * 0.2, -0.04))
			if a == "bell":
				v.deco(arm_l, ShapeKit.cyl(hr * 0.1, hr * 0.3, hr * 0.4, 8), main, Vector3(0, hand_y + len * 0.72, -0.04))
		"hammer":
			v.deco(torso, ShapeKit.cyl(0.025, 0.025, arm * 1.4, 6), dark, Vector3(tw * 1.05, -tl * 0.05, -tw * 0.3), Vector3(0, 0, 12))
			v.deco(torso, ShapeKit.box(Vector3(tw * 0.5, tw * 0.35, tw * 0.35)), dark, Vector3(tw * 1.12, tl * 0.32, -tw * 0.3))
		"rod":
			v.deco(torso, ShapeKit.cyl(0.012, 0.025, hr * 9.0, 5), dark, Vector3(-tw * 0.5, tl * 1.3, tw * 1.1), Vector3(35, 0, 18))
		"bow":
			v.deco(torso, ShapeKit.torus(tl * 1.2, tl * 1.28), dark, Vector3(0, tl * 0.5, tw * 1.05), Vector3(0, 90, 0), Vector3(1, 1.3, 0.35))
		"quiver":
			v.deco(torso, ShapeKit.cyl(tw * 0.3, tw * 0.25, tl * 1.3, 8), dark, Vector3(tw * 0.5, tl * 0.75, tw * 1.05), Vector3(0, 0, -25))
		"book":
			v.deco(arm_l, ShapeKit.box(Vector3(hr * 0.7, hr * 0.9, hr * 0.2)), dark, Vector3(0, hand_y, -hr * 0.2))
		"scroll":
			v.deco(torso, ShapeKit.cyl(tw * 0.18, tw * 0.18, tw * 2.3, 8), skin, Vector3(0, tl * 1.05, tw * 1.35), Vector3(0, 0, 90))
		"lantern":
			var lamp := ArtStyle.solid(Color(1.0, 0.86, 0.55))
			v.deco(arm_l, ShapeKit.box(Vector3(hr * 0.45, hr * 0.6, hr * 0.45)), lamp, Vector3(0, hand_y - hr * 0.4, 0))
		"spear":
			var len := hr * 8.0
			v.deco(arm_l, ShapeKit.cyl(0.025, 0.025, len, 6), dark, Vector3(0, hand_y + len * 0.25, -0.04))
			v.deco(arm_l, ShapeKit.cone(0.06, hr * 0.8, 4), main, Vector3(0, hand_y + len * 0.75 + hr * 0.4, -0.04))
		"shield":
			v.deco(torso, ShapeKit.cyl(tl * 0.75, tl * 0.75, 0.06, 10), dark, Vector3(0, tl * 0.5, tw * 1.15), Vector3(90, 0, 0))
		"basket":
			v.deco(torso, ShapeKit.cyl(tw * 0.8, tw * 0.6, tl * 0.9, 10), dark, Vector3(0, tl * 0.55, tw * 1.35))
		"rope":
			v.deco(torso, ShapeKit.torus(tw * 0.9, tw * 1.15), dark, Vector3(0, tl * 0.55, 0), Vector3(0, 0, -45), Vector3(1, 1, 2.2))
		"pick":
			v.deco(torso, ShapeKit.box(Vector3(tw * 1.2, 0.05, 0.05)), dark, Vector3(-tw * 1.05, 0, -tw * 0.2), Vector3(0, 0, 70))
		"gourd":
			v.deco(torso, ShapeKit.sphere(tw * 0.35, 8), main, Vector3(-tw * 1.0, -tl * 0.05, 0))
			v.deco(torso, ShapeKit.sphere(tw * 0.24, 8), main, Vector3(-tw * 1.0, tl * 0.2, 0))
		"glasses":
			for sx: int in [-1, 1]:
				v.deco(head, ShapeKit.torus(hr * 0.16, hr * 0.22), dark, Vector3(sx * hr * 0.36, -hr * 0.08, -hr * 0.95), Vector3(90, 0, 0))
		"goggles":
			for sx: int in [-1, 1]:
				v.deco(head, ShapeKit.torus(hr * 0.15, hr * 0.26), dark, Vector3(sx * hr * 0.36, hr * 0.48, -hr * 0.84), Vector3(70, 0, 0))
		"beard":
			v.deco(head, ShapeKit.sphere(hr * 0.55, 8), dark, Vector3(0, -hr * 0.62, -hr * 0.55), Vector3.ZERO, Vector3(1.3, 0.8, 0.8))
		"long_beard":
			v.deco(head, ShapeKit.cyl(hr * 0.5, 0.0, hr * 1.4, 8), skin, Vector3(0, -hr * 1.05, -hr * 0.62), Vector3(-12, 0, 0))
