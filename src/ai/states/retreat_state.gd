class_name RetreatState
extends AIState
## Back off: wounded fighters regroup, ranged creatures restore distance.


func id() -> StringName:
	return &"retreat"


func anim() -> StringName:
	return &"run"


func tick(_delta: float) -> StringName:
	if Game.player == null:
		return &"patrol"
	var away := c.global_position - Game.player.global_position
	away.y = 0.0
	var preferred := float(c.type.ai_value("preferred_range", 0.0))
	c.go_to(c.global_position + away.normalized() * 6.0, c.type.run_speed * 0.9)
	var d := away.length()
	if preferred > 0.0 and d >= preferred:
		return &"chase"
	if low_health():
		if t > 5.0:
			return &"flee" if c.type.ai_value("flees", false) else &"chase"
	elif t > 1.5:
		return &"chase"
	return &""
