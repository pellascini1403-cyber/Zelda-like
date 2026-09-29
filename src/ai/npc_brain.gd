class_name NPCBrain
extends AIBrain
## Routine-following: walk to the scheduled spot, idle there, face the
## player while talking.

var talking := false


func _register() -> void:
	for s: AIState in [IdleState.new(self), PatrolState.new(self), RoutineState.new(self)]:
		states[s.id()] = s


func _initial_state() -> StringName:
	return &"routine"


func tick(delta: float) -> void:
	if talking and Game.player:
		c.stop()
		c.face_towards(Game.player.global_position - c.global_position, delta)
		return
	super.tick(delta)
