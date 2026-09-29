class_name QuestNest
extends StaticBody3D
## A destructible quest target: thorn nest, spitter mound, wasp hive,
## scuttler burrow, stillness growth... Nests keep breeding defenders while
## the player is close and are tough against plain blades but weak to fire
## and explosions (ember rod, resin bombs, explosive barrels, grass fires).
##
## Data (quest stage "spawns", kind "nest"): {id, group, nest, pos, hp,
## weak: {fire: x, explosion: x}, melee: mult, spawn, spawn_every,
## spawn_max, drops: [{id, count}]}. Destroying it emits
## EventBus.quest_object_destroyed(id, group) and records flag "qd:<id>".

const LOOKS := {
	"thorn": [Color(0.33, 0.30, 0.16), Color(0.55, 0.62, 0.22)],
	"spitter": [Color(0.72, 0.62, 0.44), Color(0.42, 0.66, 0.60)],
	"hive": [Color(0.78, 0.55, 0.16), Color(0.36, 0.22, 0.10)],
	"burrow": [Color(0.40, 0.33, 0.28), Color(0.62, 0.40, 0.20)],
	"still": [Color(0.30, 0.24, 0.42), Color(0.66, 0.52, 0.95)],
	"rubble": [Color(0.46, 0.44, 0.41), Color(0.62, 0.6, 0.55)],
}

var data: Dictionary = {}
var nest_id: StringName = &""
var group: StringName = &""
var hp := 60.0
var max_hp := 60.0
var _burn := 0.0
var _burn_tick := 0.0
var _spawn_t := 6.0
var _defenders: Array = []
var _mesh: MeshInstance3D
var _fire: FireSource
var _hinted := false
var _dead := false
static var _meshes: Dictionary = {}


static func create(d: Dictionary) -> QuestNest:
	var n := QuestNest.new()
	n.data = d
	n.nest_id = StringName(d.get("id", ""))
	n.group = StringName(d.get("group", ""))
	n.max_hp = float(d.get("hp", 60.0))
	n.hp = n.max_hp
	return n


static func destroyed(id: String) -> bool:
	return WorldState.flags.has("qd:" + id)


func _ready() -> void:
	add_to_group(&"quest_nests")
	collision_layer = 1 | (1 << 3)
	collision_mask = 0
	var look := String(data.get("nest", "thorn"))
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.3 if look != "hive" else 0.8
	shape.height = 1.6 if look != "hive" else 2.6
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh_for(look)
	_mesh.material_override = WorldMaterials.get_mat(&"vertex_color")
	_mesh.visibility_range_end = 240.0
	add_child(_mesh)
	_spawn_t = float(data.get("spawn_every", 12.0)) * 0.5


func is_dead() -> bool:
	return _dead


## Called by FireSource neighbours (grass fires, burning props, bombs).
func ignite() -> void:
	if _dead or Weather.rain > 0.5 or float((data.get("weak", {"fire": 3.0}) as Dictionary).get("fire", 3.0)) <= 0.0:
		return
	if _burn <= 0.0:
		_fire = FireSource.ignite_at(get_parent(), global_position + Vector3.UP * 0.4, 6.5, 3)
	_burn = 6.0


func take_damage(info: DamageInfo) -> void:
	if _dead or (info.source is Creature):
		return   # its own defenders never wreck it
	var weak: Dictionary = data.get("weak", {"fire": 3.0, "explosion": 4.0})
	var mult := float(data.get("melee", 0.35))
	if info.kind == &"explosion":
		mult = float(weak.get("explosion", 4.0))
	elif info.element == &"fire":
		mult = float(weak.get("fire", 3.0))
		ignite()
	elif info.kind == &"environment":
		mult = 1.0
	if mult <= 0.05 and not _hinted:
		_hinted = true
		EventBus.toast.emit(tr(data.get("hint_key", "HINT_NEST_FIRE")))
	elif mult < 1.0 and not _hinted and info.source == Game.player:
		_hinted = true
		EventBus.toast.emit(tr(data.get("hint_key", "HINT_NEST_FIRE")))
	hp -= info.amount * mult
	var t := create_tween()
	_mesh.scale = Vector3(1.08, 0.92, 1.08)
	t.tween_property(_mesh, "scale", Vector3.ONE, 0.18)
	if hp <= 0.0:
		_destroy()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _burn > 0.0:
		_burn -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			hp -= max_hp * 0.07 * float((data.get("weak", {}) as Dictionary).get("fire", 3.0)) / 3.0
			if hp <= 0.0:
				_destroy()
				return
	# Breeding: defenders appear while the player is close.
	var ent := StringName(data.get("spawn", ""))
	if ent == &"" or Game.player == null:
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = float(data.get("spawn_every", 12.0))
	if global_position.distance_to(Game.player.global_position) > 34.0:
		return
	_defenders = _defenders.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not (c as Creature).is_dead())
	if _defenders.size() >= int(data.get("spawn_max", 2)):
		return
	var sd := get_tree().get_first_node_in_group(&"spawn_director") as SpawnDirector
	if sd == null:
		return
	var a := randf() * TAU
	var p := global_position + Vector3(cos(a) * 2.2, 0.6, sin(a) * 2.2)
	var c := sd.spawn_creature(ent, p, "", String(data.get("defender_group", "")))
	if c:
		_defenders.append(c)
		sd.adopt_orphan(c)
		c.perception.alert(Game.player.global_position)
		ElementFX.burst(self, p, StringName(data.get("element", "thorn")), 1.0)


func _destroy() -> void:
	if _dead:
		return
	_dead = true
	WorldState.flags["qd:" + String(nest_id)] = true
	for it in data.get("drops", []):
		Pickup.spawn(get_parent(), global_position + Vector3(randf_range(-0.8, 0.8), 0.8, randf_range(-0.8, 0.8)), StringName(it["id"]), int(it.get("count", 1)))
	ElementFX.burst(self, global_position + Vector3.UP * 0.6, StringName(data.get("element", "thorn")), 2.6)
	Effects.dust(get_parent(), global_position, 2.5)
	Audio.play_at(&"break_wood", global_position, 0.0)
	EventBus.quest_object_destroyed.emit(nest_id, group)
	collision_layer = 0
	var t := create_tween()
	t.tween_property(_mesh, "scale", Vector3(1.3, 0.05, 1.3), 0.45).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


## Shared placeholder mesh per nest look (solid colours, replaceable).
static func mesh_for(look: String) -> Mesh:
	if _meshes.has(look):
		return _meshes[look]
	var cols: Array = LOOKS.get(look, LOOKS["thorn"])
	var base: Color = cols[0]
	var accent: Color = cols[1]
	var b := MeshKit.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(look)
	match look:
		"rubble":
			for i in 9:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.0, 1.4)
				b.blob(Vector3(cos(a) * r, rng.randf_range(0.3, 1.4), sin(a) * r), Vector3(0.9, 0.7, 0.8) * rng.randf_range(0.7, 1.2), accent if i % 3 == 0 else base, base * 0.7, 0, 0.25, i)
		"hive":
			b.cylinder(Vector3(0, 0, 0), 2.4, 0.75, 0.35, 9, base, base * 0.8)
			for i in 4:
				b.cylinder(Vector3(0, 0.4 + i * 0.5, 0), 0.12, 0.8 - i * 0.1, 0.8 - i * 0.1, 9, accent)
			b.blob(Vector3(0, 2.5, 0), Vector3(0.3, 0.25, 0.3), base, base, 0, 0.1, 3)
		"still":
			for i in 6:
				var a := TAU * i / 6.0 + rng.randf() * 0.4
				var r := rng.randf_range(0.2, 0.9)
				var h := rng.randf_range(0.9, 2.2)
				b.limb(Vector3(cos(a) * r, 0, sin(a) * r), Vector3(cos(a) * (r + 0.4), h, sin(a) * (r + 0.4)), 0.28, 0.02, 5, base, accent)
			b.blob(Vector3(0, 0.3, 0), Vector3(1.0, 0.45, 1.0), base, base * 0.7, 1, 0.2, 7)
		"burrow":
			b.blob(Vector3(0, 0.25, 0), Vector3(1.6, 0.6, 1.6), base, base * 0.7, 1, 0.25, 5)
			b.cylinder(Vector3(0, 0.55, 0), 0.08, 0.7, 0.55, 10, Color(0.08, 0.06, 0.05))
			for i in 5:
				var a := TAU * i / 5.0
				b.blob(Vector3(cos(a) * 1.5, 0.2, sin(a) * 1.5), Vector3(0.35, 0.3, 0.35), accent, accent * 0.7, 0, 0.2, i)
		"spitter":
			b.blob(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 1.4), base, base * 0.75, 1, 0.22, 9)
			for i in 5:
				var a := TAU * i / 5.0 + 0.3
				b.cylinder(Vector3(cos(a) * 0.8, 0.5 + rng.randf() * 0.4, sin(a) * 0.8), 0.25, 0.22, 0.3, 7, accent, Color(0.1, 0.1, 0.1))
		_:
			b.blob(Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 1.5), base, base * 0.7, 1, 0.3, 11)
			for i in 14:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.5, 1.3)
				var y := rng.randf_range(0.3, 0.9)
				var from := Vector3(cos(a) * r, y, sin(a) * r)
				var out := Vector3(cos(a), rng.randf_range(0.3, 1.1), sin(a)).normalized()
				b.limb(from, from + out * rng.randf_range(0.5, 0.9), 0.09, 0.0, 4, accent, accent * 1.2)
	var m := b.commit()
	_meshes[look] = m
	return m
