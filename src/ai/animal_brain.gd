class_name AnimalBrain
extends AIBrain
## Grazer behaviour. Awareness of the player (or a hunting enemy nearby)
## makes the whole herd bolt.

var _check := 0.0


func _register() -> void:
	for s: AIState in [IdleState.new(self), PatrolState.new(self), FleeState.new(self), SleepState.new(self), ReactState.new(self)]:
		states[s.id()] = s


func _initial_state() -> StringName:
	return &"idle"


func tick(delta: float) -> void:
	super.tick(delta)
	_check -= delta
	if _check > 0.0 or current.id() == &"flee":
		return
	_check = 0.4
	var skittish := float(c.type.ai_value("skittish", 0.35))
	if c.perception.awareness > skittish or c.perception.recently_heard(0.6):
		scare(Game.player.global_position if Game.player else c.global_position)
		return
	# Predators: enemies hunting nearby scare animals too.
	for e in c.get_tree().get_nodes_in_group(&"enemies"):
		if (e as Creature).global_position.distance_to(c.global_position) < 9.0 and not (e as Creature).dead:
			scare((e as Creature).global_position)
			return


func scare(from: Vector3) -> void:
	(states[&"flee"] as FleeState).threat = from
	change(&"flee")
	# Herd reaction
	if c.group_id != "":
		for other in c.get_tree().get_nodes_in_group(&"animals"):
			if other != c and (other as Creature).group_id == c.group_id and (other as Creature).brain.state_name() != &"flee":
				((other as Creature).brain.states[&"flee"] as FleeState).threat = from
				(other as Creature).brain.change(&"flee")


func on_hurt(source: Node3D) -> void:
	scare(source.global_position if source else c.global_position)
