class_name SpawnDirector
extends Node3D
## Fills streamed sectors with gameplay content from region data:
## resource nodes, animal herds, roaming enemy packs, physics props.
##
## Placement is deterministic per sector slot (same world every session);
## harvested / defeated state comes from WorldState. Creatures leave with
## their sector, except those currently fighting the player (orphans), which
## are cleaned up once they calm down and are far away.

const SAFE_RADIUS_AROUND_SPAWN := 140.0

var gen: WorldGen
var creatures_root: Node3D
var _sector_creatures: Dictionary = {}   # Vector2i -> Array[Creature]
var _orphans: Array = []
var _orphan_timer := 0.0
var _poi_zones: Array = []   # [Vector2 center, radius]


func _ready() -> void:
	add_to_group(&"spawn_director")
	creatures_root = Node3D.new()
	creatures_root.name = "Creatures"
	add_child(creatures_root)
	for poi in DB.world.get("pois", []):
		var p: Array = poi["pos"]
		_poi_zones.append([Vector2(p[0], p[1]), float(poi.get("clear_radius", poi.get("flatten", 30.0)))])


func on_sector_ready(chunk: TerrainChunk, slots: Array) -> void:
	var root := chunk.gameplay_root()
	var spawned: Array = []
	var sp: Array = DB.world.get("spawn", [0, 0, 0])
	var spawn_pos := Vector2(sp[0], sp[2])
	for s in slots:
		var pos: Vector3 = s["pos"]
		var nrm: Vector3 = s["normal"]
		if _in_poi(pos):
			continue
		var region := DB.region(s["region"])
		if region == null:
			continue
		var roll: float = s["roll"]
		var id: String = s["id"]
		var hab := habitat_of(pos, nrm)
		if hab != &"land":
			# Water and cliff slots used to be dropped: now they hold the
			# swimmers and climbers of the region (and nothing else).
			if WorldState.is_defeated(id):
				continue
			if roll < 0.12 * region.enemy_density + 0.02:
				var far := Vector2(pos.x, pos.z).distance_to(spawn_pos) > SAFE_RADIUS_AROUND_SPAWN
				if far and not Debug.peaceful:
					spawned.append_array(_spawn_group(region.enemy_spawns, pos, id, s["roll2"], hab))
			elif roll > 1.0 - 0.2 * region.animal_density:
				spawned.append_array(_spawn_group(region.animal_spawns, pos, id, s["roll2"], hab))
			continue
		if pos.y < 0.8:
			continue
		var animal_cut := 0.62 + 0.14 * region.animal_density
		var enemy_cut := animal_cut + 0.2 * region.enemy_density
		if roll < 0.62:
			_spawn_resource(root, region, s)
		elif roll < animal_cut:
			if not WorldState.is_defeated(id):
				spawned.append_array(_spawn_group(region.animal_spawns, pos, id, s["roll2"]))
		elif roll < enemy_cut:
			var far_from_start := Vector2(pos.x, pos.z).distance_to(spawn_pos) > SAFE_RADIUS_AROUND_SPAWN
			if far_from_start and not WorldState.is_defeated(id) and not Debug.peaceful:
				spawned.append_array(_spawn_group(region.enemy_spawns, pos, id, s["roll2"]))
		elif roll > 0.97 and not WorldState.is_harvested(id):
			var prop := PhysicsProp.create(&"crate" if s["roll2"] < 0.7 else &"barrel", id)
			root.add_child(prop)
			prop.global_position = pos + Vector3.UP * 0.6
	_sector_creatures[chunk.coord] = spawned


func on_sector_released(chunk: TerrainChunk) -> void:
	for c in _sector_creatures.get(chunk.coord, []):
		if not is_instance_valid(c):
			continue
		if (c as Creature).brain and (c as Creature).brain.aggro:
			adopt_orphan(c)
		else:
			c.queue_free()
	_sector_creatures.erase(chunk.coord)


func adopt_orphan(c: Creature) -> void:
	if not c in _orphans:
		_orphans.append(c)


func _process(delta: float) -> void:
	_orphan_timer -= delta
	if _orphan_timer > 0.0 or Game.player == null:
		return
	_orphan_timer = 2.0
	for c in _orphans.duplicate():
		if not is_instance_valid(c):
			_orphans.erase(c)
		elif not (c as Creature).brain.aggro and (c as Creature).distance_to_player() > 90.0:
			_orphans.erase(c)
			c.queue_free()


func _in_poi(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for z in _poi_zones:
		if p.distance_to(z[0]) < z[1]:
			return true
	return false


func _spawn_resource(root: Node3D, region: RegionData, slot: Dictionary) -> void:
	var id: String = slot["id"]
	if WorldState.is_harvested(id) or region.resources.is_empty():
		return
	var total := 0.0
	for r in region.resources:
		total += float(r["weight"])
	var pick: float = slot["roll2"] * total
	var chosen: Dictionary = region.resources[0]
	for r in region.resources:
		pick -= float(r["weight"])
		if pick <= 0.0:
			chosen = r
			break
	var def: Dictionary = DB.resource_nodes.get(StringName(chosen["node"]), {})
	if def.is_empty():
		return
	var node := ResourceNode.create(def, id)
	root.add_child(node)
	node.global_position = slot["pos"]


## Where a slot sits: open water (deep enough to swim), a steep face, or land.
static func habitat_of(pos: Vector3, nrm: Vector3) -> StringName:
	if pos.y < WorldGen.SEA_LEVEL - 1.2:
		return &"water"
	if nrm.y < 0.78 and pos.y > WorldGen.SEA_LEVEL + 0.5:
		return &"cliff"
	return &"land"


## Spawn-table entry conditions: habitat, period, hours, weather.
##   {"entity", "weight", "group", "habitat": land|water|cliff,
##    "period": day|night, "hours": [from, to], "weather": [ids]}
static func entry_ok(e: Dictionary, hab: StringName = &"land") -> bool:
	if StringName(e.get("habitat", "land")) != hab:
		return false
	var period: String = e.get("period", "any")
	if period == "night" and not Clock.is_night():
		return false
	if period == "day" and Clock.is_night():
		return false
	if e.has("hours"):
		var hr: Array = e["hours"]
		var h := Clock.hour
		var inside := (h >= float(hr[0]) and h < float(hr[1])) if float(hr[0]) <= float(hr[1]) else (h >= float(hr[0]) or h < float(hr[1]))
		if not inside:
			return false
	if e.has("weather") and not String(Weather.target) in e["weather"]:
		return false
	return true


func _spawn_group(table: Array, pos: Vector3, id: String, roll: float, hab: StringName = &"land") -> Array:
	var out: Array = []
	var options: Array = []
	var total := 0.0
	for e in table:
		if not entry_ok(e, hab):
			continue
		options.append(e)
		total += float(e["weight"])
	if options.is_empty():
		return out
	var pick := roll * total
	var chosen: Dictionary = options[0]
	for e in options:
		pick -= float(e["weight"])
		if pick <= 0.0:
			chosen = e
			break
	var g: Array = chosen.get("group", [1, 1])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var n := rng.randi_range(int(g[0]), int(g[1]))
	for i in n:
		var off := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
		var p := pos + off
		p.y = gen.height(p.x, p.z) + 0.2
		if hab == &"water":
			p.y = minf(p.y + 0.5, WorldGen.SEA_LEVEL - 1.0)
		var c := spawn_creature(StringName(chosen["entity"]), p, id if i == 0 else "%s:%d" % [id, i], id)
		if c:
			out.append(c)
	return out


func spawn_creature(entity_id: StringName, pos: Vector3, spawn_id: String, group: String) -> Creature:
	var type := DB.entity(entity_id)
	if type == null:
		push_warning("SpawnDirector: unknown entity " + entity_id)
		return null
	var c: Creature
	match type.kind:
		EntityType.Kind.ANIMAL:
			c = Animal.new()
		EntityType.Kind.NPC:
			c = NPC.new()
		EntityType.Kind.BOSS:
			c = Boss.new()
		_:
			c = Enemy.new()
	c.setup(type, pos, spawn_id, group)
	creatures_root.add_child(c)
	return c
