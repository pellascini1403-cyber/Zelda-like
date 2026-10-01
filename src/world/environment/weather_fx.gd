class_name WeatherFX
extends Node3D
## Rain / snow / sand particles around the camera, ambient life (fireflies at
## night, drifting motes by day, Veil sparks), lightning bolts, ambience.
## Particle budgets come from Quality; emitters follow the camera so the cost
## is constant no matter how big the world is.

var rain: GPUParticles3D
var snow: GPUParticles3D
var sandstorm: GPUParticles3D
var fireflies: GPUParticles3D
var motes: GPUParticles3D
var veil_sparks: GPUParticles3D
## Sparse drifting leaves under trees and petals in blossom groves (day,
## dry weather): a handful at a time, tumbling slowly on the wind.
var leaves: GPUParticles3D
var petals: GPUParticles3D
var _flash: OmniLight3D
var _flash_t := 0.0
var _gen: WorldGen


func _ready() -> void:
	_gen = WorldGen.from_world_data(DB.world)
	rain = _make_precip(false)
	snow = _make_precip(true)
	add_child(rain)
	add_child(snow)
	sandstorm = _make_ambient(Color(0.9, 0.72, 0.48, 0.4), Vector2(1.8, 0.45), 700, 1.6, Vector3(14, 0.5, 0), false)
	fireflies = _make_ambient(Color(1.0, 0.92, 0.45, 1.0), Vector2(0.07, 0.07), 70, 5.0, Vector3(0.3, 0.2, 0.3), true)
	motes = _make_ambient(Color(1.0, 0.97, 0.85, 0.65), Vector2(0.04, 0.04), 60, 7.0, Vector3(0.4, 0.05, 0.2), true)
	veil_sparks = _make_ambient(Color(0.55, 1.0, 0.9, 1.0), Vector2(0.08, 0.08), 90, 4.0, Vector3(0.0, 0.8, 0.0), true)
	leaves = _make_falling([Color(0.55, 0.62, 0.26), Color(0.72, 0.6, 0.24), Color(0.42, 0.52, 0.22), Color(0.78, 0.48, 0.2)], 26)
	petals = _make_falling([Color(1.0, 0.82, 0.88), Color(0.98, 0.7, 0.8), Color(1.0, 0.94, 0.95)], 34)
	for p in [sandstorm, fireflies, motes, veil_sparks, leaves, petals]:
		add_child(p)
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


## Camera-following ambient layer (budget scaled by Quality).
func _make_ambient(col: Color, size: Vector2, amount: int, life: float, vel: Vector3, glow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = Quality.particle_amount(amount)
	p.lifetime = life
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-30, -15, -30), Vector3(60, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 5, 24)
	pm.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = vel.length() * 0.5
	pm.initial_velocity_max = vel.length() * 1.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(col, 0.0))
	fade.add_point(0.2, col)
	fade.add_point(0.8, col)
	fade.set_color(fade.get_point_count() - 1, Color(col, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(2.0, 2.0, 2.0)
	quad.material = m
	p.draw_pass_1 = quad
	return p


## Falling leaves / petals: tumbling quads, colour picked per particle.
func _make_falling(cols: Array, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = Quality.particle_amount(amount)
	p.lifetime = 9.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-24, -14, -24), Vector3(48, 24, 48))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 3, 18)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, -0.35, 0)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -160.0
	pm.angular_velocity_max = 160.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 2.5
	var g := Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[cols.size() - 1])
	for i in range(1, cols.size() - 1):
		g.add_point(float(i) / (cols.size() - 1), cols[i])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.1, Color.WHITE)
	fade.add_point(0.85, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.055)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	m.albedo_color = Color(0.85, 0.85, 0.85)
	quad.material = m
	p.draw_pass_1 = quad
	return p


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
	var ground := c + Vector3(0, -2, 0)
	for p in [sandstorm, fireflies, motes, veil_sparks]:
		p.global_position = ground
	leaves.global_position = c + Vector3(0, 5, 0)
	petals.global_position = c + Vector3(0, 4, 0)
	var region: StringName = (Game.player as Player).region if Game.player else &"valley"
	var dry := Weather.rain < 0.1
	sandstorm.emitting = Weather.sand > 0.2
	sandstorm.amount_ratio = clampf(Weather.sand, 0.05, 1.0)
	(sandstorm.process_material as ParticleProcessMaterial).direction = Vector3(Weather.wind.x, 0.05, Weather.wind.z)
	fireflies.emitting = Clock.is_night() and dry and region != &"desert" and region != &"highlands"
	motes.emitting = not Clock.is_night() and dry and Weather.sand < 0.1
	veil_sparks.emitting = region == &"veil"
	var calm_day := not Clock.is_night() and dry and Weather.sand < 0.1 and region != &"desert" and region != &"veil"
	leaves.emitting = calm_day and _gen.forest_density(c.x, c.z) > 0.3
	petals.emitting = calm_day and _gen.grove_mask(c.x, c.z) > 0.45 and _gen.forest_density(c.x, c.z) < 0.4
	var drift := Weather.wind * Weather.wind_strength
	for fp: GPUParticles3D in [leaves, petals]:
		(fp.process_material as ParticleProcessMaterial).gravity = Vector3(drift.x * 0.9, -0.35, drift.z * 0.9)
	rain.emitting = Weather.rain > 0.08 and not cold
	snow.emitting = Weather.rain > 0.08 and cold
	rain.amount_ratio = clampf(Weather.rain, 0.05, 1.0)
	snow.amount_ratio = clampf(Weather.rain, 0.05, 1.0)
	# Idle layers stop drawing once their last particles have faded
	# (an invisible GPUParticles3D still costs a draw call per pass).
	for p: GPUParticles3D in [rain, snow, sandstorm, fireflies, motes, veil_sparks, leaves, petals]:
		if p.emitting:
			p.visible = true
			p.set_meta(&"idle_t", 0.0)
		elif p.visible:
			var t: float = p.get_meta(&"idle_t", 0.0) + get_process_delta_time()
			p.set_meta(&"idle_t", t)
			if t > p.lifetime:
				p.visible = false
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


static var _dot: Texture2D


## Soft round sprite shared by every ambient particle layer (no hard quads).
static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot
