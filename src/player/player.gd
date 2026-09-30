class_name Player
extends CharacterBody3D
## The player body: movement state machine + shared physics helpers.
##
## Composition:
##   PlayerVitals  - stamina, exhaustion, temperature
##   PlayerCombat  - attacks, block/parry, damage intake, item use
##   Interactor    - context interaction prompts
##   EntityVisual  - placeholder (white) or final model; never gameplay
##
## Origin is at the feet. Collision comes from EntityType "PLAYER" data, so a
## final model with other proportions never changes how the player collides.

const WALK_SPEED := 2.3
const RUN_SPEED := 5.4
const SPRINT_SPEED := 8.2
const SPRINT_COST := 16.0
const GROUND_ACCEL := 38.0
const GROUND_DECEL := 46.0
const AIR_ACCEL := 9.0
const GRAVITY := 24.0
const TERMINAL_VELOCITY := 48.0
const JUMP_VELOCITY := 8.4
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const SWIM_DEPTH := 1.3
const DODGE_COST := 14.0
const CLIMB_SPEED := 2.0
const FALL_DAMAGE_SPEED := 19.0
const GLIDE_MIN_CLEARANCE := 2.6

var type: EntityType
var visual: EntityVisual
var vitals: PlayerVitals
var combat: PlayerCombat
var interactor: Interactor
var abilities: PlayerAbilities
var mount: Mount = null
var vehicle: Vehicle = null
var health: Health

var state: PlayerState
var states: Dictionary = {}
var sprinting := false
var blocking := false
var invulnerable := false
var air_jumps_used := 0
var coyote_timer := 0.0
var air_speed := 0.0
var leap_velocity := Vector3.ZERO
var facing_yaw := 0.0
var region: StringName = &"valley"
var physics_ready := false

var _jump_buffer := 0.0
var _noise_cooldown := 0.0
var _safe_timer := 0.0
var _glider: Node3D
var _lightning_pending := -1.0
var _region_timer := 0.0
var _step_timer := 0.0
var _world_gen: WorldGen


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 1 << 1
	collision_mask = 1 | (1 << 2) | (1 << 3)
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.45
	type = DB.entity(&"PLAYER")
	var shape := CapsuleShape3D.new()
	shape.radius = type.collider_radius
	shape.height = type.collider_height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = type.collider_height * 0.5
	add_child(cs)

	visual = EntityVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(type)

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(PlayerData.max_health, 30.0, 0.0, {})

	vitals = PlayerVitals.new()
	vitals.name = "Vitals"
	add_child(vitals)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)
	interactor = Interactor.new()
	interactor.name = "Interactor"
	add_child(interactor)
	var trail := WeaponTrail.new()
	trail.name = "WeaponTrail"
	trail.p = self
	add_child(trail)
	var glide_trail := GlideTrail.new()
	glide_trail.name = "GlideTrail"
	glide_trail.p = self
	add_child(glide_trail)
	abilities = PlayerAbilities.new()
	abilities.name = "Abilities"
	add_child(abilities)

	_glider = GliderVisual.build()
	visual.get_socket(&"back").add_child(_glider)
	_glider.visible = false

	for s: PlayerState in [GroundState.new(self), AirState.new(self), ClimbState.new(self), GlideState.new(self),
			SwimState.new(self), DodgeState.new(self), BusyState.new(self), DeadState.new(self),
			GustState.new(self), RideState.new(self), DriveState.new(self)]:
		states[s.state_name()] = s
	state = states[&"ground"]
	_world_gen = WorldGen.from_world_data(DB.world)
	Game.player = self
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if not physics_ready:
		return
	# Streaming guard: never simulate over ground whose collision isn't loaded
	# yet (after a teleport, a respawn or a very fast glide). Hold position.
	var gw := Game.world as GameWorld
	if gw and gw.streamer and not gw.streamer.has_collision_at(global_position):
		velocity = Vector3.ZERO
		return
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	else:
		_jump_buffer -= delta
	_noise_cooldown -= delta
	health.tick(delta)

	combat.pre_physics(delta)
	state.time_in_state += delta
	var next := state.physics(delta)
	if next != &"" and next != state.state_name():
		change_state(next)

	var regen := state.state_name() in [&"ground", &"busy", &"dead"] and not sprinting
	vitals.tick(delta, regen, global_position, region)
	_update_visual(delta)
	_update_region(delta)
	_update_lightning(delta)
	_footsteps(delta)
	RenderingServer.global_shader_parameter_set(&"player_pos", global_position)
	if global_position.y < -80.0:
		respawn()


func change_state(n: StringName) -> void:
	var prev := state.state_name()
	state.exit()
	state = states[n]
	state.time_in_state = 0.0
	state.enter(prev)
	EventBus.player_state_changed.emit(n)


func state_name() -> StringName:
	return state.state_name()


# --- Mounts ---------------------------------------------------------------------------------------
func ride(m: Mount) -> void:
	if mount != null or vehicle != null or state_name() in [&"dead", &"climb", &"swim", &"glide"]:
		return
	mount = m
	m.start_ride(self)
	change_state(&"ride")


## Leaves the saddle; `thrown` knocks the rider aside.
func dismount(thrown: bool) -> void:
	var m := mount
	if m == null:
		return
	mount = null
	m.end_ride()
	var side := m.facing_dir().cross(Vector3.UP).normalized()
	global_position = m.global_position + side * (m.type.collider_radius + 0.8) + Vector3.UP * 0.6
	velocity = side * (6.0 if thrown else 2.0) + Vector3.UP * (5.0 if thrown else 2.5)
	if state_name() == &"ride":
		change_state(&"air")


# --- Vehicles ------------------------------------------------------------------------------------
func enter_vehicle(v: Vehicle) -> void:
	if vehicle != null or mount != null or v.driver != null:
		return
	if state_name() in [&"dead", &"climb", &"glide", &"busy"]:
		return
	if state_name() == &"swim" and not v.is_capsule():
		return
	vehicle = v
	v.start_drive(self)
	change_state(&"drive")


## Steps out at the side with the most room (never inside a rock or an NPC).
## `thrown`: knocked off by a big hit or a wrecked hull.
func exit_vehicle(thrown: bool) -> void:
	var v := vehicle
	if v == null:
		return
	vehicle = null
	v.end_drive()
	var side := v.facing_dir().cross(Vector3.UP).normalized()
	var dist := float(v.def.get("exit_side", 1.4))
	var spot := v.global_position + side * dist
	for cand in [v.global_position + side * dist, v.global_position - side * dist, v.global_position - v.facing_dir() * (dist + 1.0)]:
		if VehicleManager.spot_is_free(get_world_3d(), cand + Vector3.UP * 0.9, Vector3(0.7, 1.6, 0.7), [v.get_rid()]):
			spot = cand
			break
	spot.y = maxf(spot.y, _world_gen.height(spot.x, spot.z)) + 0.3
	global_position = spot
	velocity = side * (5.0 if thrown else 1.0) + Vector3.UP * (5.0 if thrown else 2.0)
	if state_name() == &"drive":
		change_state(&"swim" if water_depth() > SWIM_DEPTH else &"air")


## Levity fields (Veil) lighten gravity. Cheap: a handful of zones at most.
func gravity_scale() -> float:
	var g := 1.0
	for z in get_tree().get_nodes_in_group(&"levity"):
		g = minf(g, (z as LevityZone).scale_at(global_position))
	return g


func set_collision_enabled(on: bool) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not on)


## Commit to a short action (attack swing, stagger, gather, eat).
func start_busy(anim_name: StringName, duration: float, slide: Vector3 = Vector3.ZERO, return_to: StringName = &"ground") -> void:
	var b: BusyState = states[&"busy"]
	b.anim_name = anim_name
	b.duration = duration
	b.slide = slide
	b.return_state = return_to
	if state == b:
		b.time_in_state = 0.0
	else:
		change_state(&"busy")


# --- Intent -----------------------------------------------------------------------------------
func move_input() -> Vector2:
	return InputRouter.get_move()


## World-space move direction relative to the camera.
func move_dir() -> Vector3:
	var i := move_input()
	if i == Vector2.ZERO:
		return Vector3.ZERO
	var basis: Basis = Game.camera_rig.yaw_basis() if Game.camera_rig else Basis()
	var d: Vector3 = basis * Vector3(i.x, 0, -i.y)
	d.y = 0.0
	return d.normalized() * minf(i.length(), 1.0)


func wants_sprint() -> bool:
	return InputRouter.wants_sprint()


func consume_jump() -> bool:
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		return true
	return false


# --- Physics helpers ----------------------------------------------------------------------------
func apply_horizontal(target: Vector3, accel: float, delta: float) -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	h = h.move_toward(Vector3(target.x, 0, target.z), accel * delta)
	velocity.x = h.x
	velocity.z = h.z


func do_jump() -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	air_speed = h.length()
	velocity.y = JUMP_VELOCITY
	if sprinting:
		# Sprint jump: longer, flatter.
		velocity.x *= 1.25
		velocity.z *= 1.25
		air_speed *= 1.25
		velocity.y *= 0.92
	Audio.play_at(&"jump", global_position, -6.0)
	visual.play_action(&"jump", 0.3)


func land(fall_speed: float) -> void:
	air_speed = 0.0
	if fall_speed > FALL_DAMAGE_SPEED and not Debug.god_mode:
		var d := DamageInfo.make((fall_speed - FALL_DAMAGE_SPEED) * 4.5, null)
		d.kind = &"fall"
		d.blockable = false
		take_damage(d)
		Game.camera_rig.add_trauma(0.5)
	elif fall_speed > 8.0:
		Game.camera_rig.add_trauma(0.15)
	if fall_speed > 4.0:
		Audio.play_at(&"land", global_position, -4.0)
		spawn_dust(0.6)
		visual.play_action(&"land", clampf(fall_speed * 0.025, 0.15, 0.4))


func face_move(delta: float) -> void:
	if combat.lock_target_valid() and state.state_name() == &"ground":
		var to := combat.lock_target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			face_towards(to.normalized(), delta, 12.0)
		return
	var h := Vector3(velocity.x, 0, velocity.z)
	if h.length() > 0.4:
		face_towards(h.normalized(), delta, 12.0)


func face_towards(dir: Vector3, delta: float, rate: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target := atan2(-dir.x, -dir.z)
	facing_yaw = lerp_angle(facing_yaw, target, minf(rate * delta, 1.0))


func facing_dir() -> Vector3:
	return Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))


func chest_position() -> Vector3:
	return global_position + Vector3(0, type.collider_height * 0.6, 0)


## Steep, climbable surface in `dir` at chest height. {position, normal} or {}.
func probe_wall(dir: Vector3, length: float = 0.9) -> Dictionary:
	if dir == Vector3.ZERO:
		return {}
	var from := chest_position()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * (type.collider_radius + length), 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var n: Vector3 = hit["normal"]
	if n.y > 0.6 or n.y < -0.5:
		return {}
	return {"position": hit["position"], "normal": n}


## Top of a ledge in front, for mantling. Returns Vector3 or null.
func find_ledge_top(dir: Vector3) -> Variant:
	var from := chest_position() + Vector3.UP * 1.3 + dir.normalized() * 0.7
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.8, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit["normal"].y < 0.65:
		return null
	return hit["position"]


func ground_distance(max_dist: float = 50.0) -> float:
	var from := global_position + Vector3.UP * 0.2
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * max_dist, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return max_dist if hit.is_empty() else from.y - hit["position"].y - 0.2


func is_on_floor_probe() -> bool:
	return is_on_floor() or ground_distance(0.6) < 0.35


func water_depth() -> float:
	return WorldGen.SEA_LEVEL - global_position.y


func can_glide() -> bool:
	return PlayerData.has_glider() and not vitals.exhausted and vitals.stamina > 1.0 and ground_distance(GLIDE_MIN_CLEARANCE + 1.0) > GLIDE_MIN_CLEARANCE


## Upward lift from thermals near the player (updraft zones, fires).
func updraft_lift() -> float:
	var lift := 0.0
	for z in get_tree().get_nodes_in_group(&"updraft"):
		lift = maxf(lift, z.lift_at(global_position))
	return lift


func terrain_speed_mult() -> float:
	# Deep snow slows you down a little; webs and cold slow you more.
	var m := 0.85 if global_position.y > _world_gen.snow_line() else 1.0
	if health.has_status(&"webbed"):
		m *= 0.5
	elif health.has_status(&"chilled"):
		m *= 0.8
	return m


func emit_noise(radius: float) -> void:
	if _noise_cooldown > 0.0:
		return
	_noise_cooldown = 0.4
	EventBus.noise_emitted.emit(global_position, radius, self)


func track_safe_ground(delta: float) -> void:
	_safe_timer -= delta
	if _safe_timer > 0.0:
		return
	_safe_timer = 2.0
	if is_on_floor() and not Game.in_combat and water_depth() < 0.0 and get_floor_normal().y > 0.8:
		WorldState.last_safe_position = global_position


# --- Damage / death --------------------------------------------------------------------------------
func take_damage(info: DamageInfo) -> void:
	if vehicle and vehicle.rider_hidden():
		vehicle.take_damage(info)   # the hull shields the driver
		return
	if vehicle and not invulnerable and info.amount >= 18.0:
		exit_vehicle(true)
	if mount and not invulnerable and info.amount >= 18.0:
		dismount(true)
	combat.receive(info)


func is_dead() -> bool:
	return state.state_name() == &"dead"


func drown() -> void:
	var d := DamageInfo.make(15.0, null)
	d.kind = &"environment"
	d.blockable = false
	PlayerData.health = maxf(PlayerData.health - d.amount, 1.0)
	EventBus.toast.emit(tr("TOAST_EXHAUSTED_WATER"))


func respawn() -> void:
	if vehicle:
		exit_vehicle(false)
	var pos := WorldState.last_safe_position
	if pos == Vector3.ZERO:
		var sp: Array = DB.world.get("spawn", [0, 20, 0])
		pos = Vector3(sp[0], sp[1], sp[2])
	global_position = pos + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	if PlayerData.health <= 0.0:
		PlayerData.health = PlayerData.max_health
	PlayerData.stamina = PlayerData.max_stamina
	vitals.exhausted = false
	health.statuses.clear()
	visual.setup(type)
	_glider = GliderVisual.build()
	visual.get_socket(&"back").add_child(_glider)
	_glider.visible = false
	combat.refresh_weapon_visual()
	if state.state_name() != &"ground":
		change_state(&"ground")
	EventBus.player_respawned.emit()


func is_in_critical_state() -> bool:
	return state.state_name() in [&"climb", &"glide", &"swim", &"air", &"dead", &"drive"]


# --- Lightning (storm + metal) ------------------------------------------------------------------------
func attracts_lightning() -> bool:
	return PlayerData.carries_metal() and not PlayerData.lightning_immune()


func lightning_warning() -> void:
	if _lightning_pending > 0.0:
		return
	_lightning_pending = 2.6
	EventBus.toast.emit(tr("TOAST_LIGHTNING_WARNING"))
	InputRouter.vibrate(60, 0.6)
	Effects.sparks(self, global_position + Vector3.UP * 2.0, Color(1.0, 0.95, 0.5), 2.6)


func _update_lightning(delta: float) -> void:
	if _lightning_pending <= 0.0:
		return
	_lightning_pending -= delta
	if _lightning_pending <= 0.0:
		_lightning_pending = -1.0
		# Unequipping metal in time avoids the strike.
		var pos := global_position if attracts_lightning() else global_position + Vector3(randf_range(6, 12), 0, randf_range(6, 12))
		EventBus.lightning_strike.emit(pos)


# --- Visual sync ---------------------------------------------------------------------------------------------
func _update_visual(delta: float) -> void:
	visual.rotation.y = facing_yaw
	var hs := Vector2(velocity.x, velocity.z).length()
	visual.set_locomotion(hs / RUN_SPEED, state.anim())


func set_glider_visible(v: bool) -> void:
	if _glider:
		_glider.visible = v


func spawn_dust(amount: float) -> void:
	Effects.dust(self, global_position, amount)


func spawn_splash() -> void:
	Effects.splash(self, Vector3(global_position.x, WorldGen.SEA_LEVEL, global_position.z))


func _update_region(delta: float) -> void:
	_region_timer -= delta
	if _region_timer > 0.0:
		return
	_region_timer = 1.0
	var r := _world_gen.region_at(global_position.x, global_position.z)
	if r != region:
		region = r
		EventBus.region_entered.emit(r)
	WorldState.explore(global_position, 2)


func _footsteps(delta: float) -> void:
	if state.state_name() != &"ground" or not is_on_floor():
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs < 0.5:
		return
	_step_timer -= delta * hs
	if _step_timer <= 0.0:
		_step_timer = 1.6
		var n := get_floor_normal()
		var surface := _world_gen.surface_at(global_position.x, global_position.z, global_position.y, n)
		var id := &"step_grass"
		match surface:
			WorldGen.Surface.ROCK: id = &"step_stone"
			WorldGen.Surface.SNOW: id = &"step_snow"
			WorldGen.Surface.SAND: id = &"step_sand"
		Audio.play_at(id, global_position, -12.0 + minf(hs, 8.0), 0.12)


# --- Save --------------------------------------------------------------------------------------------------------
func save_state() -> Dictionary:
	var pos := global_position
	# Never save mid-air / mid-climb positions: use the last safe spot instead.
	if state.state_name() != &"ground" and WorldState.last_safe_position != Vector3.ZERO:
		pos = WorldState.last_safe_position
	return {"pos": [pos.x, pos.y, pos.z], "yaw": facing_yaw}


func load_state(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	facing_yaw = d.get("yaw", 0.0)
