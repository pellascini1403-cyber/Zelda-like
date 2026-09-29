class_name StrikeTarget
extends StaticBody3D
## Static collider that forwards weapon hits to an owner (ore veins,
## breakable ruin walls). Lets non-creature objects join combat queries.

var target: Node


func take_damage(info: DamageInfo) -> void:
	if target and is_instance_valid(target) and target.has_method("on_struck"):
		target.on_struck(info)
