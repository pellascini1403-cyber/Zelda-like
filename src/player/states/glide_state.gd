class_name GlideState
extends PlayerState
## The Vela de Brisa: a kite-sail that turns height into distance.
## Physics-driven: inertia on turns, wind drift, thermals (updraft zones and
## fires) give lift. Loop: summit -> jump -> glide -> land -> explore.

const GLIDE_SPEED := 9.0
const SINK_SPEED := 2.0
const COST := 4.5


func state_name() -> StringName:
	return &"glide"


func enter(_prev: StringName) -> void:
	p.set_glider_visible(true)
	# Opening the sail brakes the fall.
	p.velocity.y = maxf(p.velocity.y, -3.0)
	Audio.play_at(&"glider_open", p.global_position, -2.0)
	InputRouter.vibrate(20, 0.3)


func exit() -> void:
	p.set_glider_visible(false)
	Audio.play_at(&"glider_close", p.global_position, -6.0)


func physics(delta: float) -> StringName:
	var move := p.move_dir()
	var fwd := p.facing_dir()
	# Steering: turn toward stick direction, keep momentum.
	if move != Vector3.ZERO:
		p.face_towards(move, delta, 2.8)
		fwd = p.facing_dir()
	var hspeed := GLIDE_SPEED * (1.0 if move != Vector3.ZERO else 0.75)
	var target := fwd * hspeed
	target += Weather.wind * Weather.wind_strength * 6.0
	p.apply_horizontal(target, 3.0, delta)

	var lift := p.updraft_lift()
	var target_vy := -SINK_SPEED + lift
	p.velocity.y = move_toward(p.velocity.y, target_vy, (9.0 if lift > 0.0 else 6.0) * delta)
	p.move_and_slide()

	p.vitals.drain(COST * PlayerData.glide_efficiency() * delta)
	if p.vitals.stamina <= 0.0:
		EventBus.stamina_exhausted.emit()
		return &"air"
	if p.is_on_floor():
		p.land(0.0)
		return &"ground"
	if p.water_depth() > 0.3:
		return &"swim"
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("drop"):
		return &"air"
	if move != Vector3.ZERO:
		var wall := p.probe_wall(p.facing_dir())
		if not wall.is_empty():
			return &"climb"
	return &""
