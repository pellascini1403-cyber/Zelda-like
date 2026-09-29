class_name QuestEncounter
extends Node3D
## Live combat situations built from data, used by quests and emergent
## world events alike:
##   protect — a person (cart, keeper, pilgrim) is attacked in waves; keep
##             them alive until the last wave falls.
##   survive — hold a spot for N seconds while enemies keep coming.
##   escort  — walk someone along a path; they wait when the player lags,
##             ambushes trigger at path points.
## Enemies spawned here target the protected actor (Creature.focus).
##
## Data (kind "encounter"): {id, mode, actor, actor_hp, pos, path, waves:
## [{entity, count, delay, dist}], ambushes: [{at, entity, count}],
## duration, radius, trigger_radius, interval, max_alive, shout_key,
## title_key, start_lines, end_lines, reward, element}.
## Result: EventBus.encounter_finished(id, success). Failure only resets the
## encounter (and the quest stage): nothing is ever lost for good.

enum Phase { IDLE, ACTIVE, DONE }

var data: Dictionary = {}
var enc_id: StringName = &""
var mode := "protect"
var center := Vector3.ZERO
var path: Array[Vector3] = []
var spawner: SpawnDirector
var gen: WorldGen
var actor: QuestActor
var phase := Phase.IDLE
var group_name := ""
var _wave := 0
var _wave_delay := 0.0
var _alive: Array = []
var _time := 0.0
var _outside_t := 0.0
var _spawn_t := 0.0
var _spawn_i := 0
var _ambushed: Dictionary = {}
var _hud_t := 0.0
var _cooldown := 0.0
var _shout_t := 0.0
var _shouting := false
var _path_len := 0
var _rng := RandomNumberGenerator.new()


static func create(d: Dictionary, at: Vector3, route: Array[Vector3], sd: SpawnDirector, g: WorldGen) -> QuestEncounter:
	var e := QuestEncounter.new()
	e.data = d
	e.enc_id = StringName(d.get("id", ""))
	e.mode = String(d.get("mode", "protect"))
	e.center = at
	e.path = route
	e.spawner = sd
	e.gen = g
	e.group_name = String(d.get("group", "enc:" + String(e.enc_id)))
	return e


func _ready() -> void:
	add_to_group(&"quest_encounters")
	_rng.randomize()
	_make_actor()


func _make_actor() -> void:
	var ent := StringName(data.get("actor", ""))
	if ent == &"" or DB.entity(ent) == null:
		return
	actor = QuestActor.create(ent, float(data.get("actor_hp", 120.0)))
	add_child(actor)
	actor.global_position = center + Vector3.UP * 0.2
	actor.cowering = mode == "protect"
	actor.died_signal.connect(func(_a: QuestActor) -> void: _fail())
	if not path.is_empty():
		actor.face(path[0])


func is_active() -> bool:
	return phase == Phase.ACTIVE


## The spawner may only free an encounter that is not mid-fight.
func can_release() -> bool:
	return phase != Phase.ACTIVE


func _focus_point() -> Vector3:
	return actor.global_position if actor and is_instance_valid(actor) else center


func _physics_process(delta: float) -> void:
	var p := Game.player as Player
	if p == null or not Game.is_playing():
		return
	if _hud_t > 0.0:
		_hud_t -= delta
		if _hud_t <= 0.0:
			EventBus.encounter_hud.emit("", "", 0.0)
	match phase:
		Phase.IDLE:
			_idle(p, delta)
		Phase.ACTIVE:
			_active(p, delta)


func _idle(p: Player, delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	var d := p.global_position.distance_to(_focus_point())
	# A call for help carries: the player hears it before seeing anything.
	var shout := String(data.get("shout_key", ""))
	if actor and shout != "":
		_shout_t -= delta
		if _shout_t <= 0.0:
			_shout_t = 3.0
			if d < 80.0:
				_shouting = not _shouting
				actor.shout(shout if _shouting else "")
	var trigger := float(data.get("trigger_radius", 7.0 if mode == "escort" else 24.0))
	if d < trigger and not p.is_dead() and _may_begin():
		_begin()


## A quest's encounter only starts on the step that asks for it: meeting
## the escort early must not burn the encounter before its stage (that
## would be a dead end). Standalone encounters (events) always may.
func _may_begin() -> bool:
	var q := StringName(data.get("quest", ""))
	if q == &"":
		return true
	if not Quests.is_active(q):
		return false
	for o in Quests.current_stage(q).get("objectives", []):
		if StringName(o.get("target", "")) == enc_id:
			return true
	return false


func _begin() -> void:
	phase = Phase.ACTIVE
	_wave = 0
	_wave_delay = 1.2
	_time = 0.0
	_outside_t = 0.0
	_spawn_t = 1.5
	_spawn_i = 0
	_ambushed.clear()
	if actor:
		actor.shout("")
		if mode == "escort":
			actor.cowering = false
			actor.follow(path.duplicate())
			_path_len = path.size()
			actor.arrived.connect(_succeed, CONNECT_ONE_SHOT)
	var lines: Array = data.get("start_lines", [])
	if not lines.is_empty():
		EventBus.dialogue_requested.emit(String(data.get("speaker", actor.type.name_key if actor and actor.type else "")), PackedStringArray(lines))
	Audio.play_ui(&"encounter", -3.0)
	Audio.play_at(&"creature_alert", _focus_point(), 0.0)


func _active(p: Player, delta: float) -> void:
	if p.is_dead():
		_fail()
		return
	_alive = _alive.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not (c as Creature).is_dead())
	var leave := float(data.get("abandon_radius", 110.0))
	if p.global_position.distance_to(_focus_point()) > leave:
		_fail()
		return
	match mode:
		"survive":
			_time += delta
			var r := float(data.get("radius", 18.0))
			if Vector2(p.global_position.x - center.x, p.global_position.z - center.z).length() > r:
				if _outside_t <= 0.0:
					EventBus.toast.emit(tr("ENC_RETURN"))
				_outside_t += delta
				if _outside_t > 5.0:
					_fail()
					return
			else:
				_outside_t = 0.0
			_spawn_t -= delta
			var waves: Array = data.get("waves", [])
			if _spawn_t <= 0.0 and not waves.is_empty() and _alive.size() < int(data.get("max_alive", 5)):
				_spawn_t = float(data.get("interval", 8.0))
				_spawn_group(waves[_spawn_i % waves.size()], false)
				_spawn_i += 1
			var dur := float(data.get("duration", 60.0))
			_hud(tr(data.get("title_key", "ENC_SURVIVE")), "%d:%02d" % [floori((dur - _time) / 60.0), int(dur - _time) % 60], clampf(1.0 - _time / dur, 0.0, 1.0))
			if _time >= dur:
				_succeed()
		"escort":
			var waitd := float(data.get("wait_distance", 22.0))
			if actor == null:
				_succeed()
				return
			var far := p.global_position.distance_to(actor.global_position) > waitd
			if far and actor.walking:
				actor.walking = false
				actor.shout("SHOUT_WAIT")
			elif not far and not actor.walking and not actor.path.is_empty():
				actor.walking = true
				actor.shout("")
			var reached: int = _path_len - actor.path.size()
			for i in (data.get("ambushes", []) as Array).size():
				var am: Dictionary = data["ambushes"][i]
				if not _ambushed.has(i) and reached >= int(am.get("at", 1)):
					_ambushed[i] = true
					_spawn_group(am, true)
					actor.walking = false
					actor.cowering = true
					actor.shout("SHOUT_AMBUSH")
			if actor.cowering and _alive.is_empty() and not _ambushed.is_empty():
				actor.cowering = false
				actor.shout("")
				if not far:
					actor.walking = true
			if actor.cowering and not _alive.is_empty():
				actor.walking = false
			var left := 0.0
			var prev: Vector3 = actor.global_position
			for q in actor.path:
				left += prev.distance_to(q)
				prev = q
			_hud(tr(data.get("title_key", "ENC_ESCORT")), tr("ENC_METRES_LEFT") % int(left), actor.health / actor.max_health)
		_:
			# protect: waves until the last one falls.
			var waves: Array = data.get("waves", [])
			if _alive.is_empty():
				_wave_delay -= delta
				if _wave_delay <= 0.0:
					if _wave >= waves.size():
						_succeed()
						return
					_spawn_group(waves[_wave], true)
					_wave += 1
					_wave_delay = float(waves[_wave].get("delay", 2.5)) if _wave < waves.size() else 1.0
			var hp: float = actor.health / actor.max_health if actor else 1.0
			_hud(tr(data.get("title_key", "ENC_PROTECT")), tr("ENC_WAVE") % [maxi(_wave, 1), waves.size()], hp)


func _hud(title: String, detail: String, ratio: float) -> void:
	EventBus.encounter_hud.emit(title, detail, ratio)


func _spawn_group(g: Dictionary, focus_actor: bool) -> void:
	if spawner == null:
		return
	var ent := StringName(g.get("entity", ""))
	var n := int(g.get("count", 2))
	var dist := float(g.get("dist", 16.0))
	var around := _focus_point()
	if mode == "escort" and actor and not actor.path.is_empty():
		# Ambushes come from ahead on the road.
		around = around + (actor.path[0] - around).normalized() * 6.0
	var base_a := _rng.randf() * TAU
	for i in n:
		var pos := Vector3.INF
		for attempt in 8:
			var a := base_a + TAU * (i + attempt * 0.37) / maxf(n, 1)
			var q := around + Vector3(cos(a) * dist, 0, sin(a) * dist)
			q.y = floor_y(self, gen, q.x, q.z) if gen else around.y
			if q.y > WorldGen.SEA_LEVEL + 0.3:
				pos = q
				break
		if pos == Vector3.INF:
			continue
		var c := spawner.spawn_creature(ent, pos + Vector3.UP * 0.4, "", group_name)
		if c == null:
			continue
		if focus_actor and actor and not g.get("hunt_player", false):
			c.focus = actor
		c.perception.alert(Game.player.global_position)
		c.brain.change(&"chase")
		_alive.append(c)
		ElementFX.burst(self, pos + Vector3.UP * 0.3, StringName(data.get("element", "")), 1.2)


func _clear_enemies(release: bool) -> void:
	for c in _alive:
		if not is_instance_valid(c):
			continue
		if release and spawner:
			(c as Creature).focus = null
			spawner.adopt_orphan(c)
		else:
			(c as Creature).queue_free()
	_alive.clear()


func _succeed() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.DONE
	_clear_enemies(true)
	if actor and is_instance_valid(actor):
		actor.cowering = false
		actor.shout("SHOUT_THANKS")
		if data.get("vanish", false):
			# They head off (into the lodge, home...) — no double at the door.
			var a := actor
			var t := a.create_tween()
			t.tween_interval(3.0)
			t.tween_property(a, "scale", Vector3(0.05, 0.05, 0.05), 0.5)
			t.tween_callback(a.queue_free)
	var lines: Array = data.get("end_lines", [])
	if not lines.is_empty():
		EventBus.dialogue_requested.emit(String(data.get("speaker", actor.type.name_key if actor and actor.type else "")), PackedStringArray(lines))
	EventBus.encounter_hud.emit(tr(data.get("title_key", "ENC_PROTECT")), tr("ENC_SUCCESS"), 1.0)
	_hud_t = 2.5
	if data.get("once", true):
		WorldState.flags["qe:" + String(enc_id)] = true
	if data.has("reward"):
		var source := "enc:" + String(enc_id)
		if not data.get("once", true):
			source += ":%d" % Clock.day
		Rewards.grant(data["reward"], source)
	Audio.play_ui(&"quest_stage", -2.0)
	EventBus.encounter_finished.emit(enc_id, true)


func _fail() -> void:
	if phase != Phase.ACTIVE:
		return
	_clear_enemies(false)
	phase = Phase.IDLE
	_cooldown = 8.0
	EventBus.encounter_hud.emit("", "", 0.0)
	# Fresh actor at the start (a fallen one keeps its death pose otherwise).
	if actor and is_instance_valid(actor):
		actor.queue_free()
	actor = null
	_make_actor()
	var bound := false
	for id in Quests.active_quests():
		for o in Quests.current_stage(id).get("objectives", []):
			if StringName(o.get("target", "")) == enc_id:
				bound = true
	if not bound:
		EventBus.toast.emit(tr("ENC_FAILED"))
	EventBus.encounter_finished.emit(enc_id, false)


func _exit_tree() -> void:
	if phase == Phase.ACTIVE:
		EventBus.encounter_hud.emit("", "", 0.0)
		_clear_enemies(false)


## Walkable height at x/z: terrain, or a terrace / arena floor a little
## above it (never a roof: the probe starts just 3 m over the terrain).
static func floor_y(ctx: Node3D, g: WorldGen, x: float, z: float) -> float:
	var base := g.height(x, z)
	if ctx == null or not ctx.is_inside_tree():
		return base
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, base + 3.0, z), Vector3(x, base - 2.0, z), 1)
	var hit := ctx.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else base
