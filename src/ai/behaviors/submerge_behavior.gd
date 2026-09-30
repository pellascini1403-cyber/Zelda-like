class_name SubmergeBehavior
extends AIBehavior
## Swimmers: a dark shape deep under the surface that cannot be hit. When a
## target is near the water it rises (ripples warn a moment before), strikes
## from the surface, lingers there — the window to hit it, and lightning or
## shock hits it twice as hard, it is soaked — then sinks again.
## Tuning: surface_range, surface_time, deep_depth.


func states() -> Array:
	return [SubmergedState.new(b), SurfaceState.new(b)]


func initial_state() -> StringName:
	return &"submerged"


func pre_tick(_delta: float) -> StringName:
	var id := b.current.id()
	if id in [&"submerged", &"surface", &"attack", &"react"]:
		return &""
	# Surfaced long enough (chasing, searching...): dive.
	var sf := b.states[&"surface"] as SurfaceState
	if sf.since > 0 and (Time.get_ticks_msec() - sf.since) / 1000.0 > float(param("surface_time", 4.0)):
		sf.since = 0
		return &"submerged"
	return &""


class SubmergedState:
	extends AIState
	var point := Vector3.ZERO

	func id() -> StringName:
		return &"submerged"

	func anim() -> StringName:
		return &"walk"

	func enter() -> void:
		c.set_hidden(true)
		c.sink = float(c.type.ai_value("deep_depth", 2.4))
		point = random_point_near(c.home, float(c.type.ai_value("wander_radius", 10.0)))
		c.go_to(point, c.type.walk_speed)

	func tick(_delta: float) -> StringName:
		var pl := Game.player as Player
		if pl and not pl.is_dead():
			var d := c.global_position.distance_to(pl.global_position)
			var near_water := pl.water_depth() > -1.5 or pl.vehicle != null
			if d < float(c.type.ai_value("surface_range", 12.0)) and near_water and t > 1.5 and b.cooldown_ready(&"surface"):
				return &"surface"
			if d < 24.0 and near_water:
				# Shadowing the target from below.
				c.go_to(pl.global_position, c.type.walk_speed * 1.3)
				return &""
		if c.global_position.distance_to(point) < 2.0 or t > 10.0:
			point = random_point_near(c.home, float(c.type.ai_value("wander_radius", 10.0)))
			c.go_to(point, c.type.walk_speed)
			t = 0.0
		return &""


class SurfaceState:
	extends AIState
	var since := 0

	func id() -> StringName:
		return &"surface"

	func enter() -> void:
		c.stop()
		# Rise until the head and back break the surface.
		c.sink = -0.15
		Telegraph.disc(c, c.global_position, c.type.collider_radius + 1.2, 0.8, Color(0.6, 0.85, 1.0))
		Effects.splash(c, Vector3(c.global_position.x, WorldGen.SEA_LEVEL, c.global_position.z))

	func tick(_delta: float) -> StringName:
		if t < 0.8:
			return &""
		c.set_hidden(false)
		since = Time.get_ticks_msec()
		b.set_cooldown(&"surface", 6.0)
		Audio.play_at(&"splash", c.global_position, -2.0)
		var pl := Game.player
		if pl:
			c.perception.alert(pl.global_position)
			var atk := b.pick_attack(c.global_position.distance_to(pl.global_position))
			if atk:
				(b.states[&"attack"] as AttackState).attack = atk
				return &"attack"
		return &"chase"
