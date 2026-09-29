class_name Interactable
extends Area3D
## Base for anything the player can use with the context button: resource
## nodes, chests, campfires, NPCs, pickups, readable lore.

@export var radius := 0.9


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	cs.shape = s
	cs.position.y = 0.6
	add_child(cs)


func prompt_key() -> String:
	return "PROMPT_USE"


func can_interact() -> bool:
	return true


func interact(_player: Player) -> void:
	pass
