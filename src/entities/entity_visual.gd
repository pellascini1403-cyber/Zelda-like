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

## Every logical animation the gameplay layer can request. A final model
## maps these to its clips through EntityType.anim_map (missing entries fall
## back along FALLBACK, so a model with only idle/run/attack still works).
const LOGICAL := [
	&"idle", &"walk", &"run", &"sprint", &"move", &"jump", &"fall", &"land",
	&"climb", &"climb_idle", &"ledge_climb", &"glide", &"swim", &"dodge",
	&"attack_1", &"attack_2", &"attack_3", &"attack", &"charge", &"spin", &"thrust", &"slam", &"lunge", &"windup",
	&"block", &"parry", &"hit", &"die", &"interact", &"gather", &"throw", &"eat", &"ride", &"roar",
]
const FALLBACK := {
	&"sprint": &"run", &"run": &"move", &"walk": &"move", &"move": &"idle",
	&"attack_1": &"attack", &"attack_2": &"attack", &"attack_3": &"attack", &"lunge": &"attack", &"slam": &"attack",
	&"spin": &"attack", &"thrust": &"attack", &"charge": &"windup", &"windup": &"idle", &"land": &"idle",
	&"ledge_climb": &"climb", &"climb_idle": &"climb", &"parry": &"block", &"gather": &"interact", &"eat": &"interact",
	&"throw": &"attack", &"ride": &"idle", &"roar": &"windup", &"fall": &"jump",
}

var type: EntityType
var is_placeholder := true
var state: StringName = &"idle"
var speed_ratio := 0.0

var _model: Node3D
var _anim: AnimationPlayer
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _land_t := 0.0
var _prev_yaw := 0.0
var _lean := 0.0
var _parts: Dictionary = {}          # placeholder limbs by name
var _sockets: Dictionary = {}
var _geoms: Array[GeometryInstance3D] = []
var _phase := 0.0
var _action: StringName = &""
var _action_t := 0.0
var _action_len := 0.0
var _flash := 0.0
var _flash_overlay: ShaderMaterial
## Placeholder rig description, filled by the builders (MannequinBuilder,
## CreatureBuilder): how the procedural animation should move it.
var rig_kind: StringName = &"biped"   # biped | legged | float | serpent
var legs: Array[Node3D] = []
var wings: Array[Node3D] = []
var sway_parts: Array[Node3D] = []   # tails, capes, scarves, serpent segments
var spin_parts: Array[Node3D] = []
var torso_pitch := 0.0               # hunch (elders, brutes)
var rest_scale := Vector3.ONE

static var _materials: Dictionary = {}


func setup(entity_type: EntityType) -> void:
	type = entity_type
	for c in get_children():
		c.queue_free()
	_parts.clear()
	_sockets.clear()
	_springs.clear()
	_skeleton = null
	_geoms.clear()
	legs.clear()
	wings.clear()
	sway_parts.clear()
	spin_parts.clear()
	torso_pitch = 0.0
	rest_scale = Vector3.ONE
	if type.model != "" and ResourceLoader.exists(type.model):
		_build_model()
	else:
		_build_placeholder()


# --- Final model path ------------------------------------------------------------------
## Real rigged characters (docs/CHARACTER_PIPELINE.md). Gameplay never
## changes: the collider, AI and combat stay on the parent body.
func _build_model() -> void:
	is_placeholder = false
	var scene: PackedScene = load(type.model)
	_model = scene.instantiate()
	var opts := type.model_options
	var s := CharacterModel.fit_scale(_model, type.collider_height) if opts.get("fit_height", false) else type.model_scale
	_model.scale = Vector3.ONE * s * float(type.visual.get("scale", 1.0))
	_model.position = type.model_offset
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	# Optional AnimationTree with a state machine: logical states travel to
	# nodes of the same (mapped) name; "parameters/speed" gets speed_ratio.
	_tree = _model.find_child("AnimationTree", true, false)
	if _tree:
		_tree.active = true
		var pb: Variant = _tree.get("parameters/playback")
		if pb is AnimationNodeStateMachinePlayback:
			_playback = pb
	for n in _model.find_children("*", "Node3D", true, false):
		if n.name.begins_with("socket_"):
			_sockets[StringName(n.name.trim_prefix("socket_"))] = n
	# Variants of one model per NPC: outfit/hair/headwear/accessory meshes
	# picked by the visual profile, optional palette on tintable slots.
	CharacterModel.apply_variant(_model, type.visual)
	CharacterModel.apply_palette(_model, opts.get("palette", {}))
	_skeleton = CharacterModel.find_skeleton(_model)
	if _skeleton:
		_sockets.merge(CharacterModel.bind_sockets(_skeleton, _sockets))
		_springs = CharacterModel.add_springs(_skeleton, opts)
	for g in _model.find_children("*", "GeometryInstance3D", true, false):
		_geoms.append(g)
		(g as GeometryInstance3D).visibility_range_end = BODY_VISIBLE_RANGE * maxf(1.0, type.collider_height / 2.0)
	# Sockets the model does not define fall back to sensible defaults.
	_ensure_default_sockets()
	if _anim:
		_play_clip(state)


## Distance LOD for real models: far characters stop evaluating animation and
## secondary motion (the skeleton keeps its last pose), near ones run both.
const MODEL_ANIM_RANGE := 70.0
const MODEL_SPRING_RANGE := 22.0
var _skeleton: Skeleton3D
var _springs: Array[SpringBoneChain] = []
var _lod_t := 0.0


func _update_model_lod(delta: float) -> void:
	_lod_t -= delta
	if _lod_t > 0.0:
		return
	_lod_t = 0.25
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var d := global_position.distance_to(cam.global_position) if cam else 0.0
	var near_anim := d < MODEL_ANIM_RANGE * maxf(1.0, type.collider_height / 2.0)
	if _anim:
		_anim.active = near_anim
	if _tree:
		_tree.active = near_anim
	var springs_on := d < MODEL_SPRING_RANGE and Quality.level >= 1   # MEDIUM and up
	for sp in _springs:
		if sp.active != springs_on:
			sp.active = springs_on
			sp.reset()


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


## Placeholders follow the character art direction (docs/CHARACTER_STYLE_GUIDE.md):
## the family in data/visuals.json picks the builder, the gameplay collider
## gives the size. Entities without a profile keep the plain mannequins.
func _build_placeholder() -> void:
	is_placeholder = true
	var h := type.collider_height
	var r := type.collider_radius
	match String(type.visual.get("family", "")):
		"human":
			rig_kind = &"biped"
			MannequinBuilder.build(self, h, r)   # PLACEHOLDER — final design pending
			_ensure_default_sockets()
			return
		"enemy":
			CreatureBuilder.build_enemy(self, h, r)
			_ensure_default_sockets()
			return
		"wildlife":
			CreatureBuilder.build_wildlife(self, h, r)
			_ensure_default_sockets()
			return
	var mat := placeholder_material(type.placeholder_color)
	rig_kind = &"legged" if type.placeholder_shape == &"quadruped" else (&"float" if type.placeholder_shape in [&"blob", &"orb"] else &"biped")
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
	mi.visibility_range_end = BODY_VISIBLE_RANGE if is_body else limb_range()
	if not is_body:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if type.kind != EntityType.Kind.PLAYER else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(mi)
	_parts[StringName(part_name)] = pivot
	_geoms.append(mi)
	return pivot


## Limb/detail LOD grows with the creature: a boss's horns stay visible.
func limb_range() -> float:
	return LIMB_VISIBLE_RANGE * maxf(1.0, type.collider_height / 2.0)


func add_rig() -> Node3D:
	var root := Node3D.new()
	root.name = "Rig"
	add_child(root)
	_parts[&"rig"] = root
	return root


func part(part_name: StringName) -> Node3D:
	return _parts.get(part_name)


func set_socket(socket_name: StringName, n: Node3D) -> void:
	_sockets[socket_name] = n


## Static detail mesh (hair, hats, spikes, eyes...). Joins the flash list;
## `glow` details skip shadows and stay visible as far as the body.
func deco(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = BODY_VISIBLE_RANGE * 0.5 if glow else limb_range()
	parent.add_child(mi)
	_geoms.append(mi)
	return mi


## Pivot that swings with motion (tails, capes, scarves, segments).
func sway_part(parent: Node3D, part_name: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = part_name
	p.position = pos
	parent.add_child(p)
	_parts[StringName(part_name)] = p
	sway_parts.append(p)
	return p


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
	_flash_overlay = FlashOverlay.apply(_geoms, _flash_overlay, amount, color)


## 0 = solid, 1 = gone (phasing creatures, things under water).
func set_fade(amount: float) -> void:
	for g in _geoms:
		if is_instance_valid(g):
			g.transparency = clampf(amount, 0.0, 1.0)
	visible = amount < 0.99


func _play_clip(logical: StringName) -> void:
	var clip := resolve_clip(logical)
	if clip == "":
		return
	if _playback:
		_playback.travel(StringName(clip))
	elif _anim:
		_anim.play(clip, 0.15)


## Mapped clip name for a logical state, following FALLBACK until the model
## has something to play ("" when nothing matches).
func resolve_clip(logical: StringName) -> String:
	var l := logical
	for i in 6:
		var clip: String = type.anim_map.get(String(l), String(l))
		if _has_clip(clip):
			return clip
		if not FALLBACK.has(l):
			break
		l = FALLBACK[l]
	return ""


func _has_clip(clip: String) -> bool:
	if _playback and _tree and _tree.tree_root is AnimationNodeStateMachine:
		return (_tree.tree_root as AnimationNodeStateMachine).has_node(StringName(clip))
	return _anim != null and _anim.has_animation(clip)


func _process(delta: float) -> void:
	if _action != &"":
		_action_t += delta
		if _action_t >= _action_len and _action != &"die":
			_action = &""
			if not is_placeholder:
				_play_clip(state)
	if _tree and _tree.get("parameters/speed") != null:
		_tree.set("parameters/speed", speed_ratio)
	if is_placeholder:
		_animate_placeholder(delta)
	else:
		_update_model_lod(delta)


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
	rig.scale = rest_scale
	if torso:
		torso.rotation = Vector3(torso_pitch, 0, 0)
		# Breathing (idle life) and forward lean with speed.
		torso.scale = Vector3(1.0, 1.0 + sin(Time.get_ticks_msec() * 0.0025) * 0.012, 1.0)
	# Lean into turns: yaw rate of the whole visual, smoothed.
	var yaw := global_rotation.y
	var yaw_rate := wrapf(yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.001)
	_prev_yaw = yaw
	_lean = lerpf(_lean, clampf(-yaw_rate * 0.05 * speed_ratio, -0.3, 0.3), minf(delta * 8.0, 1.0))

	_animate_extras(delta, t)
	if rig_kind == &"legged" or rig_kind == &"serpent":
		if legs.is_empty():
			for i in 4:
				var lg: Node3D = _parts.get(StringName("leg_%d" % i))
				if lg:
					legs.append(lg)
		for i in legs.size():
			# Diagonal pairs move together (trot); crawlers ripple front to back.
			var ph := _phase + (PI if (i % 2 == 0) != ((i / 2) % 2 == 0) else 0.0) + (i / 2) * 0.6 * float(legs.size() > 4)
			legs[i].rotation.x = sin(ph) * 0.7 * clampf(speed_ratio, 0.0, 1.0)
		rig.position.y = absf(sin(_phase)) * 0.06 * speed_ratio
		if _action in [&"attack", &"attack_1", &"attack_2", &"lunge", &"slam", &"thrust"]:
			rig.rotation.x = -sin(t * PI) * 0.35
			for s in [&"arm_l", &"arm_r"]:
				var pincer: Node3D = _parts.get(s)
				if pincer:
					pincer.rotation.y = (0.6 if s == &"arm_l" else -0.6) * sin(t * PI)
		elif _action in [&"windup", &"charge", &"roar"]:
			rig.rotation.x = 0.18 * sin(minf(t, 1.0) * PI * 0.5)
	elif rig_kind == &"float":
		var k := 1.0 + sin(_phase * 0.7) * 0.04
		rig.scale = Vector3(rest_scale.x / k, rest_scale.y * k, rest_scale.z / k)
		if type.flying:
			rig.position.y = sin(_phase * 0.4) * 0.15
		if _action != &"":
			var s := 1.0 + sin(t * PI) * 0.25
			rig.scale = Vector3(s, 1.0 / s, s) * rest_scale
	else:
		# Humanoid
		if leg_l and leg_r:
			leg_l.rotation.x = swing * 0.8
			leg_r.rotation.x = -swing * 0.8
		if arm_l and arm_r:
			arm_l.rotation = Vector3(-swing * 0.6, 0, -0.04)
			arm_r.rotation = Vector3(swing * 0.6, 0, 0.04)
		rig.position.y = absf(sin(_phase)) * 0.05 * speed_ratio
		rig.rotation.x = -0.12 * clampf(speed_ratio, 0.0, 1.3)
		rig.rotation.z = _lean
		# Two-segment limbs (MannequinBuilder): knees bend as the leg swings
		# back and lifts, elbows stay soft and bend more when running.
		var sp := clampf(speed_ratio, 0.0, 1.3)
		for k in 2:
			var shin_n: Node3D = _parts.get(&"shin_l" if k == 0 else &"shin_r")
			if shin_n:
				var ph := _phase + (0.0 if k == 0 else PI)
				shin_n.rotation.x = 0.06 + maxf(sin(ph - 0.6), 0.0) * 1.1 * sp
				match state:
					&"fall", &"jump": shin_n.rotation.x = 0.9 if k == 0 else 0.35
					&"ride": shin_n.rotation.x = 1.5
					&"climb", &"climb_idle": shin_n.rotation.x = 0.7
					&"swim": shin_n.rotation.x = 0.2 + maxf(sin(ph), 0.0) * 0.5
			var fore_n: Node3D = _parts.get(&"forearm_l" if k == 0 else &"forearm_r")
			if fore_n:
				fore_n.rotation = Vector3(-0.18 - 0.75 * sp, 0, 0)
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
			&"ride":
				rig.rotation = Vector3(-0.15, 0, 0)
				leg_l.rotation = Vector3(-1.2, 0, -0.5)
				leg_r.rotation = Vector3(-1.2, 0, 0.5)
				arm_l.rotation = Vector3(-0.9 + sin(_phase) * 0.1, 0, -0.1)
				arm_r.rotation = Vector3(-0.9 - sin(_phase) * 0.1, 0, 0.1)
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
			&"land":
				# Squash on impact, knees bend, arms balance.
				var sq := sin(t * PI) * 0.18
				rig.scale = Vector3(1.0 + sq * 0.6, 1.0 - sq, 1.0 + sq * 0.6)
				leg_l.rotation.x = -0.6 * sin(t * PI)
				leg_r.rotation.x = -0.6 * sin(t * PI)
				arm_l.rotation.z = -0.7 * sin(t * PI)
				arm_r.rotation.z = 0.7 * sin(t * PI)
			&"ledge_climb":
				arm_l.rotation = Vector3(lerpf(PI * 0.9, 0.3, t), 0, 0)
				arm_r.rotation = Vector3(lerpf(PI * 0.9, 0.3, t), 0, 0)
				leg_l.rotation.x = -1.2 * sin(t * PI)
				rig.rotation.x = -0.3 * sin(t * PI)
			&"parry":
				arm_r.rotation = Vector3(-1.6, lerpf(0.8, -0.6, _ease_strike(t)), 0)
				arm_l.rotation = Vector3(-0.6, 0, -0.8)
				if torso:
					torso.rotation.y = lerpf(0.4, -0.3, t)
			&"roar":
				rig.rotation.x = -0.35 * sin(t * PI)
				arm_l.rotation = Vector3(-1.0, 0, -1.2 * sin(t * PI))
				arm_r.rotation = Vector3(-1.0, 0, 1.2 * sin(t * PI))
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


## Secondary motion shared by every rig: tails/capes swing, wings flap,
## orbiting shards spin. Cheap (a few rotations), makes placeholders alive.
func _animate_extras(delta: float, t: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for i in sway_parts.size():
		var p := sway_parts[i]
		var amp := 0.12 + clampf(speed_ratio, 0.0, 1.2) * 0.25
		if rig_kind == &"serpent":
			p.rotation.y = sin(now * 3.0 + _phase * 0.5 - i * 0.7) * (0.25 + speed_ratio * 0.2)
		else:
			p.rotation.x = 0.15 * clampf(speed_ratio, 0.0, 1.0) + sin(now * 2.2 + i) * amp * 0.5
			p.rotation.z = sin(now * 1.7 + i * 1.3) * amp * 0.4
	for w in wings:
		var side := -1.0 if w.name.ends_with("l") else 1.0
		var flap := sin(now * (7.0 if type.flying else 2.0)) * (0.5 if type.flying else 0.12)
		if _action != &"":
			flap += sin(t * PI) * 0.6
		w.rotation.z = side * flap
	for sp in spin_parts:
		sp.rotation.y += delta * (1.4 + (4.0 if _action != &"" else 0.0))


func _ease_strike(t: float) -> float:
	# Anticipation, then snap: most of the motion happens in the middle third.
	return smoothstep(0.25, 0.55, t)


func is_dead_pose() -> bool:
	return _action == &"die"
