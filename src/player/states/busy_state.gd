class_name BusyState
extends PlayerState
## Short committed actions: attacks, stagger, gathering, eating, throwing.
## The combat component drives what happens; this state just holds the body.

var duration := 0.4
var anim_name: StringName = &"idle"
var slide := Vector3.ZERO
var return_state: StringName = &"ground"


func state_name() -> StringName:
	return &"busy"


func anim() -> StringName:
	return anim_name


func physics(delta: float) -> StringName:
	slide = slide.move_toward(Vector3.ZERO, 12.0 * delta)
	p.velocity.x = slide.x
	p.velocity.z = slide.z
	if p.is_on_floor():
		p.velocity.y = -2.0
	else:
		p.velocity.y -= p.GRAVITY * delta
	p.move_and_slide()
	if time_in_state >= duration:
		return return_state if p.is_on_floor() or return_state != &"ground" else &"air"
	return &""
