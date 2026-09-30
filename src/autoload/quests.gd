extends Node
## Quest system — data-driven (data/quests/*.json). See docs/QUESTS.md.
##
## A quest is a list of STAGES; a stage completes when all of its required
## OBJECTIVES are done, then the next stage starts. Objectives are reusable
## types that listen to EventBus facts emitted by the gameplay systems
## (kills, gathers, crafts, discoveries, abilities, puzzles...), are checked
## against the current world state on entering a stage, or are polled from
## the player's position/state (reach, climb, glide, swim). Nothing else in
## the game knows about quests.
##
## Lifecycle: LOCKED (prerequisites missing) → AVAILABLE → ACTIVE →
## COMPLETED, or COOLDOWN → AVAILABLE again for repeatable quests.
## Starts: "auto" · "talk:<NPC>" · "event" (first objective met) ·
## "interact:<object>" (a discovery object placed while the quest is
## available) · "poi:<id>" · "flag:<flag>" · "board" (bounty boards).
## Failing an escort/protect/survive stage only resets that stage: a quest
## can never be permanently blocked (the journal can also restart a stage).

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED, COOLDOWN }

## Brief/designer names → canonical objective types.
const ALIASES := {
	"reach_location": "reach", "defeat_enemy": "kill", "hunt": "kill", "defeat_boss": "boss",
	"collect_item": "collect", "gather_material": "gather", "investigate": "interact",
	"activate": "interact", "rescue": "interact", "use_ability": "ability_use",
	"solve_puzzle": "puzzle", "defeat_group": "clear",
}
## Every canonical objective type (validated by DB.validate()).
const TYPES := [
	"reach", "kill", "clear", "boss", "collect", "gather", "deliver", "retrieve", "interact",
	"destroy", "discover", "region", "talk", "flag", "puzzle", "ability", "ability_use", "craft",
	"cook", "mount", "open_chest", "climb", "glide", "swim", "escort", "protect", "survive",
	"course", "sneak", "event",
]
## Types satisfied by the player's position/state (polled twice a second).
const POLLED := ["reach", "climb", "glide", "swim"]

var defs: Dictionary = {}          # id -> quest dictionary (from data)
var order: Array[StringName] = []  # data order (journal ordering)
## id -> {state, stage, progress: [int], bonus_ok, completions, available_at, metric: [float]}
var state: Dictionary = {}
var tracked: StringName = &""
## Categories of the last bounties finished (anti-repetition for offers).
var recent_categories: Array = []
var _poll_timer := 0.0
var _last_pos := Vector3.INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_defs()
	reset()
	EventBus.entity_killed.connect(func(type_id: StringName, _p: Vector3) -> void: notify(&"kill", type_id))
	EventBus.creature_defeated.connect(func(type_id: StringName, group: String, sneak: bool) -> void:
		if group != "":
			notify(&"clear", StringName(group))
		if sneak:
			notify(&"sneak", type_id))
	EventBus.item_acquired.connect(func(_i: StringName, _c: int) -> void: _refresh_counts())
	EventBus.inventory_changed.connect(_refresh_counts)
	EventBus.resource_gathered.connect(func(node_type: StringName, _p: Vector3) -> void: notify(&"gather", node_type))
	EventBus.poi_discovered.connect(func(poi_id: StringName) -> void:
		notify(&"discover", poi_id)
		_try_start_by(&"poi", poi_id))
	EventBus.chest_opened.connect(func(chest_id: String, _items: Array) -> void: notify(&"open_chest", StringName(chest_id)))
	EventBus.region_entered.connect(func(region: StringName) -> void: notify(&"region", region))
	EventBus.dish_cooked.connect(func(item: StringName) -> void: notify(&"cook", item))
	EventBus.item_crafted.connect(func(item: StringName) -> void: notify(&"craft", item))
	EventBus.npc_talked.connect(_on_talk)
	EventBus.boss_defeated.connect(func(boss_id: StringName) -> void: notify(&"boss", boss_id))
	EventBus.flag_set.connect(func(flag: StringName) -> void:
		notify(&"flag", flag)
		if String(flag).begins_with("puzzle_"):
			notify(&"puzzle", StringName(String(flag).trim_prefix("puzzle_")))
		_try_start_by(&"flag", flag))
	EventBus.ability_unlocked.connect(func(ability: StringName) -> void: notify(&"ability", ability))
	EventBus.ability_used.connect(func(ability: StringName) -> void:
		if ability != &"":
			notify(&"ability_use", ability))
	EventBus.mount_tamed.connect(func(mount_id: StringName) -> void: notify(&"mount", mount_id))
	EventBus.quest_object_used.connect(func(obj: StringName, group: StringName) -> void:
		# Start first: the object that begins a quest also counts for it.
		_try_start_by(&"interact", obj)
		notify(&"interact", obj, group)
		notify(&"retrieve", obj, group))
	EventBus.quest_object_destroyed.connect(func(obj: StringName, group: StringName) -> void: notify(&"destroy", obj, group))
	EventBus.encounter_finished.connect(_on_encounter)
	EventBus.course_finished.connect(func(course: StringName, seconds: float) -> void: notify(&"course", course, &"", seconds))
	EventBus.quest_event.connect(func(ev: StringName) -> void: notify(&"event", ev))
	EventBus.time_period_changed.connect(func(_p: StringName) -> void: _refresh_availability())
	EventBus.weather_changed.connect(func(_w: StringName) -> void: _refresh_availability())


func _load_defs() -> void:
	defs.clear()
	order.clear()
	for q in DB.quests:
		var id := StringName(q["id"])
		defs[id] = q
		order.append(id)


func reset() -> void:
	state.clear()
	tracked = &""
	recent_categories.clear()
	for id in order:
		state[id] = _blank()
	_refresh_availability()


func _blank() -> Dictionary:
	return {"state": State.LOCKED, "stage": 0, "progress": [], "metric": [], "bonus_ok": true, "completions": 0, "available_at": 0.0}


# --- Queries ------------------------------------------------------------------------------------------

func quest_state(id: StringName) -> int:
	return state.get(id, {}).get("state", State.LOCKED)


func is_active(id: StringName) -> bool:
	return quest_state(id) == State.ACTIVE


func is_completed(id: StringName) -> bool:
	return quest_state(id) == State.COMPLETED or int(state.get(id, {}).get("completions", 0)) > 0 and quest_state(id) == State.COOLDOWN


func completions(id: StringName) -> int:
	return int(state.get(id, {}).get("completions", 0))


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


## Available quests the journal lists as rumours: talk-started, not hidden,
## with their giver — "what can I do now?" without map icon soup.
func rumors() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in order:
		var q: Dictionary = defs[id]
		if quest_state(id) == State.AVAILABLE and not q.get("hidden", false) and String(q.get("start", "auto")).begins_with("talk:"):
			out.append(id)
	return out


func def(id: StringName) -> Dictionary:
	return defs.get(id, {})


func current_stage(id: StringName) -> Dictionary:
	var stages: Array = defs.get(id, {}).get("stages", [])
	var i: int = state.get(id, {}).get("stage", 0)
	return stages[i] if i < stages.size() else {}


static func canon(o: Dictionary) -> String:
	var t := String(o.get("type", ""))
	return ALIASES.get(t, t)


static func need_of(o: Dictionary) -> int:
	return maxi(int(o.get("count", 1)), 1)


## [{text, done, count, need, optional}] for the current stage (journal / tracker).
func objective_lines(id: StringName) -> Array:
	var out: Array = []
	var st: Dictionary = state.get(id, {})
	var objs: Array = current_stage(id).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		var need := need_of(o)
		var have: int = st["progress"][i] if i < st.get("progress", []).size() else 0
		out.append({"text": objective_text(o), "done": have >= need, "count": have, "need": need, "optional": o.get("optional", false)})
	return out


## Objective line: its own key, or a shared template ("Defeat %s") filled
## with translated arguments (entity / item / place names).
static func objective_text(o: Dictionary) -> String:
	var txt := TranslationServer.translate(String(o.get("text_key", "")))
	var args: Array = o.get("text_args", [])
	if args.is_empty():
		return txt
	var targs: Array = []
	for a in args:
		targs.append(TranslationServer.translate(String(a)))
	if txt.count("%") != targs.size():
		return txt
	return txt % targs


## Marker for the tracked quest's next unfinished objective:
## {pos: Vector3, hint: "marked"|"area", radius} or {} (no marker / hidden).
func tracked_marker() -> Dictionary:
	if tracked == &"" or not is_active(tracked):
		return {}
	return objective_marker(tracked)


func objective_marker(id: StringName) -> Dictionary:
	var st: Dictionary = state[id]
	var objs: Array = current_stage(id).get("objectives", [])
	var q: Dictionary = defs[id]
	for i in objs.size():
		var o: Dictionary = objs[i]
		if st["progress"][i] >= need_of(o) or o.get("optional", false):
			continue
		var default_hint := "marked" if q.get("type", "side") in ["main", "bounty"] or String(q.get("start", "")).begins_with("talk:") else "area"
		var hint := String(o.get("hint", default_hint))
		if hint == "none":
			return {}
		var p: Variant = objective_position(id, o)
		if p == null:
			continue
		return {"pos": p, "hint": hint, "radius": float(o.get("area_radius", 60.0))}
	return {}


## Kept for older callers: position of the tracked marker or null.
func tracked_target() -> Variant:
	var m := tracked_marker()
	return m.get("pos") if not m.is_empty() else null


## Best-known world position for an objective (marker, explicit position,
## POI, a stage spawn with that id, or the NPC's home POI).
func objective_position(id: StringName, o: Dictionary) -> Variant:
	if o.has("marker"):
		return _v3(o["marker"])
	if o.has("pos"):
		return _v3(o["pos"])
	var t := String(o.get("target", ""))
	var c := canon(o)
	if c in ["discover", "reach", "climb"] and t != "":
		var p: Variant = poi_pos(t)
		if p != null:
			return p
	for sp in current_stage(id).get("spawns", []):
		if String(sp.get("id", "")) == t or String(sp.get("group", "")) == t or ("q:%s:%s" % [id, sp.get("id", "")]) == t:
			if sp.has("pos"):
				return _v3(sp["pos"])
			if sp.has("path"):
				return _v3((sp["path"] as Array).back())
	if c in ["talk", "deliver"] and t != "":
		return npc_home(StringName(t))
	return null


static func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(arr[0], 0, arr[1]) if arr.size() == 2 else Vector3(arr[0], arr[1], arr[2])


func poi_pos(poi_id: String) -> Variant:
	for poi in DB.world.get("pois", []):
		if poi["id"] == poi_id:
			return Vector3(poi["pos"][0], 0, poi["pos"][1])
	return null


## Where an NPC normally is: its live node if streamed in, else the POI that
## lists it.
func npc_home(npc_id: StringName) -> Variant:
	var tree := get_tree()
	if tree:
		for n in tree.get_nodes_in_group(&"npcs"):
			var c := n as Creature
			if c and c.type and c.type.id == npc_id:
				return c.global_position
	for poi in DB.world.get("pois", []):
		for n in poi.get("npcs", []):
			if StringName(n[0]) == npc_id:
				return Vector3(poi["pos"][0] + float(n[1]), 0, poi["pos"][1] + float(n[2]))
	return null


# --- Flow -----------------------------------------------------------------------------------------------

func start(id: StringName, silent: bool = false) -> bool:
	if not defs.has(id) or quest_state(id) != State.AVAILABLE:
		return false
	state[id]["state"] = State.ACTIVE
	state[id]["bonus_ok"] = true
	_enter_stage(id, 0)
	if tracked == &"" or defs[id].get("type", "side") == "main":
		tracked = id
	EventBus.quest_started.emit(id)
	if not silent:
		Audio.play_ui(&"quest_start", -3.0)
	_evaluate_all(id)
	return true


func set_tracked(id: StringName) -> void:
	if is_active(id):
		tracked = id
		EventBus.quest_updated.emit(id)


## Generic entry point: any system may report a fact by kind + id.
## `group` lets objectives target a family (clue group, spawn group).
func notify(kind: StringName, target: StringName, group: StringName = &"", value: float = 0.0) -> void:
	for id in order:
		var s: int = quest_state(id)
		if s == State.AVAILABLE and String(defs[id].get("start", "auto")) == "event" and _start_ok(defs[id]):
			# Discovery quests begin with the very fact that reveals them
			# (first chime rung, rare creature felled...), which also counts.
			var first: Array = (defs[id]["stages"][0] as Dictionary).get("objectives", [])
			if first.is_empty() or not _matches(first[0], kind, target, group) or not _conditions_ok(first[0]) or not start(id, true):
				continue
			EventBus.toast.emit(tr("QUEST_DISCOVERED") % tr(defs[id].get("title_key", "")))
			s = State.ACTIVE
		if s != State.ACTIVE:
			continue
		var objs: Array = current_stage(id).get("objectives", [])
		var changed := false
		for i in objs.size():
			var o: Dictionary = objs[i]
			if not _matches(o, kind, target, group):
				continue
			if not _conditions_ok(o):
				continue
			if kind == &"course" and o.has("par") and value > float(o["par"]):
				continue
			var need := need_of(o)
			if state[id]["progress"][i] < need:
				state[id]["progress"][i] += 1
				changed = true
		if changed:
			var before: int = state[id]["stage"]
			_after_progress(id)
			# A course time is a result, not an action: the run that finishes
			# one stage ("finish the course") is also checked against the next
			# ("finish under par").
			if kind == &"course" and is_active(id) and int(state[id]["stage"]) != before:
				var nobjs: Array = current_stage(id).get("objectives", [])
				var again := false
				for i in nobjs.size():
					var o: Dictionary = nobjs[i]
					if _matches(o, kind, target, group) and (not o.has("par") or value <= float(o["par"])) and state[id]["progress"][i] < need_of(o):
						state[id]["progress"][i] += 1
						again = true
				if again:
					_after_progress(id)


func _matches(o: Dictionary, kind: StringName, target: StringName, group: StringName = &"") -> bool:
	if StringName(canon(o)) != kind:
		return false
	var want := String(o.get("target", ""))
	if want == "" or want == "any":
		return true
	if want.begins_with("group:"):
		return StringName(want.trim_prefix("group:")) == group
	return StringName(want) == target


## Conditions an objective may require at the moment it is met:
## {period: "night"|"day", weather: [ids], state: "glide"|"swim"|"climb"|"ride",
##  min_y: metres, region: id, tide: "low"|"high"}
func _conditions_ok(o: Dictionary) -> bool:
	var c: Dictionary = o.get("conditions", {})
	if c.is_empty():
		return true
	if c.has("period"):
		if (c["period"] == "night") != Clock.is_night():
			return false
	if c.has("weather") and not String(Weather.target) in c["weather"]:
		return false
	var p := Game.player as Player
	if c.has("state") and (p == null or p.state_name() != StringName(c["state"])):
		return false
	if c.has("min_y") and (p == null or p.global_position.y < float(c["min_y"])):
		return false
	if c.has("region") and (p == null or p.region != StringName(c["region"])):
		return false
	if c.has("tide") and not QuestSpawner._tide_ok(String(c["tide"])):
		return false
	return true


## Start conditions of auto/event quests: {period, weather, region}.
func _start_ok(q: Dictionary) -> bool:
	var c: Dictionary = q.get("start_when", {})
	if c.is_empty():
		return true
	if c.has("period") and (c["period"] == "night") != Clock.is_night():
		return false
	if c.has("weather") and not String(Weather.target) in c["weather"]:
		return false
	if c.has("region"):
		var p := Game.player as Player
		if p == null or p.region != StringName(c["region"]):
			return false
	return true


func _try_start_by(kind: StringName, what: StringName) -> void:
	var key := "%s:%s" % [kind, what]
	for id in order:
		if quest_state(id) == State.AVAILABLE and String(defs[id].get("start", "")) == key and _start_ok(defs[id]):
			start(id)


## Count-type objectives mirror what the player holds right now.
func _refresh_counts() -> void:
	for id in order:
		if quest_state(id) != State.ACTIVE:
			continue
		var changed := false
		var objs: Array = current_stage(id).get("objectives", [])
		for i in objs.size():
			if canon(objs[i]) == "collect":
				var v := mini(PlayerData.inventory.count_of(StringName(objs[i]["target"])), need_of(objs[i]))
				if state[id]["progress"][i] != v:
					state[id]["progress"][i] = v
					changed = true
		if changed:
			_after_progress(id)


## Objectives already true in the current world state (checked on entering a
## stage, on start and on load: nothing can be missed by being early).
func _evaluate_all(id: StringName) -> void:
	if not is_active(id):
		return
	var objs: Array = current_stage(id).get("objectives", [])
	var p := Game.player as Player
	for i in objs.size():
		var o: Dictionary = objs[i]
		var t := String(o.get("target", ""))
		var done := false
		match canon(o):
			"collect":
				state[id]["progress"][i] = mini(PlayerData.inventory.count_of(StringName(t)), need_of(o))
			"discover":
				done = WorldState.is_poi_discovered(t)
			"flag":
				done = WorldState.flags.has(t)
			"puzzle":
				done = WorldState.flags.has("puzzle_" + t)
			"ability":
				done = PlayerData.has_ability(StringName(t))
			"open_chest":
				done = WorldState.opened.has(t)
			"boss":
				done = WorldState.flags.has("boss_" + t)
			"mount":
				done = WorldState.flags.has("mount_" + t)
			"region":
				done = p != null and p.region == StringName(t)
			"interact", "retrieve":
				done = WorldState.flags.has("qo:" + t) and not o.has("count")
			"destroy":
				done = WorldState.flags.has("qd:" + t) and not o.has("count")
		if done:
			state[id]["progress"][i] = need_of(o)
	_after_progress(id)


func _after_progress(id: StringName) -> void:
	EventBus.quest_updated.emit(id)
	var objs: Array = current_stage(id).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		if not o.get("optional", false) and state[id]["progress"][i] < need_of(o):
			return
	# Stage complete: optional objectives left undone forfeit the bonus.
	for i in objs.size():
		if objs[i].get("optional", false) and state[id]["progress"][i] < need_of(objs[i]):
			state[id]["bonus_ok"] = false
	var stage: Dictionary = current_stage(id)
	if stage.has("rewards"):
		Rewards.grant(stage["rewards"], "quest:%s:%d:s%d" % [id, int(state[id]["completions"]) + 1, int(state[id]["stage"])])
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
	var met := []
	met.resize(objs.size())
	met.fill(0.0)
	state[id]["metric"] = met


## Escort / protect / survive failed: the stage restarts (never a dead end).
func fail_stage(id: StringName, reason: String = "") -> void:
	if not is_active(id):
		return
	_enter_stage(id, state[id]["stage"])
	EventBus.quest_failed.emit(id, reason)
	EventBus.toast.emit(tr("QUEST_STAGE_RETRY"))
	_evaluate_all(id)


## Journal safety valve: restart the current stage (respawns its content).
func restart_stage(id: StringName) -> void:
	fail_stage(id, "restart")


func _on_encounter(enc: StringName, success: bool) -> void:
	for id in active_quests():
		for o in current_stage(id).get("objectives", []):
			if canon(o) in ["escort", "protect", "survive"] and StringName(o.get("target", "")) == enc:
				if success:
					notify(StringName(canon(o)), enc)
				else:
					fail_stage(id, String(enc))
				return


func _complete(id: StringName) -> void:
	var q: Dictionary = defs[id]
	var n: int = state[id]["completions"] + 1
	state[id]["completions"] = n
	if q.get("repeatable", false):
		state[id]["state"] = State.COOLDOWN
		state[id]["available_at"] = Clock.total_hours() + float(q.get("cooldown_hours", 24.0))
	else:
		state[id]["state"] = State.COMPLETED
	var source := "quest:%s:%d" % [id, n if q.get("repeatable", false) else 1]
	Rewards.grant(q.get("rewards", {}), source)
	if state[id]["bonus_ok"] and q.has("bonus_rewards"):
		Rewards.grant(q["bonus_rewards"], source + ":bonus")
	for f in q.get("unlocks", {}).get("flags", []):
		set_flag(StringName(f))
	if q.get("type", "") == "bounty":
		recent_categories.push_front(String(q.get("category", "")))
		recent_categories.resize(mini(recent_categories.size(), 4))
	EventBus.quest_completed.emit(id)
	Audio.play_ui(&"quest_complete", -1.0)
	if tracked == id:
		tracked = _next_to_track()
	_refresh_availability()


func _next_to_track() -> StringName:
	var act := active_quests()
	for a in act:
		if defs[a].get("type", "") == "main":
			return a
	return act[0] if not act.is_empty() else &""


func set_flag(flag: StringName) -> void:
	if WorldState.flags.has(String(flag)):
		return
	WorldState.flags[String(flag)] = true
	EventBus.flag_set.emit(flag)


func _prereqs_ok(q: Dictionary) -> bool:
	for pre in q.get("requires", []):
		if not is_completed(StringName(pre)) and completions(StringName(pre)) == 0:
			return false
	for f in q.get("requires_flags", []):
		if not WorldState.flags.has(String(f)):
			return false
	for a in q.get("requires_abilities", []):
		if not PlayerData.has_ability(StringName(a)):
			return false
	return true


func _refresh_availability() -> void:
	for id in order:
		var s := quest_state(id)
		if s == State.LOCKED and _prereqs_ok(defs[id]):
			state[id]["state"] = State.AVAILABLE
		elif s == State.COOLDOWN and Clock.total_hours() >= float(state[id]["available_at"]):
			state[id]["state"] = State.AVAILABLE
	if not Game.is_playing():
		return
	for id in order:
		if quest_state(id) != State.AVAILABLE or not _start_ok(defs[id]):
			continue
		var st := String(defs[id].get("start", "auto"))
		if st == "auto":
			start(id)
		elif st.begins_with("flag:") and WorldState.flags.has(st.trim_prefix("flag:")):
			start(id)
		elif st.begins_with("poi:") and WorldState.is_poi_discovered(st.trim_prefix("poi:")):
			start(id)


## Bounties a board offers right now: available, of that board, preferring
## categories the player has not just done (anti-repetition).
func board_offers(board: String, max_count: int = 3) -> Array[StringName]:
	var pool: Array = []
	for id in order:
		var q: Dictionary = defs[id]
		if q.get("type", "") != "bounty" or quest_state(id) != State.AVAILABLE:
			continue
		if String(q.get("board", "")) != board:
			continue
		var penalty := recent_categories.find(String(q.get("category", "")))
		var score := (10.0 if penalty < 0 else float(penalty) * 2.0) + float(hash(String(id) + str(Clock.day)) % 100) / 100.0
		pool.append([score, id])
	pool.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array[StringName] = []
	var cats := {}
	for e in pool:
		var cat := String(defs[e[1]].get("category", ""))
		if cats.has(cat) and pool.size() > max_count:
			continue
		cats[cat] = true
		out.append(e[1])
		if out.size() >= max_count:
			break
	return out


## Called by NPCTalk. Returns dialogue lines for this NPC (quest offer,
## progress hint, delivery or turn-in), or an empty array.
func talk_lines(npc_id: StringName) -> PackedStringArray:
	for id in order:
		var q: Dictionary = defs[id]
		var s: int = quest_state(id)
		if s == State.AVAILABLE and String(q.get("start", "")) == "talk:" + String(npc_id) and _start_ok(q):
			start(id)
			return PackedStringArray(q.get("offer_lines", []))
		if s == State.ACTIVE:
			var stage := current_stage(id)
			var objs: Array = stage.get("objectives", [])
			for i in objs.size():
				var o: Dictionary = objs[i]
				if not canon(o) in ["talk", "deliver"] or StringName(o.get("target", "")) != npc_id:
					continue
				if int(state[id]["progress"][i]) >= need_of(o):
					continue
				if canon(o) == "deliver" and PlayerData.inventory.count_of(StringName(o.get("item", ""))) < need_of(o):
					if stage.has("hint_lines"):
						return PackedStringArray(stage["hint_lines"])
					continue
				return PackedStringArray(stage.get("talk_lines", q.get("offer_lines", [])))
			if String(q.get("start", "")) == "talk:" + String(npc_id) and stage.has("hint_lines"):
				return PackedStringArray(stage["hint_lines"])
	return PackedStringArray()


func _on_talk(npc_id: StringName) -> void:
	# Deliveries hand the items over when the player talks to the recipient.
	for id in active_quests():
		var objs: Array = current_stage(id).get("objectives", [])
		for i in objs.size():
			var o: Dictionary = objs[i]
			if canon(o) == "deliver" and StringName(o.get("target", "")) == npc_id and state[id]["progress"][i] < need_of(o):
				var item := StringName(o.get("item", ""))
				if PlayerData.inventory.count_of(item) >= need_of(o):
					PlayerData.inventory.remove(item, need_of(o))
					state[id]["progress"][i] = need_of(o)
					_after_progress(id)
					break
	notify(&"talk", npc_id)


# --- Polled objectives: reach / climb / glide / swim -----------------------------------------------------

func _process(delta: float) -> void:
	if not Game.is_playing() or Game.player == null:
		return
	_poll_timer -= delta
	if _poll_timer > 0.0:
		return
	_poll_timer = 0.5
	var p := Game.player as Player
	var pos := p.global_position
	var moved := Vector2.ZERO if _last_pos == Vector3.INF else Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z)
	var rise := 0.0 if _last_pos == Vector3.INF else pos.y - _last_pos.y
	_last_pos = pos
	var st := p.state_name()
	_poll_event_starts(pos)
	for id in active_quests():
		var objs: Array = current_stage(id).get("objectives", [])
		var changed := false
		for i in objs.size():
			var o: Dictionary = objs[i]
			var c := canon(o)
			if not c in POLLED or state[id]["progress"][i] >= need_of(o):
				continue
			if not _conditions_ok(o):
				continue
			var metric := String(o.get("metric", ""))
			if metric != "":
				# Distance/height goals: count metres while in the right state.
				var in_state := (c == "glide" and st == &"glide") or (c == "swim" and st == &"swim") or (c == "climb" and st == &"climb")
				if in_state:
					var add := rise if c == "climb" else moved.length()
					if add > 0.0 and add < 40.0:
						state[id]["metric"][i] += add
						var v := mini(int(state[id]["metric"][i]), need_of(o))
						if v != state[id]["progress"][i]:
							state[id]["progress"][i] = v
							changed = true
				continue
			var t: Variant = objective_position(id, o)
			if t == null:
				continue
			var tv: Vector3 = t
			var near := Vector2(pos.x - tv.x, pos.z - tv.z).length() < float(o.get("radius", 20.0))
			if near and o.has("min_y") and pos.y < float(o["min_y"]):
				near = false
			if near and c == "glide" and not st in [&"glide", &"air"]:
				near = false
			if near and c == "swim" and st != &"swim":
				near = false
			if near:
				state[id]["progress"][i] = need_of(o)
				changed = true
		if changed:
			_after_progress(id)


## Discovery quests that begin by walking into a place (smoke on the
## horizon, a hidden grove): available + "event" start + a "reach" first
## objective.
func _poll_event_starts(pos: Vector3) -> void:
	for id in order:
		var q: Dictionary = defs[id]
		if quest_state(id) != State.AVAILABLE or String(q.get("start", "")) != "event" or not _start_ok(q):
			continue
		var first: Array = (q["stages"][0] as Dictionary).get("objectives", [])
		if first.is_empty() or canon(first[0]) != "reach" or not _conditions_ok(first[0]):
			continue
		var t: Variant = objective_position(id, first[0])
		if t == null:
			continue
		var tv: Vector3 = t
		if Vector2(pos.x - tv.x, pos.z - tv.z).length() < float(first[0].get("radius", 20.0)):
			if start(id, true):
				EventBus.toast.emit(tr("QUEST_DISCOVERED") % tr(q.get("title_key", "")))


## First frame of a new game (or after loading): auto quests start once the
## world is up; every active quest re-checks the world.
func on_game_started() -> void:
	_last_pos = Vector3.INF
	_refresh_availability()
	for id in active_quests():
		_evaluate_all(id)


# --- Save --------------------------------------------------------------------------------------------------

func save_state() -> Dictionary:
	var out := {}
	for id in order:
		var st: Dictionary = state[id]
		if st["state"] != State.LOCKED or st["completions"] > 0:
			# Progress only means something for the quest in hand.
			var live: bool = st["state"] == State.ACTIVE
			out[String(id)] = {"state": st["state"], "stage": st["stage"], "progress": st["progress"] if live else [],
				"metric": st["metric"] if live else [], "bonus_ok": st["bonus_ok"], "completions": st["completions"],
				"available_at": st["available_at"]}
	return {"quests": out, "tracked": String(tracked), "recent": recent_categories}


func load_state(d: Dictionary) -> void:
	reset()
	var qs: Dictionary = d.get("quests", {})
	for key in qs:
		var id := StringName(key)
		if not defs.has(id):
			continue   # quest removed from data: ignore
		var st: Dictionary = qs[key]
		state[id]["state"] = int(st.get("state", State.LOCKED))
		state[id]["completions"] = int(st.get("completions", 1 if state[id]["state"] == State.COMPLETED else 0))
		state[id]["available_at"] = float(st.get("available_at", 0.0))
		state[id]["bonus_ok"] = bool(st.get("bonus_ok", true))
		var stages: Array = defs[id]["stages"]
		state[id]["stage"] = clampi(int(st.get("stage", 0)), 0, stages.size() - 1)
		var need: int = (stages[state[id]["stage"]] as Dictionary).get("objectives", []).size()
		if state[id]["state"] != State.ACTIVE:
			need = 0
		var prog: Array = st.get("progress", [])
		var met: Array = st.get("metric", [])
		prog.resize(need)
		met.resize(need)
		for i in need:
			prog[i] = int(prog[i]) if prog[i] != null else 0
			met[i] = float(met[i]) if met[i] != null else 0.0
		state[id]["progress"] = prog
		state[id]["metric"] = met
	tracked = StringName(d.get("tracked", ""))
	recent_categories = d.get("recent", [])
	_refresh_availability()
