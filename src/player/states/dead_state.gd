class_name DeadState
extends PlayerState
## Down. No progress is lost: respawn at the last safe place, full health.

const RESPAWN_DELAY := 3.0


func state_name() -> StringName:
	return &"dead"


func anim() -> StringName:
	return &"idle"


func enter(_prev: StringName) -> void:
	p.velocity = Vector3.ZERO
	p.visual.play_action(&"die", 0.8)
	EventBus.player_died.emit()
	Game.clear_aggro()


func physics(delta: float) -> StringName:
	if not p.is_on_floor() and p.water_depth() <= 0.0:
		p.velocity.y -= p.GRAVITY * delta
		p.move_and_slide()
	if time_in_state >= RESPAWN_DELAY:
		p.respawn()
		return &"ground"
	return &""
