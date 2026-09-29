extends Node
## Quest system (data/quests.json).
##
## A quest is a list of stages; a stage completes when all of its objectives
## are done, then the next stage starts. Objectives listen to EventBus
## (kills, items, discoveries, chests, talks, bosses, flags, abilities,
## regions, cooking) or poll the player position ("reach"). Nothing else in
## the game knows about quests: systems keep emitting their usual events.
##
## States: locked (prerequisites missing) → available → active → completed.
## "start" decides how an available quest begins: "auto" (as soon as it is
## available), "talk:<NPC_ID>" (talking to that NPC), or "event" (its first
## objective being met starts it silently — e.g. finding a place).
##
## Saved as {quests: {id: {state, stage, progress: [..]}}, tracked}.

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED }

const OBJ_TYPES := [&"talk", &"discover", &"kill", &"collect", &"open_chest", &"boss", &"flag", &"ability", &"region", &"reach", &"cook", &"mount"]

var defs: Dictionary = {}          # id -> quest dictionary (from data)
var order: Array[StringName] = []  # data order (journal ordering)
var state: Dictionary = {}         # id -> {"state": State, "stage": int, "progress": Array}
var tracked: StringName = &""
var _reach_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_defs()
	reset()
	EventBus.entity_killed.connect(func(type_id: StringName, _p: Vector3) -> void: notify(&"kill", type_id))
	EventBus.item_acquired.connect(func(item_id: StringName, _c: int) -> void: notify(&"collect", item_id))
	EventBus.inventory_changed.connect(func() -> void: notify(&"collect", &""))
	EventBus.poi_discovered.connect(func(poi_id: StringName) -> void: notify(&"discover", poi_id))
	EventBus.chest_opened.connect(func(chest_id: String, _items: Array) -> void: notify(&"open_chest", StringName(chest_id)))
	EventBus.region_entered.connect(func(region: StringName) -> void: notify(&"region", region))
	EventBus.recipe_discovered.connect(func(item: StringName) -> void: notify(&"cook", item))
	EventBus.npc_talked.connect(_on_talk)
	EventBus.boss_defeated.connect(func(boss_id: StringName) -> void: notify(&"boss", boss_id))
	EventBus.flag_set.connect(func(flag: StringName) -> void: notify(&"flag", flag))
	EventBus.ability_unlocked.connect(func(ability: StringName) -> void: notify(&"ability", ability))
	EventBus.mount_tamed.connect(func(mount_id: StringName) -> void: notify(&"mount", mount_id))


func _load_defs() -> void:
	for q in DB.quests:
		var id := StringName(q["id"])
		defs[id] = q
		order.append(id)


func reset() -> void:
	state.clear()
	tracked = &""
	for id in order:
		state[id] = {"state": State.LOCKED, "stage": 0, "progress": []}
	_refresh_availability()


# --- Queries ----------------------------------------------------------------------------------------

func quest_state(id: StringName) -> int:
	return state.get(id, {}).get("state", State.LOCKED)


func is_active(id: StringName) -> bool:
	return quest_state(id) == State.ACTIVE


func is_completed(id: StringName) -> bool:
	return quest_state(id) == State.COMPLETED


func active_quests() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in order:
		if quest_state(id) == State.ACTIVE:
			out.append(id)
	return out


func completed_quests() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in order:
		if quest_state(id) == State.COMPLETED:
			out.append(id)
	return out


func current_stage(id: StringName) -> Dictionary:
	var q: Dictionary = defs.get(id, {})
	var stages: Array = q.get("stages", [])
	var i: int = state.get(id, {}).get("stage", 0)
	return stages[i] if i < stages.size() else {}


## [{text, done, count, need}] for the current stage (journal / tracker).
func objective_lines(id: StringName) -> Array:
	var out: Array = []
	var st: Dictionary = state.get(id, {})
	var objs: Array = current_stage(id).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		var need := int(o.get("count", 1))
		var have: int = st["progress"][i] if i < st["progress"].size() else 0
		out.append({"text": tr(o.get("text_key", "")), "done": have >= need, "count": have, "need": need})
	return out


## World position of the tracked quest's next unfinished objective (for the
## compass and the map), or null when it has none.
func tracked_target() -> Variant:
	if tracked == &"" or not is_active(tracked):
		return null
	var st: Dictionary = state[tracked]
	var objs: Array = current_stage(tracked).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		if st["progress"][i] >= int(o.get("count", 1)):
			continue
		if o.has("marker"):
			var m: Array = o["marker"]
			return Vector3(m[0], 0, m[1])
		if o["type"] in ["discover", "reach"] and o.has("target"):
			var p: Variant = _poi_pos(String(o["target"]))
			if p != null:
				return p
		if o.has("pos"):
			return Vector3(o["pos"][0], 0, o["pos"][1])
	return null


func _poi_pos(poi_id: String) -> Variant:
	for poi in DB.world.get("pois", []):
		if poi["id"] == poi_id:
			return Vector3(poi["pos"][0], 0, poi["pos"][1])
	return null


# --- Flow -------------------------------------------------------------------------------------------

func start(id: StringName, silent: bool = false) -> bool:
	if not defs.has(id) or quest_state(id) != State.AVAILABLE:
		return false
	state[id]["state"] = State.ACTIVE
	_enter_stage(id, 0)
	if tracked == &"" or defs[id].get("type", "side") == "main":
		tracked = id
	EventBus.quest_started.emit(id)
	if not silent:
		Audio.play_ui(&"quest_start", -3.0)
	# Objectives may already be satisfied (items held, place already found).
	_evaluate_all(id)
	return true


func set_tracked(id: StringName) -> void:
	if is_active(id):
		tracked = id
		EventBus.quest_updated.emit(id)


## Generic entry point: any system may report an event by type + id.
func notify(kind: StringName, target: StringName) -> void:
	for id in order:
		var s: int = quest_state(id)
		if s == State.AVAILABLE and String(defs[id].get("start", "auto")) == "event":
			# Event-started quests begin when their first objective is met.
			var first: Array = (defs[id]["stages"][0] as Dictionary).get("objectives", [])
			if not first.is_empty() and _matches(first[0], kind, target):
				start(id, true)
			continue
		if s != State.ACTIVE:
			continue
		var objs: Array = current_stage(id).get("objectives", [])
		var changed := false
		for i in objs.size():
			var o: Dictionary = objs[i]
			if kind == &"collect" and o["type"] == "collect":
				changed = _update_collect(id, i, o) or changed
			elif _matches(o, kind, target):
				var need := int(o.get("count", 1))
				if state[id]["progress"][i] < need:
					state[id]["progress"][i] += 1
					changed = true
		if changed:
			_after_progress(id)


func _matches(o: Dictionary, kind: StringName, target: StringName) -> bool:
	if StringName(o.get("type", "")) != kind:
		return false
	var want := String(o.get("target", ""))
	return want == "" or want == "any" or StringName(want) == target


func _update_collect(id: StringName, i: int, o: Dictionary) -> bool:
	var have := PlayerData.inventory.count_of(StringName(o["target"]))
	var need := int(o.get("count", 1))
	var v := mini(have, need)
	if state[id]["progress"][i] != v:
		state[id]["progress"][i] = v
		return true
	return false


func _evaluate_all(id: StringName) -> void:
	if not is_active(id):
		return
	var objs: Array = current_stage(id).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		match String(o["type"]):
			"collect":
				_update_collect(id, i, o)
			"discover":
				if WorldState.is_poi_discovered(String(o["target"])):
					state[id]["progress"][i] = 1
			"flag":
				if WorldState.flags.has(String(o["target"])):
					state[id]["progress"][i] = 1
			"ability":
				if PlayerData.abilities.has(String(o["target"])):
					state[id]["progress"][i] = 1
			"open_chest":
				if WorldState.opened.has(String(o["target"])):
					state[id]["progress"][i] = 1
			"boss":
				if WorldState.flags.has("boss_" + String(o["target"])):
					state[id]["progress"][i] = 1
			"mount":
				if WorldState.flags.has("mount_" + String(o["target"])):
					state[id]["progress"][i] = 1
	_after_progress(id)


func _after_progress(id: StringName) -> void:
	EventBus.quest_updated.emit(id)
	var objs: Array = current_stage(id).get("objectives", [])
	for i in objs.size():
		if state[id]["progress"][i] < int((objs[i] as Dictionary).get("count", 1)):
			return
	# Stage complete
	var stage: Dictionary = current_stage(id)
	if stage.has("on_complete_flag"):
		set_flag(StringName(stage["on_complete_flag"]))
	var next: int = state[id]["stage"] + 1
	if next < (defs[id]["stages"] as Array).size():
		_enter_stage(id, next)
		EventBus.quest_stage_advanced.emit(id, next)
		Audio.play_ui(&"quest_stage", -4.0)
		_evaluate_all(id)
	else:
		_complete(id)


func _enter_stage(id: StringName, i: int) -> void:
	state[id]["stage"] = i
	var objs: Array = (defs[id]["stages"][i] as Dictionary).get("objectives", [])
	var prog := []
	prog.resize(objs.size())
	prog.fill(0)
	state[id]["progress"] = prog


func _complete(id: StringName) -> void:
	state[id]["state"] = State.COMPLETED
	var r: Dictionary = defs[id].get("rewards", {})
	for it in r.get("items", []):
		var n := int(it.get("count", 1))
		PlayerData.inventory.add(StringName(it["id"]), n)
		EventBus.item_acquired.emit(StringName(it["id"]), n)
	if r.has("glimmer"):
		PlayerData.glimmer += int(r["glimmer"])
	if r.has("ability"):
		PlayerData.unlock_ability(StringName(r["ability"]))
	if r.has("flag"):
		set_flag(StringName(r["flag"]))
	if r.has("max_stamina"):
		PlayerData.max_stamina += float(r["max_stamina"])
	if r.has("max_health"):
		PlayerData.max_health += float(r["max_health"])
		PlayerData.heal(PlayerData.max_health, true)
	EventBus.quest_completed.emit(id)
	Audio.play_ui(&"quest_complete", -1.0)
	if tracked == id:
		var act := active_quests()
		tracked = act[0] if not act.is_empty() else &""
	_refresh_availability()


func set_flag(flag: StringName) -> void:
	if WorldState.flags.has(String(flag)):
		return
	WorldState.flags[String(flag)] = true
	EventBus.flag_set.emit(flag)


func _refresh_availability() -> void:
	for id in order:
		if quest_state(id) != State.LOCKED:
			continue
		var ok := true
		for pre in defs[id].get("requires", []):
			if not is_completed(StringName(pre)):
				ok = false
		if ok:
			state[id]["state"] = State.AVAILABLE
	for id in order:
		if quest_state(id) == State.AVAILABLE and String(defs[id].get("start", "auto")) == "auto" and Game.is_playing():
			start(id)


## Called by NPCTalk. Returns dialogue override lines for this NPC (quest
## offer, progress hint or turn-in), or an empty array.
func talk_lines(npc_id: StringName) -> PackedStringArray:
	for id in order:
		var q: Dictionary = defs[id]
		var s: int = quest_state(id)
		if s == State.AVAILABLE and String(q.get("start", "")) == "talk:" + String(npc_id):
			start(id)
			return PackedStringArray(q.get("offer_lines", []))
		if s == State.ACTIVE:
			var stage := current_stage(id)
			for o in stage.get("objectives", []):
				if o["type"] == "talk" and StringName(o.get("target", "")) == npc_id:
					return PackedStringArray(stage.get("talk_lines", q.get("offer_lines", [])))
			if String(q.get("start", "")) == "talk:" + String(npc_id) and stage.has("hint_lines"):
				return PackedStringArray(stage["hint_lines"])
	return PackedStringArray()


func _on_talk(npc_id: StringName) -> void:
	notify(&"talk", npc_id)


func _process(delta: float) -> void:
	if not Game.is_playing() or Game.player == null:
		return
	_reach_timer -= delta
	if _reach_timer > 0.0:
		return
	_reach_timer = 0.5
	var p := Game.player.global_position
	for id in active_quests():
		var objs: Array = current_stage(id).get("objectives", [])
		for i in objs.size():
			var o: Dictionary = objs[i]
			if o["type"] != "reach" or state[id]["progress"][i] >= 1:
				continue
			var t: Variant = Vector3(o["pos"][0], 0, o["pos"][1]) if o.has("pos") else _poi_pos(String(o.get("target", "")))
			if t != null and Vector2(p.x - t.x, p.z - t.z).length() < float(o.get("radius", 20.0)):
				state[id]["progress"][i] = 1
				_after_progress(id)


## First frame of a new game: auto quests start once the world is up.
func on_game_started() -> void:
	_refresh_availability()
	for id in active_quests():
		_evaluate_all(id)


# --- Save ------------------------------------------------------------------------------------------

func save_state() -> Dictionary:
	var out := {}
	for id in order:
		var st: Dictionary = state[id]
		if st["state"] != State.LOCKED:
			out[String(id)] = {"state": st["state"], "stage": st["stage"], "progress": st["progress"]}
	return {"quests": out, "tracked": String(tracked)}


func load_state(d: Dictionary) -> void:
	reset()
	var qs: Dictionary = d.get("quests", {})
	for key in qs:
		var id := StringName(key)
		if not defs.has(id):
			continue   # quest removed from data: ignore
		var st: Dictionary = qs[key]
		state[id]["state"] = int(st.get("state", State.LOCKED))
		var stages: Array = defs[id]["stages"]
		state[id]["stage"] = clampi(int(st.get("stage", 0)), 0, stages.size() - 1)
		var need: int = (stages[state[id]["stage"]] as Dictionary).get("objectives", []).size()
		var prog: Array = st.get("progress", [])
		prog.resize(need)
		for i in need:
			prog[i] = int(prog[i]) if prog[i] != null else 0
		state[id]["progress"] = prog
	tracked = StringName(d.get("tracked", ""))
	_refresh_availability()
