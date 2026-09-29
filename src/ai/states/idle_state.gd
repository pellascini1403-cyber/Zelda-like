class_name IdleState
extends AIState
## Stand, look around. Hostiles react to the player; sleepers doze at night.


func id() -> StringName:
	return &"idle"


func enter() -> void:
	c.stop()


func tick(_delta: float) -> StringName:
	if c.kind_is_hostile():
		var h := hostile_check()
		if h != &"":
			return h
	if c.type.ai_value("sleeps_at_night", false) and Clock.is_night() and c.global_position.distance_to(c.home) < 6.0:
		return &"sleep"
	if t > randf_range(2.0, 5.0):
		return &"patrol"
	return &""
