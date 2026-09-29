class_name Interactor
extends Node
## Finds the best interactable in front of the player and exposes a single
## contextual prompt (the touch UI shows one button with that label).

const RANGE := 2.6
const MASK := 1 << 5

var current: Interactable
var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.1
	var p: Player = get_parent()
	if not p.physics_ready:
		return
	var best: Interactable = null
	if p.state_name() == &"ground":
		var q := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = RANGE
		q.shape = sphere
		q.transform = Transform3D(Basis(), p.global_position + Vector3.UP)
		q.collision_mask = MASK
		q.collide_with_areas = true
		q.collide_with_bodies = false
		var best_score := INF
		for h in p.get_world_3d().direct_space_state.intersect_shape(q, 16):
			var it := h["collider"] as Interactable
			if it == null or not it.can_interact():
				continue
			var to := it.global_position - p.global_position
			to.y = 0.0
			var score := to.length() + p.facing_dir().angle_to(to.normalized()) * 0.8
			if score < best_score:
				best_score = score
				best = it
	if best != current:
		current = best
		EventBus.interact_prompt_changed.emit(current.prompt_key() if current else "")


func try_interact() -> bool:
	if current == null or not is_instance_valid(current) or not current.can_interact():
		return false
	current.interact(get_parent())
	current = null
	_timer = 0.0
	EventBus.interact_prompt_changed.emit("")
	return true
