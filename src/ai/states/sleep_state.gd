class_name SleepState
extends AIState
## Night rest: very low perception (perfect for sneaking), wakes on noise,
## damage or dawn.


func id() -> StringName:
	return &"sleep"


func anim() -> StringName:
	return &"idle"


func enter() -> void:
	c.stop()
	c.visual.play_action(&"die", 0.01)


func exit() -> void:
	c.visual.play_action(&"idle", 0.01)


func tick(_delta: float) -> StringName:
	if c.perception.recently_heard(0.5) or c.perception.awareness >= 0.9:
		c.perception.awareness = maxf(c.perception.awareness, 0.6)
		return &"investigate" if c.kind_is_hostile() else &"flee"
	if not Clock.is_night():
		return &"idle"
	return &""
