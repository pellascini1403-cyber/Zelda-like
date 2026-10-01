class_name CameraRig
extends Node3D
## Third-person camera.
##
## * Context distance/FOV: wide for exploration, tight in combat, far while
##   gliding (read the landscape), close while climbing (read the wall).
## * Lock-on frames player + target.
## * Gentle auto-recenter behind the direction of travel (toggleable).
## * Sphere-cast collision: never clips through terrain or walls; pulls in
##   fast, eases back out slowly.
## * Trauma-based shake for impacts.

const PIVOT_HEIGHT := 1.55
const PITCH_MIN := -72.0
const PITCH_MAX := 55.0
const BASE_FOV := 70.0
const COLLISION_RADIUS := 0.28

var target: Player
var yaw := 0.0
var pitch := -12.0
var distance := 5.5
var trauma := 0.0

var camera: Camera3D
var _pivot := Vector3.ZERO
var _current_distance := 5.5
var _idle_look_time := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	top_level = true
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = BASE_FOV
	camera.near = 0.15
	camera.far = 2400.0
	add_child(camera)
	camera.make_current()
	_noise.frequency = 2.0
	Game.camera_rig = self


func snap_to_target() -> void:
	if target == null:
		return
	_pivot = target.global_position + Vector3.UP * PIVOT_HEIGHT
	yaw = target.facing_yaw
	_current_distance = distance
	_update_transform(0.0)


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw))


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_t += delta
	var look := InputRouter.consume_look(delta)
	yaw -= look.x
	pitch = clampf(pitch - look.y, PITCH_MIN, PITCH_MAX)
	if look.length() > 0.01:
		_idle_look_time = 0.0
	else:
		_idle_look_time += delta

	var st := target.state_name()
	var locked := target.combat.lock_target_valid()
	var want_dist := 5.5
	var want_fov := BASE_FOV
	match st:
		&"glide":
			want_dist = 8.0
			want_fov = BASE_FOV + 10.0
		&"climb":
			want_dist = 5.0
		&"swim":
			want_dist = 5.2
	if target.sprinting:
		want_dist = 6.2
		want_fov = BASE_FOV + 6.0
	if Game.in_combat or locked:
		want_dist = minf(want_dist, 4.6)

	# Lock-on: steer yaw so both player and target stay framed.
	if locked:
		var to := target.combat.lock_target.global_position - target.global_position
		var target_yaw := rad_to_deg(atan2(-to.x, -to.z))
		yaw = rad_to_deg(lerp_angle(deg_to_rad(yaw), deg_to_rad(target_yaw), minf(delta * 5.0, 1.0)))
		pitch = lerpf(pitch, -14.0, delta * 3.0)
	elif Settings.get_value("auto_camera") and _idle_look_time > 1.2 and st in [&"ground", &"glide", &"swim"]:
		# Recenter behind the direction of travel, only when moving forward-ish.
		var hv := Vector3(target.velocity.x, 0, target.velocity.z)
		if hv.length() > 2.0:
			var travel_yaw := rad_to_deg(atan2(-hv.x, -hv.z))
			var diff := wrapf(travel_yaw - yaw, -180.0, 180.0)
			if absf(diff) < 120.0:
				yaw += diff * minf(delta * 0.9, 1.0)
			if st == &"glide":
				pitch = lerpf(pitch, -18.0, delta * 0.8)

	distance = lerpf(distance, want_dist, minf(delta * 3.0, 1.0))
	camera.fov = lerpf(camera.fov, want_fov, minf(delta * 4.0, 1.0))

	# Follow with separate horizontal / vertical smoothing (steps don't jolt).
	var goal := target.global_position + Vector3.UP * PIVOT_HEIGHT
	_pivot.x = lerpf(_pivot.x, goal.x, minf(delta * 14.0, 1.0))
	_pivot.z = lerpf(_pivot.z, goal.z, minf(delta * 14.0, 1.0))
	_pivot.y = lerpf(_pivot.y, goal.y, minf(delta * (10.0 if st == &"climb" else 7.0), 1.0))
	_update_transform(delta)


func _update_transform(delta: float) -> void:
	var rot := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
	var back := rot * Vector3(0, 0, 1)
	var free_dist := _collision_distance(_pivot, back, distance)
	if free_dist < _current_distance or delta == 0.0:
		_current_distance = free_dist
	else:
		_current_distance = lerpf(_current_distance, free_dist, minf(delta * 2.5, 1.0))
	global_position = _pivot + back * _current_distance
	global_basis = rot
	# Shake
	trauma = maxf(trauma - delta * 1.6, 0.0)
	var s := trauma * trauma
	camera.rotation = Vector3(
		_noise.get_noise_2d(_t * 60.0, 0.0) * 0.06 * s,
		_noise.get_noise_2d(0.0, _t * 60.0) * 0.06 * s,
		_noise.get_noise_2d(_t * 60.0, 100.0) * 0.04 * s)
	camera.position = Vector3.ZERO


func _collision_distance(from: Vector3, dir: Vector3, dist: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = COLLISION_RADIUS
	q.shape = sphere
	q.transform = Transform3D(Basis(), from)
	q.motion = dir * dist
	q.collision_mask = 1
	var res := space.cast_motion(q)
	if res.is_empty():
		return dist
	return maxf(dist * res[0] - 0.05, 0.4)
