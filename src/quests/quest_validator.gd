class_name QuestValidator
extends RefCounted
## Static checks for quest data (run by DB.validate() and the unit tests).
## Beyond references, it looks for the ways a quest can soft-lock:
##   * an objective whose target never exists while its stage is active
##     (object / nest / encounter / course / group not spawned there)
##   * a "clear" objective owing more enemies than its group spawns
##   * a talk/deliver objective with an NPC who lives nowhere
##   * a flag nothing in the game can set, prerequisite cycles
##   * a quest that rewards nothing (every quest must pay out something)

const QUEST_TYPES := ["main", "side", "discovery", "bounty", "challenge"]
const CATEGORIES := ["story", "combat", "exploration", "puzzle", "gathering", "npc", "discovery", "boss", "challenge", "crafting", "traversal"]
const DURATIONS := ["short", "medium", "long"]
const SPAWN_KINDS := ["object", "nest", "creature", "actor", "encounter", "course", "chest", "cue", "puzzle"]
const ENC_MODES := ["protect", "survive", "escort"]
const COURSE_MODES := ["glide", "run", "swim", "ride"]
const STATES := ["glide", "swim", "climb", "ride", "ground", "air"]
const HINTS := ["marked", "area", "none"]
## Flags set by systems rather than quest data.
const SYSTEM_FLAG_PREFIXES := ["boss_", "puzzle_", "mount_", "gift_", "qo:", "qd:", "qe:", "poi:"]


static func validate(db: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var quests: Array = db.quests
	var ids := {}
	var poi_ids := {}
	var npc_homes := {}
	var settable := {}
	for poi in db.world.get("pois", []):
		poi_ids[String(poi["id"])] = true
		for n in poi.get("npcs", []):
			npc_homes[String(n[0])] = true
		# Beacons and anchors set their flags when the player uses them.
		for k in ["beacon", "flag"]:
			if poi.has(k):
				settable[String(poi[k])] = true
	for q in quests:
		if ids.has(String(q.get("id", ""))):
			errors.append("quest '%s' duplicated" % q.get("id", ""))
		ids[String(q.get("id", ""))] = q
		var r: Dictionary = q.get("rewards", {})
		for f in r.get("flags", []) + ([r["flag"]] if r.has("flag") else []) + q.get("unlocks", {}).get("flags", []):
			settable[String(f)] = true
		for st in q.get("stages", []):
			if st.has("on_complete_flag"):
				settable[String(st["on_complete_flag"])] = true
		for sp in _all_spawns(q):
			if String(sp.get("kind", "")) == "actor":
				npc_homes[String(sp.get("entity", ""))] = true
			if sp.has("reward"):
				for f in (sp["reward"] as Dictionary).get("flags", []):
					settable[String(f)] = true
	for ev in db.world_events:
		for f in ev.get("reward", {}).get("flags", []):
			settable[String(f)] = true
	var group_owner := {}
	for q in quests:
		var qid := String(q.get("id", ""))
		var where := "quest '%s'" % qid
		for k in ["id", "title_key", "desc_key", "type", "category", "stages"]:
			if not q.has(k):
				errors.append("%s missing '%s'" % [where, k])
		if not String(q.get("type", "")) in QUEST_TYPES:
			errors.append("%s bad type '%s'" % [where, q.get("type", "")])
		if not String(q.get("category", "")) in CATEGORIES:
			errors.append("%s bad category '%s'" % [where, q.get("category", "")])
		var reg := String(q.get("region", "any"))
		if reg != "any" and not db.regions.has(StringName(reg)):
			errors.append("%s unknown region '%s'" % [where, reg])
		var diff := int(q.get("difficulty", 1))
		if diff < 1 or diff > 5:
			errors.append("%s difficulty out of 1..5" % where)
		if not String(q.get("duration", "short")) in DURATIONS:
			errors.append("%s bad duration '%s'" % [where, q.get("duration", "")])
		for pre in q.get("requires", []):
			if not ids.has(String(pre)):
				errors.append("%s requires unknown quest '%s'" % [where, pre])
		for a in q.get("requires_abilities", []):
			if not db.abilities.has(StringName(a)):
				errors.append("%s requires unknown ability '%s'" % [where, a])
		for f in q.get("requires_flags", []):
			if not _flag_settable(String(f), settable):
				errors.append("%s requires flag '%s' that nothing sets" % [where, f])
		errors.append_array(_check_start(q, db, npc_homes, settable, poi_ids))
		if q.get("repeatable", false) and not q.has("cooldown_hours"):
			errors.append("%s repeatable without cooldown_hours" % where)
		if q.get("type", "") == "bounty" and String(q.get("board", "")) == "":
			errors.append("%s bounty without board" % where)
		var r: Dictionary = q.get("rewards", {})
		var stage_pay := false
		for st in q.get("stages", []):
			if st.has("rewards"):
				stage_pay = true
				errors.append_array(check_reward(st["rewards"], db, where + " stage"))
		if r.is_empty() and (q.get("unlocks", {}) as Dictionary).is_empty() and not stage_pay:
			errors.append("%s rewards nothing" % where)
		errors.append_array(check_reward(r, db, where))
		if q.has("bonus_rewards"):
			errors.append_array(check_reward(q["bonus_rewards"], db, where + " bonus"))
		# Spawns (quest level) always exist while the quest is open/active.
		var q_level: Array = q.get("spawns", [])
		for sp in q_level:
			errors.append_array(_check_spawn(sp, db, poi_ids, where))
		var stages: Array = q.get("stages", [])
		if stages.is_empty():
			errors.append("%s has no stages" % where)
		for si in stages.size():
			var stage: Dictionary = stages[si]
			var sw := "%s stage %d" % [where, si]
			var s_level: Array = stage.get("spawns", [])
			for sp in s_level:
				errors.append_array(_check_spawn(sp, db, poi_ids, sw))
				var g := String(sp.get("group", ""))
				if g != "" and String(sp.get("kind", "")) == "creature":
					if group_owner.has(g) and group_owner[g] != qid:
						errors.append("%s group '%s' also used by quest '%s'" % [sw, g, group_owner[g]])
					group_owner[g] = qid
			var visible := _visible_spawns(q_level, s_level)
			if si == 0 and String(q.get("start", "")).begins_with("interact:"):
				# The object that starts the quest counts for its first step.
				visible = visible + q_level
			var objs: Array = stage.get("objectives", [])
			if objs.is_empty():
				errors.append("%s has no objectives" % sw)
			var required := 0
			for o in objs:
				if not o.get("optional", false):
					required += 1
				errors.append_array(_check_objective(o, db, sw, visible, npc_homes, settable, poi_ids))
			if required == 0 and not objs.is_empty():
				errors.append("%s has only optional objectives" % sw)
	errors.append_array(_check_cycles(quests))
	return errors


static func _all_spawns(q: Dictionary) -> Array:
	var out: Array = (q.get("spawns", []) as Array).duplicate()
	for st in q.get("stages", []):
		out.append_array(st.get("spawns", []))
	return out


## Spawns present while a stage is active (quest-level "available"-only
## spawns disappear once the quest starts).
static func _visible_spawns(q_level: Array, s_level: Array) -> Array:
	var out: Array = []
	for sp in q_level:
		if String(sp.get("when", "open")) != "available":
			out.append(sp)
	out.append_array(s_level)
	return out


static func _flag_settable(f: String, settable: Dictionary) -> bool:
	if settable.has(f):
		return true
	for pre in SYSTEM_FLAG_PREFIXES:
		if f.begins_with(pre):
			return true
	return f in ["ending_reached", "stillness_active"]


static func _check_start(q: Dictionary, db: Node, npc_homes: Dictionary, settable: Dictionary, poi_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var where := "quest '%s'" % q.get("id", "")
	var st := String(q.get("start", "auto"))
	if st in ["auto", "event", "board"]:
		if st == "board" and q.get("type", "") != "bounty":
			errors.append("%s board start on a non-bounty" % where)
		if st == "event":
			var first: Array = (q.get("stages", [{}])[0] as Dictionary).get("objectives", [])
			if first.is_empty():
				errors.append("%s event start without a first objective" % where)
	elif st.begins_with("talk:"):
		var npc := st.trim_prefix("talk:")
		if not db.entities.has(StringName(npc)):
			errors.append("%s starts at unknown NPC '%s'" % [where, npc])
		elif not npc_homes.has(npc):
			errors.append("%s starts at NPC '%s' who lives nowhere" % [where, npc])
		if (q.get("offer_lines", []) as Array).is_empty():
			errors.append("%s talk start without offer_lines" % where)
	elif st.begins_with("poi:"):
		if not poi_ids.has(st.trim_prefix("poi:")):
			errors.append("%s starts at unknown poi" % where)
	elif st.begins_with("flag:"):
		if not _flag_settable(st.trim_prefix("flag:"), settable):
			errors.append("%s starts on flag '%s' that nothing sets" % [where, st])
	elif st.begins_with("interact:"):
		var obj := st.trim_prefix("interact:")
		var found := false
		for sp in q.get("spawns", []):
			if String(sp.get("id", "")) == obj and String(sp.get("when", "open")) in ["available", "open", "always"]:
				found = true
		if not found:
			errors.append("%s starts on object '%s' that is never placed" % [where, obj])
	else:
		errors.append("%s bad start '%s'" % [where, st])
	return errors


static func check_reward(r: Dictionary, db: Node, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for it in r.get("items", []):
		if not db.items.has(StringName(it.get("id", ""))):
			errors.append("%s rewards unknown item '%s'" % [where, it.get("id", "")])
	if r.has("ability") and not db.abilities.has(StringName(r["ability"])):
		errors.append("%s rewards unknown ability '%s'" % [where, r["ability"]])
	if r.has("cosmetic") and not db.cosmetics.has(StringName(r["cosmetic"])):
		errors.append("%s rewards unknown cosmetic '%s'" % [where, r["cosmetic"]])
	for k in ["glimmer", "jade"]:
		if r.has(k) and int(r[k]) <= 0:
			errors.append("%s non-positive %s" % [where, k])
	for combo in r.get("recipes", []):
		for ing in combo:
			if not db.items.has(StringName(ing)):
				errors.append("%s recipe uses unknown item '%s'" % [where, ing])
	return errors


static func _check_spawn(sp: Dictionary, db: Node, poi_ids: Dictionary, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var kind := String(sp.get("kind", "object"))
	var w := "%s spawn '%s'" % [where, sp.get("id", kind)]
	if not kind in SPAWN_KINDS:
		errors.append("%s unknown kind '%s'" % [w, kind])
		return errors
	if sp.has("poi") and not poi_ids.has(String(sp["poi"])):
		errors.append("%s unknown poi '%s'" % [w, sp["poi"]])
	if not sp.has("pos") and not sp.has("poi") and not sp.has("rings"):
		errors.append("%s has no position" % w)
	if kind in ["object", "nest", "encounter", "course", "puzzle"] and String(sp.get("id", "")) == "":
		errors.append("%s needs an id" % w)
	match kind:
		"object":
			if not String(sp.get("look", "clue")) in QuestObject.KINDS:
				errors.append("%s unknown object look '%s'" % [w, sp.get("look", "")])
			for k in ["item", "needs_item"]:
				if sp.has(k) and not db.items.has(StringName(sp[k])):
					errors.append("%s unknown %s '%s'" % [w, k, sp[k]])
			if sp.has("reward"):
				errors.append_array(check_reward(sp["reward"], db, w))
		"nest":
			if not String(sp.get("nest", "thorn")) in QuestNest.LOOKS:
				errors.append("%s unknown nest look" % w)
			if sp.has("spawn") and not db.entities.has(StringName(sp["spawn"])):
				errors.append("%s spawns unknown entity" % w)
		"creature", "actor":
			if not db.entities.has(StringName(sp.get("entity", ""))):
				errors.append("%s unknown entity '%s'" % [w, sp.get("entity", "")])
		"encounter":
			if not String(sp.get("mode", "protect")) in ENC_MODES:
				errors.append("%s bad mode" % w)
			if sp.has("actor") and not db.entities.has(StringName(sp["actor"])):
				errors.append("%s unknown actor '%s'" % [w, sp["actor"]])
			if String(sp.get("mode", "")) == "escort" and (sp.get("path", []) as Array).size() < 2:
				errors.append("%s escort needs a path" % w)
			if String(sp.get("mode", "")) in ["protect", "escort"] and not sp.has("actor"):
				errors.append("%s needs an actor" % w)
			for g in sp.get("waves", []) + sp.get("ambushes", []):
				if not db.entities.has(StringName(g.get("entity", ""))):
					errors.append("%s wave has unknown entity '%s'" % [w, g.get("entity", "")])
			if sp.has("reward"):
				errors.append_array(check_reward(sp["reward"], db, w))
		"course":
			if (sp.get("rings", []) as Array).size() < 2:
				errors.append("%s needs 2+ rings" % w)
			if not String(sp.get("mode", "run")) in COURSE_MODES:
				errors.append("%s bad course mode" % w)
		"chest":
			if sp.has("table") and not db.loot_tables.has(StringName(sp["table"])):
				errors.append("%s unknown loot table" % w)
			for it in sp.get("items", []):
				if not db.items.has(StringName(it.get("id", ""))):
					errors.append("%s unknown item" % w)
		"puzzle":
			if (sp.get("elements", []) as Array).is_empty():
				errors.append("%s has no elements" % w)
			for el in sp.get("elements", []):
				if not String(el.get("type", "")) in ["brazier", "plate", "vane"]:
					errors.append("%s unknown element '%s'" % [w, el.get("type", "")])
	return errors


static func _spawned_ids(visible: Array, kind: String) -> Dictionary:
	var out := {}
	for sp in visible:
		if String(sp.get("kind", "object")) == kind:
			out[String(sp.get("id", ""))] = sp
		if kind == "object" and String(sp.get("kind", "")) == "actor" and sp.has("talk"):
			out[String(sp["talk"].get("id", ""))] = sp
	return out


static func _group_size(visible: Array, kinds: Array, group: String) -> int:
	var n := 0
	for sp in visible:
		var k := String(sp.get("kind", "object"))
		if k in kinds and String(sp.get("group", "")) == group:
			n += int(sp.get("count", 1)) if k == "creature" else 1
		elif k == "actor" and "object" in kinds and String(sp.get("talk", {}).get("group", "")) == group:
			n += 1
	return n


static func _check_objective(o: Dictionary, db: Node, where: String, visible: Array, npc_homes: Dictionary, settable: Dictionary, poi_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var raw := String(o.get("type", ""))
	var t := String(o.get("target", ""))
	var c: String = Quests.ALIASES.get(raw, raw)
	var w := "%s objective '%s'" % [where, raw]
	if not c in Quests.TYPES:
		errors.append("%s unknown type" % w)
		return errors
	if String(o.get("text_key", "")) == "":
		errors.append("%s missing text_key" % w)
	if o.has("hint") and not String(o["hint"]) in HINTS:
		errors.append("%s bad hint" % w)
	var cond: Dictionary = o.get("conditions", {})
	if cond.has("state") and not String(cond["state"]) in STATES:
		errors.append("%s bad state condition" % w)
	for wth in cond.get("weather", []):
		if not db.weather_types.has(StringName(wth)):
			errors.append("%s unknown weather '%s'" % [w, wth])
	var need := maxi(int(o.get("count", 1)), 1)
	match c:
		"kill", "sneak":
			if t != "any" and not db.entities.has(StringName(t)):
				errors.append("%s unknown entity '%s'" % [w, t])
		"boss":
			var ok := false
			for b in db.bosses.values():
				if String(b["entity"]) == t:
					ok = true
			if not ok:
				errors.append("%s unknown boss entity '%s'" % [w, t])
		"talk", "deliver":
			if not db.entities.has(StringName(t)):
				errors.append("%s unknown NPC '%s'" % [w, t])
			elif not npc_homes.has(t):
				errors.append("%s NPC '%s' lives nowhere" % [w, t])
			if c == "deliver" and not db.items.has(StringName(o.get("item", ""))):
				errors.append("%s delivers unknown item '%s'" % [w, o.get("item", "")])
		"collect":
			if not db.items.has(StringName(t)):
				errors.append("%s unknown item '%s'" % [w, t])
		"gather":
			if t != "any" and not db.resource_nodes.has(StringName(t)):
				errors.append("%s unknown resource node '%s'" % [w, t])
		"discover":
			if not poi_ids.has(t):
				errors.append("%s unknown poi '%s'" % [w, t])
		"region":
			if not db.regions.has(StringName(t)):
				errors.append("%s unknown region '%s'" % [w, t])
		"ability", "ability_use":
			if not db.abilities.has(StringName(t)):
				errors.append("%s unknown ability '%s'" % [w, t])
		"craft", "cook":
			if t != "any" and not db.items.has(StringName(t)):
				errors.append("%s unknown item '%s'" % [w, t])
			if c == "craft" and t != "any":
				var made := false
				for rec in db.crafting.values():
					if String(rec["result"]) == t:
						made = true
				if not made:
					errors.append("%s no recipe crafts '%s'" % [w, t])
		"flag":
			if not _flag_settable(t, settable):
				errors.append("%s flag '%s' that nothing sets" % [w, t])
		"puzzle":
			var pz := false
			for poi in db.world.get("pois", []):
				if String(poi["id"]) == t and poi.has("puzzle"):
					pz = true
			for sp in visible:
				if String(sp.get("kind", "")) == "puzzle" and String(sp.get("id", "")) == t:
					pz = true
			if not pz:
				errors.append("%s unknown puzzle '%s'" % [w, t])
		"interact", "retrieve":
			if t.begins_with("group:"):
				if _group_size(visible, ["object"], t.trim_prefix("group:")) < need:
					errors.append("%s group '%s' has fewer than %d objects" % [w, t, need])
			elif not _spawned_ids(visible, "object").has(t):
				errors.append("%s object '%s' is not placed while the stage is active" % [w, t])
		"destroy":
			if t.begins_with("group:"):
				if _group_size(visible, ["nest"], t.trim_prefix("group:")) < need:
					errors.append("%s nest group '%s' too small" % [w, t])
			elif not _spawned_ids(visible, "nest").has(t):
				errors.append("%s nest '%s' is not placed" % [w, t])
		"clear":
			var g := t.trim_prefix("group:")
			if _group_size(visible, ["creature"], g) < need:
				errors.append("%s group '%s' spawns fewer than %d enemies" % [w, g, need])
		"escort", "protect", "survive":
			var enc: Dictionary = _spawned_ids(visible, "encounter")
			if not enc.has(t):
				errors.append("%s encounter '%s' is not placed" % [w, t])
			elif String(enc[t].get("mode", "protect")) != c:
				errors.append("%s encounter '%s' mode mismatch" % [w, t])
		"course":
			if not _spawned_ids(visible, "course").has(t):
				errors.append("%s course '%s' is not placed" % [w, t])
		"reach", "climb", "glide", "swim":
			var has_pos := o.has("marker") or o.has("pos") or (t != "" and poi_ids.has(t)) or o.has("metric")
			if not has_pos:
				for sp in visible:
					if String(sp.get("id", "")) == t:
						has_pos = true
			if not has_pos:
				errors.append("%s has no place to reach" % w)
			if o.has("metric") and not String(o["metric"]) in ["distance", "height"]:
				errors.append("%s bad metric" % w)
		"mount", "open_chest", "event":
			pass
	return errors


static func _check_cycles(quests: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	var reqs := {}
	for q in quests:
		reqs[String(q.get("id", ""))] = q.get("requires", [])
	for start in reqs:
		var stack: Array = [[start, [start]]]
		var seen := {}
		while not stack.is_empty():
			var cur: Array = stack.pop_back()
			for nxt in reqs.get(cur[0], []):
				if String(nxt) == start:
					errors.append("quest '%s' has a prerequisite cycle" % start)
					stack.clear()
					break
				if not seen.has(nxt):
					seen[nxt] = true
					stack.append([String(nxt), cur[1] + [nxt]])
	return errors
