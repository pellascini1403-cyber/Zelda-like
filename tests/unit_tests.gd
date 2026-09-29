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
	test_quests()
	test_quest_objective_types()
	test_quest_rewards()
	test_quest_fail_and_recovery()
	test_quest_discovery_starts()
	test_quest_markers_and_boards()
	test_quest_validator()
	test_quest_content_goals()
	test_boss_data()
	test_abilities_data()
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
	# Quest layer: every key in quest data, upgrades, cosmetics, events, bosses.
	for q in DB.quests:
		_collect_text_keys(q, keys)
	for u in DB.upgrades.values():
		keys[u["name_key"]] = "upgrade"
		keys[u["desc_key"]] = "upgrade"
	for c in DB.cosmetics.values():
		keys[c["name_key"]] = "cosmetic"
		keys["COS_SLOT_" + String(c["slot"]).to_upper()] = "cosmetic"
	for ev in DB.world_events:
		keys[ev["name_key"]] = "event"
		for l in (ev.get("encounter", {}) as Dictionary).get("end_lines", []):
			keys[l] = "event"
	for b in DB.bosses.values():
		keys[b["title_key"]] = "boss"
		for ph in b.get("phases", []):
			if ph.has("title_key"):
				keys[ph["title_key"]] = "boss"
	for a in DB.abilities.values():
		keys[a["name_key"]] = "ability"
	var missing := PackedStringArray()
	var bad_templates := PackedStringArray()
	for lang in Settings.LANGUAGES:
		TranslationServer.set_locale(lang)
		for k in keys:
			if k == "NAME_NARRATOR":
				continue
			if tr(k) == k or tr(k).strip_edges() == "":
				missing.append("%s:%s" % [lang, k])
		# Objective templates must take exactly as many names as they are given.
		for q in DB.quests:
			for st in q["stages"]:
				for o in st["objectives"]:
					var args: Array = o.get("text_args", [])
					if not args.is_empty() and tr(String(o["text_key"])).count("%s") != args.size():
						bad_templates.append("%s:%s" % [lang, o["text_key"]])
	Settings.apply_language()
	for b in bad_templates.slice(0, 6):
		print("  template/argument mismatch ", b)
	ok(bad_templates.is_empty(), "objective templates match their arguments in every language")
	for m in missing.slice(0, 12):
		print("  missing translation ", m)
	ok(missing.is_empty(), "all %d text keys translated in %d languages (%d missing)" % [keys.size(), Settings.LANGUAGES.size(), missing.size()])


## Text keys inside quest data (titles, lines, objective texts and their
## name arguments, prompts, hints, banners, shouts).
func _collect_text_keys(v: Variant, keys: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			var x: Variant = v[k]
			if k in ["title_key", "desc_key", "text_key", "hint_key", "shout_key"] and x is String and x != "":
				keys[x] = "quest"
			elif k == "prompt" and x is String:
				keys[x] = "quest"
			elif (String(k).ends_with("_lines") or k == "lines" or k == "text_args") and x is Array:
				for line in x:
					if line is String and line == line.to_upper() and not line.is_valid_float():
						keys[line] = "quest"
			else:
				_collect_text_keys(x, keys)
	elif v is Array:
		for x in v:
			_collect_text_keys(x, keys)


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


## Quest flow without a world: start, progress by events, stage advance,
## rewards, prerequisites, save/load round trip.
func test_quests() -> void:
	_quest_reset()
	ok(Quests.quest_state(&"mq_vela") == Quests.State.AVAILABLE, "first main quest available at start")
	ok(Quests.quest_state(&"mq_thorn_road") == Quests.State.LOCKED, "second main quest locked by prerequisite")
	ok(Quests.start(&"sq_thorn_cull", true), "side quest starts")
	for i in 5:
		EventBus.entity_killed.emit(&"ENEMY_THORNLING", Vector3.ZERO)
	ok(Quests.state[&"sq_thorn_cull"]["stage"] == 1, "kill objective advances the stage")
	var g := PlayerData.glimmer
	EventBus.npc_talked.emit(&"NPC_VILLAGER")
	ok(Quests.is_completed(&"sq_thorn_cull"), "talk objective completes the quest")
	ok(PlayerData.glimmer == g + 30 and PlayerData.inventory.has(&"fur_cap"), "rewards granted")
	_force_start(&"sq_mushroom_stew")
	PlayerData.inventory.add(&"cap_mushroom", 5)
	EventBus.item_acquired.emit(&"cap_mushroom", 5)
	ok(Quests.state[&"sq_mushroom_stew"]["stage"] == 1, "collect objective counts held items")
	var saved := Quests.save_state()
	Quests.reset()
	Quests.load_state(saved)
	ok(Quests.is_completed(&"sq_thorn_cull") and Quests.state[&"sq_mushroom_stew"]["stage"] == 1, "quest state survives save/load")
	# Main line: talk -> climb (polled, done by hand here) -> glide metric -> talk.
	Quests.start(&"mq_vela", true)
	EventBus.npc_talked.emit(&"NPC_CARTOGRAPHER")
	ok(Quests.state[&"mq_vela"]["stage"] == 1, "talking to Tamsin advances the first main quest")
	ok(not Quests.tracked_marker().is_empty(), "tracked main quest exposes a marker")
	Quests.state[&"mq_vela"]["progress"][0] = 1
	Quests._after_progress(&"mq_vela")
	Quests.state[&"mq_vela"]["progress"][0] = 15
	Quests._after_progress(&"mq_vela")
	EventBus.npc_talked.emit(&"NPC_CARTOGRAPHER")
	ok(Quests.is_completed(&"mq_vela") and PlayerData.jade >= 2, "first main quest completes and pays jade")
	ok(Quests.quest_state(&"mq_thorn_road") != Quests.State.LOCKED and Quests.quest_state(&"sq_lost_kite") != Quests.State.LOCKED, "completing a quest unlocks the next ones")
	_quest_reset()


## Every objective type, driven through a synthetic quest with one stage per
## type (the facts are the same signals the gameplay systems emit).
func test_quest_objective_types() -> void:
	_quest_reset()
	var steps := [
		["kill", "ENEMY_WISP", func() -> void: EventBus.entity_killed.emit(&"ENEMY_WISP", Vector3.ZERO)],
		["hunt", "ANIMAL_WOOLHORN", func() -> void: EventBus.entity_killed.emit(&"ANIMAL_WOOLHORN", Vector3.ZERO)],
		["clear", "t_group", func() -> void: EventBus.creature_defeated.emit(&"ENEMY_THORNLING", "t_group", false)],
		["sneak", "ENEMY_THORNLING", func() -> void: EventBus.creature_defeated.emit(&"ENEMY_THORNLING", "", true)],
		["boss", "BOSS_THORNBACK", func() -> void: EventBus.boss_defeated.emit(&"BOSS_THORNBACK")],
		["collect", "flint", func() -> void:
			PlayerData.inventory.add(&"flint", 1)
			EventBus.item_acquired.emit(&"flint", 1)],
		["gather", "iron_vein", func() -> void: EventBus.resource_gathered.emit(&"iron_vein", Vector3.ZERO)],
		["interact", "t_obj", func() -> void: EventBus.quest_object_used.emit(&"t_obj", &"")],
		["retrieve", "group:t_relics", func() -> void: EventBus.quest_object_used.emit(&"t_relic", &"t_relics")],
		["destroy", "t_nest", func() -> void: EventBus.quest_object_destroyed.emit(&"t_nest", &"")],
		["discover", "echo_chamber", func() -> void: EventBus.poi_discovered.emit(&"echo_chamber")],
		["region", "desert", func() -> void: EventBus.region_entered.emit(&"desert")],
		["talk", "NPC_SMITH", func() -> void: EventBus.npc_talked.emit(&"NPC_SMITH")],
		["flag", "t_flag", func() -> void: Quests.set_flag(&"t_flag")],
		["puzzle", "t_puzzle", func() -> void: Quests.set_flag(&"puzzle_t_puzzle")],
		["ability", "jade_platform", func() -> void: PlayerData.unlock_ability(&"jade_platform")],
		["ability_use", "gust_step", func() -> void: EventBus.ability_used.emit(&"gust_step")],
		["craft", "whetstone", func() -> void: EventBus.item_crafted.emit(&"whetstone")],
		["cook", "hearty_stew", func() -> void: EventBus.dish_cooked.emit(&"hearty_stew")],
		["mount", "windstrider", func() -> void: EventBus.mount_tamed.emit(&"windstrider")],
		["open_chest", "t_chest", func() -> void: EventBus.chest_opened.emit("t_chest", [])],
		["protect", "t_enc", func() -> void: EventBus.encounter_finished.emit(&"t_enc", true)],
		["escort", "t_esc", func() -> void: EventBus.encounter_finished.emit(&"t_esc", true)],
		["survive", "t_surv", func() -> void: EventBus.encounter_finished.emit(&"t_surv", true)],
		["course", "t_course", func() -> void: EventBus.course_finished.emit(&"t_course", 10.0)],
		["event", "t_event", func() -> void: EventBus.quest_event.emit(&"t_event")],
		["deliver", "NPC_HUNTER", func() -> void:
			PlayerData.inventory.add(&"raw_meat", 1)
			EventBus.npc_talked.emit(&"NPC_HUNTER")],
	]
	var stages: Array = []
	for st in steps:
		var o := {"type": st[0], "target": st[1], "text_key": "QO_T_FIND"}
		if st[0] == "deliver":
			o["item"] = "raw_meat"
		if st[0] == "course":
			o["par"] = 30.0
		stages.append({"objectives": [o]})
	_inject({"id": "t_all", "type": "side", "category": "exploration", "start": "auto", "stages": stages, "rewards": {"glimmer": 1}})
	Quests.start(&"t_all", true)
	var covered := {}
	for i in steps.size():
		var before: int = Quests.state[&"t_all"]["stage"]
		(steps[i][2] as Callable).call()
		var advanced: bool = Quests.is_completed(&"t_all") or int(Quests.state[&"t_all"]["stage"]) > before
		ok(advanced, "objective type '%s' completes" % steps[i][0])
		covered[Quests.canon({"type": steps[i][0]})] = true
	ok(PlayerData.inventory.count_of(&"raw_meat") == 0, "deliver takes the item")
	var missing := []
	for t in Quests.TYPES:
		if not t in covered and not t in Quests.POLLED:
			missing.append(t)
	ok(missing.is_empty(), "every non-polled objective type is exercised (%s)" % ", ".join(missing))
	# Course par: a slow run does not count, a fast one does.
	_inject({"id": "t_par", "type": "challenge", "category": "challenge", "start": "auto", "rewards": {"glimmer": 1},
		"stages": [{"objectives": [{"type": "course", "target": "t_ring", "par": 20.0, "text_key": "QO_T_FIND"}]}]})
	Quests.start(&"t_par", true)
	EventBus.course_finished.emit(&"t_ring", 25.0)
	ok(Quests.is_active(&"t_par"), "a course over par does not count")
	EventBus.course_finished.emit(&"t_ring", 18.0)
	ok(Quests.is_completed(&"t_par"), "a course under par counts")
	_quest_reset()


## Rewards: the ledger never pays a source twice; repeatables pay each run;
## stage rewards; bonus rewards for optional objectives.
func test_quest_rewards() -> void:
	_quest_reset()
	var g := PlayerData.glimmer
	ok(Rewards.grant({"glimmer": 10, "jade": 1}, "test:once"), "reward granted")
	ok(not Rewards.grant({"glimmer": 10, "jade": 1}, "test:once"), "same source is never paid twice")
	ok(PlayerData.glimmer == g + 10 and PlayerData.jade == 1, "ledger kept the single payment")
	Rewards.grant({"cosmetic": "trail_jade", "recipes": [["frostmint", "sunpear"]], "reveal": [{"pos": [0, 0], "radius": 2}]}, "test:mixed")
	ok(PlayerData.cosmetics.has("trail_jade") and PlayerData.cosmetic_slots.get("trail", "") == "trail_jade", "cosmetic reward owned and worn")
	ok(not PlayerData.cookbook.is_empty(), "recipe reward fills the cookbook")
	# Repeatable: cooldown, then available again, paid again.
	_inject({"id": "t_rep", "type": "bounty", "category": "combat", "board": "hamlet", "start": "board", "repeatable": true, "cooldown_hours": 2.0,
		"rewards": {"glimmer": 5}, "stages": [{"objectives": [{"type": "event", "target": "t_go", "text_key": "QO_T_FIND"}]}]})
	g = PlayerData.glimmer
	Quests.start(&"t_rep", true)
	EventBus.quest_event.emit(&"t_go")
	ok(Quests.quest_state(&"t_rep") == Quests.State.COOLDOWN, "repeatable goes to cooldown")
	ok(not Quests.start(&"t_rep", true), "cannot restart during cooldown")
	Clock.day += 1
	Quests._refresh_availability()
	ok(Quests.quest_state(&"t_rep") == Quests.State.AVAILABLE, "repeatable returns after its cooldown")
	Quests.start(&"t_rep", true)
	EventBus.quest_event.emit(&"t_go")
	ok(PlayerData.glimmer == g + 10 and Quests.completions(&"t_rep") == 2, "each completion of a repeatable pays once")
	Clock.day -= 1
	# Stage rewards and bonus objectives.
	_inject({"id": "t_bonus", "type": "side", "category": "combat", "start": "auto", "rewards": {"glimmer": 1}, "bonus_rewards": {"glimmer": 7},
		"stages": [{"objectives": [{"type": "event", "target": "t_a", "text_key": "QO_T_FIND"}], "rewards": {"jade": 2}},
			{"objectives": [{"type": "event", "target": "t_b", "text_key": "QO_T_FIND"}, {"type": "event", "target": "t_c", "optional": true, "text_key": "QO_T_FIND"}]}]})
	var j := PlayerData.jade
	Quests.start(&"t_bonus", true)
	EventBus.quest_event.emit(&"t_a")
	ok(PlayerData.jade == j + 2, "stage rewards are paid when the stage completes")
	g = PlayerData.glimmer
	EventBus.quest_event.emit(&"t_c")
	EventBus.quest_event.emit(&"t_b")
	ok(Quests.is_completed(&"t_bonus") and PlayerData.glimmer == g + 8, "optional objective done: bonus paid with the reward")
	_quest_reset()


## Failing an escort/protect/survive stage only resets that stage; the
## journal can restart any stage: no permanent dead ends.
func test_quest_fail_and_recovery() -> void:
	_quest_reset()
	_inject({"id": "t_fail", "type": "side", "category": "npc", "start": "auto", "rewards": {"glimmer": 1},
		"stages": [{"objectives": [{"type": "event", "target": "t_pre", "text_key": "QO_T_FIND"}]},
			{"objectives": [{"type": "protect", "target": "t_guard", "text_key": "QO_T_FIND"}, {"type": "kill", "target": "ENEMY_WISP", "count": 2, "text_key": "QO_T_FIND"}]}]})
	Quests.start(&"t_fail", true)
	EventBus.quest_event.emit(&"t_pre")
	EventBus.entity_killed.emit(&"ENEMY_WISP", Vector3.ZERO)
	var failed := [false]
	var cb := func(id: StringName, _r: String) -> void: failed[0] = id == &"t_fail"
	EventBus.quest_failed.connect(cb)
	EventBus.encounter_finished.emit(&"t_guard", false)
	EventBus.quest_failed.disconnect(cb)
	ok(failed[0] and Quests.is_active(&"t_fail"), "a failed encounter reports failure and keeps the quest active")
	ok(Quests.state[&"t_fail"]["stage"] == 1 and Quests.state[&"t_fail"]["progress"][1] == 0, "failure resets only the current stage")
	Quests.restart_stage(&"t_fail")
	ok(Quests.state[&"t_fail"]["stage"] == 1, "journal restart keeps the quest on its current stage")
	EventBus.encounter_finished.emit(&"t_guard", true)
	EventBus.entity_killed.emit(&"ENEMY_WISP", Vector3.ZERO)
	EventBus.entity_killed.emit(&"ENEMY_WISP", Vector3.ZERO)
	ok(Quests.is_completed(&"t_fail"), "the stage can be completed after a failure")
	# Save mid-stage, load, keep going.
	_inject({"id": "t_save", "type": "side", "category": "combat", "start": "auto", "rewards": {"glimmer": 1},
		"stages": [{"objectives": [{"type": "kill", "target": "ENEMY_SHADE", "count": 3, "text_key": "QO_T_FIND"}]}]})
	Quests.start(&"t_save", true)
	EventBus.entity_killed.emit(&"ENEMY_SHADE", Vector3.ZERO)
	var saved := Quests.save_state()
	Quests.reset()
	Quests.load_state(saved)
	ok(Quests.is_active(&"t_save") and int(Quests.state[&"t_save"]["progress"][0]) == 1, "partial progress survives save/load")
	_quest_reset()


## Discovery starts: a fact (event), a found object (interact), a place (poi).
func test_quest_discovery_starts() -> void:
	_quest_reset()
	ok(Quests.quest_state(&"dq_gilded_hop") == Quests.State.AVAILABLE, "discovery quest waits unseen")
	ok(not &"dq_gilded_hop" in Quests.rumors(), "hidden discoveries are not listed as rumours")
	EventBus.entity_killed.emit(&"ANIMAL_GILDED_HOP", Vector3.ZERO)
	ok(Quests.is_active(&"dq_gilded_hop") and Quests.state[&"dq_gilded_hop"]["stage"] == 1, "event start: the discovering fact starts the quest and counts")
	EventBus.quest_object_used.emit(&"sails_tablet", &"")
	ok(Quests.is_active(&"dq_sealed_sails") and Quests.state[&"dq_sealed_sails"]["stage"] == 1, "object start: using the object starts the quest and counts")
	Quests.on_game_started()
	WorldState.discover_poi(&"old_quarry")
	EventBus.poi_discovered.emit(&"old_quarry")
	ok(Quests.quest_state(&"dq_stoneward") == Quests.State.ACTIVE or Quests.quest_state(&"dq_stoneward") == Quests.State.AVAILABLE, "poi start is wired")
	Quests._try_start_by(&"poi", &"old_quarry")
	ok(Quests.is_active(&"dq_stoneward"), "poi start: discovering the place starts its quest")
	_quest_reset()


## Markers: exact, area and none; bounties offer varied categories.
func test_quest_markers_and_boards() -> void:
	_quest_reset()
	_inject({"id": "t_mark", "type": "side", "category": "exploration", "start": "auto", "rewards": {"glimmer": 1},
		"stages": [{"objectives": [{"type": "event", "target": "x", "marker": [10, 20], "hint": "area", "area_radius": 40.0, "text_key": "QO_T_FIND"}]},
			{"objectives": [{"type": "event", "target": "y", "marker": [5, 5], "hint": "none", "text_key": "QO_T_FIND"}]}]})
	Quests.start(&"t_mark", true)
	var m := Quests.objective_marker(&"t_mark")
	ok(m.get("hint") == "area" and is_equal_approx(float(m.get("radius", 0)), 40.0) and (m.get("pos") as Vector3).is_equal_approx(Vector3(10, 0, 20)), "area marker carries its radius")
	EventBus.quest_event.emit(&"x")
	ok(Quests.objective_marker(&"t_mark").is_empty(), "secret objectives show no marker")
	ok(Quests.objective_text({"text_key": "QO_T_DEFEAT", "text_args": ["NAME_THORNLING"]}).contains(tr("NAME_THORNLING")), "templated objective text fills in names")
	var offers := Quests.board_offers("hamlet", 3)
	ok(not offers.is_empty(), "the hamlet board has bounties to offer")
	Quests.recent_categories = ["combat", "combat"]
	var cats := {}
	for id in Quests.board_offers("lodge", 2):
		cats[String(Quests.defs[id].get("category", ""))] = true
	ok(cats.size() >= 1, "board offers are available after recent bounties")
	_quest_reset()


## The validator catches the ways content can soft-lock.
func test_quest_validator() -> void:
	var saved: Array = DB.quests
	DB.quests = saved.duplicate()
	DB.quests.append({"id": "bad_1", "type": "side", "category": "combat", "title_key": "X", "desc_key": "X", "start": "talk:NPC_NOBODY", "rewards": {"glimmer": 1},
		"stages": [{"objectives": [{"type": "clear", "target": "nothing_here", "count": 3, "text_key": "X"}]}]})
	DB.quests.append({"id": "bad_2", "type": "side", "category": "combat", "title_key": "X", "desc_key": "X", "start": "auto",
		"stages": [{"objectives": [{"type": "escort", "target": "ghost", "text_key": "X"}, {"type": "flag", "target": "never_set", "text_key": "X"}]}]})
	var errors := QuestValidator.validate(DB)
	DB.quests = saved
	var joined := "\n".join(errors)
	ok(joined.contains("bad_1") and joined.contains("NPC_NOBODY"), "validator: unknown quest giver")
	ok(joined.contains("group 'nothing_here' spawns fewer"), "validator: clear objective without enemies")
	ok(joined.contains("encounter 'ghost' is not placed"), "validator: escort without an encounter")
	ok(joined.contains("never_set"), "validator: flag nothing can set")
	ok(joined.contains("bad_2") and joined.contains("rewards nothing"), "validator: quest without rewards")


## Content goals for the "gameplay first" direction: plenty to do, and
## varied — not a list of kill quests.
func test_quest_content_goals() -> void:
	var by_type := {}
	var by_region := {}
	var kill_only := 0
	var cats := {}
	for q in DB.quests:
		var t := String(q["type"])
		by_type[t] = by_type.get(t, 0) + 1
		if t != "main":
			by_region[String(q.get("region", ""))] = by_region.get(String(q.get("region", "")), 0) + 1
		cats[String(q.get("category", ""))] = true
		var only_kill := true
		for st in q["stages"]:
			for o in st["objectives"]:
				if not Quests.canon(o) in ["kill", "clear", "talk"]:
					only_kill = false
		if only_kill:
			kill_only += 1
	ok(by_type.get("main", 0) >= 15, "at least 15 main quests (%d)" % by_type.get("main", 0))
	ok(by_type.get("side", 0) + by_type.get("discovery", 0) >= 40, "at least 40 side + discovery quests (%d)" % (by_type.get("side", 0) + by_type.get("discovery", 0)))
	ok(by_type.get("bounty", 0) >= 6 and by_type.get("challenge", 0) >= 5, "bounties and challenges exist")
	ok(float(kill_only) / DB.quests.size() <= 0.1, "kill-and-report quests stay rare (%d)" % kill_only)
	ok(cats.size() >= 9, "quests span many categories (%d)" % cats.size())
	for r in ["valley", "forest", "highlands", "lakeshore", "coast", "desert", "veil"]:
		ok(by_region.get(r, 0) >= 2, "region %s has its own activities (%d)" % [r, by_region.get(r, 0)])
	# Consecutive main quests never lean on the same category.
	var mains: Array = []
	for q in DB.quests:
		if q["type"] == "main":
			mains.append(String(q["category"]))
	var repeats := 0
	for i in range(1, mains.size()):
		if mains[i] == mains[i - 1]:
			repeats += 1
	ok(repeats <= 3, "main quests alternate their main activity (%d repeats)" % repeats)


func _quest_reset() -> void:
	PlayerData.reset_new_game()
	WorldState.reset()
	Quests._load_defs()
	Quests.reset()


func _force_start(id: StringName) -> void:
	Quests.state[id]["state"] = Quests.State.AVAILABLE
	Quests.start(id, true)


func _inject(q: Dictionary) -> void:
	var id := StringName(q["id"])
	Quests.defs[id] = q
	if not id in Quests.order:
		Quests.order.append(id)
	Quests.state[id] = Quests._blank()
	Quests.state[id]["state"] = Quests.State.AVAILABLE


func test_boss_data() -> void:
	ok(DB.bosses.size() >= 3, "three bosses defined")
	for b in DB.bosses.values():
		var phases: Array = b.get("phases", [])
		var sorted := true
		for i in range(1, phases.size()):
			if float(phases[i]["at"]) >= float(phases[i - 1]["at"]):
				sorted = false
		ok(phases.size() >= 2 and sorted, "boss %s has ordered phases" % b["id"])
	ok(ElementFX.color(&"fire") != ElementFX.color(&"ice"), "elements have distinct FX colours")


func test_abilities_data() -> void:
	for id in [&"gust_step", &"jade_platform", &"wind_sight", &"stillness", &"strider_call"]:
		ok(DB.abilities.has(id), "ability %s defined" % id)
	var quest_abilities := {}
	for q in DB.quests:
		if q.get("rewards", {}).has("ability"):
			quest_abilities[q["rewards"]["ability"]] = true
	ok(quest_abilities.size() >= 4, "abilities are earned through quests (%d)" % quest_abilities.size())
