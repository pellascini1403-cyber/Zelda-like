class_name Mount
extends Animal
## Rideable creature. Wild: behaves like any skittish grazer (AnimalBrain).
## Mounting a wild one starts taming (it bucks, draining the rider's
## stamina); holding on tames it. Tamed: waits where it was left, comes when
## called (Strider Call), and is driven directly by the rider's input.
##
## Gameplay numbers live in EntityType.mount (entities.json); the look is
## the usual EntityVisual (placeholder or final model), so a final mount
## model drops in without touching this code.

var mount_id: StringName = &""
var tamed := false
var rider: Player = null
var taming := 0.0            # >0 while bucking
var spurs := 0.0
var _called_to := Vector3.INF
var _gait := 0.0             # 0 walk .. 1 trot .. 2 gallop
var _jump_v := 0.0
var _talk: MountInteract


func _on_built() -> void:
	super._on_built()
	add_to_group(&"mounts")
	spurs = float(type.mount.get("stamina", 4))
	_talk = MountInteract.new()
	_talk.mount = self
	_talk.position.y = type.collider_height * 0.6
	add_child(_talk)


func m(key: String, default_value: float) -> float:
	return float(type.mount.get(key, default_value))


## Seat position for the rider (world space).
func seat() -> Vector3:
	return global_position + Vector3.UP * m("seat_height", 1.8) - facing_dir() * 0.1


func ai_tick(delta: float) -> void:
	if rider:
		# Rider drives the body in _physics_process; keep health/visual ticking.
		health.tick(delta)
		visual.rotation.y = facing_yaw
		var hs := Vector2(velocity.x, velocity.z).length()
		visual.set_locomotion(hs / maxf(m("gallop", 12.0), 0.1), &"run" if hs > m("trot", 7.0) * 0.8 else &"move")
		return
	if tamed:
		_tamed_tick(delta)
		return
	super.ai_tick(delta)


func _tamed_tick(delta: float) -> void:
	health.tick(delta)
	if _called_to != Vector3.INF:
		var d := Vector2(_called_to.x - global_position.x, _called_to.z - global_position.z).length()
		if d < 3.5:
			_called_to = Vector3.INF
			stop()
		else:
			go_to(_called_to, m("gallop", 12.0) * 0.8)
	else:
		stop()
	_move(delta)
	visual.rotation.y = facing_yaw
	var hs := Vector2(velocity.x, velocity.z).length()
	visual.set_locomotion(hs / maxf(m("gallop", 12.0), 0.1), &"run" if hs > 4.0 else (&"move" if hs > 0.3 else &"idle"))


func call_to(pos: Vector3) -> void:
	_called_to = pos


# --- Riding -----------------------------------------------------------------------------------------

func start_ride(p: Player) -> void:
	rider = p
	stop()
	_called_to = Vector3.INF
	if not tamed:
		taming = 3.0 * m("tame_difficulty", 1.0)
		EventBus.toast.emit(tr("TOAST_TAMING"))
	Audio.play_at(&"mount", global_position, -2.0)
	EventBus.mount_changed.emit(true)


func end_ride() -> void:
	rider = null
	taming = 0.0
	velocity = Vector3.ZERO
	EventBus.mount_changed.emit(false)


## Called by RideState every physics frame. Returns false when the rider is
## thrown off (failed taming).
func drive(input: Vector2, cam_basis: Basis, spur: bool, jump: bool, delta: float) -> bool:
	if taming > 0.0:
		taming -= delta
		# Bucking: random lurches, the rider pays stamina to hold on.
		var lurch := Vector3(sin(Time.get_ticks_msec() * 0.013), 0, cos(Time.get_ticks_msec() * 0.009))
		velocity.x = lurch.x * 4.0
		velocity.z = lurch.z * 4.0
		facing_yaw += sin(Time.get_ticks_msec() * 0.02) * delta * 6.0
		if not rider.vitals.try_spend(22.0 * delta * m("tame_difficulty", 1.0)):
			throw_rider()
			return false
		if taming <= 0.0:
			_tamed_now()
		_physics_step(delta)
		return true
	var target_speed := 0.0
	if input.length() > 0.1:
		var fwd := -cam_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized()
		var dir := (fwd * input.y + right * input.x).normalized()
		# Mounts turn wide: steer toward the input direction at a limited rate.
		facing_yaw = lerp_angle(facing_yaw, atan2(-dir.x, -dir.z), minf(m("turn", 2.6) * delta, 1.0))
		_gait = 1.0 if input.length() > 0.7 else 0.0
		if spur and spurs >= 1.0:
			spurs -= 1.0
			_gait = 2.0
			Audio.play_at(&"mount", global_position, -6.0)
		elif _gait < 2.0 or input.length() < 0.7:
			_gait = minf(_gait, 1.0)
		target_speed = [m("walk", 4.0), m("trot", 8.0), m("gallop", 13.0)][int(_gait)]
	else:
		_gait = 0.0
	if not spur or target_speed == 0.0:
		spurs = minf(spurs + m("stamina_regen", 0.35) * delta, m("stamina", 4))
	var fwd_dir := facing_dir()
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(fwd_dir * target_speed, (10.0 if target_speed > 0.0 else 16.0) * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if jump and is_on_floor():
		velocity.y = m("jump", 7.0)
		_jump_v = velocity.y
	_physics_step(delta)
	return true


func _physics_step(delta: float) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()
	# Refuse deep water: mounts wade, never swim.
	if global_position.y < WorldGen.SEA_LEVEL - 1.2:
		velocity.x *= -0.5
		velocity.z *= -0.5


func _tamed_now() -> void:
	tamed = true
	taming = 0.0
	mount_id = StringName(type.mount.get("id", "windstrider")) if type.mount.has("id") else &"windstrider"
	WorldState.flags["mount_" + String(mount_id)] = true
	EventBus.mount_tamed.emit(mount_id)
	EventBus.title_card.emit(tr(type.name_key), tr("MOUNT_TAMED"))
	ElementFX.burst(self, global_position, &"wind", 3.0)
	MountManager.adopt(self)


func throw_rider() -> void:
	var p := rider
	if p == null:
		return
	p.dismount(true)
	(brain as AnimalBrain).scare(p.global_position)
	EventBus.toast.emit(tr("TOAST_THROWN"))


func save_state() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": facing_yaw, "hp": health.health}
