class_name Boss
extends Enemy
## Boss body: an Enemy with an arena, phases and a reward, all described in
## data/bosses.json (entity stats/attacks stay in entities.json).
##
## Flow: dormant until the player enters the arena → intro (roar + title
## card, HUD boss plate) → fight. Crossing a health threshold triggers a
## phase shift (brief invulnerable roar, shockwave, optional summons) that
## unlocks more attacks and speeds the boss up. Leaving the arena far
## enough resets the fight (full health, back home) like any encounter.

var def: Dictionary = {}
var phase := 0
var engaged := false
var arena_center := Vector3.ZERO
var arena_radius := 20.0
var _aura: GPUParticles3D


func setup_boss(boss_def: Dictionary, center: Vector3) -> void:
	def = boss_def
	arena_center = center
	arena_radius = float(def.get("arena", {}).get("radius", 20.0))


func _on_built() -> void:
	super._on_built()
	add_to_group(&"bosses")
	respawn_hours = 999999.0
	_make_aura()


func _make_brain() -> AIBrain:
	return BossBrain.new(self)


func phase_def() -> Dictionary:
	var phases: Array = def.get("phases", [])
	return phases[phase] if phase < phases.size() else {}


func allowed_attacks() -> Array:
	return phase_def().get("attacks", [])


func speed_mult() -> float:
	return float(phase_def().get("speed", 1.0))


func ai_tick(delta: float) -> void:
	super.ai_tick(delta)
	if dead or not engaged or Game.player == null:
		return
	var p := Game.player.global_position
	if Vector2(p.x - arena_center.x, p.z - arena_center.z).length() > arena_radius * 1.7 or (Game.player as Player).is_dead():
		disengage()


func engage() -> void:
	if engaged:
		return
	engaged = true
	Game.register_aggro(self, true)
	EventBus.boss_engaged.emit(type.id, self)
	EventBus.title_card.emit(tr(type.name_key), tr(def.get("title_key", "")))


func disengage() -> void:
	if not engaged:
		return
	engaged = false
	phase = 0
	health.heal(health.max_health)
	global_position = home
	velocity = Vector3.ZERO
	(brain as BossBrain).reset()
	Game.register_aggro(self, false)
	EventBus.boss_disengaged.emit(type.id)


func _on_damaged(info: DamageInfo) -> void:
	super._on_damaged(info)
	var phases: Array = def.get("phases", [])
	var next := phase + 1
	if next < phases.size() and health.ratio() <= float((phases[next] as Dictionary).get("at", 0.0)):
		phase = next
		(brain as BossBrain).begin_phase_shift()
		EventBus.boss_phase_changed.emit(type.id, phase)


## Bosses are not staggered by ordinary hits: only a full poise break.
func _on_staggered() -> void:
	brain.on_stagger(1.2)


func _on_died(info: DamageInfo) -> void:
	if dead:
		return
	var id := String(type.id)
	WorldState.flags["boss_" + id] = true
	EventBus.flag_set.emit(StringName("boss_" + id))
	super._on_died(info)
	engaged = false
	EventBus.boss_defeated.emit(type.id)
	EventBus.title_card.emit(tr("BOSS_DEFEATED"), tr(type.name_key))
	ElementFX.burst(self, global_position, StringName(def.get("element", "")), 8.0)
	if Game.camera_rig:
		Game.camera_rig.add_trauma(0.6)
	# Reward chest at the arena centre.
	var reward: Array = def.get("rewards", [])
	var chest := Chest.create("boss:" + String(def.get("id", id)), StringName(def.get("loot", "chest_grand")), reward, true)
	get_parent().add_child(chest)
	chest.global_position = arena_center + Vector3.UP * 0.2
	if _aura:
		_aura.emitting = false


func _make_aura() -> void:
	_aura = GPUParticles3D.new()
	_aura.amount = Quality.particle_amount(40)
	_aura.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = type.collider_radius * 1.2
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	pm.color = ElementFX.color(StringName(def.get("element", "")))
	_aura.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	_aura.draw_pass_1 = quad
	_aura.position.y = type.collider_height * 0.5
	_aura.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	add_child(_aura)
