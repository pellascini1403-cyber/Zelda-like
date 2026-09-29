class_name GustState
extends PlayerState
## Gust Step: a short wind-borne dash (ground or air) with a sliver of
## invulnerability. Refreshes the air jump so it chains with the Vela.

var dir := Vector3.FORWARD
var distance := 8.0
var duration := 0.22


func state_name() -> StringName:
	return &"gust"


func anim() -> StringName:
	return &"dodge"


func enter(_prev: StringName) -> void:
	var move := p.move_dir()
	dir = (move if move != Vector3.ZERO else p.facing_dir()).normalized()
	p.face_towards(dir, 1.0, 100.0)
	p.invulnerable = true
	p.visual.play_action(&"dodge", duration)
	ElementFX.ring(p, p.chest_position(), &"wind", 1.4, 0.25)
	Afterimage.spawn(p.visual, Color(0.6, 1.0, 0.85), 0.35)
	Audio.play_at(&"gust", p.global_position, -2.0)


func physics(delta: float) -> StringName:
	var speed := distance / duration
	p.velocity = dir * speed
	p.velocity.y = 0.6
	p.move_and_slide()
	if time_in_state >= duration:
		p.invulnerable = false
		p.velocity = dir * 6.0 + Vector3.UP * 1.5
		p.air_jumps_used = 0
		return &"ground" if p.is_on_floor() else &"air"
	return &""


func exit() -> void:
	p.invulnerable = false
