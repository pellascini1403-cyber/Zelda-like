class_name PlayerVitals
extends Node
## Stamina (with exhaustion), ambient temperature exposure.
## Values persist in PlayerData; this component runs the rules.

const REGEN := 26.0
const REGEN_DELAY := 0.7
const EXHAUST_RECOVER_RATIO := 0.35
const COLD_THRESHOLD := 2.0
const HEAT_THRESHOLD := 36.0

var exhausted := false
var temperature := 18.0
## -1 freezing, 0 comfortable, 1 overheating (after resistances)
var exposure := 0
var near_heat := false

var _regen_delay := 0.0
var _temp_tick := 0.0
var _exposure_tick := 0.0

var stamina: float:
	get:
		return PlayerData.stamina
	set(v):
		PlayerData.stamina = v


func drain(amount: float) -> void:
	if amount <= 0.0 or Debug.infinite_stamina:
		return
	stamina = maxf(stamina - amount, 0.0)
	_regen_delay = REGEN_DELAY
	if stamina <= 0.0 and not exhausted:
		exhausted = true
		EventBus.stamina_exhausted.emit()


## Spend a fixed chunk (dodge, climb-leap). Fails if not enough.
func try_spend(amount: float) -> bool:
	if Debug.infinite_stamina:
		return true
	if exhausted or stamina < amount * 0.5:
		return false
	drain(amount)
	return true


func ratio() -> float:
	return stamina / maxf(PlayerData.max_stamina, 1.0)


func tick(delta: float, regen_allowed: bool, pos: Vector3, region: StringName) -> void:
	if _regen_delay > 0.0:
		_regen_delay -= delta
	elif regen_allowed and stamina < PlayerData.max_stamina:
		var rate := REGEN * PlayerData.stamina_regen_mult() * (0.6 if exhausted else 1.0)
		stamina = minf(stamina + rate * delta, PlayerData.max_stamina)
	if exhausted and ratio() >= EXHAUST_RECOVER_RATIO:
		exhausted = false
	_tick_temperature(delta, pos, region)


func _tick_temperature(delta: float, pos: Vector3, region: StringName) -> void:
	_temp_tick -= delta
	if _temp_tick <= 0.0:
		_temp_tick = 0.5
		temperature = Weather.temperature_at(pos, region)
		near_heat = false
		for h in get_tree().get_nodes_in_group(&"heat_source"):
			if (h as Node3D).global_position.distance_squared_to(pos) < 36.0:
				near_heat = true
				break
		if near_heat:
			temperature = maxf(temperature, 16.0)
		var cold_limit := COLD_THRESHOLD - PlayerData.cold_resist() * 12.0
		var heat_limit := HEAT_THRESHOLD + PlayerData.heat_resist() * 12.0
		exposure = -1 if temperature < cold_limit else (1 if temperature > heat_limit else 0)
	if exposure != 0 and not Debug.god_mode:
		_exposure_tick -= delta
		if _exposure_tick <= 0.0:
			_exposure_tick = 2.5
			var p := get_parent()
			var d := DamageInfo.make(4.0, null)
			d.kind = &"environment"
			d.blockable = false
			d.poise_damage = 0.0
			p.take_damage(d)
