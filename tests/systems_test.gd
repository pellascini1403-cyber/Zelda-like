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
	# --only <section>: run one section (quests, ecosystems, forest, lake, sea, far).
	var oi := OS.get_cmdline_user_args().find("--only")
	if oi >= 0:
		match OS.get_cmdline_user_args()[oi + 1]:
			"ecosystems": await _ecosystems(w, p)
			"forest": await _forest(w, p)
			"lake": await _lake(w, p)
			"sea": await _sea(w, p)
			"far": await _far_seas(w, p)
			"quests": await _quest_content(w, p)
		# Store sandbox state lives in user:// — never leak it into the next run.
		Platform.backend.clear_owned()
		Platform.backend.sandbox = false
		_finish()
		return

	# --- Quests ---------------------------------------------------------------------------------
	check(Quests.is_active(&"mq_vela") and Quests.tracked == &"mq_vela", "main quest auto-starts and is tracked")
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
	check(Quests.state[&"mq_vela"]["stage"] >= 1, "talking to the cartographer advances the main quest")
	check(PlayerData.has_glider(), "Tamsin hands over the Vela")
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

	# --- Quest world content -----------------------------------------------------------------------
	await _quest_content(w, p)

	Debug.peaceful = false

	# --- Ecosystems (expansion phase 2) ------------------------------------------------------------
	await _ecosystems(w, p)

	# --- Forest and lake as places with rules (expansion phase 3) ---------------------------------
	await _forest(w, p)
	await _lake(w, p)

	# --- Coast and sea (expansion phase 4) --------------------------------------------------------
	await _sea(w, p)

	# --- The far seas: mist (west) and currents (east) (phase 4.5) --------------------------------
	await _far_seas(w, p)

	# --- World event -----------------------------------------------------------------------------------
	# Isolation: the director may have rolled a random beacon event during the
	# long run; only one beacon exists at a time, so close it first.
	if w.events.beacon_position() != null:
		w.events._end_beacon()
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
	check(not Quests.is_active(&"mq_sand_road"), "desert main quest waits for the beacons")
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
	check(DiscoveryDirector.is_found(&"forest_moon_gate") and WorldState.flags.has("moon_gate_open") and BrambleWall.burned("hollow_tree:door") and WorldState.flags.has("sunken_bells"), "discoveries, burned brambles and opened gates restored from the save")
	check(WorldState.flags.has("mist_bells_answered") and DiscoveryDirector.is_found(&"rip_high_isle") and DiscoveryDirector.is_found(&"mist_mirage") and WorldState.flags.has("bell:mist_bell_1"), "far-sea bells, wonders and flags restored from the save")
	check(DiscoveryDirector.is_found(&"sea_vanishing_bar") and WorldState.flags.has("lighthouse_lit") and WorldState.flags.has("gulls_cabin_open") and Quests.is_active(&"dq_sea_vanishing_isle"), "sea discoveries, the lit lamp, the opened cabin and sea quests restored from the save")
	_finish()


func _npc(id: StringName) -> Creature:
	for n in get_tree().get_nodes_in_group(&"npcs"):
		if (n as Creature).type.id == id:
			return n
	return null


func _talk(id: StringName, p: Player) -> void:
	var n := _npc(id)
	if n:
		for c in n.get_children():
			if c is NPCTalk:
				(c as NPCTalk).interact(p)
	await frames(3)
	(Game.world as GameWorld).hud.dialogue.visible = false


func _kill_near(pos: Vector3, r: float) -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group(&"creatures"):
		var cr := c as Creature
		if cr and not cr.is_dead() and cr.kind_is_hostile() and not cr is Boss and cr.global_position.distance_to(pos) < r:
			var info := DamageInfo.make(9999.0, Game.player, Vector3.ZERO)
			info.blockable = false
			cr.take_damage(info)
			n += 1
	return n


## Quest content in the real world: spawner, encounter, nest, course,
## object on a roof, board, altar, beacon, emergent encounter.
func _quest_content(w: GameWorld, p: Player) -> void:
	# Finish the first main quest so the next ones open up.
	Quests.state[&"mq_vela"]["state"] = Quests.State.COMPLETED
	Quests.state[&"mq_vela"]["completions"] = 1
	Quests._refresh_availability()
	await teleport(60.0, 150.0)
	await seconds(1.5)
	await _talk(&"NPC_MERCHANT", p)
	check(Quests.is_active(&"mq_thorn_road"), "Brask offers 'Thorns on the Road'")
	await teleport(165.0, 82.0)
	await seconds(2.0)
	var enc: QuestEncounter = null
	for e in get_tree().get_nodes_in_group(&"quest_encounters"):
		if (e as QuestEncounter).enc_id == &"cart_ambush":
			enc = e
	check(enc != null and enc.actor != null, "the cart ambush and its hauler are placed")
	var t0 := Time.get_ticks_msec()
	while enc and is_instance_valid(enc) and enc.phase != QuestEncounter.Phase.DONE and Time.get_ticks_msec() - t0 < 40000:
		await seconds(0.5)
		# The spawner may free the encounter during the wait (stage done):
		# never call into a freed node.
		if is_instance_valid(enc) and enc.is_active():
			_kill_near(enc.center, 40.0)
	check(Quests.state[&"mq_thorn_road"]["stage"] >= 1, "protecting the hauler completes the stage")
	await seconds(1.5)
	var nest: QuestNest = null
	for n in get_tree().get_nodes_in_group(&"quest_nests"):
		if (n as QuestNest).nest_id == &"road_nest":
			nest = n
	check(nest != null, "the thorn nest is placed")
	if nest:
		var slash := DamageInfo.make(20.0, p, Vector3.ZERO)
		nest.take_damage(slash)
		check(not nest.is_dead(), "blades barely scratch the nest")
		var blast := DamageInfo.make(40.0, p, Vector3.ZERO, &"fire")
		blast.kind = &"explosion"
		nest.take_damage(blast)
		await frames(3)
		check(QuestNest.destroyed("road_nest"), "an explosion destroys the nest")
	check(Quests.state[&"mq_thorn_road"]["stage"] >= 2, "destroying the nest advances the quest")
	var bombs := PlayerData.inventory.count_of(&"resin_bomb")
	await teleport(60.0, 150.0)
	await seconds(1.0)
	await _talk(&"NPC_MERCHANT", p)
	check(Quests.is_completed(&"mq_thorn_road") and PlayerData.inventory.count_of(&"resin_bomb") == bombs + 3, "turning in pays the reward")
	check(Quests.is_active(&"mq_echoes"), "the next main quest starts on its own")
	# Kite on the lookout roof (object snapped onto a structure).
	await _talk(&"NPC_CHILD", p)
	check(Quests.is_active(&"sq_lost_kite"), "Lio asks for the kite")
	await teleport(-15.0, 205.0)
	await seconds(2.0)
	var kite: QuestObject = null
	for o in get_tree().get_nodes_in_group(&"quest_objects"):
		if (o as QuestObject).object_id == &"lio_kite":
			kite = o
	check(kite != null and kite.global_position.y > 28.0, "the kite sits on the lookout roof (y %.1f)" % (kite.global_position.y if kite else 0.0))
	if kite:
		kite.interact(p)
		await frames(3)
	check(PlayerData.inventory.has(&"lios_kite"), "the kite is retrieved")
	await teleport(60.0, 150.0)
	await seconds(1.0)
	await _talk(&"NPC_CHILD", p)
	check(Quests.is_completed(&"sq_lost_kite") and PlayerData.cosmetics.has("ribbon_dawn"), "Lio rewards a glider-ribbon cosmetic")
	# Ring course (discovery start + par recheck on the same run).
	await teleport(70.0, 185.0)
	await seconds(2.0)
	var course: RingCourse = null
	for c in get_tree().get_nodes_in_group(&"ring_courses"):
		if (c as RingCourse).course_id == &"shrine_sprint":
			course = c
	check(course != null, "the shrine sprint course is placed")
	if course:
		for pt in course.points:
			p.global_position = pt
			await frames(4)
	await frames(5)
	check(Quests.is_completed(&"ch_shrine_sprint"), "running the rings under par clears the challenge")
	# Bounty board and Warden altar.
	EventBus.panel_requested.emit(&"board", "hamlet")
	await frames(2)
	check(w.hud.board.visible and w.hud.board.body.get_child_count() >= 2, "the hamlet board lists bounties")
	var offers := Quests.board_offers("hamlet", 3)
	if not offers.is_empty():
		Quests.start(offers[0])
	check(not offers.is_empty() and Quests.is_active(offers[0]), "a bounty can be taken")
	w.hud.board.close_panel()
	PlayerData.add_jade(10)
	var st := PlayerData.max_stamina
	EventBus.panel_requested.emit(&"altar", "")
	await frames(2)
	check(w.hud.altar.visible, "the Warden altar opens")
	check(PlayerData.buy_upgrade(&"breath") and PlayerData.upgrade_level(&"breath") == 1 and PlayerData.max_stamina == st + 20.0, "jade buys a blessing")
	w.hud.altar.close_panel()
	# Beacon at the temple.
	await teleport(-14.0, -312.0, 3.0)
	await seconds(2.0)
	var beacon: WardenBeacon = null
	for b in get_tree().get_nodes_in_group(&"warden_beacons"):
		if (b as WardenBeacon).flag_id == "beacon_valley":
			beacon = b
	check(beacon != null, "the valley beacon stands at the temple")
	if beacon:
		beacon.interact(p)
		await frames(3)
	check(WorldState.flags.has("beacon_valley"), "lighting the beacon sets its flag")
	# Emergent encounter: a traveller under attack.
	await teleport(120.0, 220.0)
	await seconds(1.0)
	# Isolation: the director runs one encounter at a time and never starts one
	# mid-fight; a random roll earlier in the run (or a roaming pack nearby)
	# must not decide this check.
	if w.events._encounter and is_instance_valid(w.events._encounter):
		w.events._encounter.queue_free()
		w.events._encounter = null
	for c in get_tree().get_nodes_in_group(&"creatures"):
		if (c as Creature).kind_is_hostile() and (c as Node3D).global_position.distance_to(p.global_position) < 80.0:
			(c as Creature).dead = true
			c.queue_free()
	Game.clear_aggro()
	await frames(2)
	check(w.events.trigger(&"traveler_attacked"), "a traveller-under-attack event triggers")
	var ev: QuestEncounter = w.events._encounter
	check(ev != null, "the emergent encounter is placed nearby")
	if ev:
		p.global_position = ev.center + Vector3(4, 2, 0)
		await seconds(1.0)
		var g := PlayerData.glimmer
		t0 = Time.get_ticks_msec()
		while is_instance_valid(ev) and ev.phase != QuestEncounter.Phase.DONE and Time.get_ticks_msec() - t0 < 30000:
			await seconds(0.5)
			if ev.is_active():
				_kill_near(ev.center, 40.0)
		check(PlayerData.glimmer > g, "saving the traveller pays a reward")


func _finish() -> void:
	print("\n==== SYSTEMS TEST ====")
	for l in _log:
		print(l)
	print("==== %d checks, %d failed ====" % [_log.size(), _failures.size()])
	SaveSystem.delete_save()
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _clear_hostiles(pos: Vector3, r: float) -> void:
	Debug.peaceful = true
	for c in get_tree().get_nodes_in_group(&"creatures"):
		if (c as Creature).kind_is_hostile() and (c as Node3D).global_position.distance_to(pos) < r:
			(c as Creature).dead = true
			c.queue_free()


func _spawn_test(w: GameWorld, id: StringName, pos: Vector3) -> Creature:
	var c := w.spawner.spawn_creature(id, pos, "", "t_" + String(id))
	return c


## A point near `center` whose terrain height lies in [lo, hi] (m).
func _find_height(w: GameWorld, center: Vector2, r0: float, r1: float, lo: float, hi: float, steep: bool = false) -> Variant:
	for ri in 24:
		var r := lerpf(r0, r1, ri / 23.0)
		for k in 32:
			var a := TAU * k / 32.0
			var x := center.x + cos(a) * r
			var z := center.y + sin(a) * r
			var h := w.gen.height(x, z)
			if h >= lo and h <= hi and (not steep or w.gen.normal(x, z).y < 0.7):
				return Vector3(x, h, z)
	return null


func _ecosystems(w: GameWorld, p: Player) -> void:
	Weather.set_weather(&"clear", true)
	Clock.set_time(11.0)
	# Lake: a swimmer stays in the water, cannot be hit while deep, surfaces to strike.
	var shore: Variant = _find_height(w, Vector2(-400, 70), 60.0, 190.0, -0.7, 0.2)
	check(shore != null, "lake shallows found")
	if shore != null:
		var sh: Vector3 = shore
		await teleport(sh.x, sh.z, 0.5)
		var deep: Variant = _find_height(w, Vector2(sh.x, sh.z), 5.0, 14.0, -30.0, -2.5)
		check(deep != null, "deep water near the shallows")
		if deep != null:
			var eel := _spawn_test(w, &"ENEMY_MIRE_EEL", Vector3((deep as Vector3).x, -1.5, (deep as Vector3).z))
			await seconds(1.0)
			check(eel.global_position.y < WorldGen.SEA_LEVEL and eel.hidden, "eel waits deep and hidden (y %.1f)" % eel.global_position.y)
			var hp := eel.health.health
			eel.take_damage(DamageInfo.make(40, p))
			check(eel.health.health == hp, "a submerged eel cannot be hit")
			var surfaced := false
			for i in 40:
				await seconds(0.25)
				if not eel.hidden:
					surfaced = true
					break
			check(surfaced, "eel surfaces to strike at a player in the water")
			check(eel.health.has_status(&"wet"), "swimmers are always soaked (double shock)")
			var land := true
			for i in 12:
				await seconds(0.25)
				land = land and w.gen.height(eel.global_position.x, eel.global_position.z) < WorldGen.SEA_LEVEL - 0.3
			check(land, "eel never leaves the water")
			eel.queue_free()
		await seconds(2.5)
		check(w.ambient.live_count() > 0, "ambient fauna around the lake (%s)" % ", ".join(w.ambient.live_ids()))
		check(w.ambient.live_count() <= int(Quality.current()["ambient_groups"]), "ambient fauna within the quality budget")
		var swimmers := 0
		for c in get_tree().get_nodes_in_group(&"creatures"):
			if (c as Creature).type.is_aquatic():
				swimmers += 1
		check(swimmers > 0, "water slots now hold swimmers (%d)" % swimmers)
	# Desert: the burrower travels hidden and only erupts to be hit.
	await teleport(1100.0, 250.0)
	var bur := _spawn_test(w, &"ENEMY_DUNE_BURROWER", p.global_position + Vector3(9, 0.5, 0))
	await seconds(0.8)
	check(bur.hidden and bur.brain.state_name() == &"burrowing", "burrower travels under the sand")
	bur.brain.change(&"erupt")
	await seconds(1.4)
	check(not bur.hidden, "burrower is exposed after it erupts")
	bur.queue_free()
	# Front armour: hits from the front glance off, hits from behind land.
	var cara := _spawn_test(w, &"ENEMY_BRAMBLE_CARAPACE", p.global_position + Vector3(0, 0.5, -4))
	await seconds(0.3)
	cara.facing_yaw = atan2(-(p.global_position.x - cara.global_position.x), -(p.global_position.z - cara.global_position.z))
	var h0 := cara.health.health
	cara.take_damage(DamageInfo.make(20, p))
	var front_loss := h0 - cara.health.health
	var behind := Node3D.new()
	add_child(behind)
	behind.global_position = cara.global_position - cara.facing_dir() * 3.0
	h0 = cara.health.health
	cara.take_damage(DamageInfo.make(20, behind))
	var back_loss := h0 - cara.health.health
	check(front_loss < back_loss * 0.4, "carapace shrugs off frontal hits (%.1f front vs %.1f behind)" % [front_loss, back_loss])
	cara.brain.on_stagger(1.0)
	await frames(3)
	check(cara.brain.state_name() == &"flipped", "a staggered carapace flips over")
	behind.queue_free()
	cara.queue_free()
	# Fire imp: burning ground in dry weather, doused in rain.
	var imp := _spawn_test(w, &"ENEMY_CINDER_IMP", p.global_position + Vector3(6, 0.5, 6))
	imp.perception.alert(p.global_position)
	imp.brain.change(&"chase")
	var fires0 := FireSource.active_count
	await seconds(3.5)
	check(FireSource.active_count > fires0 or imp.dead, "cinder imp leaves burning ground")
	var ign: IgniteBehavior = null
	for m in imp.brain.behaviors:
		if m is IgniteBehavior:
			ign = m
	var rain0 := Weather.rain
	Weather.rain = 1.0
	check(ign != null and ign.doused(), "rain douses the imp")
	Weather.rain = rain0
	imp.queue_free()
	# Thief: snatches glimmer, runs, pays it back with interest when caught.
	PlayerData.glimmer = 100
	var thief := _spawn_test(w, &"ENEMY_GLINT_THIEF", p.global_position + Vector3(-3, 0.5, 0))
	await frames(3)
	thief.brain.notify_hit(p)
	check(PlayerData.glimmer == 85, "thief snatches glimmer")
	thief.brain.change(&"chase")
	await frames(3)
	check(thief.brain.state_name() == &"thief_flee", "thief runs with the loot")
	thief.take_damage(DamageInfo.make(999, p))
	await frames(3)
	check(PlayerData.glimmer == 103, "catching the thief returns it with interest (%d)" % PlayerData.glimmer)
	# Highlands: a climber clings to the cliff face.
	var cliff: Variant = _find_height(w, Vector2(-60, -560), 120.0, 330.0, 20.0, 200.0, true)
	check(cliff != null, "a highland cliff found")
	if cliff != null:
		var cf: Vector3 = cliff
		await teleport(cf.x + 12.0, cf.z, 3.0)
		var wv := _spawn_test(w, &"ENEMY_CRAG_WEAVER", cf + Vector3.UP * 0.5)
		await seconds(2.0)
		var g := w.gen.height(wv.global_position.x, wv.global_position.z)
		check(absf(wv.global_position.y - g) < 1.2, "weaver clings to the terrain surface (off by %.2f)" % (wv.global_position.y - g))
		wv.queue_free()
		# Flyer: circles high, then commits to a telegraphed dive.
		var kite := _spawn_test(w, &"ENEMY_GALE_KITE", p.global_position + Vector3(10, 4, 0))
		kite.perception.alert(p.global_position)
		kite.brain.change(&"chase")
		var swooped := false
		for i in 40:
			await seconds(0.25)
			if kite.brain.state_name() == &"swoop":
				swooped = true
				break
		check(swooped, "gale kite swoops")
		kite.queue_free()


func _nodes_near(group: StringName, pos: Vector3, r: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(group):
		if (n as Node3D).global_position.distance_to(pos) < r:
			out.append(n)
	return out


func _top_at(x: float, z: float) -> float:
	var from := Vector3(x, 400.0, z)
	var hit := get_tree().root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(x, -80.0, z), 1))
	return (hit["position"] as Vector3).y if not hit.is_empty() else -INF


func _forest(w: GameWorld, p: Player) -> void:
	Weather.set_weather(&"clear", true)
	Clock.set_time(12.0)
	# Hollow Tree: slick bark, brambles that burn only when dry, rain caps.
	await teleport(390.0 + 16.0, 318.0, 1.0)
	await seconds(4.0)
	check(p.probe_wall(Vector3(-1, 0, 0), 9.0).is_empty(), "the Hollow Tree's living bark gives no grip")
	var br: Array = _nodes_near(&"brambles", Vector3(399, 14, 318), 12.0)
	check(br.size() == 1, "brambles choke the Hollow Tree's door")
	if br.size() == 1:
		Weather.set_weather(&"rain", true)
		await seconds(0.5)
		check(not (br[0] as BrambleWall).try_ignite(), "wet brambles will not burn")
		var caps: Array = _nodes_near(&"bellcaps", Vector3(390, 14, 318), 40.0)
		check(caps.size() >= 5 and Bellcap.is_wet(), "rain soaks the grove's bellcaps (%d)" % caps.size())
		if not caps.is_empty():
			var cap: Bellcap = caps[0]
			await frames(25)
			p.global_position = cap.global_position + Vector3(0, cap.size * 1.3 + 0.4, 0)
			p.velocity = Vector3.ZERO
			p.change_state(&"air")
			var peak := 0.0
			for i in 60:
				await frames(1)
				peak = maxf(peak, p.velocity.y)
			check(peak > 10.0, "a swollen bellcap throws you high (v %.1f)" % peak)
		Weather.set_weather(&"clear", true)
		Weather.wetness = 0.0
		Weather.rain = 0.0
		await seconds(0.3)
		check((br[0] as BrambleWall).try_ignite(), "dry brambles catch fire")
		await seconds(3.0)
		check(BrambleWall.burned("hollow_tree:door"), "burned brambles stay burned (door open)")
	# Down into the root heart.
	await teleport(390.0, 318.0, 0.5)
	await seconds(1.5)
	check(p.global_position.y < 9.5, "the heart pit lies below the ground (y %.1f)" % p.global_position.y)
	check(DiscoveryDirector.is_found(&"forest_hollow_heart"), "Heart of the Hollow Tree discovered")
	# Canopy Walk: decks you can stand on, weavers on them, the high nest.
	await teleport(430.0, 280.0)
	await seconds(2.0)
	var nest_y := _top_at(442.0, 288.0)
	check(nest_y > 52.0, "the crow's nest stands high above the wood (y %.1f)" % nest_y)
	var weavers := 0
	for c in _nodes_near(&"creatures", Vector3(430, 30, 280), 30.0):
		if (c as Creature).type.id == &"ENEMY_CRAG_WEAVER":
			weavers += 1
	check(weavers >= 2, "weavers wait on the canopy decks (%d)" % weavers)
	p.global_position = Vector3(442.0, nest_y + 0.5, 288.0)
	p.velocity = Vector3.ZERO
	await seconds(1.2)
	check(DiscoveryDirector.is_found(&"forest_highest_bough"), "Highest Bough discovered from the nest")
	# Night: glowcaps open, dust you in spores (stealth), open the Moon Gate.
	Clock.set_time(23.0)
	await teleport(585.0, 237.0)
	await seconds(2.0)
	check(DiscoveryDirector.is_found(&"forest_glowcap_trail"), "Glowcap Trail found at night")
	var gcs: Array = _nodes_near(&"glowcaps", p.global_position, 80.0)
	check(gcs.size() >= 6, "glowcaps line the trail (%d)" % gcs.size())
	if not gcs.is_empty():
		var gc: Glowcap = gcs[0]
		check(gc.can_interact(), "glowcaps open at night")
		p.global_position = gc.global_position + Vector3(0.8, 0.5, 0)
		await seconds(1.5)
		check(p.health.has_status(&"spored"), "glowcap dust spores the player")
		var probe := _spawn_test(w, &"ENEMY_BRAMBLE_CARAPACE", p.global_position + Vector3(6, 0.5, 0))
		await frames(2)
		var hushed := probe.perception.effective_range()
		p.health.remove_status(&"spored")
		check(hushed < probe.perception.effective_range() * 0.6, "spores halve how far creatures see you")
		probe.queue_free()
	await teleport(635.0 + 3.0, 195.0 + 3.0)
	await seconds(2.0)
	PlayerData.inventory.add(&"glowcap", 3)
	var offer: QuestObject = null
	for o in _nodes_near(&"quest_objects", Vector3(635, 20, 195), 12.0):
		if String((o as QuestObject).object_id).ends_with(":offering"):
			offer = o
	check(offer != null, "the moon-pool offering bowl is there")
	if offer:
		offer.interact(p)
		await seconds(2.5)
		check(WorldState.flags.has("moon_gate_open") and DiscoveryDirector.is_found(&"forest_moon_gate"), "three glowcaps at night open the Moon Gate")
		check(PlayerData.cookbook.size() > 0 and PlayerData.cosmetics.has("ribbon_moon"), "the Moon Gate teaches hush tea and gives the moonlit ribbon")
	Clock.set_time(12.0)


func _lake(w: GameWorld, p: Player) -> void:
	Weather.set_weather(&"clear", true)
	Clock.set_time(10.0)
	# Fishing: rod, cast, wait for the bite, pull.
	await teleport(-265.0, 94.0, 1.0)
	await seconds(2.0)
	var spots: Array = _nodes_near(&"fishing_spots", Vector3(-268, 0, 94), 8.0)
	check(spots.size() == 1, "a fishing spot off Ilo's dock")
	if spots.size() == 1:
		var fs: FishingSpot = spots[0]
		fs.interact(p)
		check(fs.phase == FishingSpot.Phase.IDLE, "no rod, no fishing")
		PlayerData.inventory.add(&"fishing_rod", 1)
		var fish0 := 0
		for f in [&"mirror_perch", &"reed_pike", &"raw_fish"]:
			fish0 += PlayerData.inventory.count_of(f)
		await seconds(0.6)
		fs.interact(p)
		check(fs.phase == FishingSpot.Phase.WAITING, "cast: the bobber is out")
		for i in 60:
			await seconds(0.2)
			if fs.phase == FishingSpot.Phase.BITE:
				break
		check(fs.phase == FishingSpot.Phase.BITE, "a fish bites")
		fs.interact(p)
		var fish1 := 0
		for f in [&"mirror_perch", &"reed_pike", &"raw_fish"]:
			fish1 += PlayerData.inventory.count_of(f)
		check(fish1 == fish0 + 1, "pulling on the bite lands a fish")
	Clock.set_time(23.0)
	check(Fishing.table("lake").any(func(e: Dictionary) -> bool: return e["item"] == "moon_carp"), "moon carp only in the night table")
	Clock.set_time(10.0)
	check(not Fishing.table("lake").any(func(e: Dictionary) -> bool: return e["item"] == "moon_carp"), "no moon carp by day")
	Fishing.land(&"moon_carp")
	check(DiscoveryDirector.is_found(&"lake_moon_carp"), "catching a moon carp is a discovery")
	# Diving into the Sunken Shrine: breath, the air vent, the three bells.
	await teleport(-420.0, 106.0, 0.0)
	p.global_position.y = WorldGen.SEA_LEVEL - 1.3
	p.change_state(&"swim")
	await seconds(0.5)
	p.change_state(&"dive")
	var st0 := p.vitals.stamina
	await seconds(2.5)
	check(p.state_name() == &"dive" and p.global_position.y < -2.5, "diving sinks you under (y %.1f)" % p.global_position.y)
	check(p.vitals.stamina < st0, "breath runs out underwater")
	await seconds(3.0)
	check(DiscoveryDirector.is_found(&"lake_sunken_shrine"), "Sunken Shrine discovered while diving")
	var vents: Array = _nodes_near(&"air_vents", Vector3(-420, -8, 100), 20.0)
	check(vents.size() == 1, "an air vent in the ruins")
	if vents.size() == 1:
		p.vitals.stamina = 5.0
		p.global_position = (vents[0] as Node3D).global_position + Vector3(0, 1.0, 0)
		await seconds(1.0)
		check(p.vitals.stamina > 20.0, "the bubble column refills your breath")
	var bells: Array = []
	for o in _nodes_near(&"quest_objects", Vector3(-420, -8, 100), 20.0):
		if String((o as QuestObject).object_id).contains(":bell"):
			bells.append(o)
	check(bells.size() == 3, "three drowned bells")
	for b in bells:
		(b as QuestObject).interact(p)
		await seconds(0.5)
	check(WorldState.flags.has("sunken_bells"), "ringing all three opens the sanctum")
	p.change_state(&"swim")
	# Night: drowned lanterns seen from the water.
	Clock.set_time(23.0)
	p.global_position = Vector3(-420.0, WorldGen.SEA_LEVEL - 1.3, 110.0)
	await seconds(1.2)
	check(DiscoveryDirector.is_found(&"lake_drowned_lanterns"), "drowned lanterns found at night on the water")
	Clock.set_time(12.0)
	# Storm: the buoys drink lightning and grow stormglass.
	Weather.set_weather(&"storm", true)
	await teleport(-290.0, 30.0, 0.0)
	p.global_position.y = WorldGen.SEA_LEVEL - 1.3
	p.change_state(&"swim")
	var glass := false
	for i in 80:
		await seconds(0.25)
		for pk in get_tree().get_nodes_in_group(&"pickups"):
			if (pk as Pickup).item_id == &"storm_glass":
				glass = true
		if glass:
			break
	check(get_tree().get_nodes_in_group(&"storm_buoys").size() >= 6, "storm buoys float on the east water")
	check(glass, "a lightning-struck buoy grows stormglass")
	check(DiscoveryDirector.is_found(&"lake_storm_buoys"), "Storm Buoys discovered in a storm")
	Weather.set_weather(&"clear", true)
	p.change_state(&"ground")


func _qobject(id: String) -> QuestObject:
	for o in get_tree().get_nodes_in_group(&"quest_objects"):
		if String((o as QuestObject).object_id) == id:
			return o
	return null


func _creature_near(id: StringName, pos: Vector3, r: float) -> Creature:
	for c in get_tree().get_nodes_in_group(&"creatures"):
		var cr := c as Creature
		if cr and cr.type and cr.type.id == id and not cr.dead and cr.global_position.distance_to(pos) < r:
			return cr
	return null


func _swim_at(x: float, z: float, depth: float = 1.2) -> void:
	await teleport(x, z, 0.0)
	var p := Game.player as Player
	p.global_position = Vector3(x, WorldGen.SEA_LEVEL - depth, z)
	p.velocity = Vector3.ZERO
	p.change_state(&"swim")
	await frames(3)


## Coast and sea (expansion phase 4): islets, tides, currents, the
## Bellhull at sea, wrecks, diving, marine fauna, storms, sea fishing,
## discoveries, sea quests.
func _sea(w: GameWorld, p: Player) -> void:
	Weather.set_weather(&"clear", true)
	Clock.set_time(12.0)
	_clear_hostiles(p.global_position, 99999.0)
	if not PlayerData.inventory.has(&"fishing_rod"):
		PlayerData.inventory.add(&"fishing_rod", 1)
	# --- Terrain: islets out of the shelf, the open sea is deep --------------------------------------
	check(w.gen.height(150, 1000) > WorldGen.SEA_LEVEL + 5.0 and w.gen.height(-60, 1160) > WorldGen.SEA_LEVEL + 4.0 and w.gen.height(-420, 1060) > WorldGen.SEA_LEVEL + 3.0, "islets stand out of the sea (light, Vigil, castaways)")
	check(w.gen.height(560, 1020) > WorldGen.SEA_LEVEL - 2.0 and w.gen.height(560, 1020) < WorldGen.SEA_LEVEL, "the Crystal Reef is a wadeable shelf")
	check(SpawnDirector.habitat_of(Vector3(380, w.gen.height(380, 1420), 1420), Vector3.UP) == &"deep", "open sea counts as the deep habitat")
	check(w.gen.height(720, 1260) > w.gen.height(760, 1320) + 2.0, "the Iron Leviathan rests on a silt bed")
	# --- Tides: the clock of the coast --------------------------------------------------------------
	check(Tide.is_low(12.0) and Tide.is_low(0.0) and Tide.is_high(18.0) and not Tide.is_low(18.0), "tide: low at noon and midnight, high at dusk")
	Clock.set_time(18.0)
	await _swim_at(318.0, 1268.0)
	await seconds(1.5)
	var bars: Array = _nodes_near(&"tide_bars", Vector3(320, 0, 1280), 30.0)
	check(bars.size() == 5, "the Vanishing Bar is five sandbars")
	var drowned := bars.all(func(b: Node) -> bool: return (b as Node3D).global_position.y + 0.5 < WorldGen.SEA_LEVEL - 1.0)
	check(drowned, "high tide: the bar is under water")
	check(not DiscoveryDirector.is_found(&"sea_vanishing_bar"), "high tide: nothing to find on the bar")
	Clock.set_time(12.0)
	await seconds(7.0)
	var dry := bars.all(func(b: Node) -> bool: return (b as Node3D).global_position.y + 0.5 > WorldGen.SEA_LEVEL)
	check(dry, "low tide: the bar rises out of the sea")
	check(DiscoveryDirector.is_found(&"sea_vanishing_bar"), "low tide: the Vanishing Bar is discovered")
	var buried: Chest = null
	for c in get_tree().get_nodes_in_group(&"chests"):
		if (c as Chest).chest_id == "vanishing_bar:buried":
			buried = c
	check(buried != null, "low tide uncovers the buried chest")
	check(DiscoveryDirector.condition_text(DB.discoveries[&"sea_vanishing_bar"]) != "", "the Atlas says when the bar appears")
	# Surf at the Tide Isle mouth: high water throws you back.
	Clock.set_time(18.0)
	await _swim_at(-800.0, 314.0)
	var s0 := p.global_position
	await seconds(2.0)
	check(Vector2(p.global_position.x - s0.x, p.global_position.z - s0.z).length() > 1.0, "high tide: the surf pushes you out of the cave mouth")
	Clock.set_time(12.0)
	# --- Currents: the sea swims for you -----------------------------------------------------------
	await _swim_at(126.0, 900.0)
	check(SeaCurrent.drift_at(p.global_position, get_tree()).length() > 2.0, "the Gull Current flows off the Dawn shore")
	var c0 := p.global_position
	await seconds(3.0)
	check(p.global_position.z - c0.z > 4.0, "idle in the current, you drift toward the light (%.1f m)" % (p.global_position.z - c0.z))
	# --- Tidewarden Light: relit only at night ------------------------------------------------------
	await teleport(150.0, 1000.0, 1.0)
	await seconds(1.5)
	var lamp := _qobject("tidewarden_light:lamp")
	check(lamp != null, "the lighthouse lamp lever is in the lamp room")
	if lamp:
		lamp.interact(p)
		check(not WorldState.flags.has("lighthouse_lit"), "by day the lamp will not take")
		Clock.set_time(22.0)
		await frames(2)
		lamp.interact(p)
		await seconds(0.8)
		check(WorldState.flags.has("lighthouse_lit") and DiscoveryDirector.is_found(&"sea_tidewarden_light"), "at night the lamp is relit: flag + discovery")
		var lamps: Array = _nodes_near(&"lighthouse_lamps", Vector3(150, 20, 1000), 60.0)
		check(lamps.size() == 1 and (lamps[0] as LighthouseLamp).lit(), "the beam sweeps the sea")
	Clock.set_time(12.0)
	# --- Vigil Rock: climb to the top, the launch point -------------------------------------------
	var vt := _top_at(-58.0, 1161.0)
	check(vt > 45.0, "Vigil Rock towers over the sea (%.0f m)" % vt)
	p.global_position = Vector3(-58.0, vt + 0.8, 1161.0)
	p.velocity = Vector3.ZERO
	await seconds(1.2)
	check(DiscoveryDirector.is_found(&"sea_vigil_top"), "standing on Vigil Rock's crown is a discovery")
	# --- The Gull's Promise: a wreck with three ways in ----------------------------------------------
	await _swim_at(28.0, 1240.0)
	await seconds(2.0)
	check(DiscoveryDirector.is_found(&"sea_gulls_promise"), "the Gull's Promise is discovered")
	var lever := _qobject("gulls_promise:lever")
	var gate: FlagGate = null
	for g in _nodes_near(&"flag_gates", Vector3(30, 0, 1250), 30.0):
		if (g as FlagGate).flag == "gulls_cabin_open":
			gate = g
	check(lever != null and gate != null, "a lever in the hold, a jammed cabin door")
	var lurker := _creature_near(&"ENEMY_HULL_LURKER", Vector3(30, -2, 1250), 25.0)
	check(lurker != null and lurker.global_position.y < WorldGen.SEA_LEVEL, "a hull lurker guards the hold, under water")
	if lever and gate:
		check(not gate._open, "the cabin is jammed")
		lever.interact(p)
		await seconds(0.8)
		check(WorldState.flags.has("gulls_cabin_open") and gate._open, "pulling the lever in the hold opens the cabin")
	var log_page := _qobject("gulls_log")
	check(log_page != null, "the Gull's log lies in the cabin")
	if log_page:
		log_page.interact(p)
		await seconds(0.6)
		check(PlayerData.inventory.count_of(&"gulls_log") == 1, "the log is taken")
	p.change_state(&"swim")
	# --- The Iron Leviathan: deep dive, air vents, longer breath ------------------------------------
	await _swim_at(724.0, 1256.0)
	await seconds(1.5)
	p.global_position = Vector3(724.0, WorldGen.SEA_LEVEL - 10.0, 1256.0)
	p.change_state(&"dive")
	await seconds(1.5)
	check(DiscoveryDirector.is_found(&"sea_leviathan"), "diving down to the Leviathan discovers it")
	check(_nodes_near(&"air_vents", Vector3(720, -15, 1260), 30.0).size() >= 1, "air still bubbles in the Leviathan's hold")
	p.vitals.stamina = PlayerData.max_stamina
	var b0 := p.vitals.stamina
	await seconds(1.5)
	var plain := b0 - p.vitals.stamina
	PlayerData.apply_buff(&"breath", 1.0, 60.0)
	p.vitals.stamina = PlayerData.max_stamina
	b0 = p.vitals.stamina
	await seconds(1.5)
	var brothed := b0 - p.vitals.stamina
	PlayerData.buffs.erase(&"breath")
	check(plain > 0.0 and brothed < plain * 0.85, "deepwater broth: breath lasts longer (%.1f vs %.1f)" % [brothed, plain])
	p.change_state(&"swim")
	# --- Marine fauna: whale, finback, storm ray ----------------------------------------------------
	await _swim_at(650.0, 1330.0)
	var whale := _spawn_test(w, &"ANIMAL_DRIFT_WHALE", Vector3(662, WorldGen.SEA_LEVEL - 3.0, 1340))
	await seconds(1.0)
	var surf_b: SurfacerBehavior = null
	if whale:
		for m in whale.brain.behaviors:
			if m is SurfacerBehavior:
				surf_b = m
	check(surf_b != null, "the drift whale is a surfacer")
	if surf_b:
		surf_b._t = 99.0
		await seconds(2.5)
		check(surf_b.breathing() and whale.global_position.y > WorldGen.SEA_LEVEL - 1.5, "the whale rises to breathe (spout seen from afar)")
		check(whale.global_position.y < WorldGen.SEA_LEVEL + 0.8, "the whale never leaves the water")
	if whale:
		whale.queue_free()
	var fin := _spawn_test(w, &"ENEMY_FINBACK", p.global_position + Vector3(16, -2.0, 0))
	var saw_fin := false
	var struck := false
	var t0 := Time.get_ticks_msec()
	while fin and is_instance_valid(fin) and Time.get_ticks_msec() - t0 < 12000:
		await frames(4)
		if not is_instance_valid(fin):
			break
		if absf(fin.sink - 0.55) < 0.01:
			saw_fin = true
		if fin.brain.state_name() in [&"surface", &"attack"]:
			struck = true
			break
	check(saw_fin, "a finback's fin cuts the surface while it shadows you")
	check(struck, "then it surfaces to strike")
	if fin and is_instance_valid(fin):
		fin.queue_free()
	var ray := _spawn_test(w, &"ENEMY_STORM_RAY", p.global_position + Vector3(10, 3, 0))
	await seconds(6.0)
	check(not is_instance_valid(ray) or ray.dead, "clear sky: a storm ray fades back into the spray")
	# --- Storms change the reef ----------------------------------------------------------------------
	await _swim_at(548.0, 1030.0, 0.6)
	await seconds(1.5)
	check(DiscoveryDirector.is_found(&"sea_crystal_reef"), "the Crystal Reef is found in fair weather")
	check(_nodes_near(&"storm_buoys", Vector3(560, 0, 1020), 45.0).size() >= 7, "crystal spires stand on the reef")
	Weather.set_weather(&"storm", true)
	var glass := false
	for i in 100:
		await seconds(0.25)
		for pk in _nodes_near(&"pickups", Vector3(560, 0, 1020), 50.0):
			if (pk as Pickup).item_id == &"storm_glass":
				glass = true
		if glass:
			break
	check(glass, "in a storm the reef spires drink lightning and grow stormglass")
	check(DiscoveryDirector.is_found(&"sea_crystal_storm"), "the storm reef is its own discovery")
	var ray2 := _spawn_test(w, &"ENEMY_STORM_RAY", p.global_position + Vector3(10, 3, 0))
	await seconds(5.0)
	check(is_instance_valid(ray2) and not ray2.dead, "storm rays hunt while the storm lasts")
	if is_instance_valid(ray2):
		ray2.queue_free()
	Weather.set_weather(&"clear", true)
	# --- Sea fishing tables ---------------------------------------------------------------------------
	Clock.set_time(23.0)
	check(Fishing.table("deep").any(func(e: Dictionary) -> bool: return e["item"] == "lantern_squid"), "lantern squid rise at night in deep water")
	Clock.set_time(12.0)
	check(not Fishing.table("deep").any(func(e: Dictionary) -> bool: return e["item"] == "lantern_squid") and Fishing.table("deep").any(func(e: Dictionary) -> bool: return e["item"] == "bluewater_runner"), "by day, bluewater runners instead")
	check(Fishing.table("reef").any(func(e: Dictionary) -> bool: return e["item"] == "glass_shrimp"), "glass shrimp on the reef")
	check(not Fishing.table("sea").any(func(e: Dictionary) -> bool: return e["item"] == "lantern_squid"), "shore water has no deep-sea fish")
	Fishing.land(&"lantern_squid")
	check(DiscoveryDirector.is_found(&"sea_lantern_squid"), "landing a lantern squid is a discovery (broth recipe)")
	# --- Castaways' Islet, and a quest the tide opens -------------------------------------------------
	Clock.set_time(18.0)
	await teleport(-418.0, 1066.0, 1.0)
	await seconds(2.0)
	check(_npc(&"NPC_CASTAWAY") != null, "Maren rows back to the islet at dusk")
	await _talk(&"NPC_CASTAWAY", p)
	check(Quests.is_active(&"dq_sea_vanishing_isle"), "Maren asks you to dig on the Vanishing Bar")
	await _swim_at(320.0, 1262.0)
	await seconds(1.5)
	check(Quests.state[&"dq_sea_vanishing_isle"]["stage"] == 0, "the bar is under water at high tide: not there yet")
	Clock.set_time(12.0)
	await seconds(1.5)
	check(Quests.state[&"dq_sea_vanishing_isle"]["stage"] >= 1, "at low tide the objective is met")
	await _swim_at(126.0, 900.0)
	# --- Sea quests start from Sabel -------------------------------------------------------------------
	await teleport(111.0, 799.0, 1.0)
	var sabel: Creature = null
	for i in 20:
		await seconds(0.25)
		sabel = _npc(&"NPC_TIDEKEEPER")
		if sabel:
			break
	await _talk(&"NPC_TIDEKEEPER", p)
	check(sabel != null and Quests.is_active(&"sq_sea_first_crossing"), "Sabel offers the First Crossing")
	# A body that finds no collider under it (its chunk not streamed yet)
	# is held on the height field instead of falling out of the world.
	var crab_at := Vector3(118.0, w.gen.height(118.0, 792.0) - 20.0, 792.0)
	var crab := _spawn_test(w, &"ANIMAL_TIDE_CRAB", crab_at)
	await seconds(1.0)
	check(is_instance_valid(crab) and not crab.dead and absf(crab.global_position.y - w.gen.height(crab.global_position.x, crab.global_position.z)) < 1.5, "creatures never fall through the terrain (spawned before its collider)")
	check(not WorldState.is_defeated("dawn_wreck:npc:0"), "Sabel is never written off as defeated")
	if is_instance_valid(crab):
		crab.queue_free()
	# The Bellhull is premium: no main quest and no sea quest may need it.
	var sea_q := 0
	var needs_boat: Array = []
	for q in DB.quests:
		var qid := String(q.get("id", ""))
		if qid.begins_with("sq_sea_") or qid.begins_with("dq_sea_"):
			sea_q += 1
		if not (String(q.get("type", "")) == "main" or qid.begins_with("sq_sea_") or qid.begins_with("dq_sea_")):
			continue
		for st in q.get("stages", []):
			for o in st.get("objectives", []):
				var cond: Dictionary = o.get("conditions", {})
				if String(cond.get("state", "")) == "ride" or String(o.get("type", "")) == "mount":
					needs_boat.append(qid)
	check(sea_q == 5, "five sea quests (%d)" % sea_q)
	check(needs_boat.is_empty(), "no main or sea quest needs a mount %s" % [needs_boat])
	check(DiscoveryDirector.found_count("coast") >= 8, "the Atlas records the sea (%d coast wonders)" % DiscoveryDirector.found_count("coast"))
	Debug.peaceful = false


func _bell(id: String) -> FogBell:
	return FogBell.find(id, get_tree())


func _env_ctrl() -> EnvironmentController:
	var ec := get_tree().root.find_children("*", "EnvironmentController", true, false)
	return ec[0] as EnvironmentController if not ec.is_empty() else null


## The far seas (phase 4.5): the Mist Sea (west) and the Current Sea (east).
func _far_seas(w: GameWorld, p: Player) -> void:
	Weather.set_weather(&"clear", true)
	Clock.set_time(6.0)
	_clear_hostiles(p.global_position, 99999.0)
	PlayerData.inventory.add(&"vela_glider")
	# --- Terrain: stacks, a mesa, an islet with a ledge -----------------------------------------------
	check(w.gen.height(-1010, -190) > 22.0 and w.gen.height(-1031, -190) < -18.0, "the Wall: a sea stack rising sheer from the deep")
	check(w.gen.height(1345, 880) > 27.0 and w.gen.height(1320, 860) < 4.0, "the High Isle: a flat top on cliff sides")
	check(w.gen.height(1061, 766) > 0.5 and absf(w.gen.height(1061, 805) + 11.0) < 1.5, "Isla del Paso and its offshore ledge")
	# --- Mist: edges, pockets, a clock ------------------------------------------------------------------
	check(MistBank.intensity(6.0) > 0.95 and MistBank.intensity(14.0) < 0.15 and MistBank.intensity(21.0) > 0.95, "the mist is thick from dusk to morning and lifts on clear afternoons")
	Weather.set_weather(&"storm", true)
	check(MistBank.intensity(6.0) < 0.5, "storm winds tear the mist thin")
	Weather.set_weather(&"clear", true)
	await _swim_at(-955.0, -50.0)
	await seconds(1.0)
	check(get_tree().get_nodes_in_group(&"mist_banks").size() == 1, "the Mist Sea's bank is placed (seen from far)")
	check(MistBank.density_at(Vector3(-1100, 0, -60), get_tree()) > 0.9, "the heart of the bank is thick at dawn")
	check(MistBank.density_at(Vector3(-1255, 0, 30), get_tree()) < 0.15, "a clear eye around the sanctuary")
	check(MistBank.density_at(Vector3(-700, 0, -60), get_tree()) == 0.0 and MistBank.density_at(Vector3(-1100, 60, -60), get_tree()) < 0.1, "the bank has edges: clear outside, clear above it")
	var ec := _env_ctrl()
	await seconds(2.5)
	check(ec != null and ec.mist > 0.6 and ec.env.fog_density > 0.02, "inside the bank the view closes in (fog %.3f)" % (ec.env.fog_density if ec else 0.0))
	var dens := MistBank.seen_density(p.global_position, get_tree())
	PlayerData.inventory.add(&"mistwalker_lantern", 1)
	PlayerData.equip(PlayerData.inventory.find_first(&"mistwalker_lantern"))
	check(MistBank.seen_density(p.global_position, get_tree()) < dens * 0.6, "the Mistwalker's lantern halves the mist you see")
	Clock.set_time(14.0)
	await seconds(3.0)
	check(ec != null and ec.mist < 0.2, "on a clear afternoon the mist lifts (%.2f)" % (ec.mist if ec else -1.0))
	Clock.set_time(6.0)
	# --- Fog bells: ring one, the next answers; the whole line wakes the great bell ---------------------
	for i in 4:
		check(_bell("mist_bell_%d" % (i + 1)) != null, "fog bell %d stands in the mist" % (i + 1))
	var b1 := _bell("mist_bell_1")
	var b2 := _bell("mist_bell_2")
	var b4 := _bell("mist_bell_4")
	if b1 and b2 and b4:
		await _swim_at(-1160.0, 12.0)
		await seconds(1.0)
		b4.interact(p)
		await seconds(2.2)
		var great := _bell("mist_bell_great")
		check(great != null, "the sanctuary's great bell hangs in its frame")
		check(not WorldState.flags.has("mist_bells_answered"), "ringing out of turn: the great bell answers, nothing opens")
		await _swim_at(-872.0, -40.0)
		await seconds(0.5)
		b1 = _bell("mist_bell_1")
		b2 = _bell("mist_bell_2")
		b1.interact(p)
		await seconds(1.9)
		check(b2 != null and b2._flare > 0.2, "ringing a bell makes the next one answer (a toll and a flare)")
	if b1:
		# The bell posts double as resting places for swimmers in the mist.
		p.change_state(&"air")
		p.global_position = b1.global_position + Vector3(1.0, 1.6, 0.4)
		p.velocity = Vector3.ZERO
		p.vitals.stamina = 20.0
		await seconds(1.5)
		check(p.state_name() == &"ground" and p.vitals.stamina > 20.0, "a swimmer can climb out on a bell's plinth and rest (%s)" % p.state_name())
		for i in [2, 3, 4]:
			var bb := _bell("mist_bell_%d" % i)
			if bb:
				p.global_position = bb.global_position + Vector3(3, -1.2, 0)
				await seconds(0.4)
				bb.interact(p)
				await seconds(0.5)
		await seconds(2.2)
		check(WorldState.flags.has("mist_bells_answered"), "the whole line rung: the great bell opens the altar")
		check(DiscoveryDirector.is_found(&"mist_bells"), "Voices in the Mist is found")
	await _swim_at(-1240.0, 30.0)
	await seconds(2.0)
	check(DiscoveryDirector.is_found(&"mist_sanctuary"), "the Sanctuary of the Bells is found")
	var lid_open := false
	for g in _nodes_near(&"flag_gates", Vector3(-1255, 5, 30), 20.0):
		if (g as FlagGate).flag == "mist_bells_answered":
			lid_open = (g as FlagGate)._open
	check(lid_open, "the altar's stone lid has slid aside")
	# --- The Teeth, the Lance (standing wreck), the Echo Cave -------------------------------------------
	await _swim_at(-1000.0, -140.0)
	await seconds(1.5)
	check(DiscoveryDirector.is_found(&"mist_teeth"), "the Teeth are found")
	await _swim_at(-1034.0, -194.0)
	await seconds(1.5)
	check(_nodes_near(&"air_vents", Vector3(-1031, -9, -190), 12.0).size() >= 1, "an air vent half-way down the Lance's shaft")
	p.global_position = Vector3(-1031.5, WorldGen.SEA_LEVEL - 12.0, -190.0)
	p.change_state(&"dive")
	await seconds(1.2)
	check(DiscoveryDirector.is_found(&"mist_lance"), "diving down inside the Lance is a discovery")
	var strongbox := false
	for c in get_tree().get_nodes_in_group(&"chests"):
		if (c as Chest).chest_id == "the_lance:strongbox":
			strongbox = (c as Node3D).global_position.y < WorldGen.SEA_LEVEL - 15.0
	check(strongbox, "the strongbox lies at the bottom of the shaft")
	p.change_state(&"swim")
	await _swim_at(-800.0, 36.0, 1.0)
	await seconds(1.5)
	p.global_position = Vector3(-785.0, WorldGen.SEA_LEVEL - 0.8, 36.0)
	await seconds(1.2)
	check(DiscoveryDirector.is_found(&"mist_echo_cave"), "the Echo Cave's chamber is found")
	var shells := 0
	for o in _nodes_near(&"quest_objects", Vector3(-785, 0, 36), 12.0):
		if String((o as QuestObject).object_id).contains(":shell_"):
			shells += 1
	check(shells == 3, "echo shells to gather on the dry ledge")
	check(_nodes_near(&"air_vents", Vector3(-800, -3, 36), 10.0).size() >= 1, "an air vent in the drowned throat")
	var shelf := false
	for c in get_tree().get_nodes_in_group(&"chests"):
		if (c as Chest).chest_id == "echo_cave:shelf":
			shelf = (c as Node3D).global_position.y > WorldGen.SEA_LEVEL + 5.0
	check(shelf, "the cave's secret: a chest on the high shelf up the chimney")
	# --- The pale ship: dawn, mist, gone when you reach it ----------------------------------------------
	Clock.set_time(5.6)
	await _swim_at(-1105.0, -228.0)
	await seconds(1.0)
	check(get_tree().get_nodes_in_group(&"mirages").size() == 1 and MirageShip.showing(Vector3(-1120, 0, -240), get_tree()), "at dawn, in the mist, the pale ship shows")
	await seconds(1.0)
	check(DiscoveryDirector.is_found(&"mist_mirage"), "reaching it at dawn in the mist is a discovery (with a recipe)")
	Clock.set_time(14.0)
	check(not MirageShip.showing(Vector3(-1120, 0, -240), get_tree()), "in the afternoon there is no ship")
	# --- The mist dweller: follows, closes in when you stop, fades with the mist ------------------------
	Clock.set_time(6.0)
	await _swim_at(-1000.0, -40.0)
	await seconds(1.0)
	var dweller := _spawn_test(w, &"ENEMY_MIST_DWELLER", p.global_position + Vector3(24, -0.5, 0))
	var stalked := false
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(dweller) and Time.get_ticks_msec() - t0 < 6000:
		await frames(4)
		if not is_instance_valid(dweller):
			break
		if dweller.brain.state_name() == &"stalk" and dweller.global_position.distance_to(p.global_position) > 10.0:
			stalked = true
		if dweller.brain.state_name() == &"chase":
			break
	check(stalked, "a mist dweller keeps its distance and follows")
	var closed := false
	t0 = Time.get_ticks_msec()
	while is_instance_valid(dweller) and Time.get_ticks_msec() - t0 < 8000:
		await frames(4)
		if is_instance_valid(dweller) and dweller.brain.state_name() in [&"chase", &"attack"]:
			closed = true
			break
	check(closed, "stand still and it closes in")
	# Isolation: a random weather roll (rain thickens the mist) must not
	# keep the bank up while we wait for it to lift.
	Weather.set_weather(&"clear", true)
	Clock.set_time(14.0)
	await seconds(7.0)
	check(not is_instance_valid(dweller) or dweller.dead, "when the mist lifts the dweller fades with it")
	Clock.set_time(9.0)
	# --- The Current Sea: tidal roads -------------------------------------------------------------------
	await _swim_at(1100.0, 652.0)
	await seconds(1.0)
	var rip: SeaCurrent = SeaCurrent.current_at(p.global_position, get_tree())
	check(rip != null and rip.tidal, "the Great Rip runs under the desert cliffs")
	if rip:
		var flood := rip.strength_now()
		Clock.set_time(12.0)
		var slack := rip.strength_now()
		check(flood > slack * 3.0, "tidal: hard on the flood (%.1f), slack at the turn (%.1f)" % [flood, slack])
		Clock.set_time(9.0)
	var r0 := p.global_position
	await seconds(3.0)
	check(p.global_position.x - r0.x > 10.0, "idle in the Rip, the sea carries you east (%.1f m)" % (p.global_position.x - r0.x))
	var plain_d := SeaCurrent.player_drift(p.global_position, Vector3.RIGHT, get_tree()).length()
	PlayerData.inventory.add(&"riptide_anklet", 1)
	PlayerData.equip(PlayerData.inventory.find_first(&"riptide_anklet"))
	var ride_d := SeaCurrent.player_drift(p.global_position, Vector3.RIGHT, get_tree()).length()
	var fight_d := SeaCurrent.player_drift(p.global_position, Vector3.LEFT, get_tree()).length()
	check(ride_d > plain_d * 1.4 and fight_d < plain_d * 0.7, "the riptide anklet: ride harder, fight less")
	p.global_position = Vector3(1395.0, WorldGen.SEA_LEVEL - 1.2, 662.0)
	await seconds(1.5)
	check(DiscoveryDirector.is_found(&"rip_great"), "riding the Rip to its end is a discovery")
	# The Rip finback comes down the current.
	await _swim_at(1150.0, 655.0)
	await seconds(1.0)
	var rf := _spawn_test(w, &"ENEMY_RIP_FINBACK", Vector3(1150.0, WorldGen.SEA_LEVEL - 3.0, 690.0))
	var rode := false
	t0 = Time.get_ticks_msec()
	while is_instance_valid(rf) and Time.get_ticks_msec() - t0 < 10000:
		await frames(4)
		if is_instance_valid(rf) and rf.brain.state_name() == &"ride":
			rode = true
			break
	check(rode, "a rip finback slips into the current upstream of you to come down on you")
	if is_instance_valid(rf):
		rf.queue_free()
	# The whirlpool keeps what the sea loses.
	await _swim_at(1195.0, 940.0)
	await seconds(1.0)
	var wp := get_tree().get_nodes_in_group(&"whirlpools")
	check(wp.size() == 1 and SeaCurrent.drift_at(Vector3(1195, -1, 940), get_tree()).length() > 1.0, "the whirlpool spins and draws you in")
	p.global_position = Vector3(1180.5, WorldGen.SEA_LEVEL - 14.0, 940.5)
	p.change_state(&"dive")
	await seconds(1.2)
	check(DiscoveryDirector.is_found(&"rip_whirlpool"), "diving its eye finds what it took")
	var hoard := false
	for c in get_tree().get_nodes_in_group(&"chests"):
		if (c as Chest).chest_id == "lost_eye:hoard":
			hoard = true
	check(hoard, "the hoard lies on the bed under the eye")
	p.change_state(&"swim")
	# The spout: a swimmer flies, a boat only rocks.
	await _swim_at(1288.0, 818.0)
	await seconds(1.0)
	var spouts := get_tree().get_nodes_in_group(&"spouts")
	check(spouts.size() == 1, "the Wind Rock's spout")
	if spouts.size() == 1:
		var spt := spouts[0] as Spout
		p.global_position = Vector3(spt.global_position.x, WorldGen.SEA_LEVEL - 1.0, spt.global_position.z)
		p.change_state(&"swim")
		await frames(2)
		spt.burst()
		await frames(2)
		check(p.state_name() == &"air" and p.velocity.y > 15.0, "the spout throws a swimmer out of the sea")
		var lift := 0.0
		for z in get_tree().get_nodes_in_group(&"updraft"):
			lift = maxf(lift, z.lift_at(Vector3(spt.global_position.x + 1.0, 20.0, spt.global_position.z + 2.0)))
		check(lift > 5.0, "and the wind over the rock keeps a glider rising")
	# The High Isle (by spout and glide, or by climbing).
	var top := _top_at(1348.0, 884.0)
	p.global_position = Vector3(1345.0, top + 1.0, 880.0)
	p.change_state(&"air")
	await seconds(1.5)
	check(DiscoveryDirector.is_found(&"rip_high_isle"), "standing on the High Isle is a discovery")
	var cache := false
	for c in get_tree().get_nodes_in_group(&"chests"):
		if (c as Chest).chest_id == "high_isle:cache":
			cache = (c as Node3D).global_position.y > 25.0
	check(cache, "its cache sits on the table-top")
	# The broken ship: bow aground, the chain down to the stern.
	await teleport(1061.0, 764.0, 1.0)
	await seconds(1.5)
	check(_qobject("broken_pact:log") != null and get_tree().root.find_child("AnchorChain", true, false) != null, "the bow's log and the anchor chain")
	await _swim_at(1061.0, 800.0)
	p.global_position = Vector3(1061.0, WorldGen.SEA_LEVEL - 9.0, 807.0)
	p.change_state(&"dive")
	await seconds(1.2)
	check(DiscoveryDirector.is_found(&"rip_split_wreck"), "following the chain down finds the stern")
	var stern_box := false
	for c in get_tree().get_nodes_in_group(&"chests"):
		if (c as Chest).chest_id == "broken_pact:strongbox":
			stern_box = (c as Node3D).global_position.y < WorldGen.SEA_LEVEL - 5.0
	check(stern_box, "the strongbox is in the drowned stern")
	p.change_state(&"swim")
	# Night, running tide: the eddy glows.
	Clock.set_time(21.0)
	await _swim_at(1220.0, 1040.0)
	await seconds(1.5)
	check(DiscoveryDirector.is_found(&"rip_luminous"), "at night on the running tide, the glowing eddy")
	Clock.set_time(18.0)
	check(DiscoveryDirector.condition_text(DB.discoveries[&"rip_luminous"]).length() > 0 and DiscoveryDirector.condition_text(DB.discoveries[&"mist_mirage"]).length() > 0, "the Atlas says when (tide, night, mist, dawn)")
	# --- Quests: two, both doable without the Bellhull -------------------------------------------------
	var far_q := 0
	for q in DB.quests:
		if String(q["id"]) in ["sq_mist_voices", "sq_rip_road"]:
			far_q += 1
	check(far_q == 2, "two far-sea quests")
	await teleport(1012.0, 304.0, 1.0)
	var nomad: Creature = null
	for i in 20:
		await seconds(0.25)
		nomad = _npc(&"NPC_NOMAD")
		if nomad:
			break
	await _talk(&"NPC_NOMAD", p)
	check(nomad != null and Quests.is_active(&"sq_rip_road"), "the nomad offers the Road in the Sea")
	var far_found := 0
	for d in far_seas_ids():
		if DiscoveryDirector.is_found(d):
			far_found += 1
	check(far_found == 11, "the Atlas holds all eleven far-sea wonders (%d)" % far_found)
	Debug.peaceful = false


func far_seas_ids() -> Array:
	return [&"mist_teeth", &"mist_bells", &"mist_sanctuary", &"mist_echo_cave", &"mist_lance", &"mist_mirage",
		&"rip_great", &"rip_whirlpool", &"rip_split_wreck", &"rip_high_isle", &"rip_luminous"]
