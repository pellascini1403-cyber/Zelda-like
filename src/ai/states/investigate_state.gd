class_name InvestigateState
extends AIState
## Something was glimpsed or heard: walk over carefully, look around.


func id() -> StringName:
	return &"investigate"


func anim() -> StringName:
	return &"walk"


func enter() -> void:
	var p := c.perception
	var goal := p.heard_at if p.recently_heard(4.0) else p.last_known
	c.go_to(goal, c.type.walk_speed * 1.2)
	Audio.play_at(&"creature_alert", c.global_position, -8.0)


func tick(_delta: float) -> StringName:
	var p := c.perception
	if p.awareness >= 1.0:
		b.alert_group(p.last_known)
		return &"chase"
	if p.sees_player:
		c.face_towards(Game.player.global_position - c.global_position, 0.2)
		c.stop()
	elif c.global_position.distance_to(c.move_target) < 1.5:
		c.stop()
	if t > 7.0 and p.awareness < 0.3:
		return &"patrol"
	return &""
