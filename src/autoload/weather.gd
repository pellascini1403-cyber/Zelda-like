extends Node
## Weather simulation (state only; visuals live in WeatherFX / Environment).
##
## Weather is chosen per region from data/regions.json weights and blends
## smoothly. Exposed values are what gameplay reads:
##   rain (0..1)      -> wet surfaces, slippery climbing, fire extinguishing
##   wind (vector)    -> glider drift, projectiles, vegetation, particles
##   storm            -> lightning strikes (metal equipment attracts them)
##   fog (0..1)       -> visibility, perception range
##   temperature_mod  -> survival

var current: StringName = &"clear"
var target: StringName = &"clear"
var blend := 1.0
var time_left := 300.0

var rain := 0.0
var cloud_cover := 0.3
var fog := 0.0
var wind := Vector3(1, 0, 0.3)
var wind_strength := 0.25
var storm := 0.0
var temperature_mod := 0.0
var wetness := 0.0
var snow := 0.0

var _region: StringName = &"valley"
var _rng := RandomNumberGenerator.new()
var _wind_angle := 0.4
var _lightning_timer := 20.0
var _from: Dictionary = {}
var _to: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	EventBus.region_entered.connect(func(r: StringName) -> void: _region = r)
	_from = DB.weather(current)
	_to = _from
	_apply(1.0)


func _process(delta: float) -> void:
	if not Game.is_playing():
		return
	var game_delta := delta * Clock.speed
	time_left -= game_delta
	if time_left <= 0.0:
		pick_next()
	if blend < 1.0:
		blend = minf(blend + game_delta / 40.0, 1.0)
		if blend >= 1.0:
			current = target
	_apply(blend)
	# Wind slowly veers
	_wind_angle += sin(Time.get_ticks_msec() * 0.00003) * delta * 0.05
	wind = Vector3(cos(_wind_angle), 0, sin(_wind_angle))
	# Surfaces take time to get wet and to dry
	var wet_target := clampf(rain * 1.2, 0.0, 1.0)
	wetness = move_toward(wetness, wet_target, delta * (0.08 if wet_target > wetness else 0.015))
	RenderingServer.global_shader_parameter_set(&"wetness", wetness)
	RenderingServer.global_shader_parameter_set(&"snow_amount", snow)
	RenderingServer.global_shader_parameter_set(&"wind_vec", Vector4(wind.x, 0, wind.z, wind_strength))
	_update_lightning(delta)


func pick_next() -> void:
	var r := DB.region(_region)
	var weights: Dictionary = r.weather_weights if r else {"clear": 1.0}
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var roll := _rng.randf() * total
	var chosen: StringName = &"clear"
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			chosen = StringName(k)
			break
	set_weather(chosen, false)


func set_weather(id: StringName, instant: bool = false) -> void:
	if not DB.weather_types.has(id):
		return
	_from = _snapshot()
	target = id
	_to = DB.weather(id)
	var dur: Array = _to.get("duration", [180, 420])
	time_left = _rng.randf_range(dur[0], dur[1])
	blend = 1.0 if instant else 0.0
	if instant:
		current = id
		_from = _to
	_apply(blend)
	EventBus.weather_changed.emit(id)


func _snapshot() -> Dictionary:
	return {"rain": rain, "cloud_cover": cloud_cover, "fog": fog, "wind": wind_strength,
		"storm": storm, "temperature": temperature_mod, "snow": snow}


func _apply(t: float) -> void:
	var k := smoothstep(0.0, 1.0, t)
	rain = lerpf(_from.get("rain", 0.0), _to.get("rain", 0.0), k)
	cloud_cover = lerpf(_from.get("cloud_cover", 0.3), _to.get("cloud_cover", 0.3), k)
	fog = lerpf(_from.get("fog", 0.0), _to.get("fog", 0.0), k)
	wind_strength = lerpf(_from.get("wind", 0.25), _to.get("wind", 0.25), k)
	storm = lerpf(_from.get("storm", 0.0), _to.get("storm", 0.0), k)
	temperature_mod = lerpf(_from.get("temperature", 0.0), _to.get("temperature", 0.0), k)
	snow = lerpf(_from.get("snow", 0.0), _to.get("snow", 0.0), k)


## Lightning seeks metal: a player carrying metal gear during a storm gets a
## visible warning before the strike (see Player._on_lightning_warning).
func _update_lightning(delta: float) -> void:
	if storm < 0.5 or Game.player == null:
		return
	_lightning_timer -= delta
	if _lightning_timer > 0.0:
		return
	_lightning_timer = _rng.randf_range(9.0, 22.0)
	var p: Node3D = Game.player
	var target_pos := p.global_position + Vector3(_rng.randf_range(-60, 60), 0, _rng.randf_range(-60, 60))
	if p.has_method("attracts_lightning") and p.attracts_lightning() and _rng.randf() < 0.55:
		p.lightning_warning()
		return
	EventBus.lightning_strike.emit(target_pos)


## Effective ambient temperature at a position (°C).
func temperature_at(pos: Vector3, region: StringName) -> float:
	var r := DB.region(region)
	var base := r.base_temperature if r else 18.0
	var altitude := -maxf(pos.y, 0.0) * 0.1
	var night := lerpf(-7.0, 0.0, Clock.daylight())
	return base + altitude + night + temperature_mod


func save_state() -> Dictionary:
	return {"current": String(target), "time_left": time_left}


func load_state(d: Dictionary) -> void:
	set_weather(StringName(d.get("current", "clear")), true)
	time_left = d.get("time_left", 300.0)
