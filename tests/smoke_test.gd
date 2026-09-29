extends Node
## End-to-end gameplay smoke test (the "first build" checklist).
## Run:  godot --headless -- --smoke      (exit code 0 = pass)
##
## Drives the real game: new game -> world streams in -> walk, sprint, jump
## -> climb a wall -> glide -> fight an enemy -> gather -> inventory/equip ->
## use an item -> physics prop -> weather + time -> save -> quit -> continue
## -> progress restored.

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


func hold(action: String, s: float) -> void:
	Input.action_press(action)
	await seconds(s)
	Input.action_release(action)


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(1)


func _run() -> void:
	SaveSystem.delete_save()
	Game.start_game(false)
	var t0 := Time.get_ticks_msec()
	while not Game.is_playing() and Time.get_ticks_msec() - t0 < 60000:
		await frames(5)
	check(Game.is_playing(), "world loads and game reaches PLAYING (%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if not Game.is_playing():
		_finish()
		return
	var w := Game.world as GameWorld
	var p := Game.player as Player
	await seconds(1.0)
	check(p.is_on_floor(), "player stands on streamed terrain (y=%.1f)" % p.global_position.y)
	check(w.streamer.loaded_count() > 20, "sectors streamed: %d" % w.streamer.loaded_count())
	check(w.pois.built_count() >= 1, "nearby POIs built: %d" % w.pois.built_count())
	var total := HorizonTiles.TILES * HorizonTiles.TILES
	check(w.horizon.tile_count() == total, "horizon tiles built: %d" % w.horizon.tile_count())
	var wait_t := Time.get_ticks_msec()
	while w.streamer.pending_jobs() > 0 and Time.get_ticks_msec() - wait_t < 20000:
		await frames(5)
	await frames(10)
	check(w.horizon.visible_count() < total, "horizon hides tiles fully covered by streamed sectors (%d/%d visible)" % [w.horizon.visible_count(), total])
	check(get_tree().get_nodes_in_group(&"npcs").size() >= 1, "village NPCs spawned")

	# --- Movement -------------------------------------------------------------
	var start := p.global_position
	InputRouter.touch_move = Vector2(0, 1)
	await seconds(1.5)
	InputRouter.touch_move = Vector2.ZERO
	check(p.global_position.distance_to(start) > 4.0, "walk/run moves the player (%.1fm)" % p.global_position.distance_to(start))
	start = p.global_position
	InputRouter.touch_move = Vector2(0, 1)
	InputRouter.touch_sprint = true
	var st0 := PlayerData.stamina
	await seconds(1.2)
	check(PlayerData.stamina < st0, "sprint drains stamina (%.0f -> %.0f)" % [st0, PlayerData.stamina])
	InputRouter.touch_sprint = false
	InputRouter.touch_move = Vector2.ZERO
	await seconds(0.3)
	var y0 := p.global_position.y
	await tap("jump")
	var peak := y0
	for i in 30:
		await frames(1)
		peak = maxf(peak, p.global_position.y)
	check(peak > y0 + 0.8, "jump rises %.2fm" % (peak - y0))
	await seconds(1.0)
	check(p.state_name() == &"ground", "lands after jump")

	# --- Climb: a 7 m test wall in front of the player -----------------------------
	var climbed := false
	var wall := StaticBody3D.new()
	var wcs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 7, 1.5)
	wcs.shape = box
	wall.add_child(wcs)
	w.add_child(wall)
	var fwd := p.facing_dir()
	wall.global_position = p.global_position + fwd * 3.0 + Vector3.UP * 3.0
	wall.look_at(wall.global_position + fwd, Vector3.UP)
	Game.camera_rig.yaw = rad_to_deg(p.facing_yaw)
	await frames(3)
	InputRouter.touch_move = Vector2(0, 1)
	var cy := p.global_position.y
	var max_y := cy
	var mantled := false
	for i in 600:
		await frames(1)
		if p.state_name() == &"climb":
			climbed = true
		max_y = maxf(max_y, p.global_position.y)
		if climbed and p.state_name() == &"ground" and p.global_position.y > cy + 5.0:
			mantled = true
			break
	InputRouter.touch_move = Vector2.ZERO
	check(climbed, "enters climb state against a steep wall")
	check(max_y > cy + 3.0, "climbing gains height (%.1fm)" % (max_y - cy))
	check(mantled, "mantles over the top ledge (state=%s)" % p.state_name())
	var st_climb := PlayerData.stamina
	check(st_climb < PlayerData.max_stamina, "climbing costs stamina (%.0f)" % st_climb)
	wall.queue_free()
	await seconds(1.5)

	# --- Glide: drop from height ------------------------------------------------
	PlayerData.inventory.add(&"vela_glider")
	p.global_position += Vector3(0, 40, 0)
	p.velocity = Vector3.ZERO
	p.change_state(&"air")
	await frames(10)
	await tap("jump")
	await frames(5)
	check(p.state_name() == &"glide", "glider opens in mid-air (state=%s)" % p.state_name())
	var gy := p.global_position.y
	InputRouter.touch_move = Vector2(0, 1)
	await seconds(1.0)
	var sink := gy - p.global_position.y
	check(sink < 4.0 and sink > 0.2, "gliding descends slowly (%.2f m/s)" % sink)
	InputRouter.touch_move = Vector2.ZERO
	Debug.infinite_stamina = false
	var land_t := Time.get_ticks_msec()
	while p.state_name() != &"ground" and Time.get_ticks_msec() - land_t < 30000:
		await frames(10)
	check(p.state_name() == &"ground", "lands from glide")

	# --- Combat ---------------------------------------------------------------------
	Debug.run("tp heath_hamlet")
	await seconds(2.0)
	Debug.god_mode = true
	Debug.run("spawn ENEMY_THORNLING 1")
	await frames(10)
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	check(enemies.size() >= 1, "enemy spawned")
	var killed := false
	var dur_before := PlayerData.weapon().durability() if PlayerData.weapon() else 0.0
	if enemies.size() >= 1:
		var e := enemies[0] as Enemy
		var hp0 := e.health.health
		for i in 40:
			if not is_instance_valid(e) or e.dead:
				killed = true
				break
			var to := e.global_position - p.global_position
			to.y = 0
			p.facing_yaw = atan2(-to.x, -to.z)
			if to.length() > 1.6:
				p.global_position = e.global_position - to.normalized() * 1.4
			await tap("attack")
			await seconds(0.35)
		killed = killed or not is_instance_valid(e) or e.dead
		check(killed or (is_instance_valid(e) and e.health.health < hp0), "attacks damage the enemy")
	check(killed, "enemy defeated")
	check(PlayerData.weapon() == null or PlayerData.weapon().durability() < dur_before, "weapon durability wears on hits")
	Debug.god_mode = false
	await seconds(2.5)

	# --- Gathering & items --------------------------------------------------------------
	var gathered := false
	var before_items := PlayerData.inventory.stacks.size()
	for r in _all_of(get_tree().root, "ResourceNode"):
		var rn := r as ResourceNode
		if rn.can_interact():
			p.global_position = rn.global_position + Vector3(1.0, 0.5, 0)
			await frames(15)
			rn.interact(p)
			gathered = true
			break
	await frames(10)
	check(gathered, "gathered a resource node")
	await seconds(1.0)
	PlayerData.health = 50.0
	PlayerData.inventory.add(&"sunpear", 1)
	PlayerData.quick_item = &"sunpear"
	await tap("use_item")
	await seconds(0.8)
	check(PlayerData.health > 50.0, "eating food heals (%.0f)" % PlayerData.health)
	PlayerData.inventory.add(&"quarry_saber")
	var saber := PlayerData.inventory.find_first(&"quarry_saber")
	PlayerData.equip(saber)
	check(PlayerData.weapon() == saber, "equip weapon from inventory")
	check(PlayerData.carries_metal(), "metal tag detected on equipment")

	# --- Physics interaction: bomb + barrel ------------------------------------------------
	var barrel := PhysicsProp.create(&"barrel")
	w.add_child(barrel)
	barrel.global_position = p.global_position + p.facing_dir() * 6.0 + Vector3.UP * 1.5
	await seconds(0.8)
	var info := DamageInfo.make(5.0, p, Vector3.ZERO, &"fire")
	barrel.take_damage(info)
	await seconds(1.8)
	check(not is_instance_valid(barrel), "fire makes the barrel explode")

	# --- Weather & time -----------------------------------------------------------------------
	Weather.set_weather(&"storm", true)
	Clock.set_time(22.0)
	await seconds(0.5)
	check(Weather.rain > 0.9 and Clock.is_night(), "storm at night applied")
	Weather.set_weather(&"clear", true)
	Clock.set_time(10.0)

	# --- Save, "close", continue -----------------------------------------------------------
	var saved_pos := p.global_position
	var saved_hp := PlayerData.health
	var saved_count := PlayerData.inventory.stacks.size()
	WorldState.flags["smoke_flag"] = true
	check(SaveSystem.save_game(), "save game")
	PlayerData.reset_new_game()
	WorldState.reset()
	check(not WorldState.flags.has("smoke_flag"), "state cleared before reload")
	Game.start_game(true)
	await frames(5)
	t0 = Time.get_ticks_msec()
	while not Game.is_playing() and Time.get_ticks_msec() - t0 < 60000:
		await frames(5)
	check(Game.is_playing(), "continue from save reaches PLAYING")
	var p2 := Game.player as Player
	await seconds(0.5)
	check(p2 != null and p2.global_position.distance_to(saved_pos) < 6.0, "position restored (%.1fm off)" % (p2.global_position.distance_to(saved_pos) if p2 else -1.0))
	check(absf(PlayerData.health - saved_hp) < 0.5, "health restored")
	check(PlayerData.inventory.stacks.size() == saved_count, "inventory restored (%d stacks, before items %d)" % [PlayerData.inventory.stacks.size(), before_items])
	check(PlayerData.weapon() != null and PlayerData.weapon().id == &"quarry_saber", "equipment restored")
	check(WorldState.flags.has("smoke_flag"), "world flags restored")
	_finish()


func _all_of(root: Node, cls: String) -> Array:
	var out: Array = []
	for n in root.find_children("*", "", true, false):
		if n.get_script() and (n.get_script() as Script).get_global_name() == cls:
			out.append(n)
	return out


func _finish() -> void:
	print("\n==== SMOKE TEST ====")
	for l in _log:
		print(l)
	print("==== %d checks, %d failed ====" % [_log.size(), _failures.size()])
	SaveSystem.delete_save()
	get_tree().quit(1 if _failures.size() > 0 else 0)
