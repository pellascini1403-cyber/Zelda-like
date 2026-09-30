class_name CurrentRiderBehavior
extends AIBehavior
## Rip hunters (with `submerge`): instead of swimming straight at you, they
## slip into the nearest sea current upstream of you and let it sweep them
## down onto you — so they come from where the water comes from, fast. Out
## of a current they hunt like any finback. The body adds the drift itself
## (ai "current_ride").

const REACH := 45.0


func states() -> Array:
	return [CurrentRideState.new(b)]


func pre_tick(_delta: float) -> StringName:
	if b.current.id() != &"submerged" or not b.cooldown_ready(&"ride"):
		return &""
	var pl := Game.player as Player
	if pl == null or c.global_position.distance_to(pl.global_position) > 50.0:
		return &""
	return &"ride" if CurrentRiderBehavior.entry_point(c, pl) != Vector3.INF else &""


## A point in a current 25 m upstream of the player, if one runs near both.
static func entry_point(cr: Creature, pl: Player) -> Vector3:
	for n in cr.get_tree().get_nodes_in_group(&"currents"):
		var cur := n as SeaCurrent
		if cur.strength_now() < 1.2:
			continue
		var inv := cur.global_transform.affine_inverse()
		var pl_l := inv * pl.global_position
		if absf(pl_l.x) > cur.width * 1.5 or pl_l.z > 10.0 or pl_l.z < -cur.length - 10.0:
			continue
		var lp := Vector3(clampf(pl_l.x, -cur.width * 0.25, cur.width * 0.25), 0, clampf(pl_l.z + 25.0, -cur.length, -1.0))
		var gp := cur.global_transform * lp
		if gp.distance_to(cr.global_position) < REACH:
			return Vector3(gp.x, cr.global_position.y, gp.z)
	return Vector3.INF


class CurrentRideState:
	extends AIState
	var point := Vector3.INF

	func id() -> StringName:
		return &"ride"

	func anim() -> StringName:
		return &"walk"

	func enter() -> void:
		c.set_hidden(true)
		c.sink = float(c.type.ai_value("deep_depth", 2.4))
		var pl := Game.player as Player
		point = CurrentRiderBehavior.entry_point(c, pl) if pl else Vector3.INF

	func exit() -> void:
		b.cooldowns[&"ride"] = 6.0

	func tick(_delta: float) -> StringName:
		var pl := Game.player as Player
		if pl == null or point == Vector3.INF or t > 10.0:
			return &"submerged"
		var in_current := SeaCurrent.current_at(c.global_position, c.get_tree()) != null
		if not in_current:
			c.go_to(point, c.type.run_speed)
			return &""
		# In the stream: let it carry us, steer toward the target.
		c.go_to(pl.global_position, c.type.walk_speed)
		if c.global_position.distance_to(pl.global_position) < float(c.type.ai_value("surface_range", 9.0)) + 3.0 and b.cooldown_ready(&"surface"):
			return &"surface"
		return &""
