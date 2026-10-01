class_name Spout
extends Node3D
## A sea spout: a rock blowhole under the surface that breathes. Bubbles
## rise and boil for a moment (the warning), then it bursts: a swimmer in
## its eye is thrown clear of the water — open the sail and the wind over
## the rock carries you up. Faster and higher in storms.

const LAUNCH := 24.0

var radius := 2.6
var period := 7.0
var _t := 0.0
var _boil: CPUParticles3D
var _jet: CPUParticles3D


static func create(r: float, every: float) -> Spout:
	var s := Spout.new()
	s.radius = r
	s.period = every
	return s


func _ready() -> void:
	add_to_group(&"spouts")
	_boil = _particles(18, 1.2, Vector2(0.5, 0.5), radius * 0.8, 1.5)
	_jet = _particles(40, 1.3, Vector2(1.2, 1.2), radius * 0.5, 16.0)
	_jet.emitting = false
	_jet.one_shot = true
	_t = randf() * period


func _particles(n: int, life: float, size: Vector2, spread_r: float, up: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = Quality.particle_amount(n)
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread_r
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = up * 0.7
	p.initial_velocity_max = up
	p.gravity = Vector3(0, -9.0, 0)
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FireSource._dot()
	m.albedo_color = Color(0.95, 1.0, 1.0, 0.7)
	q.material = m
	p.mesh = q
	p.position.y = 0.1
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 26, 12))
	add_child(p)
	return p


func cycle() -> float:
	return period * (0.6 if Weather.storm > 0.4 else 1.0)


## Seconds until the next burst (bubbles boil in the last 1.5 s).
func time_left() -> float:
	return maxf(cycle() - _t, 0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_boil.emitting = time_left() < 1.5
	if _t >= cycle():
		_t = 0.0
		burst()


func burst() -> void:
	_jet.restart()
	_jet.emitting = true
	Audio.play_at(&"splash", global_position, 2.0)
	var p := Game.player as Player
	if p == null:
		return
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if d > radius or p.global_position.y > WorldGen.SEA_LEVEL + 2.0:
		return
	var up := LAUNCH * (1.15 if Weather.storm > 0.4 else 1.0)
	p.global_position.y = maxf(p.global_position.y, WorldGen.SEA_LEVEL + 0.3)
	p.velocity = Vector3(p.velocity.x * 0.3, up, p.velocity.z * 0.3)
	p.change_state(&"air")
	EventBus.toast.emit(tr("HINT_SPOUT"))
