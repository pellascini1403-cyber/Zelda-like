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
	["09_combat", 62.0, 180.0, 20.0, -12.0, 12.5, "clear", "combat"],
	["10_ui_touch", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "touch"],
	["11_inventory", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "inventory"],
	["12_map", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "map"],
	["13_cooking", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "cook"],
	["14_settings", 62.0, 170.0, 10.0, -8.0, 9.0, "clear", "settings"],
]

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
	for shot in SHOTS:
		await _shot(shot)
	print("tour done: ", _out)
	get_tree().quit()


func _shot(s: Array) -> void:
	var w := Game.world as GameWorld
	var p := Game.player as Player
	Debug.god_mode = true
	Debug.force_touch_ui = s[7] == "touch"
	w.hud.visible = s[7] == "touch" or s[7] == "combat"
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
	match s[7]:
		"inventory", "map", "settings":
			w.hud.visible = true
			for id in [&"quarry_saber", &"tide_spear", &"emberroot", &"cap_mushroom", &"flint", &"iron_ore"]:
				PlayerData.inventory.add(id, 3)
			WorldState.discover_poi(&"echo_chamber")
			WorldState.discover_poi(&"needles")
			for x in range(20, 44):
				for z in range(20, 40):
					WorldState.explored[z * WorldState.MAP_CELLS + x] = 1
			w.hud.menu.open({"inventory": PauseMenu.TAB_INVENTORY, "map": PauseMenu.TAB_MAP, "settings": PauseMenu.TAB_SETTINGS}[s[7]])
			await get_tree().create_timer(0.4, true, false, true).timeout
		"cook":
			w.hud.visible = true
			w.hud.cooking.open(null)
			w.hud.cooking._chosen = [&"emberroot", &"cap_mushroom"]
			w.hud.cooking._refresh()
			await get_tree().create_timer(0.4, true, false, true).timeout
	rig.yaw = s[3]
	rig.pitch = s[4]
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
	for c in get_tree().get_nodes_in_group(&"creatures"):
		if (c as Creature).group_id == "tour":
			c.queue_free()
