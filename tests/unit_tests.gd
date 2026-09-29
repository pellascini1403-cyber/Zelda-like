extends Node
## Fast unit / data tests (no world needed).
## Run: godot --headless -- --unit      (exit code 0 = pass)

var _fails := 0
var _count := 0


func _ready() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	_count += 1
	if not cond:
		_fails += 1
		print("FAIL  ", what)


func _run() -> void:
	test_content()
	test_localization()
	test_inventory()
	test_durability()
	test_cooking()
	test_crafting()
	test_worldgen()
	test_chunk_seams()
	test_save_backup()
	test_quality_presets()
	test_ai_attack_pick()
	test_placeholder_colors()
	print("==== UNIT: %d checks, %d failed ====" % [_count, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func test_content() -> void:
	var errors := DB.validate()
	for e in errors:
		print("  content: ", e)
	ok(errors.is_empty(), "content cross-references are valid (%d problems)" % errors.size())
	ok(DB.items.size() >= 40, "items loaded")
	ok(DB.entities.has(&"PLAYER"), "player entity type exists")


## Every text key used by code or data exists in all 8 languages.
func test_localization() -> void:
	var keys := {}
	var re := RegEx.new()
	re.compile("tr\\(\"([A-Z0-9_]+)\"\\)")
	for f in _files("res://src", ".gd"):
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			keys[m.get_string(1)] = f
	for it: ItemData in DB.items.values():
		keys[it.name_key] = "item"
		keys[it.desc_key] = "item"
	for e: EntityType in DB.entities.values():
		keys[e.name_key] = "entity"
		for k in e.dialogue:
			if e.dialogue[k] is Array:
				for line in e.dialogue[k]:
					keys[line] = "dialogue"
	for poi in DB.world["pois"]:
		keys[poi["name_key"]] = "poi"
		if poi.has("lore"):
			keys[poi["lore"]] = "poi"
	for r: RegionData in DB.regions.values():
		keys[r.name_key] = "region"
	for w in DB.weather_types:
		keys["WEATHER_" + String(w).to_upper()] = "weather"
	for b in DB.buffs:
		keys["BUFF_" + String(b).to_upper()] = "buff"
	for c in ItemData.CATEGORIES:
		keys["CAT_" + String(c).to_upper()] = "category"
	var missing := PackedStringArray()
	for lang in Settings.LANGUAGES:
		TranslationServer.set_locale(lang)
		for k in keys:
			if k == "NAME_NARRATOR":
				continue
			if tr(k) == k or tr(k).strip_edges() == "":
				missing.append("%s:%s" % [lang, k])
	Settings.apply_language()
	for m in missing.slice(0, 12):
		print("  missing translation ", m)
	ok(missing.is_empty(), "all %d text keys translated in %d languages (%d missing)" % [keys.size(), Settings.LANGUAGES.size(), missing.size()])


func test_inventory() -> void:
	var inv := Inventory.new()
	ok(inv.add(&"sunpear", 150) == 150, "stackable add")
	ok(inv.in_category(&"food").size() == 2, "splits into stacks of max_stack")
	ok(inv.remove(&"sunpear", 120) and inv.count_of(&"sunpear") == 30, "remove across stacks")
	ok(not inv.remove(&"sunpear", 31), "cannot remove more than owned")
	for i in 8:
		inv.add(&"bough_club")
	ok(inv.add(&"bough_club") == 0, "weapon capacity respected")
	var s := inv.find_first(&"bough_club")
	ok(s.durability() == float(DB.item(&"bough_club").w("durability", 0)), "weapons start with full durability")
	var restored := Inventory.new()
	restored.from_array(inv.to_array())
	ok(restored.count_of(&"sunpear") == 30 and restored.category_count(&"weapon") == 8, "inventory serialization round trip")


func test_durability() -> void:
	PlayerData.reset_new_game()
	var club := PlayerData.weapon()
	ok(club != null and club.id == &"bough_club", "starting weapon equipped")
	var n := int(club.durability())
	for i in n:
		PlayerData.wear_weapon(1.0)
	ok(not PlayerData.inventory.has(&"bough_club"), "normal weapon breaks at 0")
	PlayerData.inventory.add(&"wayfarer_edge")
	var edge := PlayerData.inventory.find_first(&"wayfarer_edge")
	PlayerData.equip(edge)
	for i in 100:
		PlayerData.wear_weapon(1.0)
	ok(PlayerData.inventory.has(&"wayfarer_edge") and edge.is_blunted(), "heirloom blunts instead of breaking")
	PlayerData.repair_weapon(edge, 1.0)
	ok(edge.durability_ratio() == 1.0, "repair restores durability")


func test_cooking() -> void:
	var r := Cooking.resolve([&"honeycomb", &"sunpear", &"sunpear"])
	ok(r["item"] == &"honey_pear_tart", "special recipe found regardless of order")
	r = Cooking.resolve([&"emberroot", &"emberroot", &"sunpear"])
	ok(r["item"] == &"warming_curry" and r["potency"] == 2.0, "dominant tag decides dish; potency = sum")
	r = Cooking.resolve([&"emberroot", &"frostmint"])
	ok(r["item"] == &"murky_stew", "conflicting effects spoil the pot")
	r = Cooking.resolve([&"flint", &"iron_ore"])
	ok(r["item"] == &"murky_stew", "inedible pot")
	r = Cooking.resolve([&"raw_meat", &"sunpear"])
	ok(r["item"] == &"hearty_stew", "healing-only pot is a hearty stew")
	r = Cooking.resolve([&"fang_pepper", &"fang_pepper", &"fang_pepper", &"fang_pepper", &"fang_pepper"])
	ok(r["potency"] <= float(DB.cooking.get("max_potency", 3.0)), "potency is capped")


func test_crafting() -> void:
	PlayerData.reset_new_game()
	var rec: Dictionary = DB.crafting[&"craft_whetstone"]
	ok(not Crafting.can_craft(rec), "cannot craft without ingredients")
	PlayerData.inventory.add(&"flint", 3)
	ok(Crafting.craft(rec) and PlayerData.inventory.has(&"whetstone"), "crafting consumes and produces")
	ok(not PlayerData.inventory.has(&"flint"), "ingredients consumed")
	var ingot: Dictionary = DB.crafting[&"craft_iron_ingot"]
	PlayerData.inventory.add(&"iron_ore", 2)
	PlayerData.inventory.add(&"wood_bundle", 1)
	ok(not Crafting.can_craft(ingot), "station recipes need a campfire nearby")


func test_worldgen() -> void:
	var a := WorldGen.from_world_data(DB.world)
	var b := WorldGen.from_world_data(DB.world)
	var same := true
	for i in 50:
		var x := randf_range(-900, 900)
		var z := randf_range(-900, 900)
		same = same and is_equal_approx(a.height(x, z), b.height(x, z))
	ok(same, "terrain is deterministic across samplers/threads")
	var summit: Dictionary
	for poi in DB.world["pois"]:
		if poi["id"] == "cendal_summit":
			summit = poi
	var sp: Array = summit["pos"]
	ok(a.height(sp[0], sp[1]) > 250.0, "summit is the high point of the island")
	ok(a.height(0, 990) < 0.0, "island is surrounded by sea")
	ok(a.height(WorldGen.LAKE_CENTER.x, WorldGen.LAKE_CENTER.y) < -3.0, "lake basin is below sea level")


## Neighbouring sectors must share identical edge heights (no cracks).
func test_chunk_seams() -> void:
	var gen := WorldGen.from_world_data(DB.world)
	var a := ChunkBuilder.build(gen, 0, 0, 0, 0.0)
	var b := ChunkBuilder.build(gen, 1, 0, 0, 0.0)
	var n: int = a["grid"]
	var worst := 0.0
	for j in n:
		var ha: float = a["collision"][j * n + (n - 1)]
		var hb: float = b["collision"][j * n]
		worst = maxf(worst, absf(ha - hb))
	ok(worst < 0.001, "sector edges match exactly (max diff %.4f)" % worst)
	var l1 := ChunkBuilder.build(gen, 2, 0, 1, 0.0)
	ok(l1.has("veg") and not l1.has("nodes"), "LOD1 has vegetation but no gameplay content")


func test_save_backup() -> void:
	var main := SaveSystem.SLOT_PATH
	var bak := SaveSystem.BACKUP_PATH
	var f := FileAccess.open(bak, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "playtime": 42.0, "player": {}}))
	f.close()
	f = FileAccess.open(main, FileAccess.WRITE)
	f.store_string("{ corrupted")
	f.close()
	ok(SaveSystem.read_save() and SaveSystem.section("player") is Dictionary and SaveSystem._loaded.get("playtime") == 42.0, "corrupt save falls back to backup")
	SaveSystem.delete_save()
	ok(not SaveSystem.has_save(), "delete save")


func test_quality_presets() -> void:
	var keys: Array = Quality.PRESETS[Quality.Level.HIGH].keys()
	var all_ok := true
	for lvl in Quality.PRESETS:
		for k in keys:
			all_ok = all_ok and Quality.PRESETS[lvl].has(k)
	ok(all_ok, "every quality preset defines every budget")
	ok(Quality.PRESETS[Quality.Level.LOW]["vegetation_density"] < Quality.PRESETS[Quality.Level.ULTRA]["vegetation_density"], "LOW budgets are lower than ULTRA")


func test_ai_attack_pick() -> void:
	var t := DB.entity(&"ENEMY_THORNLING")
	var c := Enemy.new()
	c.type = t
	var brain := AIBrain.new(c)
	ok(brain.pick_attack(1.0).id == &"bite", "close range picks bite")
	ok(brain.pick_attack(5.0).id == &"pounce", "mid range picks pounce")
	ok(brain.pick_attack(20.0) == null, "out of range picks nothing")
	c.free()


## Placeholder identity: player white, each species a distinct solid color.
func test_placeholder_colors() -> void:
	ok(DB.entity(&"PLAYER").placeholder_color == Color.WHITE, "player placeholder is white")
	var seen := {}
	var unique := true
	for e: EntityType in DB.entities.values():
		var key := e.placeholder_color.to_html(false)
		if seen.has(key):
			unique = false
			print("  duplicate color ", key, " ", e.id, " / ", seen[key])
		seen[key] = e.id
		ok(e.model == "" or ResourceLoader.exists(e.model), "model path valid for " + e.id)
	ok(unique, "every entity type has a unique placeholder color")


func _files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), ext))
	return out
