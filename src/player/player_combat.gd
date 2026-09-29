class_name PlayerCombat
extends Node
## Player offense & defense.
##
## * Light combo (weapon-defined length), hold to charge a weapon-specific
##   finisher (spin / thrust / slam / bolt), plunge attack from the air.
## * Touch-friendly aim assist: swings snap toward the best target in front.
## * Block (hold) with a parry window on press; dodge i-frames with a
##   perfect-dodge slow motion.
## * Sneak attacks on unaware enemies deal double damage.
## * Every landed swing wears the weapon (heirlooms blunt instead of break).

const PARRY_WINDOW := 0.2
const CHARGE_TIME := 0.5
const CHARGE_COST := 22.0
const BLOCK_STAMINA_PER_DAMAGE := 0.9
const AIM_ASSIST_RANGE := 5.0
const COMBO_MULT := [1.0, 1.1, 1.45, 1.2]
const ANIMS := [&"attack_1", &"attack_2", &"attack_3", &"attack_2"]

var p: Player
var lock_target: Node3D

var _combo := 0
var _swing_t := -1.0
var _swing_hit_at := 0.0
var _swing_len := 0.0
var _swing_done := false
var _swing_kind: StringName = &"light"
var _queued := false
var _press_time := -1.0
var _charging := false
var _charge_t := 0.0
var _block_pressed_at := -10.0
var _plunging := false
var _weapon_visual: Node3D
var _hurt_cooldown := 0.0


func _ready() -> void:
	p = get_parent()
	EventBus.equipment_changed.connect(func(slot: StringName) -> void:
		if slot == &"weapon":
			refresh_weapon_visual())
	refresh_weapon_visual.call_deferred()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Weapon stats (fists when unarmed) ----------------------------------------------------------
func weapon_stack() -> ItemStack:
	return PlayerData.weapon()


func wstat(key: String, default_value: Variant) -> Variant:
	var s := weapon_stack()
	if s == null or s.def() == null:
		return {"damage": 4.0, "speed": 1.2, "reach": 1.5, "arc": 70.0, "combo": 3, "charged": "spin", "knockback": 2.0}.get(key, default_value)
	return s.def().w(key, default_value)


## True while a blow is in flight (drives the weapon trail).
func is_swinging() -> bool:
	return (_swing_t >= 0.0 and _swing_t <= _swing_len * 0.8) or _plunging or p.state_name() == &"busy" and p.visual._action in [&"spin", &"thrust", &"attack_3", &"slam"]


func weapon_damage() -> float:
	var d: float = wstat("damage", 4.0)
	var s := weapon_stack()
	if s and s.is_blunted():
		d *= 0.5
	return d * PlayerData.attack_mult()


func refresh_weapon_visual() -> void:
	if _weapon_visual:
		_weapon_visual.queue_free()
		_weapon_visual = null
	var s := weapon_stack()
	if s == null or p == null or p.visual == null:
		return
	_weapon_visual = WeaponVisual.build(s.def())
	var socket := p.visual.get_socket(&"hand_r")
	if socket:
		socket.add_child(_weapon_visual)


# --- Per-frame -------------------------------------------------------------------------------------
func pre_physics(delta: float) -> void:
	_hurt_cooldown -= delta
	var st := p.state_name()
	_update_lock_target()
	# Blocking
	var can_block := p.state.allows_block() and _swing_t < 0.0 and not _charging
	if Input.is_action_just_pressed("block"):
		_block_pressed_at = now()
	p.blocking = can_block and Input.is_action_pressed("block") and not p.vitals.exhausted

	if Input.is_action_just_pressed("use_item") and st in [&"ground", &"air"]:
		use_quick_item()
	if Input.is_action_just_pressed("cycle_weapon"):
		PlayerData.cycle_weapon()

	# Attack input
	if Input.is_action_just_pressed("attack"):
		_press_time = now()
		if st == &"air" and p.ground_distance(4.0) > 2.2:
			_start_plunge()
		elif _swing_t >= 0.0:
			_queued = true
		elif p.state.allows_attack() and not p.blocking:
			_start_swing()
	if _plunging:
		_update_plunge()
		return
	# Charge: keep holding after the first swing
	if Input.is_action_pressed("attack") and _press_time > 0.0 and now() - _press_time > CHARGE_TIME * 0.6 and not _charging and _swing_t < 0.0 and st in [&"ground", &"busy"]:
		_begin_charge()
	if _charging:
		_charge_t += delta
		p.visual.play_action(&"charge", 0.2)
		if not Input.is_action_pressed("attack"):
			_charging = false
			if _charge_t >= CHARGE_TIME * 0.5 and p.vitals.try_spend(CHARGE_COST):
				_start_charged()
			else:
				p.start_busy(&"idle", 0.05)
		return
	if not Input.is_action_pressed("attack"):
		_press_time = -1.0
	if _swing_t >= 0.0:
		_update_swing(delta)


func _begin_charge() -> void:
	_charging = true
	_charge_t = 0.0
	p.start_busy(&"charge", 10.0)
	Audio.play_at(&"charge", p.global_position, -8.0)


# --- Light combo ------------------------------------------------------------------------------------------
func _start_swing() -> void:
	var speed: float = wstat("speed", 1.0)
	var combo_len: int = wstat("combo", 3)
	_combo = _combo % combo_len
	_swing_kind = &"light"
	_swing_len = 0.5 / speed + (0.12 if _combo == combo_len - 1 else 0.0)
	_swing_hit_at = _swing_len * 0.42
	_swing_t = 0.0
	_swing_done = false
	_queued = false
	_aim_assist()
	var lunge := p.facing_dir() * (2.2 if _combo < 2 else 3.2)
	p.start_busy(ANIMS[_combo % ANIMS.size()], _swing_len, lunge)
	p.visual.play_action(ANIMS[_combo % ANIMS.size()], _swing_len)
	Audio.play_at(&"swing", p.global_position, -5.0, 0.15)


func _update_swing(delta: float) -> void:
	_swing_t += delta
	if not _swing_done and _swing_t >= _swing_hit_at:
		_swing_done = true
		var mult: float = COMBO_MULT[_combo % COMBO_MULT.size()]
		var reach: float = wstat("reach", 1.8)
		var arc: float = wstat("arc", 60.0)
		_resolve_hits(reach, arc, weapon_damage() * mult, float(wstat("knockback", 3.0)) * mult, StringName(wstat("element", "")))
	if _swing_t >= _swing_len or p.state_name() != &"busy":
		_swing_t = -1.0
		var combo_len: int = wstat("combo", 3)
		_combo += 1
		if _queued and p.state_name() in [&"busy", &"ground"] and _combo < combo_len:
			_start_swing()
		else:
			_combo = 0
			_queued = false


# --- Charged finishers --------------------------------------------------------------------------------------
func _start_charged() -> void:
	var kind := StringName(wstat("charged", "spin"))
	var dmg := weapon_damage()
	_aim_assist()
	match kind:
		&"thrust":
			p.start_busy(&"thrust", 0.45, p.facing_dir() * 12.0)
			p.visual.play_action(&"thrust", 0.45)
			_delayed_hit(0.12, float(wstat("reach", 2.5)) + 1.8, 22.0, dmg * 2.3, 9.0)
		&"slam":
			p.start_busy(&"slam", 0.7)
			p.visual.play_action(&"slam", 0.7)
			_delayed_slam(0.38, 3.6, dmg * 2.4)
		&"bolt":
			p.start_busy(&"throw", 0.4)
			p.visual.play_action(&"throw", 0.4)
			_fire_bolt()
		_:
			p.start_busy(&"spin", 0.55)
			p.visual.play_action(&"spin", 0.55)
			_delayed_hit(0.2, float(wstat("reach", 1.8)) + 0.5, 180.0, dmg * 2.0, 7.0)
	Audio.play_at(&"swing_heavy", p.global_position, -2.0)
	p.emit_noise(14.0)


func _delayed_hit(delay: float, reach: float, arc: float, dmg: float, knock: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if is_instance_valid(p) and not p.is_dead():
		_resolve_hits(reach, arc, dmg, knock, StringName(wstat("element", "")))


func _delayed_slam(delay: float, radius: float, dmg: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(p) or p.is_dead():
		return
	_slam_at(p.global_position + p.facing_dir() * 1.2, radius, dmg)


func _slam_at(center: Vector3, radius: float, dmg: float) -> void:
	var hits := CombatUtils.sphere_query(p.get_world_3d(), center, radius, CombatUtils.CREATURE_MASK | CombatUtils.PROP_MASK)
	var landed := false
	for body in hits:
		if body == p:
			continue
		var dir := (body.global_position - center)
		dir.y = 0
		var info := _make_info(dmg, dir.normalized() * 8.0 + Vector3.UP * 5.0, StringName(wstat("element", "")))
		info.poise_damage = dmg * 2.0
		info.kind = &"slam"
		if CombatUtils.deal(body, info):
			landed = true
	Game.camera_rig.add_trauma(0.45)
	Effects.dust(p, center, 2.0)
	Audio.play_at(&"slam", center, 0.0)
	InputRouter.vibrate(60, 0.8)
	EventBus.noise_emitted.emit(center, 20.0, p)
	if landed:
		PlayerData.wear_weapon(2.0)
		Game.hitstop(0.08)


func _fire_bolt() -> void:
	var origin := p.chest_position() + p.facing_dir() * 0.8
	var dir := p.facing_dir()
	if lock_target_valid():
		dir = (lock_target.global_position + Vector3.UP - origin).normalized()
	Projectile.spawn(p.get_parent(), origin, dir * 22.0, weapon_damage() * 1.6, &"fire", p, false)
	PlayerData.wear_weapon(2.0)


# --- Plunge -------------------------------------------------------------------------------------------------------
func _start_plunge() -> void:
	_plunging = true
	p.velocity = Vector3(0, -26.0, 0)
	p.change_state(&"air")
	p.visual.play_action(&"slam", 0.6)


func _update_plunge() -> void:
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	p.velocity.y = -26.0
	if p.state_name() != &"air":
		_plunging = false
		_slam_at(p.global_position, 3.2, weapon_damage() * 2.2)
		p.start_busy(&"slam", 0.45)


# --- Hit resolution -----------------------------------------------------------------------------------------------
func _make_info(dmg: float, knock: Vector3, element: StringName) -> DamageInfo:
	var info := DamageInfo.make(dmg, p, knock, element)
	info.poise_damage = dmg * float(wstat("poise_mult", 1.0))
	return info


func _resolve_hits(reach: float, arc: float, dmg: float, knock: float, element: StringName) -> void:
	var t := Transform3D(Basis(Vector3.UP, p.facing_yaw), p.chest_position())
	var targets := CombatUtils.arc_query(p.get_world_3d(), t, reach + 0.4, arc, CombatUtils.CREATURE_MASK | CombatUtils.PROP_MASK, [p.get_rid()])
	var landed := false
	for body in targets:
		var dir := body.global_position - p.global_position
		dir.y = 0.0
		var info := _make_info(dmg, dir.normalized() * knock, element)
		if body.has_method("is_unaware") and body.is_unaware():
			info.amount *= 2.0
			info.is_critical = true
		if CombatUtils.deal(body, info):
			landed = true
			var hp := body.global_position + Vector3.UP * 0.9 - dir.normalized() * 0.3
			Effects.hit_spark(p, hp, info.is_critical)
			ElementFX.ring(p, hp, element, 0.9 if not info.is_critical else 1.5, 0.22)
	if landed:
		PlayerData.wear_weapon(1.0)
		Game.hitstop(0.055 if dmg < 20.0 else 0.085)
		Game.camera_rig.add_trauma(0.18 if dmg < 20.0 else 0.32)
		InputRouter.vibrate(25, 0.5)
		Audio.play_at(&"hit", p.global_position + p.facing_dir(), -1.0)
		p.emit_noise(15.0)


func _aim_assist() -> void:
	var best: Node3D = lock_target if lock_target_valid() else null
	if best == null:
		var best_score := INF
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e.has_method("is_dead") and e.is_dead():
				continue
			var to: Vector3 = e.global_position - p.global_position
			to.y = 0.0
			var d := to.length()
			if d > AIM_ASSIST_RANGE:
				continue
			var ref := p.move_dir() if p.move_dir() != Vector3.ZERO else p.facing_dir()
			var ang := ref.angle_to(to.normalized())
			if ang > deg_to_rad(75.0):
				continue
			var score := d + ang * 3.0
			if score < best_score:
				best_score = score
				best = e
	if best:
		var to := best.global_position - p.global_position
		p.face_towards(to.normalized(), 1.0, 100.0)


# --- Lock-on ------------------------------------------------------------------------------------------------------
func lock_target_valid() -> bool:
	return lock_target != null and is_instance_valid(lock_target) and not (lock_target.has_method("is_dead") and lock_target.is_dead())


func _update_lock_target() -> void:
	if Input.is_action_just_pressed("lock_on"):
		if lock_target_valid():
			lock_target = null
		else:
			lock_target = _find_lock_target()
	if lock_target != null and (not lock_target_valid() or lock_target.global_position.distance_to(p.global_position) > 25.0):
		lock_target = null


func _find_lock_target() -> Node3D:
	var cam := p.get_viewport().get_camera_3d()
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d: float = e.global_position.distance_to(p.global_position)
		if d > 22.0:
			continue
		var score := d
		if cam:
			var fwd := -cam.global_basis.z
			score += fwd.angle_to((e.global_position - cam.global_position).normalized()) * 12.0
		if score < best_score:
			best_score = score
			best = e
	return best


# --- Damage intake --------------------------------------------------------------------------------------------------
func receive(info: DamageInfo) -> void:
	if p.is_dead() or Debug.god_mode and info.kind != &"debug":
		return
	# Dodge i-frames
	if p.invulnerable:
		var dodge: DodgeState = p.states[&"dodge"]
		if p.state == dodge and dodge.is_perfect_window() and info.kind in [&"melee", &"slam", &"projectile"]:
			_perfect_dodge()
		return
	var from_front := true
	if info.source:
		var to := info.source.global_position - p.global_position
		to.y = 0.0
		from_front = p.facing_dir().angle_to(to.normalized()) < deg_to_rad(65.0)
	if p.blocking and info.blockable and from_front:
		if now() - _block_pressed_at <= PARRY_WINDOW:
			_parry(info)
			return
		var cost := info.amount * BLOCK_STAMINA_PER_DAMAGE
		if p.vitals.try_spend(cost):
			info.amount *= 0.2 if weapon_stack() != null else 0.45
			info.knockback *= 0.4
			Audio.play_at(&"block", p.global_position, -2.0)
			Effects.hit_spark(p, p.chest_position() + p.facing_dir() * 0.5, false)
			PlayerData.wear_weapon(0.5)
		else:
			info.poise_damage = 999.0
			EventBus.toast.emit(tr("TOAST_GUARD_BROKEN"))
	match info.element:
		&"fire":
			p.health.add_status(&"burning", 3.0)
		&"electric":
			if p.health.has_status(&"wet"):
				info.amount *= 2.0
			p.health.add_status(&"shocked", 0.6)
	var dmg := info.amount
	if info.kind != &"fall" and info.kind != &"environment":
		dmg = maxf(dmg - PlayerData.defense() * 0.6, dmg * 0.25)
	PlayerData.health -= dmg
	EventBus.player_damaged.emit(dmg, info.source)
	InputRouter.vibrate(45, 0.7)
	p.visual.set_flash(0.9, Color(1.0, 0.3, 0.25))
	_clear_flash()
	if dmg > 0.5:
		Game.camera_rig.add_trauma(clampf(dmg / 40.0, 0.15, 0.6))
		Audio.play_at(&"hurt", p.global_position, -2.0)
	if PlayerData.health <= 0.0:
		PlayerData.health = 0.0
		_cancel_actions()
		p.change_state(&"dead")
		return
	var heavy := info.poise_damage >= 18.0 or info.knockback.length() > 6.0
	if (heavy or info.poise_damage >= 999.0) and _hurt_cooldown <= 0.0 and p.state_name() in [&"ground", &"busy"]:
		_hurt_cooldown = 0.6
		_cancel_actions()
		p.start_busy(&"hit", 0.4, info.knockback * 0.8)
		p.visual.play_action(&"hit", 0.4)
	elif p.state_name() in [&"climb", &"glide"] and dmg > 8.0:
		p.change_state(&"air")


func _clear_flash() -> void:
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(p):
		p.visual.set_flash(0.0)


func _parry(info: DamageInfo) -> void:
	Audio.play_at(&"parry", p.global_position, 2.0)
	Effects.hit_spark(p, p.chest_position() + p.facing_dir() * 0.6, true)
	Game.hitstop(0.12, 0.02)
	Game.camera_rig.add_trauma(0.3)
	InputRouter.vibrate(40, 1.0)
	EventBus.parry_success.emit(p.global_position)
	p.visual.play_action(&"parry", 0.3)
	ElementFX.ring(p, p.chest_position() + p.facing_dir() * 0.6, &"", 2.2, 0.35)
	ElementFX.burst(p, p.global_position, &"", 2.5)
	if info.source and info.source.has_method("on_parried"):
		info.source.on_parried()


func _perfect_dodge() -> void:
	EventBus.perfect_dodge.emit()
	Afterimage.spawn(p.visual, PlayerData.cosmetic_color("afterimage", Color(0.5, 1.0, 0.85)))
	Audio.play_ui(&"perfect_dodge", 0.0)
	Game.slow_motion(0.35, 0.9)
	PlayerData.restore_stamina(20.0)


func _cancel_actions() -> void:
	_swing_t = -1.0
	_charging = false
	_queued = false
	_plunging = false
	_combo = 0


# --- Quick item -----------------------------------------------------------------------------------------------------
func use_quick_item() -> void:
	var id := PlayerData.quick_item
	if id == &"":
		return
	var s := PlayerData.inventory.find_first(id)
	if s == null:
		EventBus.toast.emit(tr("TOAST_NONE_LEFT") % tr(DB.item(id).name_key if DB.item(id) else String(id)))
		return
	use_stack(s)


func use_stack(s: ItemStack) -> void:
	var it := s.def()
	match it.use_action:
		&"eat":
			if PlayerData.consume(s):
				p.start_busy(&"eat", 0.6)
				p.visual.play_action(&"eat", 0.6)
				Effects.sparks(p, p.chest_position(), Color(0.6, 1.0, 0.6), 0.6)
		&"throw":
			PlayerData.inventory.remove_stack(s)
			p.start_busy(&"throw", 0.35)
			p.visual.play_action(&"throw", 0.35)
			var dir := p.facing_dir()
			if lock_target_valid():
				dir = (lock_target.global_position - p.global_position).normalized()
			var vel := dir * 13.0 + Vector3.UP * 5.5
			Projectile.spawn(p.get_parent(), p.chest_position() + dir * 0.5, vel, 18.0, StringName(it.weapon.get("element", "fire")), p, true)
		&"repair":
			var w := PlayerData.weapon()
			if w == null or w.durability_ratio() >= 1.0:
				EventBus.toast.emit(tr("TOAST_NOTHING_TO_REPAIR"))
				return
			if w.is_heirloom() and not it.has_tag("heirloom_repair"):
				EventBus.toast.emit(tr("TOAST_NEEDS_INGOT"))
				return
			PlayerData.inventory.remove_stack(s)
			PlayerData.repair_weapon(w, float(it.weapon.get("repair", 0.5)))
			Audio.play_ui(&"repair")
			EventBus.toast.emit(tr("TOAST_REPAIRED"))
		_:
			pass
