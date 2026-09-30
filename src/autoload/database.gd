extends Node
## Content database. Loads every JSON under res://data/ into typed definitions.
##
## Adding content = editing JSON. No gameplay code changes needed.
## `validate()` cross-checks references and is run by the test suite.

const DATA_DIR := "res://data/"
## POI types StructureBuilder knows how to build.
const POI_TYPES := ["village", "maze", "camp", "spires", "giant_tree", "overlook", "shipwreck", "watchtower", "summit", "den",
	"temple", "shrine", "bridge", "ruins", "oasis", "arena", "anchor", "floating_isles", "npc_camp", "cave", "post", "quarry", "depot",
	"canopy_walk", "hollow_tree", "moon_shrine", "sunken_shrine"]

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
var upgrades: Dictionary = {}       # StringName -> Warden altar upgrade track
var cosmetics: Dictionary = {}      # StringName -> cosmetic (trail colours...)
var art_style: Dictionary = {}      # character art direction tokens (presentation only)
var visuals: Dictionary = {}        # StringName -> visual profile (presentation only)
var vehicles: Dictionary = {}       # StringName -> premium vehicle definition
var products: Dictionary = {}       # StringName -> store product (monetization catalogue)
var discoveries: Dictionary = {}    # StringName -> discovery (optional wonders, not quests)
var discovery_order: Array = []     # ids in file order (Atlas)
var fauna: Array = []               # ambient fauna groups (AmbientLife)
var fishing: Dictionary = {}        # fish species per waters (Fishing)
var sites: Array = []               # always-present world features (fishing spots, buoys...)


func _ready() -> void:
	reload()


func reload() -> void:
	items.clear()
	entities.clear()
	regions.clear()
	for d in _load_array("items.json"):
		var it := ItemData.from_dict(d)
		items[it.id] = it
	var raw_entities := resolve_variants(_load_array("entities.json"))
	for d in raw_entities:
		var e := EntityType.from_dict(d)
		entities[e.id] = e
	art_style = _load_dict("art_style.json")
	visuals = {}
	for v in resolve_variants(_load_array("visuals.json"), raw_entities):
		visuals[StringName(v["id"])] = v
	for e: EntityType in entities.values():
		e.visual = visuals.get(e.id, {})
	for d in _load_array("regions.json"):
		var r := RegionData.from_dict(d)
		regions[r.id] = r
	loot_tables = _keyed(_load_dict("loot.json"))
	_region_gen = null
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
	# Quests live in data/quests/*.json (any number of files, merged in name
	# order); a legacy data/quests.json is still read if present.
	quests = []
	if FileAccess.file_exists(DATA_DIR + "quests.json"):
		quests.append_array(_load_array("quests.json"))
	var qdir := DirAccess.open(DATA_DIR + "quests")
	if qdir:
		var files := Array(qdir.get_files())
		files.sort()
		for f in files:
			if String(f).ends_with(".json"):
				quests.append_array(_load_array("quests/" + f))
	upgrades = {}
	for u in _load_array("upgrades.json"):
		upgrades[StringName(u["id"])] = u
	cosmetics = {}
	for c in _load_array("cosmetics.json"):
		cosmetics[StringName(c["id"])] = c
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
	vehicles = {}
	for v in _load_array("vehicles.json"):
		vehicles[StringName(v["id"])] = v
	products = {}
	for pr in _load_array("products.json"):
		products[StringName(pr["id"])] = pr
	discoveries = {}
	discovery_order = []
	for dd in _load_array("discoveries.json"):
		var dv: Dictionary = dd
		# Spawns without their own place use the discovery's.
		for sp: Dictionary in dv.get("spawns", []):
			if not sp.has("pos") and not sp.has("poi"):
				if dv.has("poi"):
					sp["poi"] = dv["poi"]
				if dv.has("pos"):
					sp["pos"] = dv["pos"]
		discoveries[StringName(dv["id"])] = dv
		discovery_order.append(StringName(dv["id"]))
	fauna = _load_array("fauna.json")
	fishing = _load_dict("fishing.json")
	sites = _load_array("sites.json")


## Variants: an entry with "variant_of": "<base id>" is the base deep-merged
## with its own keys (dictionaries merge, everything else replaces). Spider ->
## Venom / Cave / Veil / Queen without copying definitions. A visual profile
## with no entry of its own inherits the profile of its entity's base
## (`entity_list` given): variants always look related unless overridden.
static func resolve_variants(list: Array, entity_list: Array = []) -> Array:
	var by_id := {}
	for d in list:
		by_id[String(d.get("id", ""))] = d
	if not entity_list.is_empty():
		for e in entity_list:
			var eid := String(e.get("id", ""))
			var base := String(e.get("variant_of", ""))
			if base != "" and not by_id.has(eid):
				var stub := {"id": eid, "variant_of": base}
				list = list + [stub]
				by_id[eid] = stub
			elif base != "" and by_id.has(eid) and not by_id[eid].has("variant_of"):
				by_id[eid]["variant_of"] = base
	var out: Array = []
	var cache := {}
	for d in list:
		out.append(_resolve_one(String(d.get("id", "")), by_id, cache, 0))
	return out


static func _resolve_one(id: String, by_id: Dictionary, cache: Dictionary, depth: int) -> Dictionary:
	if cache.has(id):
		return cache[id]
	var d: Dictionary = by_id.get(id, {})
	var base_id := String(d.get("variant_of", ""))
	var out: Dictionary
	if base_id == "" or not by_id.has(base_id) or depth > 4:
		out = d.duplicate(true)
	else:
		out = _deep_merge(_resolve_one(base_id, by_id, cache, depth + 1), d)
	cache[id] = out
	return out


static func _deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if over[k] is Dictionary and out.get(k) is Dictionary:
			out[k] = _deep_merge(out[k], over[k])
		else:
			out[k] = over[k].duplicate(true) if (over[k] is Dictionary or over[k] is Array) else over[k]
	return out


# --- Accessors ----------------------------------------------------------------
func item(id: StringName) -> ItemData:
	return items.get(id)


func entity(id: StringName) -> EntityType:
	return entities.get(id)


func region(id: StringName) -> RegionData:
	return regions.get(id)


func weather(id: StringName) -> Dictionary:
	return weather_types.get(id, weather_types.get(&"clear", {}))


## Loot that tells you where you are: "chest_common" opened in the forest
## rolls "chest_common@forest" when that table exists (organic finds), on the
## coast marine salvage, in the highlands ore and climbing gear...
var _region_gen: WorldGen


func regional_table(table_id: StringName, pos: Vector3) -> StringName:
	if table_id == &"":
		return table_id
	if _region_gen == null:
		_region_gen = WorldGen.from_world_data(world)
	var regional := StringName("%s@%s" % [table_id, _region_gen.region_at(pos.x, pos.z)])
	return regional if loot_tables.has(regional) else table_id


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
	errors.append_array(_validate_progression())
	errors.append_array(ArtStyle.validate(self))
	errors.append_array(_validate_vehicles())
	errors.append_array(_validate_ecology())
	return errors


const LOCOMOTIONS := ["ground", "flying", "aquatic", "climber", "burrower"]
const HABITATS := ["land", "water", "cliff"]
const FAUNA_KINDS := ["flock", "school", "motes", "skitter"]


## Variants, locomotion, behaviour modules, habitat spawn tables,
## discoveries and ambient fauna.
func _validate_ecology() -> PackedStringArray:
	var errors := PackedStringArray()
	for e: EntityType in entities.values():
		if e.variant_of != &"" and not entities.has(e.variant_of):
			errors.append("entity '%s' is a variant of unknown '%s'" % [e.id, e.variant_of])
		if not String(e.locomotion) in LOCOMOTIONS:
			errors.append("entity '%s' unknown locomotion '%s'" % [e.id, e.locomotion])
		for bname in e.behaviors:
			if not bname in AIBehavior.KNOWN:
				errors.append("entity '%s' unknown behaviour '%s'" % [e.id, bname])
		for pair in [["swoop", "swoop_attack", "swoop"], ["burrow", "erupt_attack", "erupt"], ["drop_from_above", "drop_attack", "drop"]]:
			if e.has_behavior(pair[0]):
				var aid := String(e.ai.get(pair[1], pair[2]))
				var found := false
				for a in e.attacks:
					found = found or String(a.id) == aid
				if not found:
					errors.append("entity '%s' behaviour %s needs attack '%s'" % [e.id, pair[0], aid])
	for r: RegionData in regions.values():
		for sp in r.enemy_spawns + r.animal_spawns:
			var hab := String(sp.get("habitat", "land"))
			if not hab in HABITATS:
				errors.append("region '%s' spawn '%s' unknown habitat '%s'" % [r.id, sp["entity"], hab])
				continue
			var e: EntityType = entities.get(StringName(sp["entity"]))
			if e == null:
				continue
			if (hab == "water") != e.is_aquatic():
				errors.append("region '%s': '%s' habitat %s does not fit locomotion %s" % [r.id, e.id, hab, e.locomotion])
			if hab == "cliff" and not (e.is_climber() or e.flying):
				errors.append("region '%s': '%s' on cliffs must climb or fly" % [r.id, e.id])
	var poi_ids := {}
	for poi in world.get("pois", []):
		poi_ids[String(poi["id"])] = true
	for id: StringName in discovery_order:
		var d: Dictionary = discoveries[id]
		var w := "discovery '%s'" % id
		if not regions.has(StringName(d.get("region", ""))):
			errors.append("%s unknown region '%s'" % [w, d.get("region", "")])
		if String(d.get("name_key", "")) == "":
			errors.append("%s has no name_key" % w)
		if d.has("poi") and not poi_ids.has(String(d["poi"])):
			errors.append("%s unknown poi '%s'" % [w, d["poi"]])
		if not d.has("pos") and not d.has("poi"):
			errors.append("%s has no position" % w)
		if not String(d.get("trigger", "reach")) in ["reach", "interact", "catch"]:
			errors.append("%s unknown trigger" % w)
		if String(d.get("trigger", "")) == "catch" and not items.has(StringName(d.get("catch", ""))):
			errors.append("%s catches unknown item '%s'" % [w, d.get("catch", "")])
		if d.has("found_in_poi") and not poi_ids.has(String(d["found_in_poi"])):
			errors.append("%s found in unknown poi" % w)
		if String(d.get("trigger", "reach")) == "interact" and not d.has("found_in_poi"):
			var has_obj := false
			for sp in d.get("spawns", []):
				has_obj = has_obj or String(sp.get("discover", "")) == String(id)
			if not has_obj:
				errors.append("%s is found by interaction but no spawn discovers it" % w)
		errors.append_array(QuestValidator.check_reward(d.get("reward", {}), self, w))
		for sp in d.get("spawns", []):
			errors.append_array(QuestValidator._check_spawn(sp, self, poi_ids, w))
	for sp in sites:
		errors.append_array(QuestValidator._check_spawn(sp, self, poi_ids, "site"))
	for wk in fishing.get("waters", {}):
		for fe in fishing["waters"][wk]:
			if not items.has(StringName(fe.get("item", ""))):
				errors.append("fishing '%s' unknown fish '%s'" % [wk, fe.get("item", "")])
	for f in fauna:
		if not String(f.get("kind", "")) in FAUNA_KINDS:
			errors.append("fauna '%s' unknown kind" % f.get("id", ""))
		for rg in f.get("regions", []):
			if not regions.has(StringName(rg)):
				errors.append("fauna '%s' unknown region '%s'" % [f.get("id", ""), rg])
	return errors


## Vehicles: costs name real items, quests exist, every vehicle is both
## earnable (quest + restore) and sold (product), products grant real things.
func _validate_vehicles() -> PackedStringArray:
	var errors := PackedStringArray()
	var quest_ids := {}
	for q in quests:
		quest_ids[q["id"]] = true
	for v in vehicles.values():
		var acq: Dictionary = v.get("acquire", {})
		if not quest_ids.has(acq.get("quest", "")):
			errors.append("vehicle '%s' unknown acquire quest '%s'" % [v["id"], acq.get("quest", "")])
		for it in acq.get("items", []):
			if not items.has(StringName(it["id"])):
				errors.append("vehicle '%s' needs unknown item '%s'" % [v["id"], it["id"]])
		if not products.has(StringName(v.get("product", ""))):
			errors.append("vehicle '%s' unknown product '%s'" % [v["id"], v.get("product", "")])
		if v.get("model", "") != "" and not ResourceLoader.exists(v["model"]):
			errors.append("vehicle '%s' model not found: %s" % [v["id"], v["model"]])
	for pr in products.values():
		var g: Dictionary = pr.get("grants", {})
		if g.has("vehicle") and not vehicles.has(StringName(g["vehicle"])):
			errors.append("product '%s' grants unknown vehicle" % pr["id"])
	return errors


## Quests, bosses, abilities, shops, events, mounts and POI types.
func _validate_progression() -> PackedStringArray:
	var errors := PackedStringArray()
	var poi_ids := {}
	for poi in world.get("pois", []):
		poi_ids[poi["id"]] = true
		if not poi["type"] in POI_TYPES:
			errors.append("poi '%s' unknown type '%s'" % [poi["id"], poi["type"]])
		for g in poi.get("guards", []) + poi.get("npcs", []).map(func(n: Array) -> String: return n[0]):
			if not entities.has(StringName(g)):
				errors.append("poi '%s' unknown entity '%s'" % [poi["id"], g])
		for r in poi.get("reward", []):
			if not items.has(StringName(r["id"])):
				errors.append("poi '%s' unknown reward '%s'" % [poi["id"], r["id"]])
	errors.append_array(QuestValidator.validate(self))
	for u in upgrades.values():
		if (u.get("costs", []) as Array).is_empty() or not u.has("per_level"):
			errors.append("upgrade '%s' needs costs and per_level" % u.get("id", ""))
	for c in cosmetics.values():
		if not String(c.get("slot", "")) in ["trail", "glider_trail", "afterimage"]:
			errors.append("cosmetic '%s' bad slot '%s'" % [c.get("id", ""), c.get("slot", "")])
	for b in bosses.values():
		var e: EntityType = entities.get(StringName(b["entity"]))
		if e == null or e.kind != EntityType.Kind.BOSS:
			errors.append("boss '%s' entity '%s' missing or not BOSS" % [b["id"], b["entity"]])
			continue
		var atk := {}
		for a in e.attacks:
			atk[String(a.id)] = true
		for ph in b.get("phases", []):
			for a in ph.get("attacks", []):
				if not atk.has(a):
					errors.append("boss '%s' phase uses unknown attack '%s'" % [b["id"], a])
			if ph.has("summon") and not entities.has(StringName(ph["summon"])):
				errors.append("boss '%s' summons unknown entity '%s'" % [b["id"], ph["summon"]])
		for it in b.get("rewards", []):
			if not items.has(StringName(it["id"])):
				errors.append("boss '%s' rewards unknown item '%s'" % [b["id"], it["id"]])
	for s in shops.values():
		if not entities.has(StringName(s.get("npc", ""))):
			errors.append("shop '%s' unknown npc" % s["id"])
		for it in s.get("stock", []):
			if not items.has(StringName(it["id"])):
				errors.append("shop '%s' sells unknown item '%s'" % [s["id"], it["id"]])
	for a in abilities.values():
		if a.has("mount") and not entities.has(StringName(a["mount"])):
			errors.append("ability '%s' unknown mount" % a["id"])
	for ev in world_events:
		if ev.has("spawn") and not entities.has(StringName(ev["spawn"])):
			errors.append("event '%s' spawns unknown entity" % ev["id"])
		for rg in ev.get("regions", []):
			if not regions.has(StringName(rg)):
				errors.append("event '%s' unknown region '%s'" % [ev["id"], rg])
		for it in ev.get("reward", {}).get("items", []):
			if not items.has(StringName(it["id"])):
				errors.append("event '%s' rewards unknown item" % ev["id"])
	for m in world.get("mounts", []):
		var e: EntityType = entities.get(StringName(m["entity"]))
		if e == null or e.mount.is_empty():
			errors.append("mount herd '%s' entity is not rideable" % m["id"])
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
