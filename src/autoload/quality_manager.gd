extends Node
## Adaptive quality: device tiering, presets, dynamic resolution, thermal
## governor and frame pacing. Every visual system reads its budget from here.
##
## Order of priority (from the performance rules): stability > gameplay >
## controls > stable FPS > memory > battery > visuals. When frame time is
## over budget, resolution drops first, then (sustained) the whole preset.

enum Level { LOW, MEDIUM, HIGH, ULTRA }

const PRESETS := {
	Level.LOW: {
		"render_scale": 0.7, "shadow_distance": 35.0, "shadow_size": 1024, "shadows_vegetation": false,
		"lod0_radius": 1, "lod1_radius": 2,
		"vegetation_density": 0.35, "vegetation_distance": 35.0,
		"particles": 0.35, "fog": true, "glow": false, "msaa": 0,
		"max_dynamic_lights": 2, "ai_full_distance": 40.0, "ai_reduced_distance": 90.0,
		"ambient_groups": 2, "ambient_distance": 70.0,
	},
	Level.MEDIUM: {
		"render_scale": 0.8, "shadow_distance": 55.0, "shadow_size": 2048, "shadows_vegetation": false,
		"lod0_radius": 1, "lod1_radius": 3,
		"vegetation_density": 0.6, "vegetation_distance": 45.0,
		"particles": 0.6, "fog": true, "glow": true, "msaa": 0,
		"max_dynamic_lights": 4, "ai_full_distance": 50.0, "ai_reduced_distance": 110.0,
		"ambient_groups": 4, "ambient_distance": 90.0,
	},
	Level.HIGH: {
		"render_scale": 0.9, "shadow_distance": 80.0, "shadow_size": 2048, "shadows_vegetation": true,
		"lod0_radius": 2, "lod1_radius": 3,
		"vegetation_density": 0.85, "vegetation_distance": 55.0,
		"particles": 0.85, "fog": true, "glow": true, "msaa": 0,
		"max_dynamic_lights": 6, "ai_full_distance": 60.0, "ai_reduced_distance": 130.0,
		"ambient_groups": 6, "ambient_distance": 110.0,
	},
	Level.ULTRA: {
		"render_scale": 1.0, "shadow_distance": 120.0, "shadow_size": 4096, "shadows_vegetation": true,
		"lod0_radius": 2, "lod1_radius": 4,
		"vegetation_density": 1.0, "vegetation_distance": 70.0,
		"particles": 1.0, "fog": true, "glow": true, "msaa": 1,
		"max_dynamic_lights": 8, "ai_full_distance": 70.0, "ai_reduced_distance": 150.0,
		"ambient_groups": 8, "ambient_distance": 130.0,
	},
}

var level: int = Level.MEDIUM
var detected_level: int = Level.MEDIUM
## Dynamic resolution multiplier on top of the preset render_scale.
var dynamic_scale := 1.0
var thermal_state := 0  # 0 nominal, 1 fair, 2 serious, 3 critical

var _frame_times: PackedFloat32Array = []
var _frame_idx := 0
var _over_budget_time := 0.0
var _under_budget_time := 0.0
var _session_time := 0.0
var _sustained_slow := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame_times.resize(60)
	_frame_times.fill(1.0 / 60.0)
	detected_level = detect_device_level()
	var saved: int = Settings.get_value("quality")
	level = detected_level if saved < 0 else clampi(saved, Level.LOW, Level.ULTRA)
	EventBus.settings_changed.connect(_on_settings_changed)
	apply()


func current() -> Dictionary:
	return PRESETS[level]


func shadows_for_vegetation() -> bool:
	return current()["shadows_vegetation"]


func particle_amount(base: int) -> int:
	return maxi(1, int(base * current()["particles"]))


func target_fps() -> int:
	if Settings.get_value("battery_saver") or thermal_state >= 2:
		return 30
	return int(Settings.get_value("fps_target"))


## Heuristic device tier. Platform plugins may refine it (RAM, GPU family).
func detect_device_level() -> int:
	var os_name := OS.get_name()
	var cores := OS.get_processor_count()
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	if os_name in ["Windows", "macOS", "Linux"]:
		return Level.HIGH
	if os_name == "iOS":
		var model := OS.get_model_name()
		# iPhone 12 (iPhone13,x) and newer / M-series iPads handle HIGH.
		var major := model.get_slice(",", 0).trim_prefix("iPhone").trim_prefix("iPad").to_int()
		if model.begins_with("iPad") and major >= 13:
			return Level.HIGH
		return Level.HIGH if major >= 13 else Level.MEDIUM
	# Android: rough tiering by GPU family and core count
	if "adreno" in adapter:
		var num := adapter.to_int()
		if num >= 730:
			return Level.HIGH
		if num >= 610:
			return Level.MEDIUM
		return Level.LOW
	if "mali-g7" in adapter or "immortalis" in adapter or "xclipse" in adapter:
		return Level.HIGH if cores >= 8 else Level.MEDIUM
	if "mali" in adapter or "powervr" in adapter:
		return Level.LOW
	return Level.MEDIUM if cores >= 8 else Level.LOW


func set_level(new_level: int, persist: bool = true) -> void:
	level = clampi(new_level, Level.LOW, Level.ULTRA)
	if persist:
		Settings.set_value("quality", level)
	apply()
	EventBus.quality_changed.emit(level)


func apply() -> void:
	var p := current()
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = clampf(p["render_scale"] * dynamic_scale, 0.5, 1.0)
		vp.msaa_3d = Viewport.MSAA_2X if p["msaa"] > 0 else Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	Engine.max_fps = target_fps()


func _on_settings_changed() -> void:
	Engine.max_fps = target_fps()
	var saved: int = Settings.get_value("quality")
	if saved >= 0 and saved != level:
		level = saved
		apply()
		EventBus.quality_changed.emit(level)


func _process(delta: float) -> void:
	_session_time += delta
	_frame_times[_frame_idx] = delta
	_frame_idx = (_frame_idx + 1) % _frame_times.size()
	if not Settings.get_value("dynamic_resolution"):
		return
	var avg := 0.0
	for t in _frame_times:
		avg += t
	avg /= _frame_times.size()
	var budget := 1.0 / float(target_fps())
	# Dynamic resolution: react within ~1 s, recover slowly.
	if avg > budget * 1.12:
		_over_budget_time += delta
		_under_budget_time = 0.0
	elif avg < budget * 0.85:
		_under_budget_time += delta
		_over_budget_time = 0.0
	if _over_budget_time > 1.0 and dynamic_scale > 0.72:
		dynamic_scale = maxf(dynamic_scale - 0.07, 0.72)
		_over_budget_time = 0.0
		apply()
	elif _under_budget_time > 4.0 and dynamic_scale < 1.0:
		dynamic_scale = minf(dynamic_scale + 0.05, 1.0)
		_under_budget_time = 0.0
		apply()
	_update_thermal(avg, budget)


## Thermal governor. Mobile OS thermal APIs are exposed through the platform
## layer when available; otherwise sustained slow frames at the minimum
## dynamic scale are treated as throttling and the preset steps down, trading
## peak quality for a stable 30-60 minute session.
func _update_thermal(avg: float, budget: float) -> void:
	var os_state := Platform.thermal_state()
	if os_state >= 0:
		if os_state != thermal_state:
			thermal_state = os_state
			if thermal_state >= 2 and level > Level.LOW:
				set_level(level - 1, false)
			Engine.max_fps = target_fps()
		return
	if dynamic_scale <= 0.72 and avg > budget * 1.2 and _session_time > 60.0:
		_sustained_slow += get_process_delta_time()
	else:
		_sustained_slow = maxf(_sustained_slow - get_process_delta_time(), 0.0)
	if _sustained_slow > 20.0 and level > Level.LOW:
		_sustained_slow = 0.0
		thermal_state = 1
		dynamic_scale = 0.9
		set_level(level - 1, false)
