class_name PatrolState
extends AIState
## Wander around home (camp, den, herd area).

var _point := Vector3.ZERO


func id() -> StringName:
	return &"patrol"


func anim() -> StringName:
	return &"walk"


func enter() -> void:
	_point = random_point_near(c.home, float(c.type.ai_value("wander_radius", 10.0)))
	c.go_to(_point, c.type.walk_speed)


func tick(_delta: float) -> StringName:
	if c.kind_is_hostile():
		var h := hostile_check()
		if h != &"":
			return h
	var d := Vector2(c.global_position.x - _point.x, c.global_position.z - _point.z).length()
	if d < 1.2 or t > 12.0:
		return &"idle"
	return &""
