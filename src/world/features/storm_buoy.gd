class_name StormBuoy
extends StaticBody3D
## Old iron buoys on the lake. In fair weather: rusty floats you can hop
## across. In a storm they drink lightning: one hums and glows (a warning),
## then is struck — the water around it is electrified for a moment
## (shock ×2 on anything wet: you, eels) and a shard of stormglass forms on
## its crown, there to grab until the next strike. Stand on a humming buoy
## and you take the bolt. "When it storms, this place changes."

const SHOCK_RADIUS := 7.0

var feature_id := ""
## A reef spire: a fixed crystal pillar instead of a floating buoy (taller,
## no bob, seen from further away). Same storm rules.
var spire := false
var _hum := -1.0
var _mesh: MeshInstance3D
var _glass: Node3D
var _base_y := 0.0

static var _mat: StandardMaterial3D
static var _hot: StandardMaterial3D
static var _next_strike := 0.0


static func create(id: String, is_spire: bool = false) -> StormBuoy:
	var b := StormBuoy.new()
	b.feature_id = id
	b.spire = is_spire
	return b


func _ready() -> void:
	add_to_group(&"storm_buoys")
	collision_layer = 1
	collision_mask = 0
	set_meta(&"no_climb", true)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.46, 0.33, 0.26)
		_mat.metallic = 0.6
		_mat.roughness = 0.6
		_hot = StandardMaterial3D.new()
		_hot.albedo_color = Color(0.6, 0.62, 0.9)
		_hot.emission_enabled = true
		_hot.emission = Color(0.6, 0.55, 1.0)
		_hot.emission_energy_multiplier = 3.0
	_mesh = MeshInstance3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	if spire:
		_mesh.mesh = ShapeKit.merged([[ShapeKit.cone(1.0, 7.0, 5), Transform3D(Basis(), Vector3(0, 2.5, 0))],
			[ShapeKit.cone(0.5, 4.0, 5), Transform3D(Basis(Vector3.BACK, 0.35), Vector3(0.9, 1.2, 0.3))],
			[ShapeKit.cone(0.4, 3.0, 5), Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(-0.8, 0.8, -0.4))]])
		_mesh.material_override = _glass_mat()
		cyl.radius = 1.0
		cyl.height = 7.0
		cs.position.y = 2.5
	else:
		_mesh.mesh = ShapeKit.cyl(1.0, 1.2, 1.4, 12)
		_mesh.material_override = _mat
		var mast := MeshInstance3D.new()
		mast.mesh = ShapeKit.cyl(0.08, 0.1, 1.6, 6)
		mast.material_override = _mat
		mast.position = Vector3(0.6, 1.4, 0)
		add_child(mast)
		cyl.radius = 1.1
		cyl.height = 1.4
	_mesh.visibility_range_end = 700.0
	add_child(_mesh)
	cs.shape = cyl
	add_child(cs)
	_base_y = position.y


static var _glass_m: StandardMaterial3D


static func _glass_mat() -> StandardMaterial3D:
	if _glass_m == null:
		_glass_m = StandardMaterial3D.new()
		_glass_m.albedo_color = Color(0.55, 0.9, 0.95)
		_glass_m.roughness = 0.1
		_glass_m.emission_enabled = true
		_glass_m.emission = Color(0.3, 0.7, 0.8)
		_glass_m.emission_energy_multiplier = 0.6
	return _glass_m


static func storming() -> bool:
	return Weather.storm > 0.4


func _physics_process(delta: float) -> void:
	# Bob on the swell.
	if not spire:
		_mesh.position.y = sin(Time.get_ticks_msec() * 0.0015 + hash(feature_id) % 7) * 0.08
	if not storming():
		if _hum >= 0.0:
			_hum = -1.0
			_mesh.material_override = _glass_mat() if spire else _mat
		return
	if _hum >= 0.0:
		_hum -= delta
		if _hum < 0.0:
			_strike()
		return
	# One buoy at a time hums; strikes roll every few seconds while the
	# player is near the field.
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _next_strike and Game.player and Game.player.global_position.distance_to(global_position) < 45.0 and randf() < 0.2:
		_next_strike = now + randf_range(4.5, 7.0)
		_hum = 1.6
		_mesh.material_override = _hot
		Audio.play_at(&"charge", global_position, -2.0)
		Telegraph.disc(self, global_position, SHOCK_RADIUS, 1.6, ElementFX.color(&"electric"))


func _strike() -> void:
	_mesh.material_override = _glass_mat() if spire else _mat
	EventBus.lightning_strike.emit(global_position + Vector3.UP * 1.0)
	# Electrified water: everything wet in the radius, below the surface line.
	var info := DamageInfo.make(12.0, null, Vector3.UP * 2.0, &"electric")
	info.kind = &"environment"
	info.blockable = false
	for body in CombatUtils.sphere_query(get_world_3d(), Vector3(global_position.x, WorldGen.SEA_LEVEL - 0.5, global_position.z), SHOCK_RADIUS, CombatUtils.CREATURE_MASK | CombatUtils.PLAYER_MASK):
		if (body as Node3D).global_position.y < WorldGen.SEA_LEVEL + 0.4:
			CombatUtils.deal(body, info)
	ElementFX.burst(get_parent(), Vector3(global_position.x, WorldGen.SEA_LEVEL + 0.1, global_position.z), &"electric", SHOCK_RADIUS)
	_grow_glass()


func _grow_glass() -> void:
	if _glass and is_instance_valid(_glass):
		return
	var p := Pickup.spawn(get_parent(), global_position + Vector3(0, 5.8 if spire else 1.1, 0), &"storm_glass", 1)
	_glass = p
