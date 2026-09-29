class_name EnvironmentController
extends Node3D
## Presentation of time of day + weather. One directional light (sun by day,
## moon by night), one Environment, one sky material: everything global,
## updated once per frame — no per-light work.

var sun: DirectionalLight3D
var env: Environment
var world_env: WorldEnvironment
var sky_mat: ShaderMaterial

# Key colors through the day: [hour, sky_top, horizon, light color, light energy, ambient, fog]
const KEYS := [
	[0.0, Color(0.02, 0.04, 0.1), Color(0.07, 0.1, 0.18), Color(0.5, 0.6, 0.9), 0.18, Color(0.1, 0.13, 0.22), Color(0.07, 0.09, 0.16)],
	[5.0, Color(0.05, 0.08, 0.18), Color(0.2, 0.2, 0.3), Color(0.55, 0.6, 0.85), 0.15, Color(0.14, 0.16, 0.25), Color(0.18, 0.18, 0.26)],
	[6.3, Color(0.3, 0.42, 0.66), Color(0.98, 0.62, 0.42), Color(1.0, 0.62, 0.38), 0.7, Color(0.42, 0.36, 0.38), Color(0.85, 0.6, 0.48)],
	[8.0, Color(0.28, 0.5, 0.82), Color(0.74, 0.84, 0.92), Color(1.0, 0.9, 0.75), 1.25, Color(0.5, 0.56, 0.62), Color(0.7, 0.8, 0.9)],
	[13.0, Color(0.22, 0.46, 0.84), Color(0.7, 0.83, 0.94), Color(1.0, 0.97, 0.9), 1.45, Color(0.55, 0.6, 0.66), Color(0.68, 0.8, 0.92)],
	[17.3, Color(0.27, 0.46, 0.78), Color(0.84, 0.8, 0.72), Color(1.0, 0.82, 0.6), 1.1, Color(0.5, 0.5, 0.55), Color(0.8, 0.75, 0.7)],
	[18.9, Color(0.24, 0.26, 0.5), Color(1.0, 0.5, 0.35), Color(1.0, 0.5, 0.3), 0.55, Color(0.4, 0.3, 0.36), Color(0.8, 0.48, 0.4)],
	[20.3, Color(0.04, 0.06, 0.16), Color(0.15, 0.14, 0.26), Color(0.5, 0.6, 0.9), 0.16, Color(0.12, 0.13, 0.22), Color(0.12, 0.12, 0.2)],
	[24.0, Color(0.02, 0.04, 0.1), Color(0.07, 0.1, 0.18), Color(0.5, 0.6, 0.9), 0.18, Color(0.1, 0.13, 0.22), Color(0.07, 0.09, 0.16)],
]


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "SunMoon"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = false
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.4
	sun.directional_shadow_fade_start = 0.7
	add_child(sun)

	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky.gdshader")
	sky_mat.set_shader_parameter("noise_tex", WorldMaterials.noise_texture())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.35
	env.fog_height = 40.0
	env.fog_height_density = 0.004
	env.fog_aerial_perspective = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	EventBus.quality_changed.connect(func(_l: int) -> void: _apply_quality())
	_apply_quality()


func _apply_quality() -> void:
	var q := Quality.current()
	sun.directional_shadow_max_distance = q["shadow_distance"]
	env.glow_enabled = q["glow"]
	# Reflections from the sky cost a radiance update: skip on LOW.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if Quality.level > Quality.Level.LOW else Environment.REFLECTION_SOURCE_DISABLED


func _process(_delta: float) -> void:
	var h := Clock.hour
	var k := _sample(h)
	var sky_top: Color = k[0]
	var horizon: Color = k[1]
	var light_col: Color = k[2]
	var light_energy: float = k[3]
	var ambient: Color = k[4]
	var fog_col: Color = k[5]

	# Sun path: rises in the east (+X), sets in the west, tilted south.
	var day_angle := (h - 6.0) / 24.0 * TAU
	var sun_dir := Vector3(cos(day_angle), sin(day_angle), 0.35).normalized()
	var moon_dir := -sun_dir
	var daylight := Clock.daylight()
	var light_dir := sun_dir if sun_dir.y > -0.05 else moon_dir
	sun.look_at_from_position(Vector3.ZERO, -light_dir, Vector3.UP if absf(light_dir.y) < 0.99 else Vector3.FORWARD)

	# Weather dims and greys everything.
	var overcast := clampf(Weather.cloud_cover * 1.1 - 0.35, 0.0, 1.0)
	var storm := Weather.storm
	var grey := Color(0.55, 0.58, 0.62).lerp(Color(0.28, 0.3, 0.34), storm)
	sky_top = sky_top.lerp(grey * maxf(daylight, 0.15), overcast * 0.8)
	horizon = horizon.lerp(grey * 1.2 * maxf(daylight, 0.15), overcast * 0.7)
	light_energy *= lerpf(1.0, 0.35, overcast)
	fog_col = fog_col.lerp(grey * maxf(daylight, 0.2), overcast * 0.8)

	sun.light_color = light_col
	sun.light_energy = light_energy
	sun.shadow_enabled = light_energy > 0.3
	env.ambient_light_color = ambient.lerp(grey * 0.7, overcast * 0.5)
	env.ambient_light_energy = 1.0
	env.fog_light_color = fog_col
	env.fog_density = 0.0009 + Weather.fog * 0.02 + Weather.rain * 0.004 + overcast * 0.0015
	env.fog_height_density = 0.003 + Weather.fog * 0.02

	sky_mat.set_shader_parameter("top_color", sky_top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("ground_color", horizon * 0.55)
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("sun_color", light_col)
	sky_mat.set_shader_parameter("cloud_cover", clampf(Weather.cloud_cover, 0.0, 1.0))
	sky_mat.set_shader_parameter("cloud_darkness", clampf(overcast * 0.7 + storm * 0.3, 0.0, 1.0))
	sky_mat.set_shader_parameter("night", 1.0 - daylight)
	sky_mat.set_shader_parameter("star_intensity", smoothstep(0.55, 0.95, 1.0 - daylight) * (1.0 - overcast))

	# Lanterns & windows at night (group-based, a handful of lights at most).
	var night_energy := (1.0 - daylight) * 1.4
	for l in get_tree().get_nodes_in_group(&"night_lights"):
		(l as Light3D).light_energy = night_energy


func _sample(h: float) -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var t := smoothstep(0.0, 1.0, (h - a[0]) / (b[0] - a[0]))
			return [
				(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t), (a[3] as Color).lerp(b[3], t),
				lerpf(a[4], b[4], t), (a[5] as Color).lerp(b[5], t), (a[6] as Color).lerp(b[6], t),
			]
	var last: Array = KEYS[0]
	return [last[1], last[2], last[3], last[4], last[5], last[6]]
