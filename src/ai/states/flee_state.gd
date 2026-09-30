class_name FleeState
extends AIState
## Run from a threat (player, predators, fire). Animals live here a lot.

var threat := Vector3.ZERO


func id() -> StringName:
	return &"flee"


func anim() -> StringName:
	return &"run"


func enter() -> void:
	if b.flee_from != Vector3.INF:
		threat = b.flee_from
		b.flee_from = Vector3.INF
	elif Game.player:
		threat = Game.player.global_position


func tick(_delta: float) -> StringName:
	var away := c.global_position - threat
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(randf() - 0.5, 0, randf() - 0.5)
	c.go_to(c.global_position + away.normalized() * 8.0, c.type.run_speed)
	if away.length() > 30.0 or t > 8.0:
		c.home = c.global_position
		c.perception.awareness = 0.0
		return &"idle"
	return &""
