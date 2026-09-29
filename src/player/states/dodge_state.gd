class_name DodgeState
extends PlayerState
## Roll with invulnerability frames. Dodging through an attack at the last
## moment (perfect dodge) slows time briefly: "Contratiempo".

const DURATION := 0.42
const DISTANCE := 4.6
const IFRAME_START := 0.04
const IFRAME_END := 0.3

var _dir := Vector3.FORWARD


func state_name() -> StringName:
	return &"dodge"


func enter(_prev: StringName) -> void:
	var move := p.move_dir()
	if move == Vector3.ZERO:
		# No input: backstep away from the target / facing
		move = -p.facing_dir()
	_dir = move.normalized()
	p.face_towards(_dir, 1.0, 100.0)
	p.visual.play_action(&"dodge", DURATION)
	Audio.play_at(&"dodge", p.global_position, -3.0)
	p.emit_noise(5.0)


func physics(delta: float) -> StringName:
	var t := time_in_state / DURATION
	p.invulnerable = time_in_state >= IFRAME_START and time_in_state <= IFRAME_END
	var speed := DISTANCE / DURATION * (1.4 - t * 0.8)
	p.velocity.x = _dir.x * speed
	p.velocity.z = _dir.z * speed
	p.velocity.y = -4.0 if p.is_on_floor() else p.velocity.y - p.GRAVITY * delta
	p.move_and_slide()
	if time_in_state >= DURATION:
		p.invulnerable = false
		return &"ground" if p.is_on_floor() else &"air"
	return &""


func exit() -> void:
	p.invulnerable = false


func is_perfect_window() -> bool:
	return time_in_state <= 0.22
