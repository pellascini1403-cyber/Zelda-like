class_name AttackState
extends AIState
## Executes one AttackData: windup (telegraph glow + anticipation), active
## (hit / projectile / lunge / slam / pulse), recovery (punish window).

var attack: AttackData
var _phase := 0
var _dir := Vector3.FORWARD
var _tele: Telegraph
var _hit_once := false
## Multiplier applied by bosses per phase (faster windups when enraged).
var speed_mult := 1.0


func id() -> StringName:
	return &"attack"


func enter() -> void:
	_phase = 0
	c.stop()
	var aim := c.threat_target()
	if aim:
		_dir = (aim.global_position - c.global_position)
		_dir.y = 0.0
		_dir = _dir.normalized()
	c.visual.play_action(&"windup", attack.windup)
	_hit_once = false
	_tele = null
	if attack.telegraph:
		_show_telegraph()


func exit() -> void:
	c.visual.set_flash(0.0)
	c.move_speed = 0.0
	if _tele and _tele.visible and _phase == 0:
		_tele.cancel()
	_tele = null


func _windup() -> float:
	return attack.windup / maxf(speed_mult, 0.1)


func _show_telegraph() -> void:
	var col: Color = ArtStyle.attack_color(c.type, attack.element)
	match attack.type:
		&"slam", &"pulse":
			var radius := attack.radius if attack.radius > 0.0 else attack.reach
			var center := c.global_position + (_dir * attack.reach * 0.5 if attack.type == &"slam" else Vector3.ZERO)
			_tele = Telegraph.disc(c, center, radius, _windup(), col)
		&"charge":
			_tele = Telegraph.line(c, c.global_position, _dir, attack.reach, c.type.collider_radius * 2.4, _windup(), col)
		&"melee":
			_tele = Telegraph.cone(c, c.global_position, _dir, attack.reach + c.type.collider_radius, attack.arc * 2.0, _windup(), col)


func tick(delta: float) -> StringName:
	if attack == null:
		return &"chase"
	match _phase:
		0:
			# Track the player during most of the windup, then commit.
			var aim := c.threat_target()
			if t < _windup() * 0.7 and aim and attack.type != &"charge":
				var to := aim.global_position - c.global_position
				to.y = 0.0
				_dir = to.normalized()
			c.face_towards(_dir, delta * 2.0)
			c.visual.set_flash(clampf(t / _windup(), 0.0, 1.0) * 0.55, ArtStyle.palette("violet_hot") if ArtStyle.is_corrupted(c.type) else Color(1.0, 0.85, 0.4))
			if _tele and attack.type == &"melee" and t < _windup() * 0.7:
				_tele.global_position = Telegraph._ground(c, c.global_position + _dir * (attack.reach + c.type.collider_radius) * 0.5)
				_tele.global_basis = Basis(Vector3.UP, atan2(_dir.x, _dir.z)) * Basis().scaled(Vector3(attack.reach + c.type.collider_radius, 1, (attack.reach + c.type.collider_radius) * 0.5))
			if t >= _windup():
				_phase = 1
				t = 0.0
				c.visual.set_flash(0.0)
				_strike()
		1:
			if attack.type == &"lunge":
				c.go_to(c.global_position + _dir * 3.0, attack.lunge_speed)
			elif attack.type == &"charge":
				c.go_to(c.global_position + _dir * 4.0, attack.charge_speed)
				if not _hit_once:
					_charge_contact()
			if t >= attack.active:
				_phase = 2
				t = 0.0
				c.stop()
		2:
			if t >= attack.recovery:
				b.set_cooldown(attack.id, attack.cooldown)
				return &"chase"
	return &""


func _strike() -> void:
	var anim_name := &"attack_1"
	match attack.type:
		&"melee", &"lunge":
			anim_name = &"attack_1" if randf() < 0.5 else &"attack_2"
			if attack.type == &"lunge":
				anim_name = &"lunge"
				_delayed_melee(attack.active * 0.5)
			else:
				_melee()
		&"projectile":
			anim_name = &"attack"
			var origin := c.global_position + Vector3.UP * c.type.collider_height * 0.75 + _dir * (c.type.collider_radius + 0.3)
			var aim_node := c.threat_target()
			var tgt := (aim_node.global_position if aim_node else c.global_position + _dir * 8.0) + Vector3.UP * 1.0
			var vel := _ballistic(origin, tgt, attack.projectile_speed)
			Projectile.spawn(c.get_parent(), origin, vel, attack.damage, attack.element, c, true)
			Audio.play_at(&"spit", origin, -2.0)
		&"slam":
			anim_name = &"slam"
			_slam()
		&"pulse":
			anim_name = &"attack"
			_slam()
		&"charge":
			anim_name = &"charge"
			Audio.play_at(&"swing_heavy", c.global_position, 0.0)
		&"volley":
			anim_name = &"attack"
			_volley()
		&"eruption":
			anim_name = &"slam"
			_eruptions()
		&"summon":
			anim_name = &"attack"
			_summon()
	c.visual.play_action(anim_name, attack.active + attack.recovery * 0.5)
	EventBus.noise_emitted.emit(c.global_position, 10.0, c)


func _delayed_melee(delay: float) -> void:
	await c.get_tree().create_timer(delay, false).timeout
	if is_instance_valid(c) and not c.dead and b.current == self:
		_melee()


func _melee() -> void:
	var tr := Transform3D(Basis(Vector3.UP, atan2(-_dir.x, -_dir.z)), c.global_position + Vector3.UP * c.type.collider_height * 0.5)
	for body in CombatUtils.arc_query(c.get_world_3d(), tr, attack.reach + c.type.collider_radius, attack.arc, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK, [c.get_rid()]):
		var info := DamageInfo.make(attack.damage, c, _dir * attack.knockback, attack.element)
		info.poise_damage = attack.poise_damage
		info.blockable = attack.blockable
		CombatUtils.deal(body, info)
	Audio.play_at(&"swing", c.global_position, -4.0, 0.2)


func _slam() -> void:
	var center := c.global_position + _dir * (attack.reach * 0.5)
	var radius := attack.radius if attack.radius > 0.0 else attack.reach
	for body in CombatUtils.sphere_query(c.get_world_3d(), center, radius, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
		var to: Vector3 = body.global_position - center
		to.y = 0.0
		var info := DamageInfo.make(attack.damage, c, to.normalized() * attack.knockback + Vector3.UP * 3.0, attack.element)
		info.kind = &"slam"
		info.poise_damage = attack.poise_damage
		info.blockable = attack.blockable
		CombatUtils.deal(body, info)
	Effects.dust(c, center, 2.0)
	Audio.play_at(&"slam", center, 0.0)
	if Game.camera_rig and Game.player and Game.player.global_position.distance_to(center) < 12.0:
		Game.camera_rig.add_trauma(0.3)


## Launch velocity that lands on `to` for a lobbed projectile.
func _ballistic(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var g := 16.0
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var dist := flat.length()
	var time := maxf(dist / speed, 0.35)
	var vy := (to.y - from.y + 0.5 * g * time * time) / time
	return flat / time + Vector3.UP * vy


## Charge: damage once on contact while dashing.
func _charge_contact() -> void:
	var center := c.global_position + Vector3.UP * c.type.collider_height * 0.5 + _dir * c.type.collider_radius
	for body in CombatUtils.sphere_query(c.get_world_3d(), center, c.type.collider_radius + 0.8, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
		var info := DamageInfo.make(attack.damage, c, _dir * attack.knockback + Vector3.UP * 2.5, attack.element)
		info.poise_damage = attack.poise_damage
		info.blockable = attack.blockable
		if CombatUtils.deal(body, info) and body == Game.player:
			_hit_once = true
			if Game.camera_rig:
				Game.camera_rig.add_trauma(0.35)


## Volley: a fan of projectiles aimed at the player.
func _volley() -> void:
	if Game.player == null:
		return
	var origin := c.global_position + Vector3.UP * c.type.collider_height * 0.75 + _dir * (c.type.collider_radius + 0.3)
	var tgt := Game.player.global_position + Vector3.UP * 1.0
	var n := maxi(attack.count, 1)
	for i in n:
		var k := 0.0 if n == 1 else (float(i) / (n - 1) - 0.5)
		var aim := origin + (tgt - origin).rotated(Vector3.UP, deg_to_rad(attack.spread) * k)
		Projectile.spawn(c.get_parent(), origin, _ballistic(origin, aim, attack.projectile_speed), attack.damage, attack.element, c, true)
	Audio.play_at(&"spit", origin, 0.0)


## Eruption: warning discs at (and around) the player, bursting after `delay`.
func _eruptions() -> void:
	if Game.player == null:
		return
	var n := maxi(attack.count, 1)
	var radius := attack.radius if attack.radius > 0.0 else 2.2
	var col: Color = ArtStyle.attack_color(c.type, attack.element)
	var world := c.get_world_3d()
	var parent := c.get_parent()
	for i in n:
		var p := Game.player.global_position
		if i > 0:
			var a := TAU * float(i) / n + randf() * 0.5
			p += Vector3(cos(a), 0, sin(a)) * radius * 1.6
		Telegraph.disc(c, p, radius, attack.delay, col)
		_burst_later(world, parent, p, radius, attack.delay + i * 0.12)


func _burst_later(world: World3D, parent: Node, p: Vector3, radius: float, wait: float) -> void:
	await c.get_tree().create_timer(wait, false).timeout
	if not is_instance_valid(c) or c.dead:
		return
	for body in CombatUtils.sphere_query(world, p, radius, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
		var info := DamageInfo.make(attack.damage, c, Vector3.UP * attack.knockback, attack.element)
		info.kind = &"slam"
		info.blockable = false
		info.poise_damage = attack.poise_damage
		CombatUtils.deal(body, info)
	ElementFX.burst(parent, p, attack.element, radius)
	Audio.play_at(&"slam", p, -3.0)


## Summon: calls reinforcements around the caster.
func _summon() -> void:
	var dir := c.get_tree().get_first_node_in_group(&"spawn_director")
	if dir == null or attack.summon == &"":
		return
	for i in attack.summon_count:
		var a := TAU * float(i) / attack.summon_count
		var p := c.global_position + Vector3(cos(a), 0.5, sin(a)) * (c.type.collider_radius + 3.0)
		var m: Creature = dir.spawn_creature(attack.summon, p, "", c.group_id)
		if m:
			m.perception.alert(Game.player.global_position if Game.player else p)
			ElementFX.burst(c.get_parent(), p, attack.element, 1.2)
