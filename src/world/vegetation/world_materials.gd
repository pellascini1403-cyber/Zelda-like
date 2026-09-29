class_name WorldMaterials
extends RefCounted
## Shared material cache. Every sector reuses the same few materials, which
## keeps draw calls batched and shader variants low.

static var _cache: Dictionary = {}
static var _noise: Texture2D


static func noise_texture() -> Texture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX
		n.frequency = 0.02
		n.fractal_octaves = 4
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.generate_mipmaps = true
		t.noise = n
		# Bake synchronously so first frame already has it.
		var img := n.get_seamless_image(256, 256)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise


static func get_mat(key: StringName) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match key:
		&"terrain":
			m = _shader_mat("res://assets/shaders/terrain.gdshader")
		&"foliage":
			m = _shader_mat("res://assets/shaders/foliage.gdshader")
		&"foliage_baked":
			m = _shader_mat("res://assets/shaders/foliage.gdshader")
			(m as ShaderMaterial).set_shader_parameter("baked", true)
		&"rock":
			m = _shader_mat("res://assets/shaders/foliage.gdshader")
			(m as ShaderMaterial).set_shader_parameter("is_rock", true)
			(m as ShaderMaterial).set_shader_parameter("hue_shift", Color(0.95, 0.9, 0.85))
		&"crystal":
			m = _shader_mat("res://assets/shaders/foliage.gdshader")
			(m as ShaderMaterial).set_shader_parameter("emissive", true)
			(m as ShaderMaterial).set_shader_parameter("sway", 0.0)
		&"grass":
			m = _shader_mat("res://assets/shaders/grass.gdshader")
		&"water":
			m = _shader_mat("res://assets/shaders/water.gdshader")
		&"stone":
			m = _std(Color(0.62, 0.6, 0.55), 0.9)
		&"stone_dark":
			m = _std(Color(0.38, 0.37, 0.36), 0.95)
		&"wood":
			m = _std(Color(0.45, 0.31, 0.2), 0.85)
		&"wood_light":
			m = _std(Color(0.66, 0.5, 0.33), 0.8)
		&"thatch":
			m = _std(Color(0.72, 0.6, 0.34), 0.95)
		&"cloth":
			m = _std(Color(0.63, 0.25, 0.2), 0.9)
		&"metal":
			var sm := _std(Color(0.55, 0.57, 0.6), 0.35)
			sm.metallic = 0.8
			m = sm
		&"moss_stone":
			m = _std(Color(0.42, 0.47, 0.36), 0.95)
		&"glow_rune":
			var gm := _std(Color(0.4, 0.9, 1.0), 0.4)
			gm.emission_enabled = true
			gm.emission = Color(0.3, 0.85, 1.0)
			gm.emission_energy_multiplier = 1.6
			m = gm
		&"architecture":
			m = _shader_mat("res://assets/shaders/architecture.gdshader")
		&"vertex_color":
			var vm := StandardMaterial3D.new()
			vm.vertex_color_use_as_albedo = true
			vm.roughness = 0.85
			m = vm
		_:
			push_warning("WorldMaterials: unknown key " + key)
			m = _std(Color.MAGENTA, 1.0)
	_cache[key] = m
	return m


static func _shader_mat(path: String) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load(path)
	sm.set_shader_parameter("noise_tex", noise_texture())
	return sm


static func _std(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
