class_name LevityZone
extends Node3D
## Supernatural low-gravity field (the Veil's drifting isles): inside the
## radius the player falls slower and jumps higher. Queried by the player
## through the "levity" group; no physics areas needed.

var radius := 100.0
var gravity_scale := 0.45


func _ready() -> void:
	add_to_group(&"levity")


func scale_at(pos: Vector3) -> float:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	if d > radius:
		return 1.0
	return lerpf(gravity_scale, 1.0, smoothstep(radius * 0.75, radius, d))
