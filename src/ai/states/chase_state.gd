class_name ChaseState
extends AIState
## Pursue the player to attack range. Keeps preferred distance for ranged
## creatures, gives up at the leash distance or when the trail goes cold.


func id() -> StringName:
	return &"chase"


func anim() -> StringName:
	return &"run"


func enter() -> void:
	c.target = Game.player
	Audio.play_at(&"creature_alert", c.global_position, -2.0)


func tick(_delta: float) -> StringName:
	var p := c.perception
	var player := Game.player as Player
	if player == null or player.is_dead():
		return &"search"
	if low_health() and c.type.ai_value("flee_hp", 0.0) > 0.0:
		return &"retreat"
	if p.time_since_seen > 5.0:
		return &"search"
	var leash := float(c.type.ai_value("leash", 45.0))
	if c.global_position.distance_to(c.home) > leash:
		return &"search"
	var goal := p.last_known
	var d := c.global_position.distance_to(goal)
	var preferred := float(c.type.ai_value("preferred_range", 0.0))
	if preferred > 0.0 and d < preferred * 0.6:
		return &"retreat"
	var atk := b.pick_attack(d)
	if atk and p.sees_player:
		(b.states[&"attack"] as AttackState).attack = atk
		return &"attack"
	if preferred > 0.0 and d < preferred:
		c.stop()
		c.face_towards(goal - c.global_position, 0.2)
	else:
		c.go_to(goal, c.type.run_speed)
	return &""
