extends Node
## World time. One in-game day = DAY_LENGTH real seconds (default 24 min).
##
## Emits period changes (dawn/day/dusk/night) so AI, NPC routines, spawns and
## audio can react without polling.

const DAY_LENGTH := 1440.0
const PERIODS := [[5.0, &"dawn"], [7.5, &"day"], [18.5, &"dusk"], [20.5, &"night"]]

## Hours 0..24
var hour := 8.0
var day := 1
var paused := false
var speed := 1.0
var period: StringName = &"day"


func _ready() -> void:
	period = _period_for(hour)


func _process(delta: float) -> void:
	if paused or not Game.is_playing():
		return
	advance_hours(delta * speed * 24.0 / DAY_LENGTH)


func advance_hours(h: float) -> void:
	hour += h
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	var p := _period_for(hour)
	if p != period:
		period = p
		EventBus.time_period_changed.emit(period)


func set_time(h: float) -> void:
	hour = fposmod(h, 24.0)
	advance_hours(0.0)


## Continuous time in hours since day 1 (used for respawn timers).
func total_hours() -> float:
	return (day - 1) * 24.0 + hour


func is_night() -> bool:
	return hour >= 20.0 or hour < 5.5


## 0 at night, 1 at full day, smooth at dawn/dusk.
func daylight() -> float:
	return smoothstep(4.8, 7.0, hour) * (1.0 - smoothstep(18.0, 20.3, hour))


## Sun elevation angle in degrees (-90..90), peaks at 13:00.
func sun_elevation() -> float:
	return sin((hour - 7.0) / 24.0 * TAU) * 68.0


func _period_for(h: float) -> StringName:
	var result: StringName = &"night"
	for p in PERIODS:
		if h >= p[0]:
			result = p[1]
	return result


func save_state() -> Dictionary:
	return {"hour": hour, "day": day}


func load_state(d: Dictionary) -> void:
	hour = d.get("hour", 8.0)
	day = d.get("day", 1)
	period = _period_for(hour)
