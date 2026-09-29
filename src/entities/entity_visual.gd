class_name EntityVisual
extends Node3D
## Presentation layer of an entity. The ONLY node that knows what the entity
## looks like.
##
## Gameplay (colliders, hurtboxes, AI, combat) lives on the parent body and
## talks to this node through a tiny interface:
##   set_locomotion(speed_ratio, state)   play_action(name, duration)
##   set_flash(amount, color)              get_socket(name) -> Node3D
##
## With EntityType.model empty, a solid-color placeholder is built from
## EntityType.placeholder_shape/color. With a model path, the user's scene is
## instanced instead and logical states are mapped to its clips through
## EntityType.anim_map. Nothing else changes. See docs/ASSETS.md.

var type: EntityType
var is_placeholder := true
var state: StringName = &"idle"
var speed_ratio := 0.0

var _model: Node3D
var _anim: AnimationPlayer
var _parts: Dictionary = {}          # placeholder limbs by name
var _sockets: Dictionary = {}
var _geoms: Array[GeometryInstance3D] = []
var _phase := 0.0
var _action: StringName = &""
var _action_t := 0.0
var _action_len := 0.0
var _flash := 0.0

static var _materials: Dictionary = {}


func setup(entity_type: EntityType) -> void:
	type = entity_type
	for c in get_children():
		c.queue_free()
	_parts.clear()
	_sockets.clear()
	_geoms.clear()
	if type.model != "" and ResourceLoader.exists(type.model):
		_build_model()
	else:
		_build_placeholder()


# --- Final model path ------------------------------------------------------------------
func _build_model() -> void:
	is_placeholder = false
	var scene: PackedScene = load(type.model)
	_model = scene.instantiate()
	_model.scale = Vector3.ONE * type.model_scale
	_model.position = type.model_offset
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for n in _model.find_children("*", "Node3D", true, false):
		if n.name.begins_with("socket_"):
			_sockets[StringName(n.name.trim_prefix("socket_"))] = n
	for g in _model.find_children("*", "GeometryInstance3D", true, false):
		_geoms.append(g)
	# Sockets the model does not define fall back to sensible defaults.
	_ensure_default_sockets()


# --- Placeholder path -----------------------------------------------------------------------
static func placeholder_material(c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/placeholder.gdshader")
	m.set_shader_parameter("color", c)
	_materials[key] = m
	return m


func _build_placeholder() -> void:
	is_placeholder = true
	var mat := placeholder_material(type.placeholder_color)
	var h := type.collider_height
	var r := type.collider_radius
	match type.placeholder_shape:
		&"humanoid", &"giant":
			_humanoid(mat, h, r)
		&"quadruped":
			_quadruped(mat, h, r)
		&"blob":
			_blob(mat, h, r)
		&"orb":
			_orb(mat, h, r)
		_:
			_humanoid(mat, h, r)
	_ensure_default_sockets()


const LIMB_VISIBLE_RANGE := 40.0
const BODY_VISIBLE_RANGE := 180.0


func _part(part_name: String, mesh: Mesh, mat: Material, parent: Node3D, pos: Vector3, pivot_offset: Vector3 = Vector3.ZERO) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = pos
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pivot_offset
	# Placeholder LOD: limbs vanish at distance, the body stays (cheap reads).
	var is_body := part_name in ["torso", "head"]
	mi.visibility_range_end = BODY_VISIBLE_RANGE if is_body else LIMB_VISIBLE_RANGE
	if not is_body:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if type.kind != EntityType.Kind.PLAYER else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(mi)
	_parts[StringName(part_name)] = pivot
	_geoms.append(mi)
	return pivot


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 10
	m.rings = 4
	return m


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


## Mannequin: torso, head, two arms, two legs. Proportions follow the
## gameplay capsule so the silhouette matches the collider exactly.
func _humanoid(mat: Material, h: float, r: float) -> void:
	var root := Node3D.new()
	root.name = "Rig"
	add_child(root)
	_parts[&"rig"] = root
	var leg_len := h * 0.46
	var torso_len := h * 0.34
	var head_r := h * 0.085
	var hips := _part("hips", _capsule(r * 0.62, h * 0.12), mat, root, Vector3(0, leg_len, 0))
	var torso := _part("torso", _capsule(r * 0.7, torso_len), mat, hips, Vector3(0, 0.02, 0), Vector3(0, torso_len * 0.5, 0))
	_part("head", _sphere(head_r), mat, torso, Vector3(0, torso_len + head_r * 0.9, 0))
	var arm_len := h * 0.36
	var shoulder_y := torso_len * 0.88
	for side in [-1, 1]:
		var s := "l" if side < 0 else "r"
		_part("arm_" + s, _capsule(r * 0.2, arm_len), mat, torso, Vector3(side * r * 0.86, shoulder_y, 0), Vector3(0, -arm_len * 0.5, 0))
		_part("leg_" + s, _capsule(r * 0.27, leg_len), mat, root, Vector3(side * r * 0.35, leg_len, 0), Vector3(0, -leg_len * 0.5, 0))
	var hand := Node3D.new()
	hand.name = "socket_hand_r"
	hand.position = Vector3(0, -arm_len * 0.95, 0)
	(_parts[&"arm_r"] as Node3D).add_child(hand)
	_sockets[&"hand_r"] = hand
	var back := Node3D.new()
	back.name = "socket_back"
	back.position = Vector3(0, torso_len * 0.6, r * 0.7)
	torso.add_child(back)
	_sockets[&"back"] = back


func _quadruped(mat: Material, h: float, r: float) -> void:
	var root := Node3D.new()
	root.name = "Rig"
	add_child(root)
	_parts[&"rig"] = root
	var leg_len := h * 0.45
	var body_len := r * 2.6
	var body := _part("torso", _capsule(h * 0.3, body_len), mat, root, Vector3(0, leg_len + h * 0.18, 0))
	(body.get_child(0) as Node3D).rotation_degrees = Vector3(90, 0, 0)
	_part("head", _sphere(h * 0.22), mat, body, Vector3(0, h * 0.18, -body_len * 0.55))
	var idx := 0
	for fz in [-1, 1]:
		for side in [-1, 1]:
			var n := "leg_%d" % idx
			_part(n, _capsule(h * 0.07, leg_len), mat, root, Vector3(side * h * 0.2, leg_len, fz * body_len * 0.32), Vector3(0, -leg_len * 0.5, 0))
			idx += 1
	var mouth := Node3D.new()
	mouth.name = "socket_hand_r"
	mouth.position = Vector3(0, 0, -h * 0.2)
	(_parts[&"head"] as Node3D).add_child(mouth)
	_sockets[&"hand_r"] = mouth


func _blob(mat: Material, h: float, r: float) -> void:
	var root := Node3D.new()
	root.name = "Rig"
	add_child(root)
	_parts[&"rig"] = root
	var body := _part("torso", _sphere(r * 1.05), mat, root, Vector3(0, h * 0.42, 0))
	body.scale = Vector3(1.0, 0.85, 1.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = r * 0.55
	cone.height = h * 0.35
	cone.radial_segments = 8
	var spout := _part("head", cone, mat, body, Vector3(0, r * 0.7, -r * 0.35))
	spout.rotation_degrees = Vector3(-30, 0, 0)
	var mouth := Node3D.new()
	mouth.name = "socket_hand_r"
	mouth.position = Vector3(0, h * 0.2, 0)
	spout.add_child(mouth)
	_sockets[&"hand_r"] = mouth


func _orb(mat: Material, h: float, r: float) -> void:
	var root := Node3D.new()
	root.name = "Rig"
	add_child(root)
	_parts[&"rig"] = root
	_part("torso", _sphere(r), mat, root, Vector3(0, h * 0.5, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = r * 1.25
	ring.outer_radius = r * 1.45
	ring.rings = 16
	ring.ring_segments = 6
	_part("head", ring, mat, root, Vector3(0, h * 0.5, 0))


func _ensure_default_sockets() -> void:
	for s in [&"hand_r", &"back", &"head", &"center"]:
		if _sockets.has(s):
			continue
		var n := Node3D.new()
		n.name = "socket_" + String(s)
		match s:
			&"hand_r": n.position = Vector3(type.collider_radius, type.collider_height * 0.5, -0.2)
			&"back": n.position = Vector3(0, type.collider_height * 0.7, type.collider_radius)
			&"head": n.position = Vector3(0, type.collider_height * 0.95, 0)
			&"center": n.position = Vector3(0, type.collider_height * 0.5, 0)
		add_child(n)
		_sockets[s] = n


func get_socket(socket_name: StringName) -> Node3D:
	return _sockets.get(socket_name)


# --- Animation interface ------------------------------------------------------------------
func set_locomotion(ratio: float, new_state: StringName) -> void:
	speed_ratio = ratio
	if new_state != state:
		state = new_state
		if not is_placeholder and _action == &"":
			_play_clip(state)


## One-shot action (attack, hit, dodge, die...). Placeholders animate
## procedurally; final models play the mapped clip.
func play_action(action: StringName, duration: float = 0.4) -> void:
	_action = action
	_action_t = 0.0
	_action_len = maxf(duration, 0.01)
	if not is_placeholder:
		_play_clip(action)


func set_flash(amount: float, color: Color = Color.WHITE) -> void:
	_flash = amount
	for g in _geoms:
		if is_instance_valid(g):
			g.set_instance_shader_parameter(&"flash", amount)
			g.set_instance_shader_parameter(&"flash_color", color)


func _play_clip(logical: StringName) -> void:
	if _anim == null:
		return
	var clip: String = type.anim_map.get(String(logical), String(logical))
	if _anim.has_animation(clip):
		_anim.play(clip, 0.15)


func _process(delta: float) -> void:
	if _action != &"":
		_action_t += delta
		if _action_t >= _action_len and _action != &"die":
			_action = &""
			if not is_placeholder:
				_play_clip(state)
	if is_placeholder:
		_animate_placeholder(delta)


## Procedural pose animation for the mannequin placeholders. Enough to read
## gameplay (facing, stride, windup, recoil); never a substitute for final art.
func _animate_placeholder(delta: float) -> void:
	var rig: Node3D = _parts.get(&"rig")
	if rig == null:
		return
	_phase += delta * (4.0 + speed_ratio * 7.0)
	var swing := sin(_phase) * clampf(speed_ratio, 0.0, 1.2)
	var t := _action_t / _action_len if _action != &"" else 0.0
	var arm_l: Node3D = _parts.get(&"arm_l")
	var arm_r: Node3D = _parts.get(&"arm_r")
	var leg_l: Node3D = _parts.get(&"leg_l")
	var leg_r: Node3D = _parts.get(&"leg_r")
	var torso: Node3D = _parts.get(&"torso")
	rig.rotation = Vector3.ZERO
	rig.position = Vector3.ZERO
	if torso:
		torso.rotation = Vector3.ZERO

	if type.placeholder_shape == &"quadruped":
		for i in 4:
			var leg: Node3D = _parts.get(StringName("leg_%d" % i))
			if leg:
				leg.rotation.x = sin(_phase + (PI if i % 3 == 0 else 0.0)) * 0.7 * clampf(speed_ratio, 0.0, 1.0)
		rig.position.y = absf(sin(_phase)) * 0.06 * speed_ratio
		if _action in [&"attack", &"attack_1", &"attack_2", &"lunge"]:
			rig.rotation.x = -sin(t * PI) * 0.35
	elif type.placeholder_shape == &"blob" or type.placeholder_shape == &"orb":
		var k := 1.0 + sin(_phase * 0.7) * 0.04
		rig.scale = Vector3(1.0 / k, k, 1.0 / k)
		if type.flying:
			rig.position.y = sin(_phase * 0.4) * 0.15
		if _action != &"":
			var s := 1.0 + sin(t * PI) * 0.25
			rig.scale = Vector3(s, 1.0 / s, s)
	else:
		# Humanoid
		if leg_l and leg_r:
			leg_l.rotation.x = swing * 0.8
			leg_r.rotation.x = -swing * 0.8
		if arm_l and arm_r:
			arm_l.rotation = Vector3(-swing * 0.6, 0, -0.04)
			arm_r.rotation = Vector3(swing * 0.6, 0, 0.04)
		rig.position.y = absf(sin(_phase)) * 0.05 * speed_ratio
		match state:
			&"climb", &"climb_idle":
				var c := sin(_phase * 0.8) if state == &"climb" else 0.0
				arm_l.rotation = Vector3(PI * 0.9 + c * 0.3, 0, 0)
				arm_r.rotation = Vector3(PI * 0.9 - c * 0.3, 0, 0)
				leg_l.rotation.x = -0.4 + c * 0.4
				leg_r.rotation.x = -0.4 - c * 0.4
			&"glide":
				arm_l.rotation = Vector3(PI, 0, 0.25)
				arm_r.rotation = Vector3(PI, 0, -0.25)
				leg_l.rotation.x = 0.25
				leg_r.rotation.x = 0.15
			&"swim":
				rig.rotation.x = -1.2
				rig.position.y = 0.6
				arm_l.rotation.x = PI * 0.5 + sin(_phase) * 1.2
				arm_r.rotation.x = PI * 0.5 - sin(_phase) * 1.2
			&"fall", &"jump":
				arm_l.rotation = Vector3(-0.6, 0, -0.6)
				arm_r.rotation = Vector3(-0.6, 0, 0.6)
				leg_l.rotation.x = -0.5
				leg_r.rotation.x = 0.2
			&"block":
				arm_r.rotation = Vector3(-1.4, 0.5, 0)
				arm_l.rotation = Vector3(-1.3, -0.5, 0)
		match _action:
			&"attack_1", &"attack", &"lunge":
				arm_r.rotation = Vector3(lerpf(-2.6, 0.9, _ease_strike(t)), 0, lerpf(0.4, -0.3, t))
				if torso:
					torso.rotation.y = lerpf(0.5, -0.4, _ease_strike(t))
			&"attack_2":
				arm_r.rotation = Vector3(-1.5, 0, lerpf(1.6, -1.2, _ease_strike(t)))
				if torso:
					torso.rotation.y = lerpf(-0.6, 0.6, _ease_strike(t))
			&"attack_3", &"slam":
				arm_r.rotation = Vector3(lerpf(-3.0, 0.4, _ease_strike(t)), 0, 0)
				arm_l.rotation = Vector3(lerpf(-3.0, 0.4, _ease_strike(t)), 0, 0)
				rig.rotation.x = lerpf(0.15, -0.25, t)
			&"windup":
				arm_r.rotation = Vector3(-2.4 * sin(t * PI * 0.5), 0, 0.3)
				if torso:
					torso.rotation.y = 0.4 * t
			&"charge":
				arm_r.rotation = Vector3(-1.0, 0, 1.4)
				if torso:
					torso.rotation.y = 0.9
			&"spin":
				rig.rotation.y = t * TAU
				arm_r.rotation = Vector3(-1.5, 0, 1.4)
			&"thrust":
				arm_r.rotation = Vector3(-1.5, 0, 0)
				rig.rotation.x = -0.15
			&"dodge":
				rig.rotation.x = -t * TAU
				rig.position.y = 0.5 * sin(t * PI) * 0.6
			&"hit":
				rig.rotation.x = sin(t * PI) * 0.35
			&"die":
				rig.rotation.x = lerpf(0.0, PI * 0.5, minf(t * 1.6, 1.0))
				rig.position.y = lerpf(0.0, type.collider_radius * 0.8, minf(t * 1.6, 1.0))
			&"interact", &"gather":
				arm_r.rotation.x = -0.9 * sin(t * PI)
				if torso:
					torso.rotation.x = -0.35 * sin(t * PI)
			&"throw":
				arm_r.rotation = Vector3(lerpf(-2.8, 0.8, t), 0, 0)
			&"eat":
				arm_r.rotation = Vector3(-2.0 * sin(t * PI), 0, -0.6)
	if _action == &"die":
		rig.rotation.x = lerpf(0.0, PI * 0.5, minf(t * 1.6, 1.0))


func _ease_strike(t: float) -> float:
	# Anticipation, then snap: most of the motion happens in the middle third.
	return smoothstep(0.25, 0.55, t)


func is_dead_pose() -> bool:
	return _action == &"die"
