class_name Projectile
extends Node3D
## Ballistic projectile (enemy spit, thrown resin bomb, fire bolt).
## Integrates itself and ray-casts the path each frame (no physics body), so
## hundreds are cheap. Wind pushes lobbed projectiles. Parry reflects.

var velocity := Vector3.ZERO
var damage := 10.0
var element: StringName = &""
var owner_body: Node3D
var gravity := 0.0
var explode_radius := 0.0
var life := 5.0
var reflected := false

var _mesh: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, vel: Vector3, dmg: float, elem: StringName, source: Node3D, lobbed: bool) -> Projectile:
	var p := Projectile.new()
	p.velocity = vel
	p.damage = dmg
	p.element = elem
	p.owner_body = source
	p.gravity = 16.0 if lobbed else 0.0
	p.explode_radius = 3.2 if elem == &"fire" and lobbed else (1.4 if lobbed else 0.0)
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.16
	s.height = 0.32
	s.radial_segments = 8
	s.rings = 4
	_mesh.mesh = s
	var m := StandardMaterial3D.new()
	var c := Color(1.0, 0.55, 0.15) if element == &"fire" else (Color(0.55, 0.95, 0.3) if element == &"acid" else Color(0.9, 0.9, 0.95))
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.2
	_mesh.material_override = m
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_impact(global_position, null)
		return
	velocity.y -= gravity * delta
	if gravity > 0.0:
		velocity += Weather.wind * Weather.wind_strength * 2.0 * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | CombatUtils.CREATURE_MASK | CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK)
	if is_instance_valid(owner_body) and owner_body is CollisionObject3D:
		q.exclude = [(owner_body as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_impact(hit["position"], hit["collider"])
		return
	global_position = to
	if WorldGen.SEA_LEVEL > global_position.y and element == &"fire":
		# Fire fizzles in water.
		Effects.splash(self, global_position)
		queue_free()


## Parried projectiles fly back at the thrower.
func reflect(new_owner: Node3D) -> void:
	velocity = -velocity * 1.2
	owner_body = new_owner
	reflected = true


func _impact(pos: Vector3, collider: Object) -> void:
	var info := DamageInfo.make(damage, owner_body, velocity.normalized() * 4.0, element)
	info.kind = &"projectile"
	if collider is Player and not reflected:
		var pl: Player = collider
		if pl.blocking and pl.combat.now() - pl.combat._block_pressed_at <= PlayerCombat.PARRY_WINDOW:
			reflect(pl)
			Audio.play_at(&"parry", pos, 0.0)
			return
	if explode_radius > 0.0:
		Explosion.trigger(get_parent(), pos, explode_radius, damage, element, owner_body)
	elif collider:
		CombatUtils.deal(collider, info)
		if element == &"fire" and collider is Node3D:
			FireSource.ignite_at(get_parent(), pos, 5.0)
	Effects.hit_spark(self, pos, false)
	queue_free()
