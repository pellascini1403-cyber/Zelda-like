class_name FireSource
extends Node3D
## A burning spot. Systemic rules (see data/elements.json):
##  * damages & ignites creatures and flammable props inside its radius
##  * spreads over dry grass (not when wet / raining), bounded by a global cap
##  * creates a thermal: gliders gain lift above it
##  * rain and water put it out
## Campfires are permanent FireSources (lifetime < 0) that never spread.

const MAX_ACTIVE := 18
const MAX_LIGHTS := 4

static var active_count := 0
static var light_count := 0

var lifetime := 8.0
var radius := 1.6
var spreads := true
var generation := 0
var permanent := false

var _tick := 0.0
var _spread_timer := 1.4
var _particles: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _gen: WorldGen


static func ignite_at(parent: Node, pos: Vector3, life: float = 8.0, gen: int = 0) -> FireSource:
	if active_count >= MAX_ACTIVE or parent == null:
		return null
	if Weather.rain > 0.5:
		return null
	var f := FireSource.new()
	f.lifetime = life
	f.generation = gen
	parent.add_child(f)
	f.global_position = pos
	return f


func _ready() -> void:
	add_to_group(&"updraft")
	add_to_group(&"heat_source")
	active_count += 1
	_gen = WorldGen.from_world_data(DB.world)
	_particles = _flames()
	add_child(_particles)
	_smoke = _smoke_fx()
	add_child(_smoke)
	if light_count < mini(MAX_LIGHTS, Quality.current()["max_dynamic_lights"]):
		light_count += 1
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.6, 0.3)
		_light.light_energy = 2.2
		_light.omni_range = 7.0
		_light.shadow_enabled = false
		_light.position.y = 0.8
		add_child(_light)
	Audio.play_at(&"ignite", global_position, -2.0)


func _exit_tree() -> void:
	active_count = maxi(active_count - 1, 0)
	if _light:
		light_count = maxi(light_count - 1, 0)


func _physics_process(delta: float) -> void:
	if _light:
		_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.02) * 0.35 + randf() * 0.2
	if not permanent:
		lifetime -= delta * (1.0 + Weather.rain * 6.0)
		if lifetime <= 0.0 or global_position.y < WorldGen.SEA_LEVEL:
			_extinguish()
			return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.35
		_burn_neighbours()
	if spreads and not permanent:
		_spread_timer -= delta
		if _spread_timer <= 0.0:
			_spread_timer = randf_range(1.0, 1.8)
			_try_spread()


func _burn_neighbours() -> void:
	for body in CombatUtils.sphere_query(get_world_3d(), global_position + Vector3.UP * 0.5, radius, CombatUtils.CREATURE_MASK | CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
		if body.has_method("ignite"):
			body.ignite()
		else:
			var info := DamageInfo.make(2.0, null, Vector3.ZERO, &"fire")
			info.kind = &"environment"
			info.poise_damage = 0.0
			CombatUtils.deal(body, info)


func _try_spread() -> void:
	if generation >= 4 or Weather.wetness > 0.3:
		return
	var a := randf() * TAU
	var p := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.2, 3.5)
	var h := _gen.height(p.x, p.z)
	var n := _gen.normal(p.x, p.z)
	if _gen.surface_at(p.x, p.z, h, n) in [WorldGen.Surface.GRASS, WorldGen.Surface.FOREST_FLOOR]:
		ignite_at(get_parent(), Vector3(p.x, h, p.z), randf_range(5.0, 9.0), generation + 1)


## Thermal lift for the glider: strong directly above, fades with height.
func lift_at(pos: Vector3) -> float:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	var h := pos.y - global_position.y
	if d > 3.5 or h < 0.0 or h > 35.0:
		return 0.0
	return 9.0 * (1.0 - d / 3.5) * (1.0 - h / 35.0)


func _extinguish() -> void:
	Effects.dust(self, global_position, 0.5)
	queue_free()


func _flames() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = Quality.particle_amount(26)
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, 2.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
	g.add_point(0.45, Color(1.0, 0.4, 0.1, 0.9))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.1, 0.05, 0.0))
	p.color_ramp = g
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	return p


func _smoke_fx() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = Quality.particle_amount(10)
	p.lifetime = 2.5
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.8, 0)
	p.position.y = 1.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 7.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = m
	p.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.33, 0.32, 0.0))
	g.add_point(0.2, Color(0.35, 0.33, 0.32, 0.35))
	g.set_color(g.get_point_count() - 1, Color(0.5, 0.5, 0.5, 0.0))
	p.color_ramp = g
	return p
