class_name Tide
extends RefCounted
## The sea's clock. Two tides a day, read from the hour: high around 6 and
## 18, low around 0 and 12 (low windows 22-2 and 10-14). No water moves —
## the world's tide-bound things (sandbars, surf at cave mouths, the isle
## that vanishes) read this and change the routes.


static func level(hour: float = -1.0) -> float:
	var h := Clock.hour if hour < 0.0 else hour
	return 0.5 + 0.5 * cos((h - 6.0) / 12.0 * TAU)


## How fast the water is moving (0 = slack at high/low water, 1 = full
## flood or ebb around 3, 9, 15 and 21 h). Tidal currents follow it.
static func flow(hour: float = -1.0) -> float:
	var h := Clock.hour if hour < 0.0 else hour
	return absf(sin((h - 6.0) / 12.0 * TAU))


static func is_slack(hour: float = -1.0) -> bool:
	return flow(hour) < 0.3


static func is_low(hour: float = -1.0) -> bool:
	return level(hour) < 0.25


static func is_high(hour: float = -1.0) -> bool:
	return level(hour) > 0.75


static func label_key(hour: float = -1.0) -> String:
	var h := Clock.hour if hour < 0.0 else hour
	if is_low(h):
		return "TIDE_LOW"
	if is_high(h):
		return "TIDE_HIGH"
	return "TIDE_RISING" if level(h + 0.2) > level(h) else "TIDE_FALLING"
