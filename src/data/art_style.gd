class_name ArtStyle
extends RefCounted
## Character art direction as code-side helpers over data/art_style.json and
## data/visuals.json. Presentation only: gameplay never calls this.
## Families: human (stylized mannequin placeholder), enemy (black + violet energy), wildlife (neutral).
## See docs/CHARACTER_STYLE_GUIDE.md.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


static func palette(token: String) -> Color:
	return Color(String(DB.art_style.get("palette", {}).get(token, "#ff00ff")))


static func family(t: EntityType) -> String:
	if t.visual.has("family"):
		return t.visual["family"]
	match t.kind:
		EntityType.Kind.ENEMY, EntityType.Kind.BOSS:
			return "enemy"
		EntityType.Kind.ANIMAL:
			return "wildlife"
	return "human"


static func is_corrupted(t: EntityType) -> bool:
	return t != null and family(t) == "enemy"


static func rank(t: EntityType) -> Dictionary:
	var ranks: Dictionary = DB.art_style.get("ranks", {})
	var fallback := "boss" if t.kind == EntityType.Kind.BOSS else "common"
	return ranks.get(String(t.visual.get("rank", fallback)), ranks.get("common", {}))


static func has_feature(t: EntityType, f: String) -> bool:
	return f in t.visual.get("features", [])


## Colour for effects that come from this entity (death motes, dissolves):
## every corrupted creature bleeds the same violet, whatever its species.
static func vfx_color(t: EntityType) -> Color:
	return palette("violet_core") if is_corrupted(t) else t.placeholder_color


## Telegraph / windup / projectile colour for an attack. Elements keep their
## own gameplay colour (fire is still orange); plain enemy attacks are violet.
static func attack_color(t: EntityType, element: StringName) -> Color:
	if element != &"":
		return ElementFX.color(element)
	return palette("violet_core") if is_corrupted(t) else Color(1.0, 0.42, 0.18)


# --- Materials (shared, cached) ---------------------------------------------------------
## Dark enemy body: near-black with a hint of the species colour, tonal
## variation, glossy highlights, a violet rim for silhouette and glowing
## cracks scaled by rank energy.
static func enemy_body(t: EntityType) -> ShaderMaterial:
	var r := rank(t)
	# Veins everywhere, full glowing cracks only where the profile asks.
	var energy := float(r.get("energy", 0.3)) * (1.0 if has_feature(t, "cracks") else 0.35)
	var key := "enemy|%s|%.2f" % [t.placeholder_color.to_html(false), energy]
	if _mats.has(key):
		return _mats[key]
	var cfg: Dictionary = DB.art_style.get("enemy", {})
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/enemy_body.gdshader")
	m.set_shader_parameter("body", palette("enemy_body"))
	m.set_shader_parameter("body_hi", palette("enemy_body_hi"))
	m.set_shader_parameter("tint", t.placeholder_color)
	m.set_shader_parameter("tint_amount", float(cfg.get("species_tint", 0.14)))
	m.set_shader_parameter("energy_color", palette("violet_glow"))
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("rim", float(cfg.get("rim", 0.55)))
	m.set_shader_parameter("roughness", float(cfg.get("roughness", 0.4)))
	_mats[key] = m
	return m


## Self-lit violet for eyes, cracks, horn tips, cores. Pulses in the shader.
static func energy_mat(token: String = "violet_core", strength: float = 2.2) -> ShaderMaterial:
	var key := "energy|%s|%.2f" % [token, strength]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/enemy_energy.gdshader")
	m.set_shader_parameter("color", palette(token))
	m.set_shader_parameter("strength", strength)
	_mats[key] = m
	return m


static func solid(c: Color) -> ShaderMaterial:
	return EntityVisual.placeholder_material(c)


## Shared particle quad for violet flames (aura, horn fire, wisp cores).
static func flame_mesh() -> QuadMesh:
	if _meshes.has("flame"):
		return _meshes["flame"]
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Mix, not add: violet flames must read against bright daytime skies too.
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _soft_dot()
	quad.material = m
	_meshes["flame"] = quad
	return quad


static func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex


static func flame_ramp() -> Gradient:
	if _meshes.has("ramp"):
		return _meshes["ramp"]
	var g := Gradient.new()
	g.set_color(0, Color(palette("violet_hot"), 0.0))
	g.add_point(0.12, Color(palette("violet_core"), 1.0))
	g.add_point(0.55, Color(palette("violet_glow"), 0.8))
	g.set_color(g.get_point_count() - 1, Color(palette("violet_deep"), 0.0))
	_meshes["ramp"] = g
	return g


## Violet flames rising from a volume. `amount` is before the quality scale.
static func flames(amount: int, extents: Vector3, size: float, rise: float = 1.2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "VioletFlames"
	p.amount = Quality.particle_amount(amount)
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, rise, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = sc
	p.mesh = flame_mesh()
	p.color_ramp = flame_ramp()
	p.visibility_aabb = AABB(-extents - Vector3(1, 1, 1), extents * 2.0 + Vector3(2, 4, 2))
	return p


# --- Validation ---------------------------------------------------------------------------
static func validate(db: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var st: Dictionary = db.art_style
	for token in ["enemy_body", "violet_glow", "violet_core", "violet_hot", "violet_deep"]:
		if not st.get("palette", {}).has(token):
			errors.append("art_style palette missing '%s'" % token)
	for e: EntityType in db.entities.values():
		var v: Dictionary = e.visual
		if v.is_empty():
			errors.append("entity '%s' has no visual profile (data/visuals.json)" % e.id)
			continue
		var fam := String(v.get("family", ""))
		if not fam in st.get("families", []):
			errors.append("visual '%s' unknown family '%s'" % [e.id, fam])
		var hostile := e.kind in [EntityType.Kind.ENEMY, EntityType.Kind.BOSS]
		if hostile != (fam == "enemy"):
			errors.append("visual '%s' family '%s' does not match its kind" % [e.id, fam])
		if e.kind in [EntityType.Kind.PLAYER, EntityType.Kind.NPC] and fam != "human":
			errors.append("visual '%s' people must be the human family" % e.id)
		if fam == "enemy":
			if not st.get("ranks", {}).has(String(v.get("rank", ""))):
				errors.append("visual '%s' unknown rank '%s'" % [e.id, v.get("rank", "")])
			if not String(v.get("species", "")) in st.get("species", []):
				errors.append("visual '%s' unknown species '%s'" % [e.id, v.get("species", "")])
		elif fam == "human":
			if not String(v.get("build", "average")) in st.get("builds", {}):
				errors.append("visual '%s' unknown build" % e.id)
			if not String(v.get("hair", "short")) in st.get("hair", []):
				errors.append("visual '%s' unknown hair '%s'" % [e.id, v.get("hair")])
			if not String(v.get("headwear", "none")) in st.get("headwear", []):
				errors.append("visual '%s' unknown headwear '%s'" % [e.id, v.get("headwear")])
			if not String(v.get("outfit", "tunic")) in st.get("outfits", []):
				errors.append("visual '%s' unknown outfit '%s'" % [e.id, v.get("outfit")])
			for a in v.get("accessories", []):
				if not a in st.get("accessories", []):
					errors.append("visual '%s' unknown accessory '%s'" % [e.id, a])
	return errors
