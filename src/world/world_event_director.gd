class_name WorldEventDirector
extends Node3D
## Dynamic world events (data/world_events.json). Once per in-game hour each
## event rolls its chance if the player is in one of its regions and the
## period matches. Two families:
##  * "reward" events (wind rift, star fall): a glowing beacon appears at a
##    distance; reaching it pays out and ends the event.
##  * "spawn" events (ambush, swarm, surge): a group appears around the
##    player, just out of sight, and hunts them.
##  * "encounter" events (a traveller under attack): a live QuestEncounter
##    appears within earshot — a shout for help, not a map icon.
##  * "rare" events: a rare creature (the gilded hop at dawn and dusk)
##    shows up somewhere nearby for a while.
## Spawn events with "alert": false are patrols that have not seen the
## player: a powerful enemy walking the land, visible from a distance.
## At most one of each kind runs at a time; everything is freed when it ends
## or the player wanders far away (streaming-safe). Recently seen events are
## skipped (anti-repetition).

const MAX_BEACON_DISTANCE := 400.0

var gen: WorldGen
var spawner: SpawnDirector
var _last_hour := -1
var _beacon: Node3D = null
var _beacon_def: Dictionary = {}
var _beacon_expire := 0.0
var _rng := RandomNumberGenerator.new()
var _encounter: QuestEncounter = null
var _recent: Array = []   # last event ids (anti-repetition)


func _ready() -> void:
	_rng.randomize()


func _process(_delta: float) -> void:
	if Game.player == null or not Game.is_playing() or Game.in_cutscene:
		return
	var h := int(floor(Clock.total_hours()))
	if _last_hour < 0:
		_last_hour = h
	if h != _last_hour:
		_last_hour = h
		_roll()
	if _beacon:
		_update_beacon()
	if _encounter and is_instance_valid(_encounter):
		var far := Game.player.global_position.distance_to(_encounter.center) > 220.0
		if far and _encounter.can_release():
			_encounter.queue_free()
			_encounter = null


func _roll() -> void:
	var p := Game.player as Player
	for ev in DB.world_events:
		if not String(p.region) in ev.get("regions", []):
			continue
		if not _time_ok(ev) or String(ev["id"]) in _recent:
			continue
		if _rng.randf() > float(ev.get("chance_per_hour", 0.1)):
			continue
		if _start(ev):
			return


func _time_ok(ev: Dictionary) -> bool:
	var period := String(ev.get("period", "any"))
	if (period == "night" and not Clock.is_night()) or (period == "day" and Clock.is_night()):
		return false
	if ev.has("hours"):
		var hs: Array = ev["hours"]
		var ok := false
		for i in range(0, hs.size() - 1, 2):
			if Clock.hour >= float(hs[i]) and Clock.hour < float(hs[i + 1]):
				ok = true
		if not ok:
			return false
	if ev.has("weather") and not String(Weather.target) in ev["weather"]:
		return false
	return true


func _start(ev: Dictionary) -> bool:
	var started := false
	if ev.has("encounter"):
		if not Game.in_combat and (_encounter == null or not is_instance_valid(_encounter)):
			started = _start_encounter(ev)
	elif ev.has("rare"):
		started = _start_rare(ev)
	elif ev.has("spawn"):
		if not Game.in_combat or not ev.get("alert", true):
			_start_spawn(ev)
			started = true
	elif _beacon == null:
		_start_beacon(ev)
		started = true
	if started:
		_recent.push_front(String(ev["id"]))
		_recent.resize(mini(_recent.size(), 3))
	return started


func trigger(id: StringName) -> bool:
	for ev in DB.world_events:
		if StringName(ev["id"]) == id:
			return _start(ev)
	return false


func _start_encounter(ev: Dictionary) -> bool:
	var at := _pick_spot(ev.get("distance", [45, 70]))
	if at == Vector3.INF:
		return false
	var e: Dictionary = (ev["encounter"] as Dictionary).duplicate(true)
	e["id"] = "event:" + String(ev["id"])
	e["once"] = false
	_encounter = QuestEncounter.create(e, at, [] as Array[Vector3], spawner, gen)
	add_child(_encounter)
	EventBus.world_event_started.emit(StringName(ev["id"]), at)
	return true


func _start_rare(ev: Dictionary) -> bool:
	var at := _pick_spot(ev.get("distance", [40, 80]))
	if at == Vector3.INF:
		return false
	var c := spawner.spawn_creature(StringName(ev["rare"]), at + Vector3.UP * 0.4, "", "event:" + String(ev["id"]))
	if c == null:
		return false
	spawner.adopt_orphan(c)
	ElementFX.burst(c, at + Vector3.UP * 0.5, &"jade", 1.2)
	EventBus.world_event_started.emit(StringName(ev["id"]), at)
	if ev.has("name_key"):
		EventBus.toast.emit(tr(ev["name_key"]))
	return true


func _pick_spot(dist: Array) -> Vector3:
	var p := Game.player.global_position
	for attempt in 12:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(float(dist[0]), float(dist[1]))
		var q := p + Vector3(cos(a) * r, 0, sin(a) * r)
		q.y = gen.height(q.x, q.z)
		if q.y > WorldGen.SEA_LEVEL + 0.5 and gen.normal(q.x, q.z).y > 0.75:
			return q
	return Vector3.INF


func _start_spawn(ev: Dictionary) -> void:
	var c: Array = ev.get("count", [2, 3])
	var n := _rng.randi_range(int(c[0]), int(c[1]))
	var center := _pick_spot(ev.get("distance", [14, 20]))
	if center == Vector3.INF:
		return
	var group := "event:%s:%d" % [ev["id"], Time.get_ticks_msec()]
	for i in n:
		var a := TAU * i / n
		var sp := center + Vector3(cos(a) * 2.5, 0, sin(a) * 2.5)
		sp.y = gen.height(sp.x, sp.z) + 0.4
		var m := spawner.spawn_creature(StringName(ev["spawn"] if i == 0 or not ev.has("escort") else ev["escort"]), sp, "", group)
		if m:
			if ev.get("alert", true):
				m.perception.alert(Game.player.global_position)
			spawner.adopt_orphan(m)
			ElementFX.burst(m, sp, &"still" if ev["id"] == "veil_surge" else &"sand" if ev["id"] == "sand_swarm" else &"thorn", 1.4)
	EventBus.world_event_started.emit(StringName(ev["id"]), center)
	if ev.get("alert", true):
		EventBus.toast.emit(tr(ev.get("name_key", "")))


func _start_beacon(ev: Dictionary) -> void:
	var at := _pick_spot(ev.get("distance", [60, 140]))
	if at == Vector3.INF:
		return
	_beacon_def = ev
	_beacon_expire = Clock.total_hours() + float(ev.get("duration_hours", 2.0))
	_beacon = Node3D.new()
	_beacon.name = "EventBeacon"
	add_child(_beacon)
	_beacon.global_position = at
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 1.4
	cyl.height = 70.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 10
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/wind_seal.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.position.y = 35.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(mi)
	EventBus.world_event_started.emit(StringName(ev["id"]), at)
	EventBus.toast.emit(tr(ev.get("name_key", "")))


func _update_beacon() -> void:
	var p := Game.player.global_position
	var at := _beacon.global_position
	var d := Vector2(p.x - at.x, p.z - at.z).length()
	if d < 4.0 and absf(p.y - at.y) < 6.0:
		for it in _beacon_def.get("reward", {}).get("items", []):
			var c: Array = it.get("count", [1, 1])
			Pickup.spawn(get_tree().current_scene, at + Vector3.UP * 1.0, StringName(it["id"]), _rng.randi_range(int(c[0]), int(c[1])))
		ElementFX.burst(self, at, &"wind", 4.0)
		Audio.play_ui(&"discovery", -2.0)
		_end_beacon()
	elif Clock.total_hours() > _beacon_expire or d > MAX_BEACON_DISTANCE:
		_end_beacon()


func _end_beacon() -> void:
	EventBus.world_event_ended.emit(StringName(_beacon_def.get("id", "")))
	_beacon.queue_free()
	_beacon = null
	_beacon_def = {}


## Compass / map marker for the active beacon, or null.
func beacon_position() -> Variant:
	return _beacon.global_position if _beacon else null
