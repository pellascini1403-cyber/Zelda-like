class_name FireShyBehavior
extends AIBehavior
## Scatters from fire: campfires, braziers, burning grass and a player
## holding a flame. Light is a weapon against it.

var _t := 0.0


func pre_tick(delta: float) -> StringName:
	_t -= delta
	if _t > 0.0 or b.current.id() == &"flee":
		return &""
	_t = 0.4
	for h in c.get_tree().get_nodes_in_group(&"heat_source"):
		var p := (h as Node3D).global_position
		if p.distance_to(c.global_position) < float(param("fire_fear", 7.0)):
			b.flee_from = p
			return &"flee"
	return &""
