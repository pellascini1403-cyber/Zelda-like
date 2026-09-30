class_name DropBehavior
extends AIBehavior
## Climbers: wait high on a cliff or wall above their home and drop on
## whoever passes beneath (a shadow disc marks where they will land). They
## go straight for a player who is climbing — the wall is their ground.
## Tuning: drop_radius, drop_attack.


func states() -> Array:
	return [ClingState.new(b), DropState.new(b)]


func initial_state() -> StringName:
	return &"cling"


func pre_tick(_delta: float) -> StringName:
	var pl := player()
	if pl == null or pl.is_dead():
		return &""
	var id := b.current.id()
	if id in [&"idle", &"patrol", &"cling", &"investigate", &"search"]:
		if pl.state_name() == &"climb" and c.global_position.distance_to(pl.global_position) < 16.0:
			c.perception.alert(pl.global_position)
			return &"chase"
	if id == &"idle" and c.perception.awareness < 0.3 and b.cooldown_ready(&"recling"):
		b.set_cooldown(&"recling", 8.0)
		return &"cling"
	return &""


class ClingState:
	extends AIState
	var perch := Vector3.INF

	func id() -> StringName:
		return &"cling"

	func anim() -> StringName:
		return &"walk" if c.move_speed > 0.1 else &"idle"

	func enter() -> void:
		perch = _find_perch()
		c.go_to(perch, c.type.walk_speed)

	func _find_perch() -> Vector3:
		var best := c.home
		var best_h := -INF
		var space := c.get_world_3d().direct_space_state
		for i in 10:
			var a := TAU * i / 10.0
			var p := c.home + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 12.0)
			var from := Vector3(p.x, c.home.y + 60.0, p.z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0, 1))
			if hit.is_empty() or hit["position"].y < WorldGen.SEA_LEVEL:
				continue
			if hit["position"].y > best_h:
				best_h = hit["position"].y
				best = hit["position"]
		return best

	func tick(_delta: float) -> StringName:
		if c.global_position.distance_to(perch) < 1.5:
			c.stop()
		var pl := Game.player as Player
		if pl == null or pl.is_dead():
			return &""
		var flat := Vector2(pl.global_position.x - c.global_position.x, pl.global_position.z - c.global_position.z).length()
		if flat < float(c.type.ai_value("drop_radius", 6.0)) and pl.global_position.y < c.global_position.y - 2.5 and b.cooldown_ready(&"drop"):
			return &"drop"
		if c.perception.awareness >= 1.0:
			return &"chase"
		return &""


class DropState:
	extends AIState
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var landed := false
	var tele_time := 0.6

	func id() -> StringName:
		return &"drop"

	func anim() -> StringName:
		return &"lunge"

	func enter() -> void:
		c.stop()
		landed = false
		from = c.global_position
		to = Game.player.global_position if Game.player else c.global_position
		var atk := b.attack_by_id(StringName(c.type.ai_value("drop_attack", "drop")))
		tele_time = atk.windup if atk else 0.6
		Telegraph.disc(c, to, atk.radius if atk and atk.radius > 0.0 else 2.2, tele_time, ArtStyle.attack_color(c.type, &""))
		c.visual.play_action(&"windup", tele_time)

	func exit() -> void:
		c.scripted = false
		b.set_cooldown(&"drop", 7.0)

	func tick(_delta: float) -> StringName:
		if t < tele_time:
			return &""
		var k := clampf((t - tele_time) / 0.55, 0.0, 1.0)
		c.scripted = true
		c.global_position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 2.0
		if k >= 1.0 and not landed:
			landed = true
			c.scripted = false
			var atk := b.attack_by_id(StringName(c.type.ai_value("drop_attack", "drop")))
			var radius := atk.radius if atk and atk.radius > 0.0 else 2.2
			for body in CombatUtils.sphere_query(c.get_world_3d(), to, radius, CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
				var info := DamageInfo.make(atk.damage if atk else 14.0, c, Vector3.UP * 4.0, b.attack_element(atk) if atk else &"")
				info.kind = &"slam"
				if CombatUtils.deal(body, info):
					b.notify_hit(body)
			Effects.dust(c, to, 1.6)
			Audio.play_at(&"land", to, 0.0)
			c.perception.alert(to)
		if landed and t > tele_time + 1.1:
			return &"chase"
		return &""
