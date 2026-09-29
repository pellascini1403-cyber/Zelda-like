class_name WeatherFX
extends Node3D
## Rain / snow particles around the camera, lightning bolts, ambience levels.
## Particle budgets come from Quality; emitters follow the camera so the cost
## is constant no matter how big the world is.

var rain: GPUParticles3D
var snow: GPUParticles3D
var _flash: OmniLight3D
var _flash_t := 0.0
var _gen: WorldGen


func _ready() -> void:
	_gen = WorldGen.from_world_data(DB.world)
	rain = _make_precip(false)
	snow = _make_precip(true)
	add_child(rain)
	add_child(snow)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.85, 0.9, 1.0)
	_flash.omni_range = 120.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	add_child(_flash)
	EventBus.lightning_strike.connect(_on_lightning)
	EventBus.quality_changed.connect(func(_l: int) -> void:
		rain.amount = Quality.particle_amount(1600)
		snow.amount = Quality.particle_amount(900))


func _make_precip(is_snow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = Quality.particle_amount(900 if is_snow else 1600)
	p.lifetime = 2.2 if is_snow else 0.9
	p.visibility_aabb = AABB(Vector3(-22, -20, -22), Vector3(44, 40, 44))
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 1, 20)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 4.0 if not is_snow else 25.0
	pm.initial_velocity_min = 2.0 if is_snow else 24.0
	pm.initial_velocity_max = 3.0 if is_snow else 30.0
	pm.gravity = Vector3(0, -1.0 if is_snow else -9.8, 0)
	if is_snow:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06) if is_snow else Vector2(0.015, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if is_snow else BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(1, 1, 1, 0.9) if is_snow else Color(0.75, 0.8, 0.9, 0.45)
	quad.material = m
	p.draw_pass_1 = quad
	return p


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var above := c + Vector3(0, 16, 0) + Weather.wind * Weather.wind_strength * 4.0
	var cold := c.y > _gen.snow_line() - 30.0 or Weather.snow > 0.3
	rain.global_position = above
	snow.global_position = above
	rain.emitting = Weather.rain > 0.08 and not cold
	snow.emitting = Weather.rain > 0.08 and cold
	rain.amount_ratio = clampf(Weather.rain, 0.05, 1.0)
	snow.amount_ratio = clampf(Weather.rain, 0.05, 1.0)
	var wind := Weather.wind * Weather.wind_strength
	(rain.process_material as ParticleProcessMaterial).gravity = Vector3(wind.x * 6.0, -9.8, wind.z * 6.0)
	(snow.process_material as ParticleProcessMaterial).gravity = Vector3(wind.x * 3.0, -1.0, wind.z * 3.0)

	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.light_energy = maxf(_flash_t, 0.0) * 30.0 * (0.6 + randf() * 0.4)

	# Ambience mix
	var daylight := Clock.daylight()
	Audio.set_ambience({
		&"amb_wind": clampf(0.25 + Weather.wind_strength * 0.8 + maxf(c.y - 80.0, 0.0) / 150.0, 0.0, 1.0),
		&"amb_rain": Weather.rain if not cold else 0.0,
		&"amb_day": daylight * (1.0 - Weather.rain) * 0.7,
		&"amb_night": (1.0 - daylight) * (1.0 - Weather.rain) * 0.6,
	}, delta)


func _on_lightning(pos: Vector3) -> void:
	var ground_y := _gen.height(pos.x, pos.z)
	var bottom := Vector3(pos.x, ground_y, pos.z)
	_bolt(bottom)
	_flash.global_position = bottom + Vector3.UP * 30.0
	_flash_t = 0.25
	Audio.play_at(&"thunder", bottom, 6.0, 0.15)
	var parent := get_parent()
	var info := DamageInfo.make(40.0, null, Vector3.UP * 6.0, &"electric")
	info.kind = &"environment"
	info.blockable = false
	for body in CombatUtils.sphere_query(get_world_3d(), bottom + Vector3.UP, 3.5, CombatUtils.CREATURE_MASK | CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
		CombatUtils.deal(body, info)
	if Weather.rain < 0.6:
		FireSource.ignite_at(parent, bottom, 6.0)
	EventBus.noise_emitted.emit(bottom, 60.0, null)
	if Game.camera_rig and Game.player:
		Game.camera_rig.add_trauma(clampf(1.0 - Game.player.global_position.distance_to(bottom) / 60.0, 0.1, 0.7))


func _bolt(bottom: Vector3) -> void:
	var b := MeshKit.Builder.new()
	var p := bottom + Vector3(0, 120, 0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var segs := 12
	for i in segs:
		var next := p.lerp(bottom, 1.0 / (segs - i)) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)) * (1.0 if i < segs - 1 else 0.0)
		var side := Vector3(0.35, 0, 0)
		b.quad(p - side, p + side, next + side, next - side, Color.WHITE)
		b.quad(p + side, p - side, next - side, next + side, Color.WHITE)
		var side2 := Vector3(0, 0, 0.35)
		b.quad(p - side2, p + side2, next + side2, next - side2, Color.WHITE)
		b.quad(p + side2, p - side2, next - side2, next + side2, Color.WHITE)
		p = next
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 0.95, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.8, 0.9, 1.0)
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var t := mi.create_tween()
	t.tween_interval(0.12)
	t.tween_callback(mi.queue_free)
