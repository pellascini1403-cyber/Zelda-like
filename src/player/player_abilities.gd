class_name PlayerAbilities
extends Node
## Wind Warden abilities (data/abilities.json). Unlocked through quests
## (PlayerData.abilities); one is selected and fired with the "ability"
## action, "cycle_ability" switches. Each has a stamina cost and cooldown.

var selected: StringName = &""
var cooldowns: Dictionary = {}       # id -> seconds left
var _stillness_left := 0.0
var _sight: WindSight
var p: Player


func _ready() -> void:
	p = get_parent() as Player
	_sight = WindSight.new()
	_sight.name = "WindSight"
	p.add_child.call_deferred(_sight)
	EventBus.ability_unlocked.connect(func(id: StringName) -> void:
		selected = id
		var d: Dictionary = DB.abilities.get(id, {})
		EventBus.title_card.emit(tr(d.get("name_key", "")), tr("ABILITY_LEARNED")))
	_ensure_selected()


func unlocked() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in DB.abilities:
		if PlayerData.has_ability(id):
			out.append(id)
	return out


func _ensure_selected() -> void:
	var list := unlocked()
	if list.is_empty():
		selected = &""
	elif not selected in list:
		selected = list[0]


func cycle() -> void:
	var list := unlocked()
	if list.is_empty():
		return
	var i := list.find(selected)
	selected = list[(i + 1) % list.size()]
	Audio.play_ui(&"ui_click", -8.0)
	EventBus.ability_used.emit(&"")   # HUD refresh


func cooldown_ratio(id: StringName) -> float:
	var d: Dictionary = DB.abilities.get(id, {})
	return clampf(cooldowns.get(id, 0.0) / maxf(float(d.get("cooldown", 1.0)), 0.01), 0.0, 1.0)


func _process(delta: float) -> void:
	for k in cooldowns.keys():
		cooldowns[k] -= delta
		if cooldowns[k] <= 0.0:
			cooldowns.erase(k)
	if _stillness_left > 0.0:
		_stillness_left -= delta
		if _stillness_left <= 0.0:
			_end_stillness()
	if not InputRouter.gameplay_enabled or p == null or p.is_dead():
		return
	if Input.is_action_just_pressed("cycle_ability"):
		cycle()
	if Input.is_action_just_pressed("ability"):
		use(selected)


func use(id: StringName) -> bool:
	_ensure_selected()
	if id == &"" or not PlayerData.has_ability(id) or cooldowns.has(id):
		return false
	var d: Dictionary = DB.abilities.get(id, {})
	if p.state_name() in [&"dead", &"busy", &"climb", &"swim", &"drive"] and not id in [&"wind_sight", &"vehicle_call"]:
		return false
	var cost := float(d.get("stamina", 0.0))
	if cost > 0.0 and not p.vitals.try_spend(cost):
		return false
	var ok := true
	match id:
		&"gust_step":
			var g: GustState = p.states[&"gust"]
			g.distance = float(d.get("distance", 8.0))
			g.duration = float(d.get("duration", 0.22))
			p.change_state(&"gust")
		&"jade_platform":
			_jade(d)
		&"wind_sight":
			_sight.reveal(p.global_position, float(d.get("radius", 70.0)), float(d.get("duration", 12.0)))
			Audio.play_ui(&"wind_sight", -2.0)
		&"stillness":
			Game.enemy_time_scale = float(d.get("time_scale", 0.35))
			_stillness_left = float(d.get("duration", 4.0))
			ElementFX.burst(p, p.global_position, &"still", 10.0)
			Audio.play_ui(&"stillness", -2.0)
			EventBus.flag_set.emit(&"stillness_active")
		&"strider_call":
			ok = MountManager.call_mount(p)
		&"vehicle_call":
			ok = VehicleManager.instance != null and VehicleManager.instance.summon(p)
		_:
			ok = false
	if ok:
		cooldowns[id] = float(d.get("cooldown", 1.0)) * (1.0 - PlayerData.upgrade_bonus(&"winds"))
		EventBus.ability_used.emit(id)
	return ok


func _jade(d: Dictionary) -> void:
	var existing := get_tree().get_nodes_in_group(&"jade_platforms")
	if existing.size() >= int(d.get("max_active", 2)):
		existing[0].queue_free()
	var s: Array = d.get("size", [2.6, 0.35, 2.6])
	var j := JadePlatform.create(Vector3(s[0], s[1], s[2]), float(d.get("lifetime", 9.0)))
	var pos: Vector3
	if p.is_on_floor():
		# A step ahead and up: chain two to climb a wall.
		pos = p.global_position + p.facing_dir() * 2.2 + Vector3.UP * 1.3
	else:
		pos = p.global_position + Vector3.DOWN * (s[1] * 0.5 + 0.05)
		p.velocity.y = maxf(p.velocity.y, 0.0)
	get_tree().current_scene.add_child(j)
	j.global_position = pos
	j.rotation.y = p.facing_yaw


func _end_stillness() -> void:
	Game.enemy_time_scale = 1.0
	_stillness_left = 0.0


func stillness_active() -> bool:
	return _stillness_left > 0.0


func _exit_tree() -> void:
	Game.enemy_time_scale = 1.0
