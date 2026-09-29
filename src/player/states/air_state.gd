class_name AirState
extends PlayerState
## Jumping and falling. Opens the glider, grabs walls, plunge attacks,
## fall damage on landing.

var _peak_fall_speed := 0.0


func state_name() -> StringName:
	return &"air"


func anim() -> StringName:
	return &"jump" if p.velocity.y > 0.0 else &"fall"


func allows_attack() -> bool:
	return true


func enter(_prev: StringName) -> void:
	_peak_fall_speed = 0.0


func physics(delta: float) -> StringName:
	var move := p.move_dir()
	var target := move * maxf(p.air_speed, p.RUN_SPEED * 0.6)
	p.apply_horizontal(target, p.AIR_ACCEL, delta)
	p.velocity.y -= p.GRAVITY * p.gravity_scale() * delta
	p.velocity.y = maxf(p.velocity.y, -p.TERMINAL_VELOCITY)
	_peak_fall_speed = maxf(_peak_fall_speed, -p.velocity.y)
	p.face_move(delta * 0.5)
	p.move_and_slide()
	p.coyote_timer -= delta

	if p.coyote_timer > 0.0 and p.consume_jump():
		p.do_jump()
		return &""
	if p.is_on_floor():
		p.land(_peak_fall_speed)
		return &"ground"
	if p.water_depth() > p.SWIM_DEPTH:
		return &"swim"
	# Glider: jump again while airborne with enough clearance.
	if Input.is_action_just_pressed("jump") and p.can_glide():
		return &"glide"
	# Grab walls when drifting into them
	if move != Vector3.ZERO and not p.vitals.exhausted and time_in_state > 0.15:
		var wall := p.probe_wall(move)
		if not wall.is_empty() and move.dot(-wall["normal"]) > 0.5:
			return &"climb"
	return &""
