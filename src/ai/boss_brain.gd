class_name BossBrain
extends AIBrain
## Adds dormant / intro / phase-shift states to the enemy state machine and
## restricts attack choice to the current phase's list.


func _register() -> void:
	super._register()
	for s: AIState in [BossDormantState.new(self), BossIntroState.new(self), BossPhaseState.new(self)]:
		states[s.id()] = s


func _initial_state() -> StringName:
	return &"boss_dormant"


func boss() -> Boss:
	return c as Boss


func reset() -> void:
	cooldowns.clear()
	stagger_time = 0.0
	change(&"boss_dormant")


func begin_phase_shift() -> void:
	change(&"boss_phase")


## Ordinary search/idle states would wander off: a boss holds its arena.
func change(next: StringName) -> void:
	if next in [&"search", &"patrol", &"investigate", &"idle", &"flee", &"retreat", &"sleep"] and boss().engaged:
		next = &"chase"
	super.change(next)
	if current is AttackState:
		(current as AttackState).speed_mult = boss().speed_mult()


func pick_attack(dist: float) -> AttackData:
	var allowed: Array = boss().allowed_attacks()
	var options: Array[AttackData] = []
	var total := 0.0
	for a in c.type.attacks:
		if (allowed.is_empty() or String(a.id) in allowed) and dist >= a.range_min and dist <= a.range_max and cooldown_ready(a.id):
			options.append(a)
			total += a.weight
	if options.is_empty():
		return null
	var roll := randf() * total
	for a in options:
		roll -= a.weight
		if roll <= 0.0:
			return a
	return options[0]


# --- States ------------------------------------------------------------------------------------------

class BossDormantState:
	extends AIState

	func id() -> StringName:
		return &"boss_dormant"

	func enter() -> void:
		c.stop()

	func tick(_delta: float) -> StringName:
		var bs: Boss = c as Boss
		if Game.player == null or (Game.player as Player).is_dead():
			return &""
		var p := Game.player.global_position
		if Vector2(p.x - bs.arena_center.x, p.z - bs.arena_center.z).length() < bs.arena_radius:
			return &"boss_intro"
		# Idle presence: slow turn toward the arena entrance.
		c.face_towards(p - c.global_position, 0.02)
		return &""


class BossIntroState:
	extends AIState

	func id() -> StringName:
		return &"boss_intro"

	func anim() -> StringName:
		return &"idle"

	func enter() -> void:
		c.stop()
		(c as Boss).engage()
		c.perception.alert(Game.player.global_position)
		c.visual.play_action(&"roar", 1.6)
		Audio.play_at(&"boss_roar", c.global_position, 2.0)
		if Game.camera_rig:
			Game.camera_rig.add_trauma(0.35)

	func tick(delta: float) -> StringName:
		c.face_towards(Game.player.global_position - c.global_position, delta * 2.0)
		if t > 2.2:
			return &"chase"
		return &""


class BossPhaseState:
	extends AIState

	func id() -> StringName:
		return &"boss_phase"

	func enter() -> void:
		var bs: Boss = c as Boss
		c.stop()
		c.health.invulnerable = true
		c.visual.play_action(&"roar", 1.4)
		c.visual.set_flash(0.8, ElementFX.color(StringName(bs.def.get("element", ""))))
		Audio.play_at(&"boss_roar", c.global_position, 3.0)
		var pd: Dictionary = bs.phase_def()
		ElementFX.burst(c, c.global_position, StringName(bs.def.get("element", "")), float(pd.get("shockwave", 7.0)))
		# Shockwave pushes the player out of melee range.
		if Game.player and Game.player.global_position.distance_to(c.global_position) < float(pd.get("shockwave", 7.0)):
			var info := DamageInfo.make(float(pd.get("shockwave_damage", 8.0)), c, (Game.player.global_position - c.global_position).normalized() * 12.0 + Vector3.UP * 4.0, StringName(bs.def.get("element", "")))
			info.blockable = false
			CombatUtils.deal(Game.player, info)
		if Game.camera_rig:
			Game.camera_rig.add_trauma(0.5)
		var summon := StringName(pd.get("summon", ""))
		var dir := c.get_tree().get_first_node_in_group(&"spawn_director")
		if summon != &"" and dir:
			for i in int(pd.get("summon_count", 2)):
				var a := TAU * i / float(pd.get("summon_count", 2))
				var sp := c.global_position + Vector3(cos(a), 0.5, sin(a)) * (c.type.collider_radius + 4.0)
				var m: Creature = dir.spawn_creature(summon, sp, "", c.group_id)
				if m:
					m.perception.alert(Game.player.global_position)
		if pd.has("weather"):
			Weather.set_weather(StringName(pd["weather"]), false)
		if pd.has("title_key"):
			EventBus.toast.emit(tr(pd["title_key"]))

	func exit() -> void:
		c.health.invulnerable = false
		c.visual.set_flash(0.0)

	func tick(delta: float) -> StringName:
		if Game.player:
			c.face_towards(Game.player.global_position - c.global_position, delta)
		if t > 1.8:
			return &"chase"
		return &""
