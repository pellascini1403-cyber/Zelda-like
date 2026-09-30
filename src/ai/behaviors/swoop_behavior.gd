class_name SwoopBehavior
extends AIBehavior
## Flyers: climb out of reach, circle the target, then dive along a line.
## The dive is announced by a shadow disc on the ground where it will land,
## so the counterplay is to read the shadow and dodge or parry at impact.
## After the dive it skims the ground for a moment: the punish window.
## Tuning: swoop_height, swoop_every (s), swoop_attack (module attack id).


func states() -> Array:
	return [SwoopState.new(b)]


func pre_tick(_delta: float) -> StringName:
	if b.current.id() != &"chase" or not b.cooldown_ready(&"swoop"):
		return &""
	var pl := player()
	if pl == null or pl.is_dead():
		return &""
	var d := c.global_position.distance_to(pl.global_position)
	if d > 3.0 and d < 28.0 and c.perception.sees_player:
		return &"swoop"
	return &""


class SwoopState:
	extends AIState
	var phase := 0
	var locked := Vector3.ZERO
	var tele: Telegraph
	var hit := false
	var orbit := 0.0
	var dir := Vector3.FORWARD

	func id() -> StringName:
		return &"swoop"

	func anim() -> StringName:
		return &"run"

	func enter() -> void:
		phase = 0
		hit = false
		tele = null
		orbit = randf() * TAU
		c.lift = float(c.type.ai_value("swoop_height", 8.0))

	func exit() -> void:
		c.lift = 0.0
		c.scripted = false
		if tele and phase == 1:
			tele.cancel()
		b.set_cooldown(&"swoop", float(c.type.ai_value("swoop_every", 6.0)))

	func tick(delta: float) -> StringName:
		var pl := Game.player as Player
		if pl == null:
			return &"chase"
		match phase:
			0:
				# Circle high over the target.
				orbit += delta * 1.4
				c.go_to(pl.global_position + Vector3(cos(orbit), 0, sin(orbit)) * 8.0, c.type.run_speed)
				if t > 1.8:
					phase = 1
					t = 0.0
					locked = pl.global_position
					var atk := b.attack_by_id(StringName(c.type.ai_value("swoop_attack", "swoop")))
					var windup := atk.windup if atk else 0.9
					tele = Telegraph.disc(c, locked, 2.4, windup, ArtStyle.attack_color(c.type, atk.element if atk else &""))
					Audio.play_at(&"gust", c.global_position, -2.0)
			1:
				c.go_to(locked, c.type.walk_speed)
				var atk := b.attack_by_id(StringName(c.type.ai_value("swoop_attack", "swoop")))
				if t >= (atk.windup if atk else 0.9):
					phase = 2
					t = 0.0
					dir = (locked - c.global_position)
					c.scripted = true
					c.visual.play_action(&"charge", 0.6)
			2:
				# Straight dive through the locked point.
				var atk := b.attack_by_id(StringName(c.type.ai_value("swoop_attack", "swoop")))
				var spd := atk.charge_speed if atk else 20.0
				var step := dir.normalized() * spd * delta
				c.global_position += step
				c.face_towards(step, delta)
				var ground := c.global_position.y - 0.8
				var from := c.global_position + Vector3.UP * 2.0
				var g := c.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1))
				if not g.is_empty():
					ground = g["position"].y
				if not hit:
					_contact(atk)
				if c.global_position.y < ground + 0.9 or t > 1.2:
					c.global_position.y = maxf(c.global_position.y, ground + 0.9)
					phase = 3
					t = 0.0
					c.scripted = false
					c.lift = -float(c.type.ai_value("hover", 3.0)) + 0.9
					Effects.dust(c, c.global_position, 1.2)
			3:
				# Skimming the ground: vulnerable.
				c.stop()
				if t > float(c.type.ai_value("swoop_recover", 1.4)):
					return &"chase"
		return &""

	func _contact(atk: AttackData) -> void:
		var center := c.global_position + Vector3.UP * 0.5
		for body in CombatUtils.sphere_query(c.get_world_3d(), center, c.type.collider_radius + 1.0, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
			var info := DamageInfo.make(atk.damage if atk else 12.0, c, dir.normalized() * (atk.knockback if atk else 8.0) + Vector3.UP * 3.0, b.attack_element(atk) if atk else &"")
			info.poise_damage = atk.poise_damage if atk else 20.0
			if CombatUtils.deal(body, info) and body == Game.player:
				hit = true
				b.notify_hit(body)
