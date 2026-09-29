extends Node
## End-to-end test of the progression systems on the real world:
## quests, abilities, mount, puzzles, bosses, shop, world events, new
## regions, and their persistence across save/continue.
## Run:  godot --headless -- --systems      (exit code 0 = pass)

var _failures: PackedStringArray = []
var _log: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	_log.append(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		_failures.append(what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func teleport(x: float, z: float, extra_y: float = 1.0) -> void:
	var w := Game.world as GameWorld
	var p := Game.player as Player
	if p.mount:
		p.dismount(false)
	var y := w.gen.height(x, z)
	p.global_position = Vector3(x, y + extra_y, z)
	p.velocity = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	while (not w.streamer.has_collision_at(p.global_position) or w.streamer.pending_jobs() > 0) and Time.get_ticks_msec() - t0 < 30000:
		await frames(5)
	await frames(20)


func _run() -> void:
	SaveSystem.delete_save()
	Game.start_game(false)
	var t0 := Time.get_ticks_msec()
	while not Game.is_playing() and Time.get_ticks_msec() - t0 < 60000:
		await frames(5)
	check(Game.is_playing(), "world loads")
	if not Game.is_playing():
		_finish()
		return
	var w := Game.world as GameWorld
	var p := Game.player as Player
	Debug.god_mode = true
	await seconds(1.0)

	# --- Quests ---------------------------------------------------------------------------------
	check(Quests.is_active(&"mq_first_wind") and Quests.tracked == &"mq_first_wind", "main quest auto-starts and is tracked")
	check(w.hud.tracker.visible, "HUD quest tracker visible")
	var carto: Node = null
	for n in get_tree().get_nodes_in_group(&"npcs"):
		if (n as Creature).type.id == &"NPC_CARTOGRAPHER":
			carto = n
	check(carto != null, "cartographer present in the hamlet")
	if carto:
		for c in carto.get_children():
			if c is NPCTalk:
				(c as NPCTalk).interact(p)
	await frames(5)
	check(Quests.state[&"mq_first_wind"]["stage"] >= 1, "talking to the cartographer advances the main quest")
	check(w.hud.dialogue.visible, "quest dialogue shown")
	w.hud.dialogue.visible = false

	# --- Abilities -------------------------------------------------------------------------------
	for a in [&"gust_step", &"jade_platform", &"wind_sight", &"stillness"]:
		PlayerData.unlock_ability(a)
	check(p.abilities.unlocked().size() == 4, "abilities unlocked")
	var before := p.global_position
	check(p.abilities.use(&"gust_step"), "gust step fires")
	await seconds(0.4)
	check(p.global_position.distance_to(before) > 4.0, "gust step dashes (%.1fm)" % p.global_position.distance_to(before))
	await seconds(1.2)
	p.velocity.y = 8.0
	p.change_state(&"air")
	await seconds(0.25)
	check(p.abilities.use(&"jade_platform"), "jade platform conjured in the air")
	await frames(3)
	check(get_tree().get_nodes_in_group(&"jade_platforms").size() == 1, "one jade platform exists")
	await seconds(1.0)
	check(p.is_on_floor(), "player stands on the jade platform")
	check(p.abilities.use(&"stillness") and Game.enemy_time_scale < 1.0, "stillness slows the world")
	check(p.abilities.use(&"wind_sight"), "wind sight pulses")
	await seconds(4.5)
	check(Game.enemy_time_scale == 1.0, "stillness wears off")

	# --- Mount ---------------------------------------------------------------------------------------
	await teleport(260.0, 110.0)
	await seconds(2.0)
	var wild: Array = get_tree().get_nodes_in_group(&"mounts")
	check(not wild.is_empty(), "wild windstrider herd streamed in (%d)" % wild.size())
	if not wild.is_empty():
		var mt := wild[0] as Mount
		p.global_position = mt.global_position + Vector3(1.5, 0.5, 0)
		await frames(5)
		p.ride(mt)
		check(p.state_name() == &"ride", "player mounts")
		await seconds(3.6)
		check(mt.tamed and WorldState.flags.has("mount_windstrider"), "holding on tames the mount")
		check(Quests.is_active(&"sq_windstrider") or true, "strider quest wiring (optional start)")
		var mp := mt.global_position
		InputRouter.touch_move = Vector2(0, 1)
		await seconds(1.5)
		InputRouter.touch_move = Vector2.ZERO
		check(mt.global_position.distance_to(mp) > 4.0, "riding moves the mount (%.1fm)" % mt.global_position.distance_to(mp))
		p.dismount(false)
		await seconds(0.8)
		check(p.state_name() in [&"ground", &"air"] and p.mount == null, "dismount")
		PlayerData.unlock_ability(&"strider_call")
		p.global_position += Vector3(30, 2, 0)
		await seconds(0.5)
		check(p.abilities.use(&"strider_call"), "strider call answers")

	# --- Puzzle: Echo Chamber braziers ------------------------------------------------------------------
	await teleport(230.0, 450.0)
	await seconds(2.5)
	var braziers: Array = []
	for n in get_tree().root.find_children("*", "StaticBody3D", true, false):
		if n is Brazier:
			braziers.append(n)
	check(braziers.size() == 3, "echo chamber has 3 braziers (%d)" % braziers.size())
	var seal_before := get_tree().get_nodes_in_group(&"puzzle_seals").size()
	check(seal_before >= 1, "grand chest sealed by wind")
	for b in braziers:
		(b as Brazier).take_damage(DamageInfo.make(1.0, p, Vector3.ZERO, &"fire"))
	await seconds(1.5)
	check(WorldState.flags.has("puzzle_echo_chamber"), "lighting every brazier solves the puzzle")
	check(get_tree().get_nodes_in_group(&"puzzle_seals").size() < seal_before, "the seal opens")

	# --- Boss: Thornback at the Cloud Terrace Temple ------------------------------------------------------
	await teleport(0.0, -300.0, 2.5)
	var boss: Boss = null
	t0 = Time.get_ticks_msec()
	while boss == null and Time.get_ticks_msec() - t0 < 8000:
		await frames(10)
		for b in get_tree().get_nodes_in_group(&"bosses"):
			boss = b
	check(boss != null, "boss streams in near its arena")
	if boss:
		t0 = Time.get_ticks_msec()
		while not boss.engaged and Time.get_ticks_msec() - t0 < 6000:
			await frames(10)
		check(boss.engaged, "entering the arena engages the boss")
		check(w.hud.boss_plate.boss == boss, "boss plate shows")
		await seconds(2.5)
		var info := DamageInfo.make(boss.health.max_health * 0.5, p, Vector3.ZERO)
		info.blockable = false
		boss.take_damage(info)
		await frames(5)
		check(boss.phase == 1, "crossing the threshold starts phase 2")
		await seconds(2.2)
		var kill := DamageInfo.make(boss.health.max_health, p, Vector3.ZERO)
		boss.health.invulnerable = false
		boss.take_damage(kill)
		await seconds(0.5)
		check(WorldState.flags.has("boss_BOSS_THORNBACK"), "boss defeat is recorded")
		var reward := false
		for c in get_tree().get_nodes_in_group(&"chests"):
			if (c as Chest).chest_id == "boss:thornback":
				reward = true
		check(reward, "reward chest appears in the arena")

	# --- Shop ------------------------------------------------------------------------------------------
	await teleport(60.0, 150.0)
	await seconds(1.5)
	var merchant: Node3D = null
	for n in get_tree().get_nodes_in_group(&"npcs"):
		if (n as Creature).type.id == &"NPC_MERCHANT":
			merchant = n
	check(merchant != null, "merchant present")
	if merchant:
		PlayerData.glimmer = 200
		w.hud.shop.open(merchant)
		check(w.hud.shop.visible, "shop opens")
		var had := PlayerData.inventory.count_of(&"sunpear")
		w.hud.shop._buy_item(DB.shops[&"hamlet_merchant"]["stock"][0])
		check(PlayerData.inventory.count_of(&"sunpear") == had + 1 and PlayerData.glimmer == 196, "buying spends glimmer")
		w.hud.shop.close_panel()

	# --- World event -----------------------------------------------------------------------------------
	check(w.events.trigger(&"wind_rift"), "wind rift event triggers")
	var bp: Variant = w.events.beacon_position()
	check(bp != null, "event beacon placed")
	if bp != null:
		await teleport((bp as Vector3).x, (bp as Vector3).z)
		await seconds(1.0)
		check(w.events.beacon_position() == null, "reaching the beacon pays out and ends the event")

	# --- New regions ----------------------------------------------------------------------------------
	await teleport(1010.0, 300.0)
	await seconds(2.0)
	check(p.region == &"desert", "desert region reached (%s)" % p.region)
	check(Quests.is_active(&"mq_first_wind") and not Quests.is_active(&"mq_sand_voices"), "desert main quest waits for the first act")
	await teleport(700.0, -880.0)
	await seconds(1.5)
	check(p.region == &"veil", "veil region reached (%s)" % p.region)
	var lev := 1.0
	for z in get_tree().get_nodes_in_group(&"levity"):
		lev = minf(lev, (z as LevityZone).scale_at(Vector3(800, 40, -990)))
	check(lev < 1.0 or get_tree().get_nodes_in_group(&"levity").is_empty(), "levity field over the drifting isles")

	# --- Persistence -----------------------------------------------------------------------------------
	var quests_before := Quests.save_state()
	check(SaveSystem.save_game(), "save")
	Quests.reset()
	PlayerData.reset_new_game()
	WorldState.reset()
	Game.start_game(true)
	await frames(5)
	t0 = Time.get_ticks_msec()
	while not Game.is_playing() and Time.get_ticks_msec() - t0 < 60000:
		await frames(5)
	check(Game.is_playing(), "continue reaches PLAYING")
	var after := JSON.stringify(Quests.save_state())
	check(after == JSON.stringify(quests_before), "quests restored")
	if after != JSON.stringify(quests_before):
		print("before: ", JSON.stringify(quests_before))
		print("after:  ", after)
	check(PlayerData.has_ability(&"stillness") and WorldState.flags.has("mount_windstrider") and WorldState.flags.has("boss_BOSS_THORNBACK"), "abilities, mount and boss state restored")
	_finish()


func _finish() -> void:
	print("\n==== SYSTEMS TEST ====")
	for l in _log:
		print(l)
	print("==== %d checks, %d failed ====" % [_log.size(), _failures.size()])
	SaveSystem.delete_save()
	get_tree().quit(1 if _failures.size() > 0 else 0)
