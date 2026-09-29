class_name RoutineState
extends AIState
## NPC daily schedule.


func id() -> StringName:
	return &"routine"


func anim() -> StringName:
	return &"walk" if c.move_speed > 0.0 else &"idle"


func tick(_delta: float) -> StringName:
	var goal := (c as NPC).scheduled_position()
	var d := Vector2(c.global_position.x - goal.x, c.global_position.z - goal.z).length()
	if d > 1.0:
		c.go_to(goal, c.type.walk_speed)
	else:
		c.stop()
		if t > 6.0:
			t = 0.0
			c.facing_yaw += randf_range(-1.0, 1.0)
	return &""
