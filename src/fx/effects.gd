class_name Effects
extends RefCounted
## Pooled one-shot particle effects. Counts scale with Quality.particles.
## CPUParticles3D is used for small bursts: cheap at these counts and
## identical on Mobile and Compatibility renderers.

const POOL_SIZE := 10

static var _pools: Dictionary = {}   # kind -> Array[CPUParticles3D]
static var _root: Node3D
static var _idx: Dictionary = {}


static func _ensure_root(ctx: Node) -> bool:
	if _root != null and is_instance_valid(_root) and _root.is_inside_tree():
		return true
	if ctx == null or not ctx.is_inside_tree():
		return false
	_pools.clear()
	_idx.clear()
	_root = Node3D.new()
	_root.name = "EffectsPool"
	ctx.get_tree().current_scene.add_child(_root)
	return true


static func _take(ctx: Node, kind: StringName) -> CPUParticles3D:
	if not _ensure_root(ctx):
		return null
	if not _pools.has(kind):
		var arr: Array[CPUParticles3D] = []
		for i in POOL_SIZE:
			var p := _make(kind)
			_root.add_child(p)
			arr.append(p)
		_pools[kind] = arr
		_idx[kind] = 0
	var i: int = _idx[kind]
	_idx[kind] = (i + 1) % POOL_SIZE
	return _pools[kind][i]


static func _mat(c: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emissive else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _make(kind: StringName) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	p.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	match kind:
		&"spark":
			p.amount = Quality.particle_amount(18)
			p.lifetime = 0.35
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 9.0
			p.spread = 180.0
			p.gravity = Vector3(0, -12, 0)
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
			quad.material = _mat(Color(1.0, 0.85, 0.5), true)
		&"dust":
			p.amount = Quality.particle_amount(14)
			p.lifetime = 0.8
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.direction = Vector3.UP
			p.spread = 80.0
			p.gravity = Vector3(0, 0.5, 0)
			p.damping_min = 2.0
			p.damping_max = 3.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			quad.material = _mat(Color(0.75, 0.7, 0.6, 0.55), false)
		&"splash":
			p.amount = Quality.particle_amount(24)
			p.lifetime = 0.7
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 6.0
			p.direction = Vector3.UP
			p.spread = 35.0
			p.gravity = Vector3(0, -14, 0)
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
			quad.material = _mat(Color(0.85, 0.95, 1.0, 0.8), false)
		&"glow":
			p.amount = Quality.particle_amount(16)
			p.lifetime = 0.9
			p.explosiveness = 0.3
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			p.direction = Vector3.UP
			p.spread = 60.0
			p.gravity = Vector3(0, 1.5, 0)
			quad.material = _mat(Color(1, 1, 1), true)
		&"leaves":
			p.amount = Quality.particle_amount(12)
			p.lifetime = 1.4
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.spread = 120.0
			p.gravity = Vector3(0, -2.5, 0)
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.8
			quad.material = _mat(Color(0.45, 0.62, 0.25), false)
	return p


static func _fire(p: CPUParticles3D, pos: Vector3, color: Color = Color.WHITE) -> void:
	if p == null:
		return
	p.global_position = pos
	p.color = color
	p.restart()
	p.emitting = true


static func hit_spark(ctx: Node, pos: Vector3, critical: bool) -> void:
	_fire(_take(ctx, &"spark"), pos, Color(1.0, 0.55, 0.3) if critical else Color(1.0, 0.95, 0.8))


static func dust(ctx: Node, pos: Vector3, amount: float) -> void:
	var p := _take(ctx, &"dust")
	if p:
		p.scale_amount_max = 3.0 + amount * 2.0
	_fire(p, pos + Vector3.UP * 0.1)


static func splash(ctx: Node, pos: Vector3) -> void:
	_fire(_take(ctx, &"splash"), pos)


static func sparks(ctx: Node, pos: Vector3, color: Color, _duration: float) -> void:
	_fire(_take(ctx, &"glow"), pos, color)


static func leaves(ctx: Node, pos: Vector3) -> void:
	_fire(_take(ctx, &"leaves"), pos)
