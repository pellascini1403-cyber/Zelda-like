class_name Vehicle
extends CharacterBody3D
## A premium vehicle's gameplay body (data: data/vehicles.json). Arcade
## handling tuned per class, never a wheel/suspension simulation (mobile):
##
##   heavy   — fastest; heavy acceleration, wide turns at speed, boost gauge.
##   light   — agile; charge-jump (hold/release), air control, landing boost.
##   capsule — slowest; real land_mode / water_mode switch (terrain vs water
##             under the hull), floats and steers on water, fires its chin
##             barrels (heat-limited, reduced against bosses), armoured hull.
##
## The look is VehicleVisual (placeholder or the final model). The driver is
## the Player in DriveState; this body owns speed, heading and collisions.

signal mode_changed(mode: StringName)

const GRAVITY := 24.0
const WATER_ENTER_DEPTH := 0.7     # water under the hull deeper than this = float
const WATER_EXIT_DEPTH := 0.35     # ground this close to the surface = drive out
const BIKE_WADE_LIMIT := 0.55      # bikes refuse water deeper than this

var id: StringName
var def: Dictionary
var h: Dictionary
var visual: VehicleVisual
var driver: Player = null
var speed := 0.0                   # signed, along the heading
var heading := 0.0                 # yaw (0 = -Z)
var mode: StringName = &"land_mode"
var transform_t := 0.0             # 0 land .. 1 water (capsule)
var boost_left := 0.0
var boosting := false
var heat := 0.0
var overheated := 0.0
var hull := 0.0
var hull_max := 0.0
var disabled_for := 0.0            # wrecked hull: cannot be summoned for a while
var grounded := true
var air_time := 0.0
var charge := 0.0
var _cooldown := 0.0
var _muzzle_i := 0
var _steer := 0.0
var _engine: AudioStreamPlayer3D
var _wake: CPUParticles3D
var _gen: WorldGen
var _water_warned := false
var _land_speed := 0.0


func setup(vehicle_id: StringName) -> void:
	id = vehicle_id
	def = DB.vehicles.get(vehicle_id, {})
	h = def.get("handling", {})
	hull_max = float(def.get("hull", 0))
	hull = hull_max
	boost_left = float(h.get("boost_seconds", 0.0))


func _ready() -> void:
	add_to_group(&"vehicles")
	# Layer 2 (the player's): enemy blows, projectiles and creatures treat a
	# driven vehicle like its driver's body.
	collision_layer = 1 << 1
	collision_mask = 1 | (1 << 2) | (1 << 3)
	floor_max_angle = acos(float(h.get("slope_limit", 0.6)))
	floor_snap_length = 0.7
	floor_stop_on_slope = true
	var col: Dictionary = def.get("collider", {})
	var shape := BoxShape3D.new()
	var r := float(col.get("radius", 0.5))
	var hh := float(col.get("height", 1.2))
	shape.size = Vector3(r * 2.0, hh - 0.3, float(col.get("length", 2.0)))
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.3 + (hh - 0.3) * 0.5
	add_child(cs)
	visual = VehicleVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(def)
	_engine = AudioStreamPlayer3D.new()
	_engine.bus = &"SFX"
	_engine.unit_size = 8.0
	_engine.max_distance = 70.0
	_engine.stream = Audio._get_stream(StringName(def.get("sound", {}).get("engine", "")))
	_engine.volume_db = -8.0
	add_child(_engine)
	_gen = WorldGen.from_world_data(DB.world)
	if String(def.get("class", "")) == "capsule":
		_wake = _make_wake()
		add_child(_wake)
	rotation.y = heading


func is_capsule() -> bool:
	return String(def.get("class", "")) == "capsule"


func is_bike() -> bool:
	return not is_capsule()


func rider_hidden() -> bool:
	return String(def.get("rider", "seated")) == "enclosed"


func facing_dir() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


func seat_position() -> Vector3:
	return visual.seat().global_position


func max_speed() -> float:
	if mode == &"water_mode":
		return float(h.get("water_speed", 6.0))
	var m := float(h.get("max_speed", 10.0))
	if boosting:
		m = float(h.get("boost_speed", m))
	return m * _weather_mult()


## Rain/snow cost grip, sandstorms cost speed (world matters to machines).
func _weather_mult() -> float:
	match Weather.current:
		&"sandstorm": return 0.88
		&"snow": return 0.92
	return 1.0


func _grip() -> float:
	var g := float(h.get("grip", 6.0))
	if Weather.current in [&"rain", &"storm"]:
		g *= 0.6
	elif Weather.current == &"snow" or global_position.y > _gen.snow_line():
		g *= 0.5
	return g


# --- Driving (called by DriveState every physics frame) -------------------------------------------------
func start_drive(p: Player) -> void:
	driver = p
	_engine.play()
	Audio.play_at(&"vehicle_start", global_position, -3.0)
	EventBus.vehicle_changed.emit(true)


func end_drive() -> void:
	driver = null
	boosting = false
	charge = 0.0
	visual.set_charge(0.0)
	EventBus.vehicle_changed.emit(false)


func drive(input: Vector2, cam_basis: Basis, boost: bool, jump_held: bool, jump_released: bool, fire: bool, delta: float) -> void:
	_cooldown -= delta
	_cool(delta)
	var dir := Vector3.ZERO
	if input.length() > 0.1:
		var fwd := -cam_basis.z
		fwd.y = 0.0
		var right := cam_basis.x
		right.y = 0.0
		dir = (fwd.normalized() * input.y + right.normalized() * input.x).normalized()
	var mag := clampf(input.length(), 0.0, 1.0)
	if mode == &"water_mode" or transform_t > 0.01 and transform_t < 0.99:
		_drive_water(dir, mag, delta)
	else:
		_drive_land(dir, mag, boost, jump_held, jump_released, delta)
	if fire and def.has("weapon"):
		_fire()


func _drive_land(dir: Vector3, mag: float, boost: bool, jump_held: bool, jump_released: bool, delta: float) -> void:
	var fwd := facing_dir()
	var target := 0.0
	_steer = 0.0
	if dir != Vector3.ZERO:
		var reverse := dir.dot(fwd) < -0.55 and speed < 2.5
		if reverse:
			target = -float(h.get("reverse", 4.0)) * mag
		else:
			target = max_speed() * mag
			# Turn rate falls with speed: heavy machines carve wide arcs.
			var t := clampf(absf(speed) / maxf(float(h.get("max_speed", 10.0)), 0.1), 0.0, 1.0)
			var rate := lerpf(float(h.get("turn", 2.0)), float(h.get("turn_at_speed", 1.0)), t)
			if not grounded:
				rate = float(h.get("air_control", 0.4))
			var want := atan2(-dir.x, -dir.z)
			var diff := wrapf(want - heading, -PI, PI)
			var step := clampf(diff, -rate * delta, rate * delta)
			heading += step
			_steer = clampf(diff * 2.0, -1.0, 1.0)
	# Boost (heavy): a gauge, not a spam button.
	boosting = false
	var boost_max := float(h.get("boost_seconds", 0.0))
	if boost_max > 0.0:
		if boost and boost_left > 0.0 and target > 0.0 and grounded:
			boosting = true
			boost_left = maxf(boost_left - delta, 0.0)
			target = max_speed() * mag
		else:
			boost_left = minf(boost_left + float(h.get("boost_regen", 0.2)) * delta, boost_max)
	# Speed toward target: accelerate, brake, or coast.
	if grounded:
		var rate2 := float(h.get("accel", 8.0))
		if target == 0.0:
			rate2 = float(h.get("coast", 3.0))
		elif signf(target) != signf(speed) and absf(speed) > 0.5 or absf(target) < absf(speed):
			rate2 = float(h.get("brake", 16.0))
		speed = move_toward(speed, target, rate2 * delta)
		# Slopes: climbing costs speed, steep ones are a wall.
		var n := get_floor_normal() if is_on_floor() else Vector3.UP
		var slope_down := -n.dot(fwd)   # >0 uphill
		speed -= slope_down * GRAVITY * 0.35 * delta * signf(speed)
		if n.y < float(h.get("slope_limit", 0.6)) and slope_down > 0.0:
			speed = minf(speed, 2.0)
	# Jump: light bikes charge (hold) then pop (release); heavy ones hop.
	var jump := float(h.get("jump", 0.0))
	if grounded and jump > 0.0:
		if jump_held:
			charge = minf(charge + delta / maxf(float(h.get("charge_time", 0.5)), 0.05), 1.0)
		if jump_released:
			velocity.y = jump + float(h.get("jump_charge", 0.0)) * charge
			grounded = false
			Audio.play_at(&"vehicle_jump", global_position, -4.0)
			charge = 0.0
	elif not grounded:
		charge = 0.0
	visual.set_charge(charge)
	_integrate(delta)


func _drive_water(dir: Vector3, mag: float, delta: float) -> void:
	var fwd := facing_dir()
	var target := 0.0
	_steer = 0.0
	if dir != Vector3.ZERO and transform_t > 0.9:
		target = max_speed() * mag * clampf(dir.dot(fwd) * 0.5 + 0.7, 0.2, 1.0)
		var want := atan2(-dir.x, -dir.z)
		var diff := wrapf(want - heading, -PI, PI)
		var rate := float(h.get("water_turn", 1.2))
		heading += clampf(diff, -rate * delta, rate * delta)
		_steer = clampf(diff * 2.0, -1.0, 1.0)
	# Boats keep momentum: gentle thrust, water drag.
	speed = move_toward(speed, target, float(h.get("water_accel", 3.0)) * delta)
	speed -= speed * float(h.get("water_drag", 0.8)) * 0.15 * delta
	_integrate(delta)


## Move, keep lateral grip, handle floor, water and collisions.
func _integrate(delta: float) -> void:
	var fwd := facing_dir()
	var hv := Vector3(velocity.x, 0, velocity.z)
	var want := fwd * speed
	# Grip: lateral velocity bleeds off (lower grip = the machine slides).
	var g := _grip() if mode == &"land_mode" else 1.2
	hv = hv.lerp(want, clampf(g * delta, 0.0, 1.0)) if grounded or mode == &"water_mode" else hv.lerp(want, clampf(0.8 * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	_update_mode(delta)
	if mode == &"water_mode" or transform_t > 0.5:
		var surface := WorldGen.SEA_LEVEL - float(h.get("draft", 1.0)) + sin(Time.get_ticks_msec() * 0.0021) * 0.05
		velocity.y = (surface - global_position.y) * 3.5
	elif is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.5
	else:
		velocity.y -= GRAVITY * (0.85 if not grounded else 1.0) * delta
	# Bikes refuse deep water: the front wheel stops at the bank.
	if is_bike():
		var ahead := global_position + fwd * signf(speed) * 1.6
		var depth := WorldGen.SEA_LEVEL - _gen.height(ahead.x, ahead.z)
		if depth > BIKE_WADE_LIMIT and absf(speed) > 0.1:
			speed = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
			if not _water_warned and driver:
				_water_warned = true
				EventBus.toast.emit(tr("TOAST_VEHICLE_NO_WATER"))
	var vy_before := velocity.y
	move_and_slide()
	_handle_collisions()
	var was := grounded
	grounded = is_on_floor() or mode == &"water_mode"
	if grounded:
		if not was and air_time > 0.35:
			_land(vy_before)
		air_time = 0.0
	else:
		air_time += delta
	rotation.y = heading
	_pitch_to_ground(delta)
	visual.update_motion(speed, _steer, -_steer * float(h.get("lean", 0.2)) * clampf(absf(speed) / 8.0, 0.0, 1.0), grounded, delta)
	_update_audio()


func _land(vy: float) -> void:
	var cam: Node = Game.camera_rig
	if vy < -16.0:
		speed *= 0.6
		if cam:
			cam.add_trauma(0.35)
		Audio.play_at(&"land", global_position, 0.0)
		if vy < -30.0 and driver:
			var d := DamageInfo.make(10.0, null)
			d.kind = &"environment"
			d.blockable = false
			driver.combat.receive(d)
	else:
		# Clean landing: the Sparrow springs forward.
		var boost := float(h.get("landing_boost", 0.0))
		if boost > 0.0 and speed > 3.0:
			speed = minf(speed + boost, max_speed() + boost)
			ElementFX.ring(self, global_position + Vector3.UP * 0.2, &"wind", 1.4, 0.3)
		if cam:
			cam.add_trauma(0.12)
		Audio.play_at(&"vehicle_land", global_position, -4.0)
	Effects.dust(self, global_position, 1.2)


## Visual pitch follows the ground under the axles (cheap: two heights).
func _pitch_to_ground(delta: float) -> void:
	if not grounded or mode == &"water_mode":
		visual.rotation.x = lerpf(visual.rotation.x, clampf(velocity.y * 0.02, -0.35, 0.35), minf(delta * 3.0, 1.0))
		return
	var fwd := facing_dir()
	var half := float(def.get("collider", {}).get("length", 2.0)) * 0.45
	var a := global_position + fwd * half
	var b := global_position - fwd * half
	var pitch := atan2(_gen.height(a.x, a.z) - _gen.height(b.x, b.z), half * 2.0)
	visual.rotation.x = lerpf(visual.rotation.x, clampf(pitch, -0.6, 0.6), minf(delta * 8.0, 1.0))


## Rams: enemies take a knock (heavy class), everyone else just stops us.
func _handle_collisions() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other is Creature:
			var cr := other as Creature
			if absf(speed) > 6.0:
				var ram := float(h.get("ram_damage", 0.0))
				if cr.is_in_group(&"enemies") and ram > 0.0 and driver:
					var info := DamageInfo.make(ram * absf(speed) / 10.0, driver, facing_dir() * 6.0)
					CombatUtils.deal(cr, info)
				Audio.play_at(&"block", global_position, -4.0)
			speed *= 0.3
		elif other is StaticBody3D and absf(speed) > 12.0 and c.get_normal().y < 0.5:
			# Head-on into a wall: stop hard, shake.
			speed *= 0.2
			if Game.camera_rig:
				Game.camera_rig.add_trauma(0.3)


# --- Amphibious: land_mode <-> water_mode --------------------------------------------------------------
func _update_mode(delta: float) -> void:
	if not is_capsule():
		return
	var ground := _gen.height(global_position.x, global_position.z)
	var depth := WorldGen.SEA_LEVEL - ground
	var want := mode
	if mode == &"land_mode" and depth > WATER_ENTER_DEPTH and global_position.y < WorldGen.SEA_LEVEL + 0.2:
		want = &"water_mode"
	elif mode == &"water_mode":
		# Drive out when the bank ahead (or under us) rises near the surface.
		var ahead := global_position + facing_dir() * 1.2
		var depth_ahead := WorldGen.SEA_LEVEL - _gen.height(ahead.x, ahead.z)
		if depth < WATER_EXIT_DEPTH or (depth_ahead < WATER_EXIT_DEPTH and speed > 0.5):
			want = &"land_mode"
	if want != mode:
		_set_mode(want)
	var target := 1.0 if mode == &"water_mode" else 0.0
	var tt := float(h.get("transform_time", 0.7))
	transform_t = move_toward(transform_t, target, delta / maxf(tt, 0.05))
	visual.set_water_blend(transform_t)
	if _wake:
		_wake.emitting = mode == &"water_mode" and absf(speed) > 1.0
		_wake.position = Vector3(0, WorldGen.SEA_LEVEL - global_position.y + 0.05, 0.9)


func _set_mode(m: StringName) -> void:
	mode = m
	if m == &"water_mode":
		_land_speed = speed
		speed *= 0.5
		Effects.splash(self, global_position + Vector3.UP * 0.5)
		Audio.play_at(&"splash", global_position, 0.0)
		Audio.play_at(&"capsule_transform", global_position, -2.0)
		_engine.stream = Audio._get_stream(StringName(def.get("sound", {}).get("water", "")))
	else:
		velocity.y = 3.0
		Audio.play_at(&"capsule_transform", global_position, -2.0)
		_engine.stream = Audio._get_stream(StringName(def.get("sound", {}).get("engine", "")))
	if driver:
		_engine.play()
	mode_changed.emit(m)
	EventBus.vehicle_mode_changed.emit(m)


# --- Weapon (capsule) ----------------------------------------------------------------------------------
func _cool(delta: float) -> void:
	var w: Dictionary = def.get("weapon", {})
	if w.is_empty():
		return
	if overheated > 0.0:
		overheated -= delta
		if overheated <= 0.0:
			heat = 0.0
		return
	heat = maxf(heat - float(w.get("cool_rate", 0.3)) * delta, 0.0)


func heat_ratio() -> float:
	return 1.0 if overheated > 0.0 else heat


func _fire() -> void:
	var w: Dictionary = def["weapon"]
	if _cooldown > 0.0 or overheated > 0.0 or visual.muzzles().is_empty() or transform_t > 0.1 and transform_t < 0.9:
		return
	_cooldown = float(w.get("cooldown", 0.3))
	var muzzle: Node3D = visual.muzzles()[_muzzle_i % visual.muzzles().size()]
	_muzzle_i += 1
	var from := muzzle.global_position
	var aim: Variant = _aim_target(float(w.get("range", 30.0)), float(w.get("aim_cone", 20.0)))
	var dir := facing_dir() if aim == null else ((aim as Node3D).global_position + Vector3.UP * 0.8 - from).normalized()
	var p := Projectile.spawn(get_parent(), from, dir * float(w.get("speed", 30.0)), float(w.get("damage", 8.0)), &"", driver, false)
	p.vs_boss = float(w.get("boss_mult", 0.5))
	p.life = float(w.get("range", 30.0)) / float(w.get("speed", 30.0)) + 0.1
	visual.recoil()
	Effects.hit_spark(self, from, false)
	Audio.play_at(&"capsule_fire", from, -3.0)
	heat += float(w.get("heat_per_shot", 0.15))
	if heat >= 1.0:
		overheated = float(w.get("overheat_lock", 2.0))
		Audio.play_at(&"capsule_overheat", global_position, -2.0)
		EventBus.toast.emit(tr("TOAST_VEHICLE_OVERHEAT"))


## Lock-on target if any, else the nearest enemy inside the aim cone.
func _aim_target(reach: float, cone_deg: float) -> Variant:
	if driver and driver.combat.lock_target_valid():
		return driver.combat.lock_target
	var best: Node3D = null
	var best_d := reach
	var fwd := facing_dir()
	var cos_c := cos(deg_to_rad(cone_deg))
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or (e is Creature and (e as Creature).dead):
			continue
		var to := n.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and fwd.dot(to / maxf(d, 0.01)) > cos_c:
			best = n
			best_d = d
	return best


# --- Damage ----------------------------------------------------------------------------------------------
## Enclosed capsule: the hull takes the blows. Bikes: the rider does, and
## big hits throw them off (same rule as mounts).
func take_damage(info: DamageInfo) -> void:
	visual.set_flash(0.6, Color(1, 0.9, 0.8))
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if is_instance_valid(visual):
			visual.set_flash(0.0))
	if rider_hidden() and hull_max > 0.0:
		hull -= info.amount
		Audio.play_at(&"block", global_position, -2.0)
		if hull <= 0.0:
			hull = 0.0
			disabled_for = 60.0
			EventBus.toast.emit(tr("TOAST_VEHICLE_WRECKED"))
			Effects.dust(self, global_position, 2.0)
			if driver:
				driver.exit_vehicle(true)
		return
	if driver:
		if info.amount >= 18.0:
			var p := driver
			p.exit_vehicle(true)
			p.combat.receive(info)
		else:
			driver.combat.receive(info)


# --- Audio / VFX -----------------------------------------------------------------------------------------
func _update_audio() -> void:
	if _engine == null or not _engine.playing:
		return
	var pr: Array = def.get("sound", {}).get("pitch", [0.8, 1.4])
	var t := clampf(absf(speed) / maxf(float(h.get("max_speed", 10.0)), 0.1), 0.0, 1.2)
	_engine.pitch_scale = lerpf(float(pr[0]), float(pr[1]), t) + (0.12 if boosting else 0.0) + charge * 0.2
	_engine.volume_db = lerpf(-12.0, -4.0, t)


func _make_wake() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Wake"
	p.amount = Quality.particle_amount(18)
	p.lifetime = 1.1
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 0.6, 1)
	p.spread = 35.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.7))
	g.set_color(1, Color(0.85, 0.92, 0.95, 0.0))
	p.color_ramp = g
	return p


# --- Idle (parked, no driver) ----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if disabled_for > 0.0:
		disabled_for -= delta
	if driver:
		return   # DriveState drives us
	var gw := Game.world as GameWorld
	if gw and gw.streamer and not gw.streamer.has_collision_at(global_position):
		velocity = Vector3.ZERO
		return
	# Parked: brake to a stop, settle on the ground or float.
	speed = move_toward(speed, 0.0, float(h.get("brake", 12.0)) * delta)
	_integrate(delta)
