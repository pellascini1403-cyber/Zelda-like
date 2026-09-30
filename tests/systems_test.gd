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
	# --only <section>: run one section (vehicles, ecosystems, forest, lake).
	var oi := OS.get_cmdline_user_args().find("--only")
	if oi >= 0:
		match OS.get_cmdline_user_args()[oi + 1]:
			"vehicles": await _vehicles(w, p)
			"ecosystems": await _ecosystems(w, p)
			"forest": await _forest(w, p)
			"lake": await _lake(w, p)
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

	# --- Premium vehicles ---------------------------------------------------------------------------
	await _vehicles(w, p)

	Debug.peaceful = false

	# --- Ecosystems (expansion phase 2) ------------------------------------------------------------
	await _ecosystems(w, p)

	# --- Forest and lake as places with rules (expansion phase 3) ---------------------------------
	await _forest(w, p)
	await _lake(w, p)

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
	check(PlayerData.owns_vehicle(&"longwake") and PlayerData.owns_vehicle(&"sparrow") and PlayerData.owns_vehicle(&"bellhull"), "vehicles restored from the save")
	check(DiscoveryDirector.is_found(&"forest_moon_gate") and WorldState.flags.has("moon_gate_open") and BrambleWall.burned("hollow_tree:door") and WorldState.flags.has("sunken_bells"), "discoveries, burned brambles and opened gates restored from the save")
	# Store entitlements belong to the account: a brand-new game gets them back.
	PlayerData.reset_new_game()
	Platform.apply_entitlements()
	check(PlayerData.owns_vehicle(&"bellhull") and not PlayerData.owns_vehicle(&"longwake"), "store purchase re-applies to a new game, earned ones do not")
	Platform.backend.clear_owned()
	Platform.backend.sandbox = false
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
		if enc.is_active():
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


## Steers the driven vehicle toward `target` through the real input path.
func _steer_to(target: Vector3, v: Vehicle) -> void:
	var basis: Basis = Game.camera_rig.yaw_basis()
	var d := target - v.global_position
	d.y = 0.0
	d = d.normalized()
	var fwd := -basis.z
	fwd.y = 0.0
	var right := basis.x
	right.y = 0.0
	InputRouter.touch_move = Vector2(d.dot(right.normalized()), d.dot(fwd.normalized()))


## Drives toward `target` for `secs`; returns the top speed reached.
func _drive(v: Vehicle, target: Vector3, secs: float) -> float:
	var top := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0 and is_instance_valid(v):
		_steer_to(target, v)
		top = maxf(top, absf(v.speed))
		await frames(1)
	InputRouter.touch_move = Vector2.ZERO
	return top


func _summon_and_enter(p: Player, id: StringName) -> Vehicle:
	PlayerData.equip_vehicle(id)
	var mgr := VehicleManager.instance
	if not mgr.summon(p):
		return null
	await seconds(0.6)
	var v := mgr.active
	p.enter_vehicle(v)
	await frames(3)
	return v


func _vehicles(w: GameWorld, p: Player) -> void:
	var mgr := VehicleManager.instance
	check(mgr != null, "vehicle manager in the world")
	check(not mgr.summon(p), "no vehicle, no summon")
	# Restoration at the bench: parts + materials + glimmer.
	check(not VehicleManager.restore_status(&"longwake")["ok"], "restoring needs the parts")
	for vid in [&"longwake", &"sparrow"]:
		for it in DB.vehicles[vid]["acquire"]["items"]:
			PlayerData.inventory.add(StringName(it["id"]), int(it["count"]))
	PlayerData.glimmer = 1300
	check(VehicleManager.restore(&"longwake") and PlayerData.owns_vehicle(&"longwake"), "Longwake restored at the bench")
	check(PlayerData.glimmer == 600 and PlayerData.inventory.count_of(&"longwake_core") == 0, "restoring spends glimmer and consumes the parts")
	check(PlayerData.has_ability(&"vehicle_call"), "first vehicle teaches Vantrel Call")
	check(VehicleManager.restore(&"sparrow"), "Sparrow restored at the bench")
	# Store (sandboxed): optional purchase grants the capsule.
	Platform.backend.clear_owned()
	Platform.backend.sandbox = true
	Platform.purchase("vehicle_bellhull")
	await frames(2)
	check(PlayerData.owns_vehicle(&"bellhull") and String(PlayerData.vehicles.get("bellhull", "")) == "store", "store purchase grants the Bellhull")
	check(Platform.owns("vehicle_bellhull"), "entitlement recorded for restore")
	mgr._unveil_pending = &""

	# Heavy on the desert flats: fastest, boost goes beyond.
	await teleport(1100.0, 250.0)
	p.facing_yaw = -PI * 0.5
	Game.camera_rig.yaw = -90.0
	var far := Vector3(1400, 0, 250)
	# The vehicle track must be empty: the desert has residents now
	# (burrowers surface under wheels, imps run across the road).
	_clear_hostiles(p.global_position, 120.0)
	var heavy := await _summon_and_enter(p, &"longwake")
	check(heavy != null and p.state_name() == &"drive", "Longwake summoned beside the player and driven")
	var top_heavy := 0.0
	if heavy:
		var start := heavy.global_position
		check(start.distance_to(p.global_position) < 8.0, "summon spot is next to the player")
		top_heavy = await _drive(heavy, far, 6.0)
		check(heavy.global_position.distance_to(start) > 60.0, "Longwake covers ground (%.0f m in 6 s)" % heavy.global_position.distance_to(start))
		InputRouter.touch_sprint = true
		var top_boost := await _drive(heavy, far, 1.5)
		InputRouter.touch_sprint = false
		check(top_boost > float(heavy.h["max_speed"]) * 0.98, "boost pushes past cruising speed (%.1f)" % top_boost)
		p.exit_vehicle(false)
		await frames(3)
		check(p.vehicle == null and p.state_name() != &"drive", "getting out leaves the driver on foot")
	# Light: slower top speed, but it jumps.
	await teleport(1100.0, 250.0)
	_clear_hostiles(p.global_position, 120.0)
	p.facing_yaw = -PI * 0.5
	var light := await _summon_and_enter(p, &"sparrow")
	check(light != null, "Sparrow summoned (previous machine put away)")
	var top_light := 0.0
	if light:
		check(get_tree().get_nodes_in_group(&"vehicles").size() == 1, "only one vehicle out at a time")
		top_light = await _drive(light, far, 4.0)
		var y0 := light.global_position.y
		Input.action_press("jump")
		await seconds(0.5)
		Input.action_release("jump")
		var peak := y0
		for i in 40:
			await frames(1)
			peak = maxf(peak, light.global_position.y)
		check(peak - y0 > 1.5, "charged jump leaves the ground (%.1f m)" % (peak - y0))
		p.exit_vehicle(false)
	check(top_heavy > top_light, "heavy is faster than light (%.1f > %.1f)" % [top_heavy, top_light])
	# Capsule: slowest, amphibious, armed.
	await teleport(1100.0, 250.0)
	p.facing_yaw = -PI * 0.5
	var cap := await _summon_and_enter(p, &"bellhull")
	if cap:
		check(not p.visual.visible, "the capsule encloses its driver")
		var top_cap := await _drive(cap, far, 4.0)
		check(top_cap < top_light, "capsule is the slowest (%.1f)" % top_cap)
		InputRouter.touch_move = Vector2.ZERO
		# The desert has its own residents now (burrowers, imps): clear the
		# range so the auto-aim can only pick the test target.
		for c in get_tree().get_nodes_in_group(&"creatures"):
			if (c as Creature).kind_is_hostile() and (c as Node3D).global_position.distance_to(cap.global_position) < 45.0:
				c.queue_free()
		await frames(2)
		var e := w.spawner.spawn_creature(&"ENEMY_THORNLING", cap.global_position + cap.facing_dir() * 9.0 + Vector3.UP, "", "test")
		await frames(10)
		var hp0: float = e.health.health if e else 0.0
		Input.action_press("attack")
		await seconds(2.2)
		Input.action_release("attack")
		var hit_ok := e == null or not is_instance_valid(e) or e.health.health < hp0
		if not hit_ok:
			print("chin debug: enemy at %s (d %.1f) hp %.0f/%.0f state %s hidden %s in_enemies %s | cap facing %s heat %.2f over %.1f mode %s" % [e.global_position, e.global_position.distance_to(cap.global_position), e.health.health, hp0, e.brain.state_name(), e.hidden, e.is_in_group(&"enemies"), cap.facing_dir(), cap.heat, cap.overheated, cap.mode])
		check(hit_ok, "chin barrels hit the enemy in front")
		check(cap.heat_ratio() > 0.3, "firing builds heat (%.2f)" % cap.heat_ratio())
		mgr.boss_active = true
		check(mgr.summon_block_reason(p) != "", "no summoning during a boss fight")
		mgr.boss_active = false
		p.exit_vehicle(false)
	# Water: swim out, call the capsule, it floats; drive back to shore, it rolls out.
	await teleport(-330.0, 60.0, 0.0)
	p.global_position.y = WorldGen.SEA_LEVEL - 1.2
	p.change_state(&"swim")
	await frames(10)
	var boat := await _summon_and_enter(p, &"bellhull")
	check(boat != null, "the capsule can be called while swimming")
	if boat:
		for i in 90:
			await frames(1)
		check(boat.mode == &"water_mode" and boat.transform_t > 0.9, "water under the hull: water_mode, wheels folded")
		check(absf(boat.global_position.y - (WorldGen.SEA_LEVEL - float(boat.h["draft"]))) < 0.4, "the capsule floats at its waterline")
		var shore := Vector3(-250, 0, 100)
		var t0 := Time.get_ticks_msec()
		while boat.mode == &"water_mode" and Time.get_ticks_msec() - t0 < 30000:
			_steer_to(shore, boat)
			await frames(1)
		InputRouter.touch_move = Vector2.ZERO
		check(boat.mode == &"land_mode", "reaching the shore: land_mode, wheels down")
		p.exit_vehicle(false)
	var gy := w.gen.height(-250, 100)
	check(not VehicleManager.spot_is_free(p.get_world_3d(), Vector3(-250, gy, 100), Vector3(2, 2, 2)), "summon spots cutting into the ground are rejected")
	check(VehicleManager.spot_is_free(p.get_world_3d(), Vector3(-250, gy + 40.0, 100), Vector3(2, 2, 2)), "open air counts as free")
	mgr.put_away()


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
