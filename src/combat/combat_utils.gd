class_name CombatUtils
extends RefCounted
## Shared hit detection. Melee uses an arc query against creature bodies
## rather than animation-driven hitboxes, so final models / animations can be
## swapped without retuning combat.

const CREATURE_MASK := 1 << 2       # layer 3: creatures
const PLAYER_MASK := 1 << 1         # layer 2: player
const PROP_MASK := 1 << 3           # layer 4: props


## Returns bodies inside a cone (reach, half-angle) in front of `origin`.
static func arc_query(world: World3D, origin: Transform3D, reach: float, arc_deg: float, mask: int, exclude: Array[RID] = []) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	q.shape = sphere
	q.transform = Transform3D(Basis(), origin.origin)
	q.collision_mask = mask
	q.exclude = exclude
	q.collide_with_areas = false
	var hits := world.direct_space_state.intersect_shape(q, 24)
	var fwd := -origin.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cos_arc := cos(deg_to_rad(arc_deg))
	for h in hits:
		var body: Node3D = h["collider"]
		if body == null or body in out:
			continue
		var to := body.global_position - origin.origin
		to.y = 0.0
		var dist := to.length()
		if dist < 0.8 or fwd.dot(to / maxf(dist, 0.001)) >= cos_arc:
			out.append(body)
	return out


static func sphere_query(world: World3D, center: Vector3, radius: float, mask: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	q.shape = sphere
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = mask
	for h in world.direct_space_state.intersect_shape(q, 32):
		var body: Node3D = h["collider"]
		if body and not body in out:
			out.append(body)
	return out


## Anything with take_damage(info) can be hit (creatures, props, ore rocks).
static func deal(target: Node, info: DamageInfo) -> bool:
	if target and target.has_method("take_damage"):
		target.take_damage(info)
		return true
	return false


static func line_of_sight(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = exclude
	return world.direct_space_state.intersect_ray(q).is_empty()
