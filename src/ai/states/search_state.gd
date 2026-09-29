class_name SearchState
extends AIState
## Lost the player: sweep around the last known position, then go home.

var _spot := Vector3.ZERO


func id() -> StringName:
	return &"search"


func anim() -> StringName:
	return &"walk"


func enter() -> void:
	_spot = c.perception.last_known
	c.go_to(_spot, c.type.walk_speed * 1.3)


func tick(_delta: float) -> StringName:
	if c.perception.sees_player and c.perception.awareness > 0.6:
		c.perception.alert(Game.player.global_position)
		return &"chase"
	if c.global_position.distance_to(c.move_target) < 1.5:
		c.go_to(random_point_near(_spot, 6.0), c.type.walk_speed)
	if t > 9.0:
		c.perception.awareness = 0.0
		c.go_to(c.home, c.type.walk_speed)
		return &"patrol"
	return &""
