class_name GameWorld
extends Node3D
## Root of the gameplay scene. Composes the world systems in dependency
## order, runs the loading sequence and the dynamic music director.
##
##   IslandMap + HorizonTiles (threads) -> Water -> Environment/Weather FX
##   -> Streamer + Spawns + POIs + AI -> Player + Camera -> HUD
##   -> load save -> wait for ground collision -> PLAYING

var island := IslandMap.new()
var gen: WorldGen
var streamer: WorldStreamer
var spawner: SpawnDirector
var pois: PoiManager
var bosses: BossManager
var mounts: MountManager
var events: WorldEventDirector
var quest_content: QuestSpawner
var ai: AIManager
var environment_ctl: EnvironmentController
var weather_fx: WeatherFX
var water: WaterSurface
var horizon: HorizonTiles
var player: Player
var camera_rig: CameraRig
var hud: HUD
var loading: LoadingScreen

var _music_timer := 0.0
var _ready_to_play := false


func _ready() -> void:
	Game.world = self
	loading = LoadingScreen.new()
	add_child(loading)
	loading.set_progress(0.05, "LOADING_WORLD")
	await get_tree().process_frame
	_start()


func _start() -> void:
	gen = WorldGen.from_world_data(DB.world)
	# Vegetation arrays for sector/tile batching (read by worker threads).
	MeshKit.warm_arrays()
	# 1. Island height field on a worker thread.
	var task := WorkerThreadPool.add_task(island.build.bind(DB.world), true, "island_map")
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	island.finalize()
	loading.set_progress(0.3, "LOADING_TERRAIN")

	# 2. Distant terrain (tiles built on a worker thread) + water
	# Lambdas capture locals by value: fill a shared array instead of assigning.
	var tiles_data: Array = []
	var tiles_task := WorkerThreadPool.add_task(func() -> void: tiles_data.append_array(HorizonTiles.build_data(island, DB.world)), true, "horizon")
	while not WorkerThreadPool.is_task_completed(tiles_task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(tiles_task)
	horizon = HorizonTiles.new()
	horizon.name = "Horizon"
	add_child(horizon)
	horizon.apply(tiles_data)
	water = WaterSurface.new()
	water.name = "Water"
	add_child(water)
	water.setup(island.texture)
	var mist := MistBanks.new()
	mist.name = "Mist"
	add_child(mist)
	mist.build(gen)
	for f in DB.world.get("falls", []):
		var wf := Waterfall.create(f, gen)
		wf.name = "Falls_" + String(f["id"])
		add_child(wf)

	# 3. Atmosphere
	environment_ctl = EnvironmentController.new()
	environment_ctl.name = "Environment"
	add_child(environment_ctl)
	weather_fx = WeatherFX.new()
	weather_fx.name = "WeatherFX"
	add_child(weather_fx)

	# 4. Streaming & content
	streamer = WorldStreamer.new()
	streamer.name = "Streamer"
	add_child(streamer)
	spawner = SpawnDirector.new()
	spawner.name = "Spawner"
	spawner.gen = gen
	add_child(spawner)
	streamer.sector_coverage_changed.connect(horizon.set_sector_covered)
	streamer.sector_gameplay_ready.connect(spawner.on_sector_ready)
	streamer.sector_gameplay_released.connect(spawner.on_sector_released)
	pois = PoiManager.new()
	pois.name = "POIs"
	pois.gen = gen
	pois.spawner = spawner
	add_child(pois)
	bosses = BossManager.new()
	bosses.name = "Bosses"
	bosses.gen = gen
	bosses.spawner = spawner
	add_child(bosses)
	mounts = MountManager.new()
	mounts.name = "Mounts"
	mounts.gen = gen
	mounts.spawner = spawner
	add_child(mounts)
	events = WorldEventDirector.new()
	events.name = "WorldEvents"
	events.gen = gen
	events.spawner = spawner
	add_child(events)
	quest_content = QuestSpawner.new()
	quest_content.name = "QuestContent"
	quest_content.gen = gen
	quest_content.spawner = spawner
	quest_content.streamer = streamer
	add_child(quest_content)
	ai = AIManager.new()
	ai.name = "AIManager"
	add_child(ai)

	# 5. Save data (global state) before the player exists
	if Game.load_on_start and SaveSystem.read_save():
		SaveSystem.apply_loaded_globals()
	else:
		SaveSystem.new_game()

	# 6. Player + camera
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var sp: Array = DB.world.get("spawn", [0, 20, 0])
	player.global_position = Vector3(sp[0], sp[1], sp[2])
	player.facing_yaw = float(DB.world.get("spawn_yaw", 0.0))
	if SaveSystem.has_loaded():
		player.load_state(SaveSystem.section("player"))
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.target = player
	camera_rig.snap_to_target()
	streamer.focus = player

	# 7. UI
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.island = island

	# 8. Wait for collision under the player, then drop them onto the ground.
	loading.set_progress(0.5, "LOADING_TERRAIN")
	while not streamer.has_collision_at(player.global_position):
		loading.set_progress(0.5 + 0.4 * minf(streamer.loaded_count() / 40.0, 1.0), "LOADING_TERRAIN")
		await get_tree().process_frame
	pois.build_near(player.global_position)
	loading.set_progress(0.95, "LOADING_READY")
	await get_tree().physics_frame
	_place_on_ground(player)
	camera_rig.snap_to_target()
	player.physics_ready = true
	Game.state = Game.State.PLAYING
	Quests.on_game_started()
	InputRouter.gameplay_enabled = true
	_ready_to_play = true
	loading.finish()
	if not SaveSystem.has_loaded():
		EventBus.toast.emit(tr("TOAST_WELCOME"))
		EventBus.dialogue_requested.emit("NAME_NARRATOR", PackedStringArray(["INTRO_1", "INTRO_2", "INTRO_3"]))
	SaveSystem.save_game()


func _place_on_ground(body: Node3D) -> void:
	var from := body.global_position + Vector3.UP * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 200.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		body.global_position = hit["position"] + Vector3.UP * 0.1
	else:
		body.global_position.y = gen.height(body.global_position.x, body.global_position.z) + 0.5


func _process(delta: float) -> void:
	if not _ready_to_play:
		return
	_music_timer -= delta
	if _music_timer <= 0.0:
		_music_timer = 1.5
		_update_music()


## Music director: combat > night > region mood. Crossfades are handled by
## Audio.play_music; this only chooses the mood.
func _update_music() -> void:
	var track := &"music_day"
	var boss_fight := false
	for b in get_tree().get_nodes_in_group(&"bosses"):
		if (b as Boss).engaged and not (b as Boss).dead:
			boss_fight = true
	var region := player.region if player else &""
	if boss_fight:
		track = &"music_boss"
	elif Game.in_combat:
		track = &"music_combat"
	elif Clock.is_night():
		track = &"music_night"
	elif player and player.global_position.y > 110.0:
		track = &"music_high"
	elif region == &"desert":
		track = &"music_desert"
	elif region == &"veil":
		track = &"music_veil"
	Audio.play_music(track)


func _exit_tree() -> void:
	Audio.stop_all()
	Game.clear_aggro()
