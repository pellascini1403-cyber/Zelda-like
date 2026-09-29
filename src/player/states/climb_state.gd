class_name ClimbState
extends PlayerState
## Free climbing on any steep surface (terrain cliffs, rock spires, trunks,
## ruin walls). A real system: stamina, stop & rest, climb-leap, ledge mantle,
## slipping on wet rock.

const STICK_DISTANCE := 0.45
const LEAP_COST := 22.0
const MOVE_COST := 8.0
const IDLE_COST := 1.2

var normal := Vector3.BACK
var _leap_time := 0.0
var _slip_timer := 0.0
var _mantle_t := -1.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO


func state_name() -> StringName:
	return &"climb"


func anim() -> StringName:
	if _mantle_t >= 0.0:
		return &"climb"
	return &"climb" if p.velocity.length() > 0.2 else &"climb_idle"


func enter(_prev: StringName) -> void:
	p.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	p.velocity = Vector3.ZERO
	_leap_time = 0.0
	_mantle_t = -1.0
	_slip_timer = 2.5
	var wall := p.probe_wall(p.facing_dir(), 1.0)
	if not wall.is_empty():
		normal = wall["normal"]
	Audio.play_at(&"grab", p.global_position, -6.0)


func exit() -> void:
	p.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED


func physics(delta: float) -> StringName:
	if _mantle_t >= 0.0:
		return _mantle(delta)

	var input := p.move_input()
	# Surface frame
	var up := (Vector3.UP - normal * normal.dot(Vector3.UP)).normalized()
	var right := up.cross(normal).normalized()
	var speed := p.CLIMB_SPEED * PlayerData.climb_speed_mult()
	var vel := (up * input.y + right * input.x) * speed

	# Climb-leap
	_leap_time -= delta
	if Input.is_action_just_pressed("jump"):
		if p.vitals.try_spend(LEAP_COST):
			var dir := up if input.length() < 0.3 else (up * input.y + right * input.x).normalized()
			_leap_time = 0.28
			p.leap_velocity = dir * 8.0
			Audio.play_at(&"jump", p.global_position, -4.0)
		else:
			return _let_go()
	if _leap_time > 0.0:
		vel = p.leap_velocity
	elif Input.is_action_just_pressed("drop") or Input.is_action_just_pressed("dodge"):
		return _let_go()

	# Wet rock: periodic slips when climbing upward
	if Weather.wetness > 0.35 and input.y > 0.2 and _leap_time <= 0.0:
		_slip_timer -= delta
		if _slip_timer <= 0.0:
			_slip_timer = randf_range(1.8, 3.2)
			p.global_position -= up * 0.9
			p.visual.play_action(&"hit", 0.3)
			Audio.play_at(&"slip", p.global_position, -4.0)

	# Stamina
	var moving := vel.length() > 0.1
	p.vitals.drain((MOVE_COST if moving else IDLE_COST) * delta)
	if p.vitals.stamina <= 0.0:
		EventBus.stamina_exhausted.emit()
		return _let_go()

	p.velocity = vel - normal * 1.5
	p.move_and_slide()
	p.face_towards(-normal, delta, 20.0)

	# Re-acquire the surface under the hands.
	var wall := p.probe_wall(-normal, 1.1)
	if wall.is_empty():
		# Nothing at chest height: are we at a ledge?
		if input.y > 0.1 or _leap_time > 0.0:
			var top: Variant = p.find_ledge_top(-normal)
			if top != null:
				return _start_mantle(top)
		return _let_go()
	normal = normal.slerp(wall["normal"], minf(delta * 12.0, 1.0)).normalized()
	var target_pos: Vector3 = wall["position"] + normal * STICK_DISTANCE
	var offset := target_pos - p.chest_position()
	p.global_position += offset * minf(delta * 10.0, 1.0)

	# Surface got walkable or we reached the ground
	if wall["normal"].y >= 0.62:
		return &"ground"
	if input.y < -0.2 and p.is_on_floor_probe():
		return &"ground"
	return &""


func _let_go() -> StringName:
	p.velocity = normal * 2.5 + Vector3.DOWN
	p.coyote_timer = 0.0
	return &"air"


func _start_mantle(top: Vector3) -> StringName:
	_mantle_t = 0.0
	_mantle_from = p.global_position
	_mantle_to = top + Vector3(0, 0.05, 0)
	p.visual.play_action(&"ledge_climb", 0.35)
	return &""


func _mantle(delta: float) -> StringName:
	_mantle_t += delta / 0.38
	var t := minf(_mantle_t, 1.0)
	var up_first := Vector3(_mantle_from.x, lerpf(_mantle_from.y, _mantle_to.y, smoothstep(0.0, 0.6, t)), _mantle_from.z)
	p.global_position = up_first.lerp(_mantle_to, smoothstep(0.4, 1.0, t))
	if t >= 1.0:
		_mantle_t = -1.0
		p.velocity = Vector3.ZERO
		return &"ground"
	return &""
