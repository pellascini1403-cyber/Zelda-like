extends Node
## Content database. Loads every JSON under res://data/ into typed definitions.
##
## Adding content = editing JSON. No gameplay code changes needed.
## `validate()` cross-checks references and is run by the test suite.

const DATA_DIR := "res://data/"

var items: Dictionary = {}          # StringName -> ItemData
var entities: Dictionary = {}       # StringName -> EntityType
var regions: Dictionary = {}        # StringName -> RegionData
var loot_tables: Dictionary = {}    # StringName -> Array[Dictionary]
var crafting: Dictionary = {}       # StringName -> Dictionary
var cooking: Dictionary = {}        # rules dictionary
var resource_nodes: Dictionary = {} # StringName -> Dictionary
var weather_types: Dictionary = {}  # StringName -> Dictionary
var buffs: Dictionary = {}          # StringName -> Dictionary
var world: Dictionary = {}          # layout: pois, structures, spawn point
var element_rules: Dictionary = {}
var quests: Array = []              # quest definitions (see Quests autoload)
var bosses: Dictionary = {}         # StringName -> boss definition
var abilities: Dictionary = {}      # StringName -> ability definition
var shops: Dictionary = {}          # StringName -> shop definition
var world_events: Array = []        # dynamic world event definitions


func _ready() -> void:
	reload()


func reload() -> void:
	items.clear()
	entities.clear()
	regions.clear()
	for d in _load_array("items.json"):
		var it := ItemData.from_dict(d)
		items[it.id] = it
	for d in _load_array("entities.json"):
		var e := EntityType.from_dict(d)
		entities[e.id] = e
	for d in _load_array("regions.json"):
		var r := RegionData.from_dict(d)
		regions[r.id] = r
	loot_tables = _keyed(_load_dict("loot.json"))
	crafting = {}
	for d in _load_array("crafting.json"):
		crafting[StringName(d["id"])] = d
	cooking = _load_dict("cooking.json")
	resource_nodes = {}
	for d in _load_array("resource_nodes.json"):
		resource_nodes[StringName(d["id"])] = d
	weather_types = {}
	for d in _load_array("weather.json"):
		weather_types[StringName(d["id"])] = d
	buffs = _keyed(_load_dict("buffs.json"))
	world = _load_dict("world.json")
	element_rules = _load_dict("elements.json")
	quests = _load_array("quests.json")
	bosses = {}
	for b in _load_array("bosses.json"):
		bosses[StringName(b["id"])] = b
	abilities = {}
	for a in _load_array("abilities.json"):
		abilities[StringName(a["id"])] = a
	shops = {}
	for s in _load_array("shops.json"):
		shops[StringName(s["id"])] = s
	world_events = _load_array("world_events.json")


# --- Accessors ----------------------------------------------------------------
func item(id: StringName) -> ItemData:
	return items.get(id)


func entity(id: StringName) -> EntityType:
	return entities.get(id)


func region(id: StringName) -> RegionData:
	return regions.get(id)


func weather(id: StringName) -> Dictionary:
	return weather_types.get(id, weather_types.get(&"clear", {}))


## Rolls a loot table. Returns Array of { "id": StringName, "count": int }.
func roll_loot(table_id: StringName, rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	if table_id == &"" or not loot_tables.has(table_id):
		return out
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for entry in loot_tables[table_id]:
		if rng.randf() <= float(entry.get("chance", 1.0)):
			var c: Array = entry.get("count", [1, 1])
			out.append({"id": StringName(entry["id"]), "count": rng.randi_range(int(c[0]), int(c[1]))})
	return out


# --- Validation -----------------------------------------------------------------
## Returns a list of human readable problems. Empty = content is consistent.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for table_id in loot_tables:
		for entry in loot_tables[table_id]:
			if not items.has(StringName(entry["id"])):
				errors.append("loot '%s' references unknown item '%s'" % [table_id, entry["id"]])
	for e: EntityType in entities.values():
		if e.loot_table != &"" and not loot_tables.has(e.loot_table):
			errors.append("entity '%s' unknown loot table '%s'" % [e.id, e.loot_table])
		if e.model != "" and not ResourceLoader.exists(e.model):
			errors.append("entity '%s' model not found: %s" % [e.id, e.model])
	for r: RegionData in regions.values():
		for s in r.enemy_spawns + r.animal_spawns:
			if not entities.has(StringName(s["entity"])):
				errors.append("region '%s' unknown entity '%s'" % [r.id, s["entity"]])
		for res in r.resources:
			if not resource_nodes.has(StringName(res["node"])):
				errors.append("region '%s' unknown resource node '%s'" % [r.id, res["node"]])
		for w in r.weather_weights:
			if not weather_types.has(StringName(w)):
				errors.append("region '%s' unknown weather '%s'" % [r.id, w])
	for n in resource_nodes.values():
		if not loot_tables.has(StringName(n.get("loot", ""))):
			errors.append("resource node '%s' unknown loot '%s'" % [n["id"], n.get("loot", "")])
	for rec in crafting.values():
		if not items.has(StringName(rec["result"])):
			errors.append("recipe '%s' unknown result '%s'" % [rec["id"], rec["result"]])
		for ing in rec["ingredients"]:
			if not items.has(StringName(ing)):
				errors.append("recipe '%s' unknown ingredient '%s'" % [rec["id"], ing])
	for it: ItemData in items.values():
		if it.icon != "" and not ResourceLoader.exists(it.icon):
			errors.append("item '%s' icon missing: %s" % [it.id, it.icon])
		if not it.category in ItemData.CATEGORIES:
			errors.append("item '%s' bad category '%s'" % [it.id, it.category])
		for eff in it.effects:
			if eff.get("type") == "buff" and not buffs.has(StringName(eff.get("buff", ""))):
				errors.append("item '%s' unknown buff '%s'" % [it.id, eff.get("buff")])
	for poi in world.get("pois", []):
		if poi.has("loot") and not loot_tables.has(StringName(poi["loot"])):
			errors.append("poi '%s' unknown loot '%s'" % [poi["id"], poi["loot"]])
	for tag in cooking.get("dish_for_tag", {}):
		if not items.has(StringName(cooking["dish_for_tag"][tag])):
			errors.append("cooking dish for '%s' unknown item" % tag)
	for sp in cooking.get("specials", []):
		for ing in sp["ingredients"] + [sp["item"]]:
			if not items.has(StringName(ing)):
				errors.append("cooking special '%s' unknown item '%s'" % [sp["id"], ing])
	return errors


# --- IO -----------------------------------------------------------------------------
func _read_json(file_name: String) -> Variant:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("DB: missing data file " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("DB: invalid JSON in " + path)
	return parsed


func _load_array(file_name: String) -> Array:
	var v: Variant = _read_json(file_name)
	return v if v is Array else []


func _load_dict(file_name: String) -> Dictionary:
	var v: Variant = _read_json(file_name)
	return v if v is Dictionary else {}


func _keyed(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[StringName(k)] = d[k]
	return out
