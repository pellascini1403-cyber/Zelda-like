class_name RideState
extends PlayerState
## Riding: the mount body moves, the rider follows the seat. Jump = mount
## jump, sprint = spur (limited, regenerating), interact = dismount. Taking a
## heavy hit or failing to tame throws the rider off.


func state_name() -> StringName:
	return &"ride"


func anim() -> StringName:
	return &"ride"


func enter(_prev: StringName) -> void:
	p.velocity = Vector3.ZERO
	p.set_collision_enabled(false)


func exit() -> void:
	p.set_collision_enabled(true)


func physics(delta: float) -> StringName:
	var mt := p.mount
	if mt == null or not is_instance_valid(mt) or mt.dead:
		p.mount = null
		return &"air"
	var basis: Basis = Game.camera_rig.yaw_basis() if Game.camera_rig else Basis()
	var still_on := mt.drive(p.move_input(), basis, Input.is_action_just_pressed("sprint") or InputRouter.touch_sprint and time_in_state > 0.2, Input.is_action_just_pressed("jump"), delta)
	if not still_on or p.mount == null:
		return &"air"
	p.global_position = mt.seat()
	p.facing_yaw = mt.facing_yaw
	p.velocity = mt.velocity
	if Input.is_action_just_pressed("interact") and time_in_state > 0.3 and mt.taming <= 0.0:
		p.dismount(false)
		return &"air"
	return &""
