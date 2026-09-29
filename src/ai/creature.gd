class_name Creature
extends CharacterBody3D
## Shared body for every AI-driven entity (enemies, animals, NPCs, bosses).
##
## Gameplay only: collider & stats come from EntityType data; the look is an
## EntityVisual child (placeholder or final model). AIManager decides how
## often `ai_tick` runs based on distance to the player (full / reduced /
## dormant) so far-away creatures cost almost nothing.

signal died_signal(creature: Creature)

enum Tier { FULL, REDUCED, DORMANT }

var type: EntityType
var visual: EntityVisual
var health: Health
var perception: Perception
var brain: AIBrain
var home := Vector3.ZERO
var spawn_id := ""
var group_id := ""
var tier: int = Tier.FULL
var facing_yaw := 0.0
var target: Node3D
var move_target := Vector3.ZERO
var move_speed := 0.0
var knockback := Vector3.ZERO
var dead := false
var respawn_hours := 72.0

var _collision: CollisionShape3D
var _stuck_time := 0.0
var _avoid_sign := 1.0
var _last_pos := Vector3.ZERO
var _debug_label: Label3D


func setup(entity_type: EntityType, spawn_pos: Vector3, id: String = "", group: String = "") -> void:
	type = entity_type
	home = spawn_pos
	spawn_id = id
	group_id = group
	dead = false
	knockback = Vector3.ZERO
	target = null
	if not is_inside_tree():
		return
	_build()


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 1 | (1 << 1) | (1 << 2) | (1 << 3)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)
	if type:
		_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = type.collider_radius
	shape.height = maxf(type.collider_height, type.collider_radius * 2.0)
	_collision.shape = shape
	_collision.position.y = shape.height * 0.5
	add_child(_collision)
	visual = EntityVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(type)
	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(type.max_health, type.poise, type.defense, type.element_mult)
	health.died.connect(_on_died)
	health.staggered.connect(_on_staggered)
	health.damaged.connect(_on_damaged)
	perception = Perception.new(self)
	brain = _make_brain()
	global_position = home
	facing_yaw = randf() * TAU
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING if type.flying else CharacterBody3D.MOTION_MODE_GROUNDED
	if Debug.show_entity_debug:
		enable_debug_label(true)
	_on_built()


## Override: which brain drives this creature.
func _make_brain() -> AIBrain:
	return AIBrain.new(self)


func _on_built() -> void:
	pass


# --- Tick (called by AIManager) --------------------------------------------------------------
func ai_tick(delta: float) -> void:
	if type == null:
		return
	health.tick(delta)
	if not dead:
		perception.update(delta)
		brain.tick(delta)
	_move(delta)
	visual.rotation.y = facing_yaw
	var hs := Vector2(velocity.x, velocity.z).length()
	visual.set_locomotion(hs / maxf(type.run_speed, 0.1), brain.anim_state() if not dead else &"idle")
	if _debug_label:
		_debug_label.text = "%s\n%s  HP %d/%d\n%s" % [type.id, brain.state_name(), health.health, health.max_health, (target.name if target else "-")]


func _move(delta: float) -> void:
	var desired := Vector3.ZERO
	if not dead and move_speed > 0.01:
		var to := move_target - global_position
		if not type.flying:
			to.y = 0.0
		if to.length() > 0.3:
			desired = _avoid(to.normalized()) * move_speed
			face_towards(desired, delta)
	knockback = knockback.move_toward(Vector3.ZERO, 18.0 * delta)
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 20.0 * delta)
	velocity.x = hv.x + knockback.x
	velocity.z = hv.z + knockback.z
	if type.flying:
		var ground := _ground_height()
		var hover := ground + 3.0 + sin(Time.get_ticks_msec() * 0.002 + home.x) * 0.4
		if move_target.y > ground + 1.0 and target:
			hover = maxf(hover, move_target.y + 1.0)
		velocity.y = (hover - global_position.y) * 3.0 + knockback.y
	elif is_on_floor():
		velocity.y = -1.0 + knockback.y
	else:
		velocity.y -= 24.0 * delta
	# Reduced-tier ticks carry several frames of delta: scale the step.
	var step_scale := delta / maxf(get_physics_process_delta_time(), 0.001)
	velocity *= step_scale
	move_and_slide()
	velocity /= step_scale
	if knockback.y > 0.0:
		knockback.y = 0.0
	# Stuck detection -> flip avoidance side
	if move_speed > 0.5:
		if global_position.distance_to(_last_pos) < move_speed * delta * 0.25:
			_stuck_time += delta
			if _stuck_time > 0.6:
				_avoid_sign = -_avoid_sign
				_stuck_time = 0.0
		else:
			_stuck_time = 0.0
	_last_pos = global_position
	if global_position.y < -60.0:
		_on_died(DamageInfo.make(0, null))


## Cheap local avoidance: probe ahead, veer around obstacles, refuse cliffs
## and deep water (no navmesh needed on open terrain).
func _avoid(dir: Vector3) -> Vector3:
	if type.flying:
		return dir
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.6
	for attempt in 5:
		var angle: float = [0.0, 0.7, -0.7, 1.4, -1.4][attempt] * _avoid_sign
		var d := dir.rotated(Vector3.UP, angle)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * (type.collider_radius + 1.2), 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit["normal"].y < 0.6:
			continue
		# Ground ahead: no cliffs, no deep water
		var ahead := global_position + d * 2.0 + Vector3.UP * 2.0
		var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 8.0, 1))
		if g.is_empty():
			continue
		if g["position"].y < global_position.y - 3.5 or g["position"].y < WorldGen.SEA_LEVEL - 0.6:
			continue
		return d
	return Vector3.ZERO


func _ground_height() -> float:
	var from := global_position + Vector3.UP * 2.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1))
	return hit["position"].y if not hit.is_empty() else global_position.y - 3.0


func face_towards(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	facing_yaw = lerp_angle(facing_yaw, atan2(-dir.x, -dir.z), minf(type.turn_speed * delta, 1.0))


func facing_dir() -> Vector3:
	return Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))


func go_to(pos: Vector3, speed: float) -> void:
	move_target = pos
	move_speed = speed


func stop() -> void:
	move_speed = 0.0


func distance_to_player() -> float:
	return global_position.distance_to(Game.player.global_position) if Game.player else INF


# --- Damage ---------------------------------------------------------------------------------------
func take_damage(info: DamageInfo) -> void:
	if dead:
		return
	health.apply_damage(info)
	knockback += info.knockback * clampf(70.0 / type.mass, 0.15, 1.6)


func _on_damaged(info: DamageInfo) -> void:
	visual.set_flash(1.0)
	_flash_off()
	if info.source and info.source is Node3D:
		brain.on_hurt(info.source)


func _flash_off() -> void:
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(visual):
		visual.set_flash(0.0)


func _on_staggered() -> void:
	brain.on_stagger(0.7)


func on_parried() -> void:
	brain.on_stagger(1.6)
	visual.play_action(&"hit", 0.5)


func is_dead() -> bool:
	return dead


## Sneak-attack check: unaware creatures take double damage.
func is_unaware() -> bool:
	return brain.is_unaware()


func _on_died(_info: DamageInfo) -> void:
	if dead:
		return
	dead = true
	move_speed = 0.0
	_collision.set_deferred("disabled", true)
	visual.play_action(&"die", 0.7)
	Game.register_aggro(self, false)
	remove_from_group(&"enemies")
	for drop in DB.roll_loot(type.loot_table):
		Pickup.spawn(get_parent(), global_position + Vector3(randf_range(-0.6, 0.6), 0.8, randf_range(-0.6, 0.6)), drop["id"], drop["count"])
	if spawn_id != "":
		WorldState.mark_defeated(spawn_id, respawn_hours)
	EventBus.entity_killed.emit(type.id, global_position)
	Audio.play_at(&"creature_die", global_position, -2.0)
	died_signal.emit(self)
	# Dissolve: the body sinks and shrinks into motes of its own colour.
	await get_tree().create_timer(1.3).timeout
	if not is_instance_valid(self):
		return
	var t := create_tween()
	t.tween_property(visual, "scale", Vector3(1.15, 0.05, 1.15), 0.7).set_ease(Tween.EASE_IN)
	Effects.sparks(self, global_position + Vector3.UP * type.collider_height * 0.5, type.placeholder_color, 0.6)
	await t.finished
	if is_instance_valid(self):
		Effects.dust(self, global_position, 1.0)
		queue_free()


func enable_debug_label(on: bool) -> void:
	if on and _debug_label == null:
		_debug_label = Label3D.new()
		_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_debug_label.font_size = 28
		_debug_label.pixel_size = 0.004
		_debug_label.position.y = type.collider_height + 0.6
		_debug_label.no_depth_test = true
		add_child(_debug_label)
	elif not on and _debug_label:
		_debug_label.queue_free()
		_debug_label = null


func kind_is_hostile() -> bool:
	return type.kind == EntityType.Kind.ENEMY or type.kind == EntityType.Kind.BOSS
