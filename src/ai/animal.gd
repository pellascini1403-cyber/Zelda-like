class_name Animal
extends Creature
## Wildlife: grazes, rests at night, startles and flees from the player,
## predators, fire and explosions. Part of the ecosystem, not a target dummy.


func _on_built() -> void:
	add_to_group(&"creatures")
	add_to_group(&"animals")
	EventBus.explosion.connect(_on_scare)
	EventBus.lightning_strike.connect(func(pos: Vector3) -> void: _on_scare(pos, 40.0))


func _make_brain() -> AIBrain:
	return AnimalBrain.new(self)


func _on_scare(pos: Vector3, radius: float) -> void:
	if dead or not is_inside_tree():
		return
	if global_position.distance_to(pos) < radius * 3.0:
		(brain as AnimalBrain).scare(pos)
