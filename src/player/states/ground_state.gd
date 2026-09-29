class_name GroundState
extends PlayerState
## Walk / run / sprint, jump, entry point for climb, dodge and interaction.

var _wall_push_time := 0.0


func state_name() -> StringName:
	return &"ground"


func anim() -> StringName:
	if p.blocking:
		return &"block"
	var s := Vector2(p.velocity.x, p.velocity.z).length()
	if s < 0.3:
		return &"idle"
	return &"sprint" if p.sprinting else (&"run" if s > 3.0 else &"walk")


func allows_attack() -> bool:
	return true


func allows_block() -> bool:
	return true


func enter(_prev: StringName) -> void:
	_wall_push_time = 0.0
	p.air_jumps_used = 0


func physics(delta: float) -> StringName:
	var move := p.move_dir()
	var input_len := p.move_input().length()
	var exhausted := p.vitals.exhausted
	p.sprinting = p.wants_sprint() and input_len > 0.3 and not exhausted and not p.blocking and p.vitals.stamina > 0.0
	var speed: float
	if p.blocking:
		speed = p.WALK_SPEED * 0.7
	elif exhausted:
		speed = p.WALK_SPEED
	elif p.sprinting:
		speed = p.SPRINT_SPEED
		p.vitals.drain(p.SPRINT_COST * delta)
	elif input_len < 0.55:
		speed = p.WALK_SPEED
	else:
		speed = p.RUN_SPEED
	speed *= PlayerData.speed_mult() * p.terrain_speed_mult()
	p.apply_horizontal(move * speed * minf(input_len * 1.4, 1.0), p.GROUND_ACCEL if move != Vector3.ZERO else p.GROUND_DECEL, delta)
	p.velocity.y = -2.0
	p.face_move(delta)
	p.move_and_slide()

	if p.sprinting:
		p.emit_noise(11.0)
	elif move != Vector3.ZERO:
		p.emit_noise(3.0)

	if not p.is_on_floor():
		p.coyote_timer = p.COYOTE_TIME
		return &"air"
	if p.water_depth() > p.SWIM_DEPTH:
		return &"swim"
	if p.consume_jump():
		p.do_jump()
		return &"air"
	if Input.is_action_just_pressed("dodge") and p.vitals.try_spend(p.DODGE_COST):
		return &"dodge"
	if Input.is_action_just_pressed("interact"):
		p.interactor.try_interact()
	# Climb: keep pushing toward a steep surface for a moment
	if move != Vector3.ZERO and not exhausted and not p.blocking:
		var wall := p.probe_wall(move)
		if not wall.is_empty() and move.dot(-wall["normal"]) > 0.55:
			_wall_push_time += delta
			if _wall_push_time > 0.12:
				return &"climb"
		else:
			_wall_push_time = 0.0
	p.track_safe_ground(delta)
	return &""
