extends Node
## Renders a set of reference screenshots for visual QA (needs a GPU or a
## software renderer, not --headless).
## Run: godot -- --tour <absolute output dir>

const SHOTS := [
	# [name, player x, z, camera yaw, pitch, hour, weather, extra]
	["01_village_morning", 62.0, 170.0, 10.0, -8.0, 8.5, "clear", ""],
	["02_mountain_view", 40.0, 60.0, 14.0, 4.0, 16.5, "clear", ""],
	["03_spires", 330.0, -150.0, 40.0, -2.0, 11.0, "cloudy", ""],
	["04_forest_rain", 470.0, 230.0, -30.0, -6.0, 14.0, "rain", ""],
	["05_lake_dusk", -250.0, 70.0, 95.0, -6.0, 18.8, "clear", ""],
	["06_night_camp", 285.0, -10.0, 60.0, -10.0, 23.0, "clear", ""],
	["07_glide", 0.0, -250.0, 170.0, -18.0, 12.0, "windy", "glide"],
	["08_maze", 205.0, 435.0, -60.0, -25.0, 10.0, "clear", ""],
	["08b_temple", 6.0, -266.0, -6.0, 10.0, 16.8, "clear", ""],
	["08c_bridge", -282.0, 445.0, 66.0, -4.0, 8.8, "clear", ""],
	["08d_temple_night", 6.0, -266.0, -6.0, 10.0, 22.5, "clear", ""],
	["08e_natural_falls", -40.0, -205.0, 8.0, 9.0, 15.8, "clear", ""],
	["08f_desert_oasis", 985.0, 330.0, -40.0, -6.0, 10.5, "clear", ""],
	["08g_sandstorm", 1180.0, 220.0, 60.0, -2.0, 13.0, "sandstorm", ""],
	["08h_veil_night", 872.0, -890.0, 36.0, 6.0, 21.5, "clear", ""],
	["08i_boss", 0.0, -285.0, 0.0, -9.0, 16.0, "clear", "boss"],
	["09_combat", 62.0, 180.0, 20.0, -12.0, 12.5, "clear", "combat"],
	["10_ui_touch", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "touch"],
	["11_inventory", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "inventory"],
	["12_map", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "map"],
	["12b_journal", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "journal"],
	["12c_title_card", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "title"],
	["13_cooking", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "cook"],
	["14_settings", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "settings"],
	# Quest layer (content-first pass)
	["15_quest_help_call", 154.0, 94.0, -47.0, -12.0, 10.5, "clear", "protect"],
	["15b_quest_protect_fight", 163.0, 87.0, -47.0, -14.0, 10.5, "clear", "protect"],
	["16_quest_nest_fire", 182.0, 74.0, -41.0, -16.0, 15.0, "clear", "nest"],
	["17_beacon_pillar", -40.0, -150.0, -14.0, 12.0, 19.2, "clear", "beacon"],
	["18_hunters_lodge", 360.0, 172.0, -40.0, -8.0, 9.5, "clear", ""],
	["19_glow_grotto_night", 614.0, 320.0, 126.0, -4.0, 22.5, "clear", "grotto"],
	["20_smoke_on_horizon", 30.0, 250.0, 132.0, 2.0, 14.0, "clear", "smoke"],
	["21_ring_course", 62.0, 178.0, -133.0, -6.0, 11.0, "clear", "course"],
	["22_captive_fang_camp", 282.0, -37.0, -128.0, -12.0, 12.0, "clear", "captive"],
	["23_bounty_board", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "board"],
	["24_warden_altar", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "altar"],
	["25_journal_v2", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "journal2"],
	["26_reward_popup", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "reward"],
	# Character art direction lineups, seen through the gameplay camera.
	["27_lineup_people_a", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:people_a"],
	["27b_lineup_people_b", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:people_b"],
	["28_lineup_enemies", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:enemies"],
	["29_lineup_minibosses", 154.0, 94.0, -47.0, -8.0, 16.5, "clear", "lineup:minibosses"],
	["30_lineup_bosses", 154.0, 94.0, -47.0, -2.0, 16.5, "clear", "lineup:bosses"],
	["31_lineup_species", 154.0, 94.0, -47.0, -10.0, 19.5, "clear", "lineup:species"],
	["32_lineup_enemies_night", 154.0, 94.0, -47.0, -10.0, 22.5, "clear", "lineup:enemies"],
	["34_lineup_enemies_close", 154.0, 94.0, -47.0, -14.0, 10.5, "clear", "lineup:enemies_close"],
	["35_lineup_warden", 154.0, 94.0, -47.0, 4.0, 17.5, "clear", "lineup:warden"],
	["36_vehicles_lineup", 154.0, 94.0, -47.0, -10.0, 10.0, "clear", "vehicles:lineup"],
	["36b_vehicles_close", 154.0, 94.0, -47.0, -14.0, 16.5, "clear", "vehicles:close"],
	["37_vehicle_heavy_drive", 1100.0, 250.0, -90.0, -10.0, 10.5, "clear", "vehicles:drive_longwake"],
	["37b_vehicle_light_jump", 1100.0, 250.0, -90.0, -8.0, 10.5, "clear", "vehicles:jump_sparrow"],
	["38_vehicle_capsule_water", -330.0, 60.0, 45.0, -10.0, 11.0, "clear", "vehicles:water"],
	["39_garage", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "vehicles:garage"],
	["40_vantrel_depot", 1052.0, 448.0, -146.0, -4.0, 16.0, "clear", "vehicles:none"],
	["41_vehicles_night", 1100.0, 250.0, -90.0, -10.0, 22.5, "clear", "vehicles:drive_longwake"],
	["33_lineup_wildlife", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:wildlife"],
	# Ecosystems expansion
	["42_eco_families_a", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:eco_a"],
	["42b_eco_families_b", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:eco_b"],
	["43_eco_variants", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:eco_variants"],
	["44_eco_wildlife", 154.0, 94.0, -47.0, -10.0, 10.5, "clear", "lineup:wildlife2"],
	["45_eco_fireflies", 470.0, 230.0, -30.0, -2.0, 22.5, "clear", "eco:none"],
	["46_eco_eel_surfacing", -262.0, 70.0, 95.0, -14.0, 11.0, "clear", "eco:eel"],
	["47_eco_kite_swoop", 40.0, 60.0, 14.0, 4.0, 12.0, "clear", "eco:kite"],
	["48_eco_burning_imp", 700.0, -100.0, 30.0, -10.0, 13.0, "clear", "eco:imp"],
]

const LINEUPS := {
	"people_a": [["PLAYER", "NPC_MERCHANT", "NPC_SMITH", "NPC_CHILD", "NPC_KEEPER", "NPC_GUARD", "NPC_FISHER", "NPC_SCHOLAR", "NPC_HUNTER", "NPC_CARAVAN"], 7.0],
	"people_b": [["NPC_CARTOGRAPHER", "NPC_VILLAGER", "NPC_NOMAD", "NPC_COURIER", "NPC_CLIMBER", "NPC_HERMIT", "NPC_PILGRIM", "NPC_TRAVELER", "NPC_MENTOR"], 7.0],
	"enemies": [["ENEMY_THORNLING", "ENEMY_SCUTTLER", "ENEMY_SPITTER", "ENEMY_WISP", "ENEMY_SHADE", "ENEMY_BULWARK"], 8.0],
	"enemies_close": [["ENEMY_THORNLING", "ENEMY_SCUTTLER", "ENEMY_SPITTER", "ENEMY_SHADE"], 4.5],
	"warden": [["BOSS_STILLWAKE_WARDEN"], 12.0],
	"minibosses": [["BOSS_THORN_CHIEF", "BOSS_GLASS_STALKER", "BOSS_HOLLOW_SHADE", "BOSS_STONEWARD", "BOSS_CRAG_HARRIER"], 11.0],
	"bosses": [["BOSS_THORNBACK", "BOSS_GLASS_MATRIARCH", "BOSS_STILLWAKE_WARDEN"], 22.0],
	"species": [["spider", "dragon", "serpent", "goblin", "ENEMY_THORNLING"], 8.0],
	"eco_a": [["ENEMY_GALE_KITE", "ENEMY_MIRE_EEL", "ENEMY_CRAG_WEAVER", "ENEMY_BRAMBLE_CARAPACE", "ENEMY_CINDER_IMP"], 8.0],
	"eco_b": [["ENEMY_DUNE_BURROWER", "ENEMY_HUSH_DRIFTER", "ENEMY_GLINT_THIEF", "ENEMY_DUSKWING", "ENEMY_SHELLBACK"], 8.0],
	"eco_variants": [["ENEMY_RIME_THORNLING", "ENEMY_STORM_BULWARK", "ENEMY_TIDE_SPITTER", "ENEMY_CAVE_WEAVER", "ENEMY_VEIL_WEAVER"], 8.0],
	"wildlife2": [["ANIMAL_CRAG_GOAT", "ANIMAL_REED_HERON", "ANIMAL_TIDE_CRAB", "ANIMAL_DUNE_FOX", "ANIMAL_LUMEN_STAG"], 8.0],
	"wildlife": [["ANIMAL_WOOLHORN", "ANIMAL_BURROWHOP", "ANIMAL_GILDED_HOP", "MOUNT_WINDSTRIDER", "ENEMY_THORNLING"], 8.0],
}

var _out := ""
var _quality := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var i := args.find("--tour")
	_out = args[i + 1] if i >= 0 and args.size() > i + 1 else "user://tour"
	var q := args.find("--quality")
	_quality = args[q + 1].to_int() if q >= 0 else 2
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveSystem.delete_save()
	Settings.set_value("quality", _quality, false)
	Quality.set_level(_quality, false)
	get_tree().change_scene_to_file(Game.MENU_SCENE)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("00_title.png"))
	Game.start_game(false)
	while not Game.is_playing():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	get_tree().root.find_child("DialogueBox", true, false)
	var hud := (Game.world as GameWorld).hud
	hud.dialogue.visible = false
	Clock.paused = true
	var only := ""
	var oi := OS.get_cmdline_user_args().find("--only")
	if oi >= 0:
		only = OS.get_cmdline_user_args()[oi + 1]
	for shot in SHOTS:
		if only != "" and not String(shot[0]) in only.split(","):
			continue
		await _shot(shot)
	print("tour done: ", _out)
	get_tree().quit()


func _shot(s: Array) -> void:
	var w := Game.world as GameWorld
	var p := Game.player as Player
	Debug.god_mode = true
	Debug.force_touch_ui = s[7] == "touch"
	w.hud.visible = s[7] in ["touch", "combat", "boss", "title", "protect", "nest", "course", "captive", "reward"]
	var pos := Vector3(s[1], 0, s[2])
	pos.y = w.gen.height(pos.x, pos.z) + 1.0
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.facing_yaw = deg_to_rad(s[3])
	Clock.set_time(s[5])
	Weather.set_weather(StringName(s[6]), true)
	var rig := Game.camera_rig as CameraRig
	rig.yaw = s[3]
	rig.pitch = s[4]
	# Let streaming catch up around the new position.
	for i in 90:
		await get_tree().process_frame
		if w.streamer.pending_jobs() == 0 and i > 40:
			break
	await get_tree().create_timer(1.5).timeout
	if s[7] == "glide":
		PlayerData.inventory.add(&"vela_glider")
		p.global_position.y += 60.0
		p.change_state(&"glide")
		rig.snap_to_target()
		await get_tree().create_timer(0.6).timeout
	if s[7] == "combat":
		w.spawner.spawn_creature(&"ENEMY_THORNLING", p.global_position + p.facing_dir() * 5.0 + Vector3(1.5, 0.5, 0), "", "tour")
		w.spawner.spawn_creature(&"ENEMY_BULWARK", p.global_position + p.facing_dir() * 8.0 + Vector3(-2.5, 0.5, 0), "", "tour")
		w.spawner.spawn_creature(&"ENEMY_SPITTER", p.global_position + p.facing_dir() * 11.0 + Vector3(3.0, 0.5, 0), "", "tour")
		w.spawner.spawn_creature(&"ANIMAL_WOOLHORN", p.global_position + p.facing_dir() * 9.0 + Vector3(-6.0, 0.5, 2), "", "tour")
		await get_tree().create_timer(0.3).timeout
		Input.action_press("attack")
		await get_tree().create_timer(0.12).timeout
		Input.action_release("attack")
		await get_tree().create_timer(0.15).timeout
	if s[7] == "boss":
		var boss: Boss = null
		for i in 120:
			await get_tree().process_frame
			for b in get_tree().get_nodes_in_group(&"bosses"):
				boss = b
			if boss and boss.engaged:
				break
		await get_tree().create_timer(3.2).timeout
		if boss:
			var info := DamageInfo.make(boss.health.max_health * 0.3, p, Vector3.ZERO)
			boss.take_damage(info)
			(boss.brain as BossBrain).change(&"chase")
			await get_tree().create_timer(1.6).timeout
		rig.yaw = s[3]
	if s[7] in ["protect", "nest", "beacon", "course", "captive", "board", "altar", "journal2", "reward", "smoke"]:
		await _quest_setup(s[7], p, w)
	if String(s[7]).begins_with("lineup:"):
		_lineup(String(s[7]).trim_prefix("lineup:"), p, w)
		await get_tree().create_timer(0.8).timeout
	if String(s[7]).begins_with("vehicles:"):
		await _vehicle_shot(String(s[7]).trim_prefix("vehicles:"), p, w)
	if String(s[7]).begins_with("eco:"):
		await _eco_shot(String(s[7]).trim_prefix("eco:"), p, w)
	if s[7] == "title":
		EventBus.title_card.emit(tr("POI_CLOUD_TEMPLE"), tr("REGION_HIGHLANDS"))
		await get_tree().create_timer(1.2).timeout
	match s[7]:
		"board":
			w.hud.visible = true
			EventBus.panel_requested.emit(&"board", "hamlet")
			await get_tree().create_timer(0.4, true, false, true).timeout
		"altar":
			w.hud.visible = true
			EventBus.panel_requested.emit(&"altar", "")
			await get_tree().create_timer(0.4, true, false, true).timeout
		"journal2":
			w.hud.visible = true
			w.hud.menu.open(PauseMenu.TAB_JOURNAL)
			await get_tree().create_timer(0.4, true, false, true).timeout
		"inventory", "map", "settings", "journal":
			w.hud.visible = true
			for id in [&"quarry_saber", &"tide_spear", &"emberroot", &"cap_mushroom", &"flint", &"iron_ore"]:
				PlayerData.inventory.add(id, 3)
			WorldState.discover_poi(&"echo_chamber")
			WorldState.discover_poi(&"needles")
			for x in range(20, 44):
				for z in range(20, 40):
					WorldState.explored[z * WorldState.MAP_CELLS + x] = 1
			if not Quests.is_active(&"sq_thorn_cull"):
				Quests.start(&"sq_thorn_cull", true)
				EventBus.entity_killed.emit(&"ENEMY_THORNLING", Vector3.ZERO)
				EventBus.entity_killed.emit(&"ENEMY_THORNLING", Vector3.ZERO)
			w.hud.menu.open({"inventory": PauseMenu.TAB_INVENTORY, "map": PauseMenu.TAB_MAP, "settings": PauseMenu.TAB_SETTINGS, "journal": PauseMenu.TAB_JOURNAL}[s[7]])
			await get_tree().create_timer(0.4, true, false, true).timeout
		"cook":
			w.hud.visible = true
			w.hud.cooking.open(null)
			w.hud.cooking._chosen = [&"emberroot", &"cap_mushroom"]
			w.hud.cooking._refresh()
			await get_tree().create_timer(0.4, true, false, true).timeout
	if not String(s[7]) in ["vehicles:drive_longwake", "vehicles:jump_sparrow", "vehicles:water"]:
		rig.yaw = s[3]
	rig.pitch = s[4]
	if not s[7] in ["reward"]:
		w.hud.dialogue.visible = false
		w.hud.title_card.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join(s[0] + ".png")
	img.save_png(path)
	print("saved %s  | draw calls %d  primitives %dk  objects %d" % [path.get_file(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	if w.hud.menu.visible:
		w.hud.menu.close_menu()
	if w.hud.cooking.visible:
		w.hud.cooking.close_panel()
	if w.hud.board.visible:
		w.hud.board.close_panel()
	if w.hud.altar.visible:
		w.hud.altar.close_panel()
	for c in get_tree().get_nodes_in_group(&"creatures"):
		if (c as Creature).group_id == "tour":
			c.queue_free()
	for n in get_tree().get_nodes_in_group(&"tour_lineup"):
		n.queue_free()
	InputRouter.touch_move = Vector2.ZERO
	if p.vehicle:
		p.exit_vehicle(false)
	w.vehicles.put_away()


## Ecosystem captures: creatures doing their thing in their place.
func _eco_shot(kind: String, p: Player, w: GameWorld) -> void:
	var fwd := p.facing_dir()
	match kind:
		"eel":
			# First deep spot ahead of the shore.
			var at := p.global_position + fwd * 10.0
			for k in 30:
				var q := p.global_position + fwd * (6.0 + k) + fwd.cross(Vector3.UP) * 3.5
				if w.gen.height(q.x, q.z) < -1.3:
					at = q
					break
			var eel := w.spawner.spawn_creature(&"ENEMY_MIRE_EEL", Vector3(at.x, -1.0, at.z), "", "tour")
			await get_tree().create_timer(0.5).timeout
			eel.brain.change(&"surface")
			await get_tree().create_timer(1.1).timeout
			eel.brain.change(&"idle")
			eel.face_towards(p.global_position - eel.global_position, 1.0)
		"kite":
			for i in 3:
				var k := w.spawner.spawn_creature(&"ENEMY_GALE_KITE", p.global_position + fwd * (9.0 + i * 5.0) + Vector3(i * 3.0 - 3.0, 6.0 + i * 2.0, 0), "", "tour")
				k.perception.alert(p.global_position)
				k.brain.change(&"chase")
			await get_tree().create_timer(2.6).timeout
		"imp":
			for i in 2:
				var imp := w.spawner.spawn_creature(&"ENEMY_CINDER_IMP", p.global_position + fwd * (7.0 + i * 3.0) + Vector3(i * 2.0, 0.5, 0), "", "tour")
				imp.perception.alert(p.global_position)
				imp.brain.change(&"chase")
			await get_tree().create_timer(3.0).timeout
		_:
			await get_tree().create_timer(2.5).timeout


## Vehicle captures: parked lineup, driving, jumping, floating, garage.
func _vehicle_shot(kind: String, p: Player, w: GameWorld) -> void:
	for id in DB.vehicles:
		PlayerData.own_vehicle(id, "earned")
	w.vehicles._unveil_pending = &""
	w.hud.title_card.visible = false
	match kind:
		"lineup", "close":
			var fwd := p.facing_dir()
			var right := fwd.cross(Vector3.UP).normalized()
			var dist := 7.0 if kind == "lineup" else 4.2
			var ids := [&"longwake", &"sparrow", &"bellhull"]
			for i in ids.size():
				if kind == "close" and i != 0:
					continue
				var vis := VehicleVisual.new()
				vis.add_to_group(&"tour_lineup")
				w.add_child(vis)
				vis.setup(DB.vehicles[ids[i]])
				var pos := p.global_position + fwd * dist + right * (i - 1) * 3.4 * (1.0 if kind == "lineup" else 0.0)
				pos.y = w.gen.height(pos.x, pos.z)
				vis.global_position = pos
				vis.rotation.y = p.facing_yaw + PI * 0.5 + 0.35
		"drive_longwake", "jump_sparrow", "water":
			var id: StringName = {"drive_longwake": &"longwake", "jump_sparrow": &"sparrow", "water": &"bellhull"}[kind]
			if kind == "water":
				p.global_position.y = WorldGen.SEA_LEVEL - 1.2
				p.change_state(&"swim")
				await get_tree().create_timer(0.3).timeout
			PlayerData.equip_vehicle(id)
			w.vehicles.summon(p)
			await get_tree().create_timer(0.6).timeout
			p.enter_vehicle(w.vehicles.active)
			InputRouter.touch_move = Vector2(0, 1)
			await get_tree().create_timer(2.4 if kind != "water" else 3.0).timeout
			if kind == "jump_sparrow":
				Input.action_press("jump")
				await get_tree().create_timer(0.45).timeout
				Input.action_release("jump")
				await get_tree().create_timer(0.35).timeout
			InputRouter.touch_move = Vector2.ZERO if kind == "water" else InputRouter.touch_move

			(Game.camera_rig as CameraRig).yaw = rad_to_deg(w.vehicles.active.heading) + 25.0
		"garage":
			w.hud.visible = true
			w.hud.menu.open(PauseMenu.TAB_GARAGE)
			w.hud.menu.garage._selected = &"longwake"
			w.hud.menu.garage.refresh()
			await get_tree().create_timer(0.6, true, false, true).timeout


## Visual-only lineup (no AI) in front of the player, turned 3/4 to camera.
## Plain ids come from the database; bare species names are example
## profiles with no gameplay data (spider, dragon...).
func _lineup(which: String, p: Player, w: GameWorld) -> void:
	var ids: Array = LINEUPS[which][0]
	var dist: float = LINEUPS[which][1]
	var fwd := p.facing_dir()
	var right := fwd.cross(Vector3.UP).normalized()
	var spacing := dist * 0.32 if which != "bosses" else 12.0
	for i in ids.size():
		var id: String = ids[i]
		var t: EntityType
		if DB.entities.has(StringName(id)):
			t = DB.entity(StringName(id))
		else:
			t = EntityType.new()
			t.id = StringName(id)
			t.kind = EntityType.Kind.ENEMY
			t.collider_height = 1.3 if id != "goblin" else 1.2
			t.collider_radius = 0.7 if id != "goblin" else 0.4
			t.placeholder_color = Color(0.3, 0.3, 0.3)
			var feats := {"spider": ["claws"], "dragon": ["horns", "claws", "spine_spikes", "wings", "long_neck"], "serpent": [], "goblin": ["horns", "ears"]}
			t.visual = {"family": "enemy", "rank": "elite" if id != "goblin" else "common", "species": id, "features": feats.get(id, [])}
		var holder := Node3D.new()
		holder.add_to_group(&"tour_lineup")
		w.add_child(holder)
		var pos := p.global_position + fwd * dist + right * (i - (ids.size() - 1) * 0.5) * spacing
		pos.y = w.gen.height(pos.x, pos.z) + (1.6 if t.flying else 0.0)
		holder.global_position = pos
		holder.rotation.y = p.facing_yaw + PI + 0.45
		var v := EntityVisual.new()
		holder.add_child(v)
		v.setup(t)


func _complete(id: StringName) -> void:
	if Quests.is_completed(id):
		return
	Quests.state[id]["state"] = Quests.State.COMPLETED
	Quests.state[id]["completions"] = 1
	Quests._refresh_availability()


## Puts the quest layer in the state each capture needs.
func _quest_setup(kind: String, p: Player, w: GameWorld) -> void:
	_complete(&"mq_vela")
	match kind:
		"protect", "nest":
			if not Quests.is_active(&"mq_thorn_road") and not Quests.is_completed(&"mq_thorn_road"):
				Quests.start(&"mq_thorn_road", true)
			if kind == "nest":
				# Finish the ambush from the previous capture: the stage advances.
				for e in get_tree().get_nodes_in_group(&"quest_encounters"):
					if (e as QuestEncounter).is_active():
						(e as QuestEncounter)._succeed()
				for c in get_tree().get_nodes_in_group(&"enemies"):
					if (c as Node3D).global_position.distance_to(p.global_position) < 80.0:
						c.queue_free()
			for i in 40:
				await get_tree().process_frame
			await get_tree().create_timer(5.0 if kind == "protect" else 2.0).timeout
			if kind == "nest":
				for n in get_tree().get_nodes_in_group(&"quest_nests"):
					(n as QuestNest).ignite()
				await get_tree().create_timer(1.2).timeout
		"beacon":
			for b in get_tree().get_nodes_in_group(&"warden_beacons"):
				if not (b as WardenBeacon)._lit:
					(b as WardenBeacon)._light(true)
			await get_tree().create_timer(0.6).timeout
		"smoke":
			await get_tree().create_timer(2.0).timeout
		"course":
			var course: RingCourse = null
			for c in get_tree().get_nodes_in_group(&"ring_courses"):
				if (c as RingCourse).course_id == &"shrine_sprint":
					course = c
			if course:
				p.global_position = course.points[0]
				await get_tree().create_timer(0.3).timeout
				p.global_position = course.points[0] + Vector3(-8, -0.5, -6)
			await get_tree().create_timer(1.8).timeout
		"captive":
			_complete(&"mq_thorn_road")
			if not Quests.is_active(&"sq_fang_rescue"):
				Quests.start(&"sq_fang_rescue", true)
			await get_tree().create_timer(3.0).timeout
		"board", "altar", "journal2":
			_complete(&"mq_thorn_road")
			for id in [&"sq_lost_kite", &"sq_smith_ore", &"sq_courier_rounds"]:
				if Quests.quest_state(id) == Quests.State.AVAILABLE:
					Quests.start(id, true)
			PlayerData.add_jade(9)
			for c in [&"trail_ember", &"ribbon_dawn", &"echo_storm", &"trail_frost"]:
				PlayerData.own_cosmetic(c)
			PlayerData.buy_upgrade(&"vela")
		"reward":
			Rewards.grant({"jade": 3, "glimmer": 60, "items": [{"id": "stamina_bloom", "count": 1}], "cosmetic": "trail_jade"}, "quest:tour_reward:1")
			EventBus.title_card.emit(tr("Q_MQ_CLOUD_TEMPLE"), tr("QUEST_COMPLETED"))
			await get_tree().create_timer(0.9).timeout
