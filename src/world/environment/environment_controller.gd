class_name EnvironmentController
extends Node3D
## Presentation of time of day + weather ("Jade, Cinnabar & Ink Mist").
##
## One directional light (sun by day, moon by night), one Environment, one sky
## material and a baked 3D colour-grading LUT: all global, updated once per
## frame. Warm key light against cool jade/blue ambient is the core of the
## look; height fog makes the mist bands between depth planes.

var sun: DirectionalLight3D
## Shadowless fills that turn the flat ambient into a hemisphere: a cool sky
## fill from above (opposite the sun) and a warm-green bounce from the ground.
## light_specular = 0 marks them as fills for the custom light() shaders
## (terrain canopy dapple only touches the key light).
var sky_fill: DirectionalLight3D
var bounce: DirectionalLight3D
var env: Environment
var world_env: WorldEnvironment
var sky_mat: ShaderMaterial

# [hour, sky_top, horizon, light color, light energy, ambient, fog]
const KEYS := [
	[0.0, Color(0.04, 0.06, 0.14), Color(0.13, 0.16, 0.25), Color(0.64, 0.72, 0.94), 0.42, Color(0.17, 0.2, 0.27), Color(0.12, 0.15, 0.22)],
	[4.8, Color(0.07, 0.1, 0.2), Color(0.26, 0.26, 0.36), Color(0.64, 0.7, 0.92), 0.36, Color(0.2, 0.22, 0.3), Color(0.24, 0.24, 0.32)],
	[6.2, Color(0.32, 0.42, 0.66), Color(0.98, 0.72, 0.5), Color(1.0, 0.68, 0.42), 0.95, Color(0.36, 0.37, 0.46), Color(0.86, 0.74, 0.62)],
	[8.0, Color(0.26, 0.5, 0.84), Color(0.74, 0.86, 0.93), Color(1.0, 0.88, 0.68), 1.45, Color(0.36, 0.47, 0.52), Color(0.74, 0.84, 0.88)],
	[13.0, Color(0.2, 0.45, 0.84), Color(0.7, 0.84, 0.93), Color(1.0, 0.95, 0.84), 1.6, Color(0.38, 0.5, 0.55), Color(0.72, 0.84, 0.9)],
	[17.2, Color(0.24, 0.44, 0.78), Color(0.84, 0.84, 0.82), Color(1.0, 0.82, 0.6), 1.3, Color(0.36, 0.44, 0.54), Color(0.78, 0.8, 0.8)],
	[18.9, Color(0.24, 0.3, 0.56), Color(0.98, 0.66, 0.44), Color(1.0, 0.6, 0.34), 0.85, Color(0.3, 0.3, 0.4), Color(0.8, 0.62, 0.52)],
	[20.2, Color(0.06, 0.08, 0.18), Color(0.22, 0.2, 0.32), Color(0.64, 0.7, 0.94), 0.38, Color(0.18, 0.19, 0.28), Color(0.18, 0.18, 0.26)],
	[24.0, Color(0.04, 0.06, 0.14), Color(0.13, 0.16, 0.25), Color(0.64, 0.72, 0.94), 0.42, Color(0.17, 0.2, 0.27), Color(0.12, 0.15, 0.22)],
]


## Look tunables (art direction, docs/ART_DIRECTION.md "Luz"). Kept in one
## place so look-dev can audition variants without touching the code paths.
var look := {
	"exposure": 0.85,
	"ambient_day": 0.8,        # flat ambient energy by day (clear sky)
	"fill": 0.7,              # cool sky fill energy
	"bounce": 0.14,            # warm ground bounce, fraction of the sun
	"height_fog": 0.005,        # base height-fog density (valley mist)
	"aerial": 0.75,            # aerial perspective (distance takes the sky colour)
	"fog": 0.0014,             # base distance fog density
	"contrast": 1.1,
	"saturation": 0.95,
}

## Supernatural tint applied while inside the Veil Reaches (0..1).
var veil := 0.0
var desert := 0.0


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "SunMoon"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = false
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.4
	sun.directional_shadow_fade_start = 0.7
	sun.light_angular_distance = 0.6
	add_child(sun)
	sky_fill = _fill_light("SkyFill")
	bounce = _fill_light("GroundBounce")

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
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.45
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.55
	env.fog_height = 32.0
	env.fog_height_density = 0.018
	env.fog_aerial_perspective = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.06
	env.adjustment_color_correction = ColorGrade.build_lut()
	# Compatibility (Web, old GLES) applies height fog to everything below
	# the camera and washes the image out: it keeps distance fog only.
	_compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	RenderingServer.global_shader_parameter_set(&"compat_gamma", 1.0 if _compat else 0.0)
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	EventBus.quality_changed.connect(func(_l: int) -> void: _apply_quality())
	_apply_quality()


func _fill_light(n: String) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = n
	l.shadow_enabled = false
	l.light_specular = 0.0
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(l)
	return l


func _apply_quality() -> void:
	var q := Quality.current()
	# Forest floor: real tree shadows on HIGH+, painted canopy shade below.
	RenderingServer.global_shader_parameter_set(&"canopy_dark", 0.25 if Quality.shadows_for_vegetation() else 0.9)
	sun.directional_shadow_max_distance = q["shadow_distance"]
	env.glow_enabled = q["glow"]
	# Reflections from the sky cost a radiance update: skip on LOW.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if Quality.level > Quality.Level.LOW else Environment.REFLECTION_SOURCE_DISABLED


func _process(delta: float) -> void:
	var h := Clock.hour
	var k := _sample(h)
	var sky_top: Color = k[0]
	var horizon: Color = k[1]
	var light_col: Color = k[2]
	var light_energy: float = k[3]
	var ambient: Color = k[4]
	var fog_col: Color = k[5]

	# Regional moods blend in smoothly (desert heat haze, Veil otherworld).
	var target_desert := 0.0
	var target_veil := 0.0
	if Game.player:
		var r: StringName = (Game.player as Player).region
		target_desert = 1.0 if r == &"desert" else 0.0
		target_veil = 1.0 if r == &"veil" else 0.0
	desert = move_toward(desert, target_desert, delta * 0.25)
	veil = move_toward(veil, target_veil, delta * 0.25)
	if desert > 0.0:
		horizon = horizon.lerp(Color(0.98, 0.84, 0.64) * maxf(Clock.daylight(), 0.25), desert * 0.6)
		fog_col = fog_col.lerp(Color(0.95, 0.8, 0.6) * maxf(Clock.daylight(), 0.25), desert * 0.7)
		light_col = light_col.lerp(Color(1.0, 0.86, 0.66), desert * 0.5)
	if veil > 0.0:
		sky_top = sky_top.lerp(Color(0.2, 0.12, 0.38), veil * 0.7)
		horizon = horizon.lerp(Color(0.62, 0.5, 0.86), veil * 0.7)
		fog_col = fog_col.lerp(Color(0.56, 0.46, 0.8), veil * 0.8)
		ambient = ambient.lerp(Color(0.36, 0.3, 0.55), veil * 0.6)

	# Sun path: rises in the east (+X), sets in the west, tilted south.
	var day_angle := (h - 6.0) / 24.0 * TAU
	# Peak elevation ~55° (never overhead): side light models every form.
	var sun_dir := Vector3(cos(day_angle), sin(day_angle) * 0.8, 0.55).normalized()
	var moon_dir := -sun_dir
	var daylight := Clock.daylight()
	var light_dir := sun_dir if sun_dir.y > -0.05 else moon_dir
	# Keep the light a little above the horizon so shadows never go infinite.
	light_dir.y = maxf(light_dir.y, 0.12)
	light_dir = light_dir.normalized()
	sun.look_at_from_position(Vector3.ZERO, -light_dir, Vector3.UP if absf(light_dir.y) < 0.99 else Vector3.FORWARD)

	# Weather dims and greys everything.
	var overcast := clampf(Weather.cloud_cover * 1.1 - 0.35, 0.0, 1.0)
	var storm := Weather.storm
	var grey := Color(0.6, 0.64, 0.67).lerp(Color(0.3, 0.32, 0.37), storm)
	sky_top = sky_top.lerp(grey * maxf(daylight, 0.15), overcast * 0.8)
	horizon = horizon.lerp(grey * 1.15 * maxf(daylight, 0.15), overcast * 0.7)
	light_energy *= lerpf(1.0, 0.4, overcast)
	fog_col = fog_col.lerp(grey * maxf(daylight, 0.2), overcast * 0.8)
	if Weather.sand > 0.0:
		fog_col = fog_col.lerp(Color(0.8, 0.6, 0.38) * maxf(daylight, 0.2), Weather.sand)
		horizon = horizon.lerp(Color(0.85, 0.66, 0.44) * maxf(daylight, 0.2), Weather.sand)
		light_energy *= lerpf(1.0, 0.55, Weather.sand)

	env.tonemap_exposure = look.exposure
	env.adjustment_contrast = look.contrast
	env.adjustment_saturation = look.saturation
	sun.light_color = light_col
	sun.light_energy = light_energy
	# Moonlight shadows are soft and translucent: night stays readable.
	sun.shadow_opacity = lerpf(0.55, 1.0, smoothstep(0.1, 0.4, daylight))
	sun.shadow_enabled = light_energy > 0.2
	env.ambient_light_color = ambient.lerp(grey * 0.75, overcast * 0.5)
	# Flat ambient is kept low by day so the key light carves volume; the
	# hemisphere fills carry the cool sky / warm ground split. Overcast days
	# go back to soft, even light. Night keeps a readable moonlit fill
	# (mobile screens are viewed in bright rooms).
	env.ambient_light_energy = lerpf(look.ambient_day, 0.95, overcast) * daylight + (1.0 - daylight) * 1.9
	var flat := Vector3(light_dir.x, 0.0, light_dir.z).normalized()
	_aim(sky_fill, (Vector3.UP * 1.6 - flat).normalized())
	sky_fill.light_color = sky_top.lerp(horizon, 0.45).lerp(Color(0.62, 0.76, 1.0), 0.4)
	sky_fill.light_energy = daylight * lerpf(look.fill, 0.2, overcast)
	_aim(bounce, (Vector3.DOWN * 1.2 - flat * 0.6).normalized())
	bounce.light_color = Color(0.72, 0.68, 0.42).lerp(Color(0.9, 0.78, 0.6), desert)
	bounce.light_energy = daylight * light_energy * look.bounce
	env.fog_light_color = fog_col
	env.fog_density = look.fog + Weather.fog * 0.018 + Weather.rain * 0.004 + overcast * 0.0012 + Weather.sand * 0.02 + veil * 0.002
	env.fog_height_density = look.height_fog + Weather.fog * 0.03 + Weather.rain * 0.01
	# Dawn mist settles in the valleys.
	var dawn := smoothstep(4.5, 6.5, h) * (1.0 - smoothstep(7.5, 10.0, h))
	env.fog_height = 30.0 + dawn * 25.0
	env.fog_height_density += dawn * 0.008
	if _compat:
		# No aerial perspective in Compatibility: distance fog alone would
		# bleach the far mountains, so it is kept thinner there.
		env.fog_height_density = 0.0
		env.fog_density *= 0.5

	var cam := get_viewport().get_camera_3d()
	# Sea mist banks: the view closes in to a few tens of metres, pale and
	# soft; out of the bank the air clears again (MistBank has edges).
	var mist_target: float = MistBank.seen_density(cam.global_position, get_tree()) if cam else 0.0
	mist = move_toward(mist, mist_target, delta * 0.6)
	if mist > 0.0:
		# Pearl grey, not sky-tinted: aerial perspective would blend the mist
		# into the sky colour and it would stop reading as a wall.
		var pearl := Color(0.8, 0.82, 0.83) * clampf(daylight + 0.3, 0.5, 1.0)
		env.fog_light_color = env.fog_light_color.lerp(pearl, mist * 0.9)
		env.fog_density += mist * 0.035
		if not _compat:
			env.fog_height_density += mist * 0.02
		env.fog_sun_scatter = lerpf(0.45, 0.1, mist)
		env.fog_aerial_perspective = lerpf(look.aerial, 0.0, mist)
		env.fog_sky_affect = lerpf(0.55, 0.92, mist)
	else:
		env.fog_sun_scatter = 0.45
		env.fog_aerial_perspective = look.aerial
		env.fog_sky_affect = 0.55

	# Under the surface: teal murk, short sight, a tint over everything.
	var under_target := 1.0 if cam and cam.global_position.y < WorldGen.SEA_LEVEL - 0.1 else 0.0
	underwater = move_toward(underwater, under_target, delta * 4.0)
	if underwater > 0.0:
		var murk := Color(0.08, 0.32, 0.36) * maxf(daylight, 0.25)
		env.fog_light_color = env.fog_light_color.lerp(murk, underwater)
		env.fog_density = lerpf(env.fog_density, 0.075, underwater)
		env.fog_height_density = lerpf(env.fog_height_density, 0.0, underwater)
	_under_overlay().color = Color(0.1, 0.45, 0.5, 0.28 * underwater)
	_under_overlay().visible = underwater > 0.01

	sky_mat.set_shader_parameter("top_color", sky_top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("ground_color", horizon * 0.62)
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("sun_color", light_col)
	sky_mat.set_shader_parameter("cloud_cover", clampf(Weather.cloud_cover, 0.0, 1.0))
	sky_mat.set_shader_parameter("cloud_darkness", clampf(overcast * 0.7 + storm * 0.3, 0.0, 1.0))
	sky_mat.set_shader_parameter("night", 1.0 - daylight)
	sky_mat.set_shader_parameter("star_intensity", smoothstep(0.55, 0.95, 1.0 - daylight) * (1.0 - overcast))
	sky_mat.set_shader_parameter("veil", veil)

	# Lanterns & windows at night (group-based, a handful of lights at most).
	var night_energy := (1.0 - daylight) * 1.6
	for l in get_tree().get_nodes_in_group(&"night_lights"):
		(l as Light3D).light_energy = night_energy
	RenderingServer.global_shader_parameter_set(&"night_glow", 1.0 - daylight)
	var fleck := light_col.srgb_to_linear() * light_energy * smoothstep(0.25, 0.6, daylight) * (1.0 - overcast) * (1.0 - storm)
	RenderingServer.global_shader_parameter_set(&"sun_fleck", Vector4(fleck.r, fleck.g, fleck.b, 1.0))
	# Water reflects the live sky (linear colours, before fog).
	var st := sky_top.srgb_to_linear()
	var sh := horizon.srgb_to_linear()
	RenderingServer.global_shader_parameter_set(&"sky_top", Vector3(st.r, st.g, st.b))
	RenderingServer.global_shader_parameter_set(&"sky_horizon", Vector3(sh.r, sh.g, sh.b))
	RenderingServer.global_shader_parameter_set(&"mist_color", Vector3(fog_col.r, fog_col.g, fog_col.b) * 1.04)


var underwater := 0.0
var mist := 0.0
var _compat := false
var _overlay: ColorRect


func _under_overlay() -> ColorRect:
	if _overlay == null:
		var layer := CanvasLayer.new()
		layer.layer = -1
		add_child(layer)
		_overlay = ColorRect.new()
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_overlay)
	return _overlay


## Points a light so it shines FROM `from_dir` (unit vector toward the light).
func _aim(l: DirectionalLight3D, from_dir: Vector3) -> void:
	l.look_at_from_position(Vector3.ZERO, -from_dir, Vector3.UP if absf(from_dir.y) < 0.99 else Vector3.FORWARD)


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
