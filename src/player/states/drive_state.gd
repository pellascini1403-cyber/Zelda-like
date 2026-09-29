class_name DriveState
extends PlayerState
## Driving a Vantrel vehicle: the vehicle body moves, the driver follows its
## seat (bikes: visible, seated; the capsule: enclosed, hidden). Move =
## heading + throttle (camera-relative), sprint = boost, jump = hold/release
## jump, attack = fire (capsule), interact = get out.


func state_name() -> StringName:
	return &"drive"


func anim() -> StringName:
	return &"ride"


func enter(_prev: StringName) -> void:
	p.velocity = Vector3.ZERO
	p.set_collision_enabled(false)
	if p.vehicle and p.vehicle.rider_hidden():
		p.visual.visible = false


func exit() -> void:
	p.set_collision_enabled(true)
	p.visual.visible = true


func physics(delta: float) -> StringName:
	var v := p.vehicle
	if v == null or not is_instance_valid(v):
		p.vehicle = null
		return &"air"
	var basis: Basis = Game.camera_rig.yaw_basis() if Game.camera_rig else Basis()
	var boost := Input.is_action_pressed("sprint") or InputRouter.touch_sprint
	v.drive(p.move_input(), basis, boost, Input.is_action_pressed("jump"), Input.is_action_just_released("jump"),
		Input.is_action_pressed("attack"), delta)
	if p.vehicle == null:
		return &"air"
	p.global_position = v.seat_position() - Vector3.UP * (0.55 if not v.rider_hidden() else 0.0)
	p.facing_yaw = v.heading
	p.velocity = v.velocity
	if Input.is_action_just_pressed("interact") and time_in_state > 0.35:
		p.exit_vehicle(false)
		return &""
	return &""
