class_name SwimState
extends PlayerState
## Surface swimming. Stamina is the limit: the open sea is a real barrier
## early on, lakes and rivers are routes. Exhaustion = drown -> respawn.

const SWIM_SPEED := 2.8
const DASH_SPEED := 5.2
const DASH_COST := 14.0
const TREAD_COST := 1.8
const FLOAT_OFFSET := 1.35


func state_name() -> StringName:
	return &"swim"


func enter(_prev: StringName) -> void:
	p.velocity.y *= 0.2
	p.health.add_status(&"wet", 10.0)
	p.health.remove_status(&"burning")
	Audio.play_at(&"splash", p.global_position)
	p.spawn_splash()


func physics(delta: float) -> StringName:
	var move := p.move_dir()
	var dashing := p.wants_sprint() and move != Vector3.ZERO and p.vitals.stamina > 0.0
	var speed := DASH_SPEED if dashing else SWIM_SPEED
	var drift := SeaCurrent.drift_at(p.global_position, p.get_tree())
	p.apply_horizontal(move * speed * PlayerData.speed_mult() * (1.0 + PlayerData.armor_bonus("swim_speed")) + drift, 6.0, delta)
	var surface := WorldGen.SEA_LEVEL - FLOAT_OFFSET
	p.velocity.y = (surface - p.global_position.y) * 4.0
	p.face_move(delta * 0.6)
	p.move_and_slide()
	p.vitals.drain((DASH_COST if dashing else TREAD_COST) * delta)
	p.health.add_status(&"wet", 5.0)
	if p.vitals.stamina <= 0.0:
		p.drown()
		return &"dead"
	if p.water_depth() < p.SWIM_DEPTH - 0.25 and p.is_on_floor_probe():
		return &"ground"
	# Dive: only where there is water below worth diving into.
	if Input.is_action_just_pressed("dodge") and p.vitals.stamina > 12.0 and p.ground_distance(4.0) > 2.2:
		return &"dive"
	if p.consume_jump() and p.vitals.try_spend(10.0):
		p.velocity.y = 5.0
		return &"air"
	# Climb out onto steep banks
	if move != Vector3.ZERO:
		var wall := p.probe_wall(move)
		if not wall.is_empty() and move.dot(-wall["normal"]) > 0.5:
			return &"climb"
	return &""
