extends Node
## Persistent world facts: harvested nodes, opened chests, defeated camps,
## discovered places and the explored-map mask.

const MAP_CELLS := 64  # exploration mask resolution (32 m per cell)

## node id -> Clock.total_hours() when it respawns
var harvested: Dictionary = {}
var opened: Dictionary = {}
## spawn id -> total hours when it may respawn
var defeated: Dictionary = {}
var discovered_pois: Dictionary = {}
var flags: Dictionary = {}
var explored := PackedByteArray()
var map_revealed_all := false
var last_safe_position := Vector3.ZERO


func _ready() -> void:
	reset()


func reset() -> void:
	harvested.clear()
	opened.clear()
	defeated.clear()
	discovered_pois.clear()
	flags.clear()
	explored.resize(MAP_CELLS * MAP_CELLS)
	explored.fill(0)
	map_revealed_all = false


func is_harvested(id: String) -> bool:
	if not harvested.has(id):
		return false
	if Clock.total_hours() >= float(harvested[id]):
		harvested.erase(id)
		return false
	return true


func mark_harvested(id: String, respawn_hours: float) -> void:
	harvested[id] = Clock.total_hours() + respawn_hours


func is_defeated(spawn_id: String) -> bool:
	if not defeated.has(spawn_id):
		return false
	if Clock.total_hours() >= float(defeated[spawn_id]):
		defeated.erase(spawn_id)
		return false
	return true


func mark_defeated(spawn_id: String, respawn_hours: float) -> void:
	defeated[spawn_id] = Clock.total_hours() + respawn_hours


func discover_poi(poi_id: StringName) -> bool:
	if discovered_pois.has(String(poi_id)):
		return false
	discovered_pois[String(poi_id)] = Clock.total_hours()
	EventBus.poi_discovered.emit(poi_id)
	return true


func is_poi_discovered(poi_id: String) -> bool:
	return map_revealed_all or discovered_pois.has(poi_id)


## Reveals the exploration mask around a world position.
func explore(pos: Vector3, radius_cells: int = 2) -> void:
	var cell_size := WorldGen.WORLD_HALF * 2.0 / MAP_CELLS
	var cx := int((pos.x + WorldGen.WORLD_HALF) / cell_size)
	var cz := int((pos.z + WorldGen.WORLD_HALF) / cell_size)
	for z in range(cz - radius_cells, cz + radius_cells + 1):
		for x in range(cx - radius_cells, cx + radius_cells + 1):
			if x < 0 or z < 0 or x >= MAP_CELLS or z >= MAP_CELLS:
				continue
			if Vector2(x - cx, z - cz).length() <= radius_cells + 0.5:
				explored[z * MAP_CELLS + x] = 1


func is_explored(x: int, z: int) -> bool:
	return map_revealed_all or explored[z * MAP_CELLS + x] == 1


func save_state() -> Dictionary:
	return {
		"harvested": harvested, "opened": opened, "defeated": defeated,
		"pois": discovered_pois, "flags": flags,
		"explored": Marshalls.raw_to_base64(explored),
		"safe_pos": [last_safe_position.x, last_safe_position.y, last_safe_position.z],
	}


func load_state(d: Dictionary) -> void:
	reset()
	harvested = d.get("harvested", {})
	opened = d.get("opened", {})
	defeated = d.get("defeated", {})
	discovered_pois = d.get("pois", {})
	flags = d.get("flags", {})
	var raw := Marshalls.base64_to_raw(d.get("explored", ""))
	if raw.size() == MAP_CELLS * MAP_CELLS:
		explored = raw
	var sp: Array = d.get("safe_pos", [0, 0, 0])
	last_safe_position = Vector3(sp[0], sp[1], sp[2])
