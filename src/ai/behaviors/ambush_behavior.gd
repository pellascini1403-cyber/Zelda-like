class_name AmbushBehavior
extends AIBehavior
## Waits crouched and still near home (reads as a rock, a stump, a pile of
## bones). A player who walks in close is jumped; one who spots it first
## gets a sneak attack. Tuning: ambush_range (m).


func states() -> Array:
	return [LurkState.new(b)]


func initial_state() -> StringName:
	return &"lurk"


func pre_tick(_delta: float) -> StringName:
	# Fight over and back home: settle down again.
	if b.current.id() == &"idle" and c.global_position.distance_to(c.home) < 4.0 and c.perception.awareness < 0.3:
		return &"lurk"
	return &""


class LurkState:
	extends AIState

	func id() -> StringName:
		return &"lurk"

	func enter() -> void:
		c.stop()
		c.visual.scale = Vector3(1.1, 0.7, 1.1)

	func exit() -> void:
		c.visual.scale = Vector3.ONE

	func tick(_delta: float) -> StringName:
		var pl := Game.player as Player
		if pl == null or pl.is_dead():
			return &""
		var d := c.global_position.distance_to(pl.global_position)
		var r := float(c.type.ai_value("ambush_range", 5.0))
		if d < r or c.perception.awareness >= 1.0:
			c.perception.alert(pl.global_position)
			b.alert_group(pl.global_position)
			var atk := b.pick_attack(d)
			if atk:
				(b.states[&"attack"] as AttackState).attack = atk
				return &"attack"
			return &"chase"
		return &""
