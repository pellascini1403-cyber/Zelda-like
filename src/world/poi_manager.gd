class_name PoiManager
extends Node3D
## Points of interest (data/world.json "pois").
##
## * Structures are built when within BUILD_DISTANCE so their silhouettes are
##   on the horizon long before the player arrives (curiosity), and freed
##   when far behind.
## * Their creatures are activated only inside ACTIVATE_DISTANCE.
## * Walking into discover_radius reveals the place on the map.

const BUILD_DISTANCE := 650.0
const FREE_DISTANCE := 800.0
const ACTIVATE_DISTANCE := 110.0
const DEACTIVATE_DISTANCE := 170.0

var gen: WorldGen
var spawner: SpawnDirector
var _builder: StructureBuilder
var _built: Dictionary = {}     # poi id -> {root, spawns, active, creatures}
var _timer := 0.0
var _build_queue: Array = []


func _ready() -> void:
	_builder = StructureBuilder.new(gen)


func pois() -> Array:
	return DB.world.get("pois", [])


func poi_position(poi: Dictionary) -> Vector3:
	var p: Array = poi["pos"]
	var y: float = poi.get("pad_height", gen.height(p[0], p[1]))
	return Vector3(p[0], y, p[1])


func _process(delta: float) -> void:
	if Game.player == null:
		return
	# One structure build per frame at most (they can be big).
	if not _build_queue.is_empty():
		_build(_build_queue.pop_front())
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var ppos := Game.player.global_position
	for poi in pois():
		var id: String = poi["id"]
		var pos := poi_position(poi)
		var d := Vector2(ppos.x - pos.x, ppos.z - pos.z).length()
		if d < float(poi.get("discover_radius", 40.0)):
			if WorldState.discover_poi(StringName(id)):
				EventBus.title_card.emit(tr(poi["name_key"]), tr(DB.region(gen.region_at(pos.x, pos.z)).name_key) if DB.region(gen.region_at(pos.x, pos.z)) else "")
				Audio.play_ui(&"discovery", -2.0)
		if not _built.has(id):
			if d < BUILD_DISTANCE and not poi in _build_queue:
				_build_queue.append(poi)
			continue
		var entry: Dictionary = _built[id]
		if d > FREE_DISTANCE:
			_free(id)
			continue
		if not entry["active"] and d < ACTIVATE_DISTANCE:
			_activate(id)
		elif entry["active"] and d > DEACTIVATE_DISTANCE:
			_deactivate(id)


## Synchronous build of everything near a position (initial load).
func build_near(pos: Vector3) -> void:
	for poi in pois():
		var p := poi_position(poi)
		if Vector2(pos.x - p.x, pos.z - p.z).length() < BUILD_DISTANCE and not _built.has(poi["id"]):
			_build(poi)


func _build(poi: Dictionary) -> void:
	if _built.has(poi["id"]):
		return
	var root := Node3D.new()
	root.name = "POI_" + String(poi["id"])
	add_child(root)
	root.global_position = poi_position(poi)
	var spawns := _builder.build(poi, root)
	_built[poi["id"]] = {"root": root, "spawns": spawns, "active": false, "creatures": []}


func _activate(id: String) -> void:
	var e: Dictionary = _built[id]
	e["active"] = true
	for s in e["spawns"]:
		if WorldState.is_defeated(s["id"]):
			continue
		var c := spawner.spawn_creature(s["entity"], s["pos"], s["id"], s["group"])
		if c:
			e["creatures"].append(c)


func _deactivate(id: String) -> void:
	var e: Dictionary = _built[id]
	var keep: Array = []
	for c in e["creatures"]:
		if is_instance_valid(c):
			if (c as Creature).brain and (c as Creature).brain.aggro:
				keep.append(c)
				spawner.adopt_orphan(c)
			else:
				c.queue_free()
	e["creatures"] = []
	e["active"] = false


func _free(id: String) -> void:
	_deactivate(id)
	var e: Dictionary = _built[id]
	if is_instance_valid(e["root"]):
		e["root"].queue_free()
	_built.erase(id)


func built_count() -> int:
	return _built.size()
