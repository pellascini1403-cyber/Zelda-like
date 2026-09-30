class_name PhysicsProp
extends RigidBody3D
## Interactive physical object with a material that decides its reactions:
##   wood  -> breakable, flammable (burns then breaks, drops loot)
##   metal -> heavy, conductive (electric damage arcs to nearby creatures)
##   stone -> heavy, rolls, crushes (boulders)
##   explosive -> blows up on fire or strong hits
## Simulation sleeps / freezes far from the player (distance activation).

const FREEZE_DISTANCE := 70.0

var kind: StringName = &"crate"
var material_type: StringName = &"wood"
var hp := 20.0
var loot_table: StringName = &""
var persist_id := ""

var _burning := 0.0
var _check := 0.0
var _mesh: MeshInstance3D
var _fire: FireSource


static func create(prop_kind: StringName, id: String = "") -> PhysicsProp:
	var p := PhysicsProp.new()
	p.kind = prop_kind
	p.persist_id = id
	return p


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1 | (1 << 1) | (1 << 2) | (1 << 3)
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 2
	add_to_group(&"props")
	var cs := CollisionShape3D.new()
	var b := MeshKit.Builder.new()
	match kind:
		&"crate":
			material_type = &"wood"
			mass = 12.0
			hp = 12.0
			loot_table = &"crate"
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			cs.shape = box
			b.box(Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Color(0.62, 0.45, 0.28))
			b.box(Vector3(0, 0, 0.505), Vector3(0.9, 0.12, 0.01), Color(0.45, 0.3, 0.18))
			b.box(Vector3(0, 0, -0.505), Vector3(0.9, 0.12, 0.01), Color(0.45, 0.3, 0.18))
		&"barrel":
			material_type = &"explosive"
			mass = 20.0
			hp = 6.0
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.45
			cyl.height = 1.1
			cs.shape = cyl
			b.cylinder(Vector3(0, -0.55, 0), 1.1, 0.45, 0.45, 10, Color(0.55, 0.22, 0.14))
			b.cylinder(Vector3(0, -0.2, 0), 0.08, 0.47, 0.47, 10, Color(0.3, 0.3, 0.3))
			b.cylinder(Vector3(0, 0.25, 0), 0.08, 0.47, 0.47, 10, Color(0.3, 0.3, 0.3))
		&"metal_crate":
			material_type = &"metal"
			mass = 60.0
			hp = 999.0
			var box2 := BoxShape3D.new()
			box2.size = Vector3(1.2, 1.2, 1.2)
			cs.shape = box2
			b.box(Vector3.ZERO, Vector3(1.2, 1.2, 1.2), Color(0.5, 0.53, 0.56))
		&"boulder":
			material_type = &"stone"
			mass = 180.0
			hp = 999.0
			var sph := SphereShape3D.new()
			sph.radius = 1.3
			cs.shape = sph
			b.blob(Vector3.ZERO, Vector3(1.35, 1.3, 1.35), Color(0.56, 0.54, 0.5), Color(0.4, 0.38, 0.36), 1, 0.06, 4)
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.commit()
	_mesh.material_override = WorldMaterials.get_mat(&"vertex_color")
	_mesh.visibility_range_end = 150.0 if kind == &"boulder" else 90.0
	add_child(_mesh)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.5 if kind == &"boulder" else 0.8
	pm.bounce = 0.05
	physics_material_override = pm
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_update_activation()
	if _burning > 0.0:
		_burning -= delta
		if _burning <= 0.0:
			break_apart()


func _update_activation() -> void:
	if Game.player == null:
		return
	var far := global_position.distance_to(Game.player.global_position) > FREEZE_DISTANCE
	if far != freeze:
		freeze = far
	# Fell out of the world
	if global_position.y < -60.0:
		queue_free()


## Rolling boulders & thrown crates hurt what they hit.
func _on_body_entered(body: Node) -> void:
	var speed := linear_velocity.length()
	if speed < 5.0 or body == self:
		return
	var info := DamageInfo.make(speed * mass * 0.02, self, linear_velocity.normalized() * speed * 0.5)
	info.kind = &"slam"
	info.blockable = kind != &"boulder"
	CombatUtils.deal(body, info)
	Audio.play_at(&"thud", global_position, -2.0)


func take_damage(info: DamageInfo) -> void:
	if info.element == &"fire":
		ignite()
	if info.element == &"electric" and material_type == &"metal":
		_conduct(info)
	if material_type == &"explosive" and (info.element == &"fire" or info.amount >= hp):
		explode()
		return
	if info.knockback != Vector3.ZERO:
		apply_central_impulse(info.knockback * clampf(mass * 0.3, 2.0, 30.0))
	if material_type == &"wood":
		hp -= info.amount
		Effects.hit_spark(self, global_position, false)
		if hp <= 0.0:
			break_apart()


func ignite() -> void:
	match material_type:
		&"explosive":
			if _burning <= 0.0:
				_burning = 1.2
				_attach_fire()
		&"wood":
			if _burning <= 0.0 and Weather.rain < 0.5:
				_burning = 5.0
				_attach_fire()


func _attach_fire() -> void:
	if _fire == null and FireSource.active_count < FireSource.MAX_ACTIVE:
		_fire = FireSource.new()
		_fire.permanent = true
		_fire.spreads = false
		_fire.radius = 1.2
		add_child(_fire)


func _conduct(info: DamageInfo) -> void:
	for body in CombatUtils.sphere_query(get_world_3d(), global_position, 4.0, CombatUtils.CREATURE_MASK | CombatUtils.PLAYER_MASK):
		var d := DamageInfo.make(info.amount * 0.8, info.source, Vector3.ZERO, &"electric")
		d.kind = &"environment"
		CombatUtils.deal(body, d)
	Effects.sparks(self, global_position, Color(0.7, 0.85, 1.0), 0.5)


func explode() -> void:
	if is_queued_for_deletion():
		return
	var parent := get_parent()
	var pos := global_position
	queue_free()
	Explosion.trigger(parent, pos, 5.0, 45.0, &"fire", self)
	if persist_id != "":
		WorldState.mark_harvested(persist_id, 72.0)


func break_apart() -> void:
	if is_queued_for_deletion():
		return
	if material_type == &"explosive":
		explode()
		return
	Effects.leaves(self, global_position)
	Effects.dust(self, global_position, 1.0)
	Audio.play_at(&"break_wood", global_position, 0.0)
	for drop in DB.roll_loot(DB.regional_table(loot_table, global_position)):
		Pickup.spawn(get_parent(), global_position + Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4)), drop["id"], drop["count"])
	if persist_id != "":
		WorldState.mark_harvested(persist_id, 72.0)
	queue_free()
