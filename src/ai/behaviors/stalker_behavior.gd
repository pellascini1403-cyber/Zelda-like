class_name StalkerBehavior
extends AIBehavior
## Mist hunters: they do not rush in. A dark hump keeps pace out at the
## edge of sight, circling — behind the Bellhull, beside a swimmer. Keep
## moving and it only follows; stop (to fish, to look around, to dive) and
## it closes in. Move off fast and it melts back into the mist.
## Tuning: stalk_distance, stalk_depth, strike_after (s standing still).

var _still := 0.0
var _last := Vector3.INF


func states() -> Array:
	return [StalkState.new(b)]


func player_speed(delta: float) -> float:
	var pl := Game.player as Player
	if pl == null:
		return 0.0
	var pos := pl.global_position
	var sp := 0.0 if _last == Vector3.INF else Vector2(pos.x - _last.x, pos.z - _last.z).length() / maxf(delta, 0.001)
	_last = pos
	return sp


func pre_tick(delta: float) -> StringName:
	var pl := Game.player as Player
	if pl == null or pl.is_dead():
		return &""
	var sp := player_speed(delta)
	_still = _still + delta if sp < 1.0 else 0.0
	var id := b.current.id()
	if id in [&"attack", &"react", &"flee"]:
		return &""
	var d := c.global_position.distance_to(pl.global_position)
	if id == &"chase":
		# Caught moving off at speed: back into the white.
		if sp > 3.5 and d > 6.0:
			_still = 0.0
			return &"stalk"
		return &""
	if id == &"stalk":
		return &"chase" if _still > float(param("strike_after", 3.0)) else &""
	return &"stalk" if d < 60.0 else &""


class StalkState:
	extends AIState
	var _side := 1.0

	func id() -> StringName:
		return &"stalk"

	func anim() -> StringName:
		return &"walk"

	func enter() -> void:
		c.set_hidden(false)
		c.sink = float(c.type.ai_value("stalk_depth", 0.35))
		_side = 1.0 if randf() < 0.5 else -1.0

	func exit() -> void:
		c.sink = float(c.type.ai_value("swim_depth", 0.6))

	func tick(_delta: float) -> StringName:
		var pl := Game.player as Player
		if pl == null:
			return &"patrol"
		var to_me := c.global_position - pl.global_position
		to_me.y = 0.0
		var d := to_me.length()
		if d > 70.0:
			return &"patrol"
		# Hold a ring around the target, sliding round it.
		var want := float(c.type.ai_value("stalk_distance", 22.0))
		var dir := to_me / maxf(d, 0.01)
		var tangent := Vector3(-dir.z, 0, dir.x) * _side
		var goal := pl.global_position + (dir * want + tangent * 6.0)
		c.go_to(goal, c.type.walk_speed * (1.6 if absf(d - want) > 8.0 else 1.0))
		c.face_towards(-to_me, 0.05)
		return &""
