class_name BrambleWall
extends StaticBody3D
## Forest rule #3 — fire opens, rain protects. A thicket of old thorns that
## blocks a doorway. Fire burns it away for good (a fire weapon, a bomb,
## burning grass, a Cinder Imp's trail...) — but only in dry weather: wet
## brambles smoulder and hold. Burned state persists (flag "feat:<id>").

var feature_id := ""
var size := Vector3(3.2, 3.6, 1.2)
var _burning := 0.0
var _hint_cool := 0.0


static func create(id: String, wall_size: Vector3) -> BrambleWall:
	var w := BrambleWall.new()
	w.feature_id = id
	w.size = wall_size
	return w


static func burned(id: String) -> bool:
	return WorldState.flags.has("feat:" + id)


func _ready() -> void:
	if burned(feature_id):
		queue_free()
		return
	add_to_group(&"brambles")
	collision_layer = 1 | CombatUtils.PROP_MASK
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(feature_id)
	var stems: Array = []
	var thorns: Array = []
	for i in 16:
		var len := rng.randf_range(1.2, 2.6)
		var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-1.2, 1.2))),
			Vector3(rng.randf_range(-size.x, size.x) * 0.45, rng.randf_range(0.3, size.y - 0.3), rng.randf_range(-size.z, size.z) * 0.4))
		stems.append([ShapeKit.capsule(0.08, len), xf])
		for k in 3:
			thorns.append([ShapeKit.cone(0.04, 0.22, 4), xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, rng.randf_range(-len * 0.4, len * 0.4), 0))])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.27, 0.22, 0.16)
	var thorn := StandardMaterial3D.new()
	thorn.albedo_color = Color(0.5, 0.42, 0.3)
	for pair: Array in [[stems, mat], [thorns, thorn]]:
		var mi := MeshInstance3D.new()
		mi.mesh = ShapeKit.merged(pair[0])
		mi.material_override = pair[1]
		mi.visibility_range_end = 160.0
		add_child(mi)


static func too_wet() -> bool:
	return Weather.rain > 0.3 or Weather.wetness > 0.5


func take_damage(info: DamageInfo) -> void:
	if info.element == &"fire" or info.kind == &"explosion":
		try_ignite()
	elif _hint_cool <= 0.0 and info.source == Game.player:
		_hint_cool = 6.0
		EventBus.toast.emit(tr("HINT_BRAMBLE_BLADE"))


func try_ignite() -> bool:
	if _burning > 0.0:
		return true
	if too_wet():
		if _hint_cool <= 0.0:
			_hint_cool = 5.0
			EventBus.toast.emit(tr("HINT_BRAMBLE_WET"))
		return false
	_burning = 2.2
	for i in 3:
		FireSource.ignite_at(get_parent(), global_position + global_basis * Vector3((i - 1) * size.x * 0.3, 0.3, 0), 3.0)
	return true


func _process(delta: float) -> void:
	_hint_cool -= delta
	if _burning > 0.0:
		_burning -= delta
		scale.y = maxf(_burning / 2.2, 0.05)
		if _burning <= 0.0:
			WorldState.flags["feat:" + feature_id] = true
			EventBus.flag_set.emit(StringName("feat:" + feature_id))
			Effects.dust(self, global_position + Vector3.UP, 2.0)
			queue_free()
		return
	# Fire spreading next to it catches it (burning grass, a campfire...).
	if Engine.get_process_frames() % 30 == 0 and not too_wet():
		for h in get_tree().get_nodes_in_group(&"heat_source"):
			if (h as Node3D).global_position.distance_to(global_position) < size.x * 0.8 + 1.5:
				try_ignite()
				break
