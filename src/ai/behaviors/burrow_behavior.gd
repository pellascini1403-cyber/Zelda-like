class_name BurrowBehavior
extends AIBehavior
## Travels under the ground, leaving a moving dust trail. It hunts by
## vibration: a target that keeps moving is followed, one that stands still
## for a moment is lost. Close enough, the ground trembles (a disc warns),
## it bursts out, stays exposed for a while, then digs back in.
## Tuning: hear_range, still_time, surface_time, erupt_attack.


func states() -> Array:
	return [BurrowingState.new(b), EruptState.new(b)]


func initial_state() -> StringName:
	return &"burrowing"


func pre_tick(_delta: float) -> StringName:
	var id := b.current.id()
	if id in [&"burrowing", &"erupt", &"attack", &"react"]:
		return &""
	var er := b.states[&"erupt"] as EruptState
	if er.since > 0 and (Time.get_ticks_msec() - er.since) / 1000.0 > float(param("surface_time", 5.0)):
		er.since = 0
		return &"burrowing"
	return &""


class BurrowingState:
	extends AIState
	var still := 0.0
	var dust := 0.0
	var point := Vector3.ZERO

	func id() -> StringName:
		return &"burrowing"

	func anim() -> StringName:
		return &"walk"

	func enter() -> void:
		c.set_hidden(true)
		Effects.dust(c, c.global_position, 1.4)
		still = 0.0
		point = random_point_near(c.home, float(c.type.ai_value("wander_radius", 10.0)))

	func tick(delta: float) -> StringName:
		dust -= delta
		if dust <= 0.0 and c.velocity.length() > 0.5 and c.tier == Creature.Tier.FULL:
			dust = 0.25
			Effects.dust(c, c.global_position, 0.5)
		var pl := Game.player as Player
		var hunting := false
		if pl and not pl.is_dead():
			var d := c.global_position.distance_to(pl.global_position)
			var moving := Vector2(pl.velocity.x, pl.velocity.z).length() > 1.2 or pl.vehicle != null
			still = 0.0 if moving else still + delta
			if d < float(c.type.ai_value("hear_range", 26.0)) and still < float(c.type.ai_value("still_time", 1.5)):
				hunting = true
				c.go_to(pl.global_position, c.type.run_speed)
				if d < 2.4 and t > 1.0:
					return &"erupt"
		if not hunting:
			if c.global_position.distance_to(point) < 2.0 or t > 9.0:
				point = random_point_near(c.home, float(c.type.ai_value("wander_radius", 10.0)))
				t = 0.0
			c.go_to(point, c.type.walk_speed)
		return &""


class EruptState:
	extends AIState
	var since := 0
	var burst := false

	func id() -> StringName:
		return &"erupt"

	func enter() -> void:
		c.stop()
		burst = false
		var atk := b.attack_by_id(StringName(c.type.ai_value("erupt_attack", "erupt")))
		Telegraph.disc(c, c.global_position, atk.radius if atk and atk.radius > 0.0 else 2.2, atk.windup if atk else 0.8, ArtStyle.attack_color(c.type, &""))
		if Game.camera_rig and Game.player and Game.player.global_position.distance_to(c.global_position) < 10.0:
			Game.camera_rig.add_trauma(0.15)

	func tick(_delta: float) -> StringName:
		var atk := b.attack_by_id(StringName(c.type.ai_value("erupt_attack", "erupt")))
		if not burst and t >= (atk.windup if atk else 0.8):
			burst = true
			c.set_hidden(false)
			since = Time.get_ticks_msec()
			var radius := atk.radius if atk and atk.radius > 0.0 else 2.2
			for body in CombatUtils.sphere_query(c.get_world_3d(), c.global_position, radius, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
				var info := DamageInfo.make(atk.damage if atk else 14.0, c, Vector3.UP * (atk.knockback if atk else 8.0), b.attack_element(atk) if atk else &"")
				info.kind = &"slam"
				info.blockable = false
				if CombatUtils.deal(body, info):
					b.notify_hit(body)
			Effects.dust(c, c.global_position, 2.5)
			Audio.play_at(&"slam", c.global_position, 0.0)
			c.visual.play_action(&"slam", 0.6)
		if burst and t > 1.2:
			if Game.player:
				c.perception.alert(Game.player.global_position)
			return &"chase"
		return &""
