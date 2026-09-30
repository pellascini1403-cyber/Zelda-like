class_name QuestSpawner
extends Node3D
## Streams quest content into the world around the player: clues, relics,
## levers, nests, quest enemies, captives, encounters, ring courses, reward
## chests and distant visual cues (smoke columns, light pillars).
##
## Where content comes from (see docs/QUESTS.md, "spawns"):
##   quest "spawns"  — present while the quest is open/available/active
##                     ("when": open | available | active | always)
##   stage "spawns"  — present only while that stage is the current one
## Placement: "pos": [x, z] (terrain height) or [x, y, z] (absolute), relative
## to "poi" when given; "snap": "top" drops onto the highest collider (tower
## tops, roofs) and waits for it to stream in; "float" sits on the water.
##
## Nothing here decides quest logic: it only makes sure the things quests
## talk about exist when the player is near, and never come back once used
## (WorldState flags qo:/qd:/qe:). A failed stage frees and respawns its
## content fresh; "clear" groups respawn only the enemies still owed.

const RANGE := {
	"object": 170.0, "nest": 150.0, "creature": 110.0, "actor": 130.0, "encounter": 140.0,
	"course": 320.0, "chest": 150.0, "cue": 900.0, "zone": 260.0, "feature": 160.0,
}
const MARGIN := 30.0
const LINGER_DISTANCE := 45.0
const LINGER_SECONDS := 25.0

var gen: WorldGen
var spawner: SpawnDirector
var streamer: WorldStreamer
var _live: Dictionary = {}   # key -> {nodes: Array, quest, kind, group, linger}
## Entries whose creatures were all defeated: no respawn until the player
## leaves the area or the entry stops being wanted.
var _cleared: Dictionary = {}
var _timer := 0.0
var _now := 0.0


func _ready() -> void:
	add_to_group(&"quest_spawner")
	EventBus.quest_failed.connect(func(id: StringName, _r: String) -> void: release_quest(id))
	EventBus.game_loaded.connect(release_all)


func _process(delta: float) -> void:
	_now += delta
	if Game.player == null or not Game.is_playing():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	sync()


## Wanted entries right now: key -> [entry, quest_id].
func wanted() -> Dictionary:
	var out := {}
	for id in Quests.order:
		var q: Dictionary = Quests.defs[id]
		var s := Quests.quest_state(id)
		var qspawns: Array = q.get("spawns", [])
		for i in qspawns.size():
			var e: Dictionary = qspawns[i]
			var when := String(e.get("when", "open"))
			var ok := false
			match when:
				"always":
					ok = true
				"available":
					ok = s == Quests.State.AVAILABLE and Quests._start_ok(q)
				"active":
					ok = s == Quests.State.ACTIVE
				_:
					ok = s == Quests.State.AVAILABLE or s == Quests.State.ACTIVE
			if ok and _conditions_ok(e):
				out["%s:q%d" % [id, i]] = [e, id]
		if s == Quests.State.ACTIVE:
			var st: int = Quests.state[id]["stage"]
			var sspawns: Array = Quests.current_stage(id).get("spawns", [])
			for i in sspawns.size():
				if _conditions_ok(sspawns[i]):
					out["%s:s%d:%d" % [id, st, i]] = [sspawns[i], id]
	# Sites: world features that are simply always there (fishing spots,
	# storm buoys, trail markers), subject to their own conditions.
	for i in DB.sites.size():
		var se: Dictionary = DB.sites[i]
		if _conditions_ok(se):
			out["site:%d" % i] = [se, &""]
	# Discoveries: their things exist while waiting to be found (and after,
	# if they persist) and only when their world conditions hold.
	for did: StringName in DB.discovery_order:
		var dd: Dictionary = DB.discoveries[did]
		if DiscoveryDirector.is_found(did) and not dd.get("persist", false):
			continue
		if not DiscoveryDirector.world_ok(dd.get("conditions", {})):
			continue
		var ds: Array = dd.get("spawns", [])
		for i in ds.size():
			if _conditions_ok(ds[i]):
				out["disc:%s:%d" % [did, i]] = [ds[i], &""]
	return out


func _conditions_ok(e: Dictionary) -> bool:
	var c: Dictionary = e.get("conditions", {})
	if c.has("period") and (c["period"] == "night") != Clock.is_night():
		return false
	if c.has("weather") and not String(Weather.target) in c["weather"]:
		return false
	if c.has("flag") and not WorldState.flags.has(String(c["flag"])):
		return false
	if c.has("not_flag") and WorldState.flags.has(String(c["not_flag"])):
		return false
	if c.has("tide") and not _tide_ok(String(c["tide"])):
		return false
	if c.has("hours"):
		var hr: Array = c["hours"]
		var h := Clock.hour
		if not ((h >= float(hr[0]) and h < float(hr[1])) if float(hr[0]) <= float(hr[1]) else (h >= float(hr[0]) or h < float(hr[1]))):
			return false
	return true


static func _tide_ok(t: String) -> bool:
	match t:
		"low": return Tide.is_low()
		"high": return Tide.is_high()
	return true


func sync() -> void:
	var want := wanted()
	for key in _live.keys():
		if not want.has(key):
			_release(key, false)
	for key in _cleared.keys():
		if not want.has(key):
			_cleared.erase(key)
	var ppos := Game.player.global_position
	for key in want:
		var e: Dictionary = want[key][0]
		var quest: StringName = want[key][1]
		var kind := String(e.get("kind", "object"))
		var at: Variant = anchor(e)
		if at == null:
			continue
		var a: Vector3 = at
		var d := Vector2(ppos.x - a.x, ppos.z - a.z).length()
		var r := float(e.get("range", RANGE.get(kind, 150.0)))
		if d > r + MARGIN:
			_cleared.erase(key)
		if _live.has(key):
			if d > r + MARGIN:
				_release(key, false)
			else:
				_maintain(key)
		elif d < r and not _cleared.has(key) and not _persisted_done(e, kind):
			_spawn(key, e, quest, kind)


## XZ anchor of an entry (y = 0), or null if it cannot be placed.
func anchor(e: Dictionary) -> Variant:
	var base := Vector3.ZERO
	if e.has("poi"):
		var pp: Variant = Quests.poi_pos(String(e["poi"]))
		if pp == null:
			return null
		base = pp
	if e.has("pos"):
		var off: Array = e["pos"]
		return base + (Vector3(off[0], 0, off[1]) if off.size() == 2 else Vector3(off[0], 0, off[2]))
	if e.has("rings") and not (e["rings"] as Array).is_empty():
		var r0: Array = e["rings"][0]
		return base + Vector3(r0[0], 0, r0[1])
	return base if e.has("poi") else null


## Full position (with height) or Vector3.INF when not placeable yet.
func place(e: Dictionary, xz: Vector3, pos_arr: Array = []) -> Vector3:
	var arr: Array = pos_arr if not pos_arr.is_empty() else e.get("pos", [])
	if arr.size() == 3:
		return Vector3(xz.x, float(arr[1]), xz.z)
	var y := 0.0
	if String(e.get("snap", "")) == "top":
		var from := Vector3(xz.x, 700.0, xz.z)
		var q := PhysicsRayQueryParameters3D.create(from, Vector3(xz.x, -60.0, xz.z), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return Vector3.INF
		y = (hit["position"] as Vector3).y
		if e.has("min_y") and y < float(e["min_y"]):
			return Vector3.INF
	else:
		y = QuestEncounter.floor_y(self, gen, xz.x, xz.z)
		if e.get("float", false):
			y = maxf(y, WorldGen.SEA_LEVEL - 0.25)
	return Vector3(xz.x, y + float(e.get("lift", 0.0)), xz.z)


func _persisted_done(e: Dictionary, kind: String) -> bool:
	var id := String(e.get("id", ""))
	match kind:
		"object":
			return e.get("once", true) and id != "" and WorldState.flags.has("qo:" + id) and e.get("hide_used", true)
		"nest":
			return QuestNest.destroyed(id)
		"encounter":
			return e.get("once", true) and WorldState.flags.has("qe:" + id)
		"actor":
			var tid := String(e.get("talk", {}).get("id", ""))
			return tid != "" and WorldState.flags.has("qo:" + tid) and e.get("talk", {}).get("vanish", true)
	return false


func _has_ground(p: Vector3) -> bool:
	return streamer == null or streamer.has_collision_at(p)


func _spawn(key: String, e: Dictionary, quest: StringName, kind: String) -> void:
	var xz: Vector3 = anchor(e)
	var nodes: Array = []
	var group := String(e.get("group", ""))
	match kind:
		"object":
			var pos := place(e, xz)
			if pos == Vector3.INF:
				return
			var o := QuestObject.create(e)
			add_child(o)
			o.global_position = pos
			o.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
			nodes.append(o)
		"nest":
			var pos := place(e, xz)
			if pos == Vector3.INF:
				return
			var n := QuestNest.create(e)
			add_child(n)
			n.global_position = pos
			nodes.append(n)
		"chest":
			var pos := place(e, xz)
			if pos == Vector3.INF:
				return
			var c := Chest.create(String(e.get("id", key)), StringName(e.get("table", "chest_common")), e.get("items", []), e.get("grand", false))
			add_child(c)
			c.global_position = pos
			c.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
			nodes.append(c)
		"creature":
			var pos := place(e, xz)
			if pos == Vector3.INF or not _has_ground(pos) or spawner == null:
				return
			var n := _creature_budget(key, e, quest)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(key)
			var spread := float(e.get("spread", 4.0))
			for i in n:
				var p := pos
				if i > 0 or n > 1:
					var a := TAU * i / n + rng.randf() * 0.5
					p = pos + Vector3(cos(a), 0, sin(a)) * spread * rng.randf_range(0.5, 1.0)
					if (e.get("pos", []) as Array).size() != 3:
						p.y = QuestEncounter.floor_y(self, gen, p.x, p.z)
				var c := spawner.spawn_creature(StringName(e.get("entity", "")), p + Vector3.UP * 0.3, "", group)
				if c == null:
					continue
				if e.get("alert", false):
					c.perception.alert(Game.player.global_position)
					c.brain.change(&"chase")
				nodes.append(c)
		"actor":
			var pos := place(e, xz)
			if pos == Vector3.INF or not _has_ground(pos):
				return
			var ac := QuestActor.create(StringName(e.get("entity", "NPC_VILLAGER")), float(e.get("hp", 100.0)))
			ac.tied = e.get("tied", false)
			ac.cowering = e.get("cowering", false)
			if e.has("talk"):
				var t: Dictionary = (e["talk"] as Dictionary).duplicate()
				var route: Array[Vector3] = []
				for q in t.get("then_path", []):
					var qxz := _rel(e, q)
					route.append(Vector3(qxz.x, gen.height(qxz.x, qxz.z), qxz.z))
				t["then_path"] = route
				ac.talk = t
			add_child(ac)
			ac.global_position = pos + Vector3.UP * 0.2
			ac.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
			if e.has("shout_key"):
				ac.shout(String(e["shout_key"]))
			nodes.append(ac)
		"encounter":
			var pos := place(e, xz)
			if pos == Vector3.INF or not _has_ground(pos):
				return
			var route: Array[Vector3] = []
			for q in e.get("path", []):
				var qxz := _rel(e, q)
				route.append(Vector3(qxz.x, gen.height(qxz.x, qxz.z), qxz.z))
			var ed := e.duplicate()
			ed["quest"] = String(quest)
			var enc := QuestEncounter.create(ed, pos, route, spawner, gen)
			add_child(enc)
			nodes.append(enc)
		"course":
			var pts: Array[Vector3] = []
			for r in e.get("rings", []):
				var ra: Array = r
				var rxz := _rel(e, ra)
				if ra.size() >= 3 and e.get("absolute", false):
					pts.append(Vector3(rxz.x, float(ra[2]), rxz.z))
				else:
					var h := float(ra[2]) if ra.size() >= 3 else float(e.get("h", 2.5))
					var ground := maxf(gen.height(rxz.x, rxz.z), WorldGen.SEA_LEVEL)
					pts.append(Vector3(rxz.x, ground + h, rxz.z))
			var course := RingCourse.create(e, pts)
			add_child(course)
			nodes.append(course)
		"puzzle":
			var pos := place(e, xz)
			if pos == Vector3.INF:
				return
			var root := Node3D.new()
			root.name = "Puzzle_" + String(e.get("id", ""))
			add_child(root)
			root.global_position = pos
			var pg := PuzzleGroup.new()
			pg.puzzle_id = String(e.get("id", ""))
			root.add_child(pg)
			for el in e.get("elements", []):
				var at: Array = el.get("at", [0, 0])
				var ep := pos + Vector3(at[0], 0, at[1])
				ep.y = gen.height(ep.x, ep.z) if at.size() == 2 else pos.y + float(at[2])
				var node: Node3D
				match String(el.get("type", "brazier")):
					"plate":
						var plate := PressurePlate.new()
						plate.puzzle_id = pg.puzzle_id
						node = plate
					"vane":
						var vane := WindVane.new()
						vane.puzzle_id = pg.puzzle_id
						node = vane
					_:
						var br := Brazier.new()
						br.puzzle_id = pg.puzzle_id
						node = br
				root.add_child(node)
				node.global_position = ep
				if el.has("crate"):
					var ca: Array = el["crate"]
					var crate := PhysicsProp.create(&"crate", "%s:crate%d" % [pg.puzzle_id, root.get_child_count()])
					root.add_child(crate)
					crate.global_position = pos + Vector3(ca[0], 0, ca[1])
					crate.global_position.y = gen.height(crate.global_position.x, crate.global_position.z) + 0.7
			if e.has("seal"):
				var sd: Dictionary = e["seal"]
				var sa: Array = sd.get("at", [0, 0])
				var seal := WindSeal.new()
				seal.puzzle_id = pg.puzzle_id
				root.add_child(seal)
				seal.global_position = pos + Vector3(sa[0], 0, sa[1])
				seal.global_position.y = gen.height(seal.global_position.x, seal.global_position.z)
				if sd.has("chest"):
					var cd: Dictionary = sd["chest"]
					var ch := Chest.create(String(cd.get("id", pg.puzzle_id + ":chest")), StringName(cd.get("table", "chest_rare")), cd.get("items", []), cd.get("grand", true))
					root.add_child(ch)
					ch.global_position = seal.global_position + Vector3(0, 0.05, 0)
			nodes.append(root)
		"feature":
			var pos := place(e, xz)
			if pos == Vector3.INF:
				return
			var f: Node3D = Features.make(e)
			if f == null:
				push_warning("QuestSpawner: unknown feature " + String(e.get("feature", "")))
				return
			add_child(f)
			f.global_position = pos
			f.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
			nodes.append(f)
		"zone":
			# Physics fields discoveries and quests can place: a thermal
			# column, a low-gravity pocket.
			var pos := place(e, xz)
			if pos == Vector3.INF:
				return
			var z: Node3D
			if String(e.get("zone", "updraft")) == "levity":
				var lz := LevityZone.new()
				lz.radius = float(e.get("radius", 20.0))
				lz.gravity_scale = float(e.get("strength", 0.45))
				z = lz
			else:
				var uz := UpdraftZone.new()
				uz.radius = float(e.get("radius", 6.0))
				uz.height = float(e.get("height", 60.0))
				uz.strength = float(e.get("strength", 11.0))
				z = uz
			add_child(z)
			z.global_position = pos
			nodes.append(z)
		"cue":
			var pos := place(e, xz)
			if pos == Vector3.INF:
				return
			var cue := Cue.make(String(e.get("cue", "smoke")))
			add_child(cue)
			cue.global_position = pos
			nodes.append(cue)
		_:
			push_warning("QuestSpawner: unknown spawn kind " + kind)
			return
	_live[key] = {"nodes": nodes, "quest": quest, "kind": kind, "group": group, "linger": -1.0}


## [x, z] (or [x, z, h]) relative to the entry's POI when it has one.
func _rel(e: Dictionary, a: Array) -> Vector3:
	var base := Vector3.ZERO
	if e.has("poi"):
		var pp: Variant = Quests.poi_pos(String(e["poi"]))
		if pp != null:
			base = pp
	return base + Vector3(a[0], 0, a[1])


## Enemies owed by a "clear" objective on this group, minus those alive.
func _creature_budget(key: String, e: Dictionary, quest: StringName) -> int:
	var n := int(e.get("count", 1))
	var g := String(e.get("group", ""))
	if g == "" or not Quests.is_active(quest):
		return n
	var objs: Array = Quests.current_stage(quest).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		if Quests.canon(o) == "clear" and String(o.get("target", "")).trim_prefix("group:") == g:
			var remaining := Quests.need_of(o) - int(Quests.state[quest]["progress"][i])
			for k in _live:
				if k != key and _live[k]["group"] == g:
					for c in _live[k]["nodes"]:
						if is_instance_valid(c) and c is Creature and not (c as Creature).is_dead():
							remaining -= 1
			return clampi(remaining, 0, n)
	return n


## Keeps live content consistent with streaming (no creature over holes).
func _maintain(key: String) -> void:
	var L: Dictionary = _live[key]
	if L["kind"] != "creature":
		return
	var any := false
	for c in L["nodes"]:
		if is_instance_valid(c):
			any = true
			if not _has_ground((c as Node3D).global_position) and not ((c as Creature).brain and (c as Creature).brain.aggro):
				_release(key, true)
				return
	if not any:
		# Everyone was defeated: no instant respawn. A "clear" group respawns
		# only what is still owed once the player comes back later.
		_cleared[key] = true
		_live.erase(key)


func _release(key: String, force: bool) -> void:
	if not _live.has(key):
		return
	var L: Dictionary = _live[key]
	if not force and L["kind"] in ["actor", "encounter"]:
		# Let rescued / escorted people stay a moment instead of popping out.
		var near := false
		for n in L["nodes"]:
			if is_instance_valid(n):
				if n is QuestEncounter and not (n as QuestEncounter).can_release():
					return
				if Game.player and (n as Node3D).global_position.distance_to(Game.player.global_position) < LINGER_DISTANCE:
					near = true
		if near:
			if float(L["linger"]) < 0.0:
				L["linger"] = _now + LINGER_SECONDS
			if _now < float(L["linger"]):
				return
	for n in L["nodes"]:
		if not is_instance_valid(n):
			continue
		if n is Creature:
			var c := n as Creature
			c.focus = null
			if not force and c.brain and c.brain.aggro and spawner:
				spawner.adopt_orphan(c)
			else:
				c.queue_free()
		else:
			(n as Node).queue_free()
	_live.erase(key)


## Frees (and so respawns fresh) everything a quest placed: used when a
## stage fails or restarts.
func release_quest(id: StringName) -> void:
	for key in _live.keys():
		if _live[key]["quest"] == id:
			_release(key, true)
	for key in _cleared.keys():
		if String(key).begins_with(String(id) + ":"):
			_cleared.erase(key)
	_timer = 0.0


func release_all() -> void:
	for key in _live.keys():
		_release(key, true)
	_cleared.clear()


func live_count() -> int:
	return _live.size()
