class_name StructureBuilder
extends RefCounted
## Builds each POI type from data/world.json. Every structure answers the
## design rule "things on the horizon exist for a reason": each one hides a
## reward, a camp, a vantage point or a piece of lore.
##
## Returns creature spawn definitions: [{entity, pos, group, id}] (world pos).

const STONE := Color(0.63, 0.61, 0.56)
const STONE_DARK := Color(0.45, 0.44, 0.42)
const MOSS := Color(0.44, 0.5, 0.36)
const WOOD := Color(0.47, 0.33, 0.21)
const WOOD_LIGHT := Color(0.66, 0.5, 0.33)
const THATCH := Color(0.74, 0.62, 0.36)
const CLOTH := Color(0.68, 0.3, 0.22)
const PLASTER := Color(0.86, 0.82, 0.72)

var gen: WorldGen


func _init(world_gen: WorldGen) -> void:
	gen = world_gen


## Types whose builders place the POI's "npcs" themselves.
const HANDLES_NPCS := ["village", "oasis", "npc_camp", "cave", "post", "quarry", "temple"]


func build(poi: Dictionary, root: Node3D) -> Array:
	var spawns := _build_type(poi, root)
	_extras(poi, root)
	if not poi["type"] in HANDLES_NPCS:
		spawns.append_array(_people(poi, root))
	return spawns


## "npcs": [[entity, x, z, (flag)]] — an optional flag makes someone move in
## only once the story put them there (a rescued scholar, a returned mentor).
func _people(poi: Dictionary, root: Node3D) -> Array:
	var spawns: Array = []
	var npcs: Array = poi.get("npcs", [])
	for i in npcs.size():
		var n: Array = npcs[i]
		var sp := _spawn(root, n[0], Vector3(n[1], 0, n[2]), poi["id"], i, poi["id"])
		if n.size() > 3:
			sp["flag"] = String(n[3])   # PoiManager spawns them once the flag is set
		spawns.append(sp)
	return spawns


## Warden beacon at `local` (lit if its flag is already set).
func _beacon(poi: Dictionary, root: Node3D, local: Vector3) -> void:
	if not poi.has("beacon"):
		return
	var b := WardenBeacon.new()
	b.flag_id = String(poi["beacon"])
	root.add_child(b)
	b.position = local


## Optional features any POI can carry: a smoke column seen from afar, a
## bounty board, a Warden altar.
func _extras(poi: Dictionary, root: Node3D) -> void:
	if poi.get("smoke", false):
		var at: Array = poi.get("smoke_at", [0, 0])
		var cue := Cue.make("smoke")
		root.add_child(cue)
		cue.position = Vector3(at[0], _ground(root, Vector3(at[0], 0, at[1])) + 1.0, at[1])
	if poi.has("board"):
		var ba: Array = poi.get("board_at", [4, 4])
		var board := BountyBoard.new()
		board.board_id = String(poi["board"])
		root.add_child(board)
		board.position = Vector3(ba[0], _ground(root, Vector3(ba[0], 0, ba[1])), ba[1])
		board.rotation.y = float(poi.get("board_yaw", 0.0))
	if poi.has("beacon") and poi.has("beacon_at"):
		var bt: Array = poi["beacon_at"]
		_beacon(poi, root, Vector3(bt[0], _ground(root, Vector3(bt[0], 0, bt[1])), bt[1]))
	if poi.get("altar", false):
		var aa: Array = poi.get("altar_at", [-4, 4])
		var altar := WardenAltar.new()
		root.add_child(altar)
		altar.position = Vector3(aa[0], _ground(root, Vector3(aa[0], 0, aa[1])), aa[1])
		altar.rotation.y = float(poi.get("altar_yaw", 0.0))


func _npc_spawns(poi: Dictionary, root: Node3D) -> Array:
	var spawns := _people(poi, root)
	var guards: Array = poi.get("guards", [])
	for i in guards.size():
		var a := TAU * i / guards.size() + 0.4
		spawns.append(_spawn(root, guards[i], Vector3(cos(a), 0, sin(a)) * 4.0, poi["id"] + ":g", i, poi["id"] + ":g"))
	return spawns


func _build_type(poi: Dictionary, root: Node3D) -> Array:
	var kind: String = poi["type"]
	match kind:
		"npc_camp": return _npc_camp(poi, root)
		"cave": return _cave(poi, root)
		"post": return _post(poi, root)
		"quarry": return _quarry(poi, root)
		"depot": return _depot(poi, root)
		"village": return _village(poi, root)
		"maze": return _maze(poi, root)
		"camp": return _camp(poi, root)
		"spires": return _spires(poi, root)
		"giant_tree": return _giant_tree(poi, root)
		"overlook": return _overlook(poi, root)
		"shipwreck": return _shipwreck(poi, root)
		"watchtower": return _watchtower(poi, root)
		"summit": return _summit(poi, root)
		"den": return _den(poi, root)
		"temple": return _temple(poi, root)
		"shrine": return _shrine(poi, root)
		"bridge": return _bridge(poi, root)
		"ruins": return _ruins(poi, root)
		"oasis": return _oasis(poi, root)
		"arena": return _arena(poi, root)
		"anchor": return _anchor(poi, root)
		"floating_isles": return _floating_isles(poi, root)
	push_warning("StructureBuilder: unknown POI type " + kind)
	return []


func _ground(root: Node3D, local: Vector3) -> float:
	var w := root.global_position + local
	return gen.height(w.x, w.z) - root.global_position.y


func _spawn(root: Node3D, entity: String, local: Vector3, group: String, idx: int, poi_id: String) -> Dictionary:
	var pos := root.global_position + Vector3(local.x, 0, local.z)
	pos.y = gen.height(pos.x, pos.z) + 0.3
	return {"entity": StringName(entity), "pos": pos, "group": group, "id": "%s:%d" % [poi_id, idx]}


# --- Village: Aldea Brezo (Wind Warden hamlet) --------------------------------------------------
func _village(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var houses := [[Vector3(-12, 0, -8), 0.2, StructureKit.ROOF], [Vector3(10, 0, -10), -0.3, StructureKit.ROOF_LIGHT], [Vector3(-14, 0, 10), 1.4, StructureKit.ROOF_LIGHT], [Vector3(13, 0, 9), -1.2, StructureKit.ROOF]]
	for h in houses:
		_house(k, root, h[0], h[1], h[2])
	# Landmark: three-storey wind pagoda on a low terrace, seen from afar.
	var tower := Vector3(0, _ground(root, Vector3(0, 0, -21)), -21)
	var top := k.terrace(tower, 9.0, 9.0, 0.8, 0.0, [0], true, 2.5)
	k.pagoda(tower + Vector3(0, top, 0), 3, 5.0, 0.0)
	# Well with a little glazed canopy
	var well := Vector3(4, _ground(root, Vector3(4, 0, 2)), 2)
	StructureKit.prism_into(k.b, well, well + Vector3(0, 0.9, 0), 1.0, 1.0, 10, StructureKit.id(StructureKit.WHITE_STONE, 1.0))
	k.pillar(well + Vector3(-1.2, 0, 0), 2.4, 0.12, StructureKit.INK_WOOD, 5)
	k.pillar(well + Vector3(1.2, 0, 0), 2.4, 0.12, StructureKit.INK_WOOD, 5)
	k.hip_roof(well + Vector3(0, 2.4, 0), 3.6, 2.0, 0.9, 0.0)
	# Wind gate on the road to the southern fields
	var gate_pos := Vector3(15, 0, 25)
	gate_pos.y = _ground(root, gate_pos)
	k.wind_gate(gate_pos, 5.0, 4.2, 0.53)
	# Lantern posts around the square and ribbon poles
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var lp := Vector3(cos(a), 0, sin(a)) * 20.0
		lp.y = _ground(root, lp)
		k.lantern_post(lp, a + PI)
	for rp in [Vector3(-5, 0, 3), Vector3(7, 0, 14)]:
		rp.y = _ground(root, rp)
		k.pillar(rp, 6.5, 0.1, StructureKit.INK_WOOD, 5)
		for j in 3:
			k.ribbon(rp + Vector3(0, 6.3 - j * 0.1, 0), 3.0 - j * 0.5, 0.2, [StructureKit.CINNABAR_LIGHT, StructureKit.JADE, StructureKit.GOLD][j], j * 1.1)
	k.build(root, "VillageMesh", 1200.0)

	var fire := Campfire.new()
	root.add_child(fire)
	fire.position = Vector3(0, _ground(root, Vector3(0, 0, 5)), 5)
	var stone := LoreStone.new()
	stone.lore_key = "LORE_VILLAGE_STONE"
	stone.title_key = "LORE_TITLE_VILLAGE"
	root.add_child(stone)
	stone.position = Vector3(-4, _ground(root, Vector3(-4, 0, -14)), -14)
	# A few real lights at night (budget: 3); the rest glow via emission.
	_night_lights(root, k.lamps, 3)
	for i in 3:
		var crate := PhysicsProp.create(&"crate")
		root.add_child(crate)
		crate.position = Vector3(-9 + i * 1.1, _ground(root, Vector3(-9, 0, -3)) + 0.55 + (1.05 if i == 2 else 0.0), -3)
		if i == 2:
			crate.position.x = -8.45
	return _people(poi, root)


## Village house: stone plinth, timber-frame hall with lattice walls and a
## glazed eave roof.
func _house(k: StructureKit, root: Node3D, c: Vector3, yaw: float, roof_col: Color) -> void:
	c.y = _ground(root, c)
	var top := k.terrace(c, 7.6, 6.6, 0.45, yaw, [], false, 2.0)
	k.hall(c + Vector3(0, top, 0), 6.0, 5.0, 3.0, yaw, roof_col)


## Adds up to `budget` OmniLights at the given lamp positions (lit at night
## by EnvironmentController via the "night_lights" group).
func _night_lights(root: Node3D, lamps: Array[Vector3], budget: int) -> void:
	var step := maxi(1, lamps.size() / maxi(budget, 1))
	var n := 0
	var i := 0
	while i < lamps.size() and n < budget:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.4)
		light.light_energy = 0.0
		light.omni_range = 10.0
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 60.0
		light.distance_fade_length = 20.0
		light.add_to_group(&"night_lights")
		root.add_child(light)
		light.position = lamps[i]
		n += 1
		i += step


# --- Labyrinth ruin: walls, dead ends with small chests, grand chest in the heart --------------
func _maze(poi: Dictionary, root: Node3D) -> Array:
	var size: int = poi.get("cells", 9)
	var cell := 4.2
	var wall_h: float = poi.get("wall_height", 5.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(poi["id"])
	# Recursive backtracker on a grid. walls[x][z] = [north, east, south, west]
	var walls := []
	var visited := []
	for x in size:
		walls.append([])
		visited.append([])
		for z in size:
			walls[x].append([true, true, true, true])
			visited[x].append(false)
	var stack: Array[Vector2i] = [Vector2i(0, size / 2)]
	visited[0][size / 2] = true
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options := []
		for i in 4:
			var n: Vector2i = cur + dirs[i]
			if n.x >= 0 and n.y >= 0 and n.x < size and n.y < size and not visited[n.x][n.y]:
				options.append(i)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: int = options[rng.randi() % options.size()]
		var nxt: Vector2i = cur + dirs[d]
		walls[cur.x][cur.y][d] = false
		walls[nxt.x][nxt.y][(d + 2) % 4] = false
		visited[nxt.x][nxt.y] = true
		stack.append(nxt)
	# Open the heart (3x3 room) and the entrance
	var mid := size / 2
	for x in range(mid - 1, mid + 2):
		for z in range(mid - 1, mid + 2):
			for i in 4:
				var n: Vector2i = Vector2i(x, z) + dirs[i]
				if n.x >= mid - 1 and n.x <= mid + 1 and n.y >= mid - 1 and n.y <= mid + 1:
					walls[x][z][i] = false
	walls[0][mid][3] = false

	var k := StructureKit.new(hash(poi["id"]) + 1)
	var half := size * cell * 0.5
	var origin := Vector3(-half, 0, -half)
	var style: String = poi.get("style", "moss")
	var col: Color = {"moss": Color(0.7, 0.74, 0.62), "sandstone": Color(0.86, 0.66, 0.46)}.get(style, StructureKit.WHITE_STONE)
	for x in size:
		for z in size:
			var base := origin + Vector3(x * cell, 0, z * cell)
			var w: Array = walls[x][z]
			if w[0]:
				k.wall(base, base + Vector3(cell, 0, 0), wall_h, 0.8, col, true)
			if w[3]:
				k.wall(base, base + Vector3(0, 0, cell), wall_h, 0.8, col, true)
			if x == size - 1 and w[1]:
				k.wall(base + Vector3(cell, 0, 0), base + Vector3(cell, 0, cell), wall_h, 0.8, col, true)
			if z == size - 1 and w[2]:
				k.wall(base + Vector3(0, 0, cell), base + Vector3(cell, 0, cell), wall_h, 0.8, col, true)
	# Corner posts: squat pale stone piers, some capped with lanterns, some
	# broken — the ruin's crown silhouette.
	for x in size + 1:
		for z in size + 1:
			var roll := rng.randf()
			var pp := origin + Vector3(x * cell, 0, z * cell)
			if roll < 0.18:
				k.block(pp + Vector3(0, wall_h * 0.5 + 0.4, 0), Vector3(1.2, wall_h + 0.8, 1.2), StructureKit.WHITE_STONE * 0.86)
				k.block(pp + Vector3(0, wall_h + 0.9, 0), Vector3(1.5, 0.2, 1.5), StructureKit.ROOF, 0.0, false, 0.0, StructureKit.GLAZE)
				k.lantern(pp + Vector3(0, wall_h + 1.35, 0), 0.9)
			elif roll < 0.35:
				k.block(pp + Vector3(0, wall_h * 0.5 + 0.2, 0), Vector3(1.1, wall_h + rng.randf() * 1.4, 1.1), StructureKit.WHITE_STONE * 0.8)
	# Entrance: a wind gate with glowing runes on the plaque
	var gate := origin + Vector3(-2.5, 0, mid * cell + cell * 0.5)
	k.wind_gate(gate, cell * 1.3, wall_h + 0.6, PI * 0.5)
	k.rune(gate + Vector3(0.3, wall_h * 0.9 + 0.7, 0), Vector3(0.05, 0.9, 1.3))
	# Floor slab
	k.block(Vector3(0, -0.2, 0), Vector3(size * cell + 1.0, 0.5, size * cell + 1.0), StructureKit.COOL_STONE * 0.8, 0.0, true, 0.0)
	# Heart shrine: a small hexagonal pavilion over the grand chest.
	k.pavilion(origin + Vector3((mid + 0.5) * cell, -0.4, (mid + 0.5) * cell), 3.2, 6, 3.2, 0.0, 3)
	k.build(root, "Maze", 1200.0)

	# Grand chest in the heart, small chests in dead ends.
	var grand := Chest.create(poi["id"] + ":grand", StringName(poi.get("loot", "chest_grand")), poi.get("reward", []), true)
	root.add_child(grand)
	grand.position = origin + Vector3((mid + 0.5) * cell, 0.1, (mid + 0.5) * cell)
	var dead_ends: Array[Vector2i] = []
	for x in size:
		for z in size:
			var open := 0
			for i in 4:
				if not walls[x][z][i]:
					open += 1
			if open == 1 and absi(x - mid) + absi(z - mid) > 2:
				dead_ends.append(Vector2i(x, z))
	var n_small: int = poi.get("small_chests", 3)
	# Puzzle: the grand chest sits inside a wind seal until every element
	# (braziers / pressure plates) placed in the far dead ends is active.
	var pz: Dictionary = poi.get("puzzle", {})
	if not pz.is_empty():
		var group := PuzzleGroup.new()
		group.puzzle_id = poi["id"]
		root.add_child(group)
		var seal := WindSeal.new()
		seal.puzzle_id = poi["id"]
		seal.radius = 1.5
		root.add_child(seal)
		seal.position = grand.position - Vector3(0, 0.05, 0)
		var far_ends := dead_ends.duplicate()
		far_ends.sort_custom(func(a: Vector2i, b2: Vector2i) -> bool: return absi(a.x - mid) + absi(a.y - mid) > absi(b2.x - mid) + absi(b2.y - mid))
		for i in mini(int(pz.get("count", 2)), far_ends.size()):
			var de: Vector2i = far_ends[i]
			var cpos := origin + Vector3((de.x + 0.5) * cell, 0.0, (de.y + 0.5) * cell)
			if pz.get("type", "braziers") == "braziers":
				var br := Brazier.new()
				br.puzzle_id = poi["id"]
				root.add_child(br)
				br.position = cpos
			else:
				var plate := PressurePlate.new()
				plate.puzzle_id = poi["id"]
				root.add_child(plate)
				plate.position = cpos
				# A crate one cell toward the maze's open side to push onto it.
				var crate := PhysicsProp.create(&"crate", "%s:weight%d" % [poi["id"], i])
				root.add_child(crate)
				crate.position = cpos + Vector3(0, 0.6, 0) + (Vector3(mid - de.x, 0, mid - de.y).normalized() * 1.4)
			dead_ends.erase(de)
	for i in mini(n_small, dead_ends.size()):
		var de: Vector2i = dead_ends[(i * 7 + 3) % dead_ends.size()]
		var ch := Chest.create("%s:small%d" % [poi["id"], i], &"chest_common")
		root.add_child(ch)
		ch.position = origin + Vector3((de.x + 0.5) * cell, 0.05, (de.y + 0.5) * cell)
	var stone := LoreStone.new()
	stone.lore_key = poi.get("lore", "LORE_MAZE")
	stone.title_key = poi["name_key"]
	root.add_child(stone)
	stone.position = gate + Vector3(-3.0, 0, 4.0)
	stone.rotation.y = -PI * 0.5
	var spawns: Array = []
	var guards: Array = poi.get("guards", [])
	for i in guards.size():
		var ge: Vector2i = dead_ends[(i * 5 + 1) % maxi(dead_ends.size(), 1)] if not dead_ends.is_empty() else Vector2i(1, 1)
		spawns.append(_spawn(root, guards[i], origin + Vector3((ge.x + 0.5) * cell, 0, (ge.y + 0.5) * cell), poi["id"], i, poi["id"]))
	return spawns


# --- Enemy camp -------------------------------------------------------------------------------------------
func _camp(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	# Palisade ring with gaps
	for i in 22:
		if i % 11 == 0 or i % 11 == 1:
			continue
		var a := TAU * i / 22.0
		var p := Vector3(cos(a), 0, sin(a)) * 13.0
		p.y = _ground(root, p)
		var h := 2.6 + (i % 3) * 0.4
		k.block(p + Vector3(0, h * 0.5, 0), Vector3(0.45, h, 0.45), WOOD, a)
		k.block(p + Vector3(0, h + 0.25, 0), Vector3(0.3, 0.5, 0.3), WOOD_LIGHT, a + 0.785, false)
	# Tents
	for t in [[Vector3(-5, 0, -4), 0.4], [Vector3(5, 0, -5), -0.5], [Vector3(-4, 0, 6), 2.6]]:
		var c: Vector3 = t[0]
		c.y = _ground(root, c)
		k.roof(c, 3.2, 4.0, 2.4, CLOTH, t[1])
	# Lookout platform (climbable ladder-less: climb the posts)
	var lp := Vector3(8, 0, 6)
	lp.y = _ground(root, lp)
	for off in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		k.block(lp + off + Vector3(0, 2.5, 0), Vector3(0.3, 5.0, 0.3), WOOD)
	k.block(lp + Vector3(0, 5.1, 0), Vector3(2.8, 0.25, 2.8), WOOD_LIGHT)
	k.build(root, "Camp", 700.0)

	var bon := FireSource.new()
	bon.permanent = true
	bon.spreads = false
	bon.radius = 0.8
	root.add_child(bon)
	bon.position = Vector3(0, _ground(root, Vector3.ZERO), 0)
	# Barrels and crates by the tents: fire + barrel = your plan.
	for bp in [Vector3(-3, 0, -2), Vector3(-2.2, 0, -2.6), Vector3(3.5, 0, 3.0)]:
		var barrel := PhysicsProp.create(&"barrel")
		root.add_child(barrel)
		barrel.position = bp + Vector3(0, _ground(root, bp) + 0.6, 0)
	for cp in [Vector3(6, 0, -1), Vector3(6, 0, -2.1)]:
		var crate := PhysicsProp.create(&"crate")
		root.add_child(crate)
		crate.position = cp + Vector3(0, _ground(root, cp) + 0.55, 0)
	var chest := Chest.create(poi["id"] + ":chest", StringName(poi.get("loot", "chest_camp")))
	root.add_child(chest)
	chest.position = Vector3(0, _ground(root, Vector3(0, 0, -8)), -8)
	# A boulder perched uphill: roll it into the camp.
	if poi.has("boulder"):
		var bl: Array = poi["boulder"]
		var boulder := PhysicsProp.create(&"boulder")
		root.add_child(boulder)
		var bpos := Vector3(bl[0], 0, bl[1])
		boulder.position = bpos + Vector3(0, _ground(root, bpos) + 1.4, 0)
	var spawns: Array = []
	var guards: Array = poi.get("guards", [])
	for i in guards.size():
		var a := TAU * i / guards.size() + 0.3
		spawns.append(_spawn(root, guards[i], Vector3(cos(a), 0, sin(a)) * 5.0, poi["id"], i, poi["id"]))
	return spawns


# --- Needle spires: climbing playground, reward on the tallest --------------------------------------
func _spires(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(poi["id"])
	var tallest := Vector3.ZERO
	var tallest_h := 0.0
	for i in int(poi.get("count", 9)):
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.0, 70.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = _ground(root, p) - 1.0
		var h := rng.randf_range(16.0, 44.0)
		var rad := rng.randf_range(2.4, 4.2)
		# Stack of tapering, slightly offset drums: reads as a weathered rock needle.
		var drums := int(h / 5.0)
		var pos := p
		for d in drums:
			var t := float(d) / drums
			var dr := lerpf(rad, rad * 0.45, t)
			var seg_h := h / drums
			var off := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)) * t
			k.drum(pos + off, seg_h + 0.3, dr, dr * 0.93, 7, StructureKit.COOL_STONE * (0.9 + 0.12 * t))
			pos.y += seg_h
		var s := CylinderShape3D.new()
		s.radius = rad * 0.78
		s.height = h
		k.shapes.append([Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), s])
		if h > tallest_h:
			tallest_h = h
			tallest = p + Vector3(0, h, 0)
		# Cap: flat enough to stand on
		k.block(p + Vector3(0, h + 0.15, 0), Vector3(rad * 0.9, 0.3, rad * 0.9), MOSS, rng.randf() * TAU)
	k.build(root, "Spires", 1600.0)
	var chest := Chest.create(poi["id"] + ":top", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = tallest + Vector3(0, 0.3, 0)
	_beacon(poi, root, tallest + Vector3(1.4, 0.3, 0.6))
	return []


# --- Giant tree ----------------------------------------------------------------------------------------------
func _giant_tree(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var bark := Color(0.4, 0.3, 0.24)
	var trunk_h := 34.0
	# Buttress roots
	for i in 6:
		var a := TAU * i / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		k.block(d * 3.2 + Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 4.5), bark * 0.9, a, true)
	k.pillar(Vector3(0, -1, 0), trunk_h * 0.5, 3.6, bark, 12)
	k.pillar(Vector3(0, trunk_h * 0.5 - 1.0, 0), trunk_h * 0.5, 3.0, bark * 1.05, 12)
	# Canopy platforms (walkable) + leaf masses (visual)
	var leaf := Color(0.36, 0.56, 0.36)
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		var y := trunk_h - 6.0 + (i % 2) * 5.0
		k.block(d * 5.0 + Vector3(0, y, 0), Vector3(1.4, 1.2, 8.0), bark, a + PI * 0.5)
		k.canopy(d * 9.0 + Vector3(0, y + 3.5, 0), Vector3(6.0, 4.0, 6.0), leaf * 1.1, leaf * 0.55, i)
	k.canopy(Vector3(0, trunk_h + 5.0, 0), Vector3(10.0, 6.0, 10.0), leaf * 1.15, leaf * 0.6, 9)
	# Offerings: ribbons tied around the trunk, a lantern at the roots.
	for i in 7:
		var a := TAU * i / 7.0
		k.ribbon(Vector3(cos(a) * 3.7, 6.0 + (i % 3) * 0.4, sin(a) * 3.7), 2.4, 0.18, [StructureKit.CINNABAR_LIGHT, StructureKit.GOLD, StructureKit.JADE][i % 3], a)
	k.lantern_post(Vector3(5.5, _ground(root, Vector3(5.5, 0, 1)), 1), PI)
	k.block(Vector3(0, trunk_h - 0.2, 0), Vector3(8.0, 0.6, 8.0), bark * 1.1)
	k.build(root, "GiantTree", 2000.0)
	var chest := Chest.create(poi["id"] + ":crown", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = Vector3(1.5, trunk_h + 0.1, 0)
	var hive := ResourceNode.create(DB.resource_nodes.get(&"honeycomb", {}), poi["id"] + ":hive")
	if not WorldState.is_harvested(poi["id"] + ":hive"):
		root.add_child(hive)
		hive.position = Vector3(-2.0, trunk_h + 0.1, 1.0)
	return []


# --- Overlook with a thermal ---------------------------------------------------------------------------------
func _overlook(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var g := _ground(root, Vector3.ZERO)
	var top := k.terrace(Vector3(0, g, 0), 9.0, 9.0, 0.5, 0.3, [2], true, 3.0)
	k.pavilion(Vector3(0, g + top - 0.45, 0), 2.8, 6, 3.0, 0.3, 1)
	k.rune(Vector3(0, g + top + 0.03, 0), Vector3(1.6, 0.04, 0.22), 0.3)
	for off in [Vector3(4.6, 0, 4.6), Vector3(-4.6, 0, 4.6)]:
		k.lantern_post(Vector3(off.x, g + top, off.z), 0.3)
	k.build(root, "Overlook", 1400.0)
	_night_lights(root, k.lamps, 1)
	var up := UpdraftZone.new()
	var off: Array = poi.get("updraft", [12, 0])
	var up_pos := Vector3(off[0], 0, off[1])
	up.height = poi.get("updraft_height", 70.0)
	root.add_child(up)
	up.position = up_pos + Vector3(0, _ground(root, up_pos), 0)
	var stone := LoreStone.new()
	stone.lore_key = poi.get("lore", "LORE_OVERLOOK")
	stone.title_key = poi["name_key"]
	root.add_child(stone)
	stone.position = Vector3(0, _ground(root, Vector3.ZERO) + 1.0, -1.2)
	return []


# --- Shipwreck ------------------------------------------------------------------------------------------------
func _shipwreck(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var hull := Color(0.4, 0.3, 0.22)
	var yaw := 0.5
	for i in 9:
		var z := -9.0 + i * 2.2
		var w := 3.6 - absf(i - 4.0) * 0.45
		k.block(Vector3(-w, 1.2, z), Vector3(0.35, 2.6, 2.1), hull, yaw * 0.1)
		if i % 3 != 1:
			k.block(Vector3(w, 1.0 + (i % 2) * 0.4, z), Vector3(0.35, 2.2, 2.1), hull * 0.9, yaw * 0.1)
		k.block(Vector3(0, 0.1, z), Vector3(w * 2.0, 0.3, 2.1), hull * 1.1)
	k.pillar(Vector3(0, 0, -2), 11.0, 0.3, hull * 0.8, 6)
	k.block(Vector3(1.2, 8.0, -2), Vector3(0.1, 4.0, 3.5), Color(0.8, 0.76, 0.66), 0.4, false)
	var n := k.build(root, "Wreck", 900.0)
	n.rotation = Vector3(0.05, yaw, 0.12)
	var chest := Chest.create(poi["id"] + ":hold", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), false)
	root.add_child(chest)
	chest.position = Vector3(0.5, 0.3, 2.0)
	var spawns: Array = []
	var guards: Array = poi.get("guards", [])
	for i in guards.size():
		spawns.append(_spawn(root, guards[i], Vector3(8 + i * 3, 0, -6 + i * 4), poi["id"], i, poi["id"]))
	return spawns


# --- Broken watchtower ------------------------------------------------------------------------------------------
func _watchtower(poi: Dictionary, root: Node3D) -> Array:
	# A Wind Warden pagoda, its upper storeys torn away long ago: climb the
	# broken columns for the view.
	var k := StructureKit.new(hash(poi["id"]))
	var g := _ground(root, Vector3.ZERO)
	var top := k.terrace(Vector3(0, g, 0), 9.0, 9.0, 0.7, 0.4, [0], false, 3.0)
	k.pagoda(Vector3(0, g + top, 0), 4, 5.4, 0.4, 2)
	k.rock(Vector3(6, g + 0.5, 2), Vector3(1.5, 1.0, 1.4), StructureKit.COOL_STONE)
	k.rock(Vector3(-5, g + 0.4, 5), Vector3(1.1, 0.8, 1.3), StructureKit.COOL_STONE)
	k.block_xf(Transform3D(Basis(Vector3(0.3, 0, 1).normalized(), 0.5), Vector3(4.5, g + 0.4, -5.0)), Vector3(4.0, 0.3, 3.0), StructureKit.ROOF, true, StructureKit.GLAZE)
	k.build(root, "Watchtower", 1600.0)
	var stone := LoreStone.new()
	stone.lore_key = poi.get("lore", "LORE_TOWER")
	stone.title_key = poi["name_key"]
	root.add_child(stone)
	stone.position = Vector3(0, _ground(root, Vector3(0, 0, 7)) + 0.9, 7.0)
	return []


# --- Summit cairn -----------------------------------------------------------------------------------------------
func _summit(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var y := _ground(root, Vector3.ZERO)
	for i in 5:
		k.rock(Vector3(0, y + 0.5 + i * 0.7, 0), Vector3(1.4 - i * 0.22, 0.45, 1.3 - i * 0.2), STONE * (1.0 + i * 0.03))
	k.pillar(Vector3(0, y + 3.2, 0), 3.0, 0.08, StructureKit.INK_WOOD, 5)
	for j in 3:
		k.ribbon(Vector3(0, y + 6.0 - j * 0.15, 0), 2.6 - j * 0.4, 0.2, [StructureKit.CINNABAR_LIGHT, StructureKit.GOLD, StructureKit.JADE][j], j * 2.0)
	k.build(root, "Cairn", 2500.0)
	var chest := Chest.create(poi["id"] + ":peak", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = Vector3(2.0, _ground(root, Vector3(2, 0, 0)), 0)
	return []


# --- Den (animal/enemy lair among rocks) ------------------------------------------------------------------------
func _den(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(cos(a), 0, sin(a)) * 6.0
		p.y = _ground(root, p) + 0.6
		k.rock(p, Vector3(2.0, 1.6, 1.8), STONE_DARK)
	k.build(root, "Den", 600.0)
	var spawns: Array = []
	var guards: Array = poi.get("guards", [])
	for i in guards.size():
		spawns.append(_spawn(root, guards[i], Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), poi["id"], i, poi["id"]))
	var chest := Chest.create(poi["id"] + ":stash", StringName(poi.get("loot", "chest_common")))
	root.add_child(chest)
	chest.position = Vector3(0, _ground(root, Vector3.ZERO), 0)
	return spawns


# --- Cloud Terrace Temple: the Wind Wardens' seat on the mountain shoulder -----------------------
func _temple(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	k.near_range = 220.0
	var yaw: float = poi.get("yaw", 0.0)
	var basis := Basis(Vector3.UP, yaw)
	# Lower court: broad terrace, stairs down the slope toward the valley path.
	var t1 := k.terrace(Vector3.ZERO, 34.0, 30.0, 1.4, yaw, [0], true, 9.0)
	# Upper court with the main hall (double eave).
	var c2 := basis * Vector3(0, 0, -5.0) + Vector3(0, t1, 0)
	var t2 := k.terrace(c2, 22.0, 14.0, 1.8, yaw, [0], true, 2.0)
	k.hall(c2 + Vector3(0, t2, 0) + basis * Vector3(0, 0, -1.0), 12.0, 7.6, 4.4, yaw, StructureKit.ROOF, true)
	# East: five-storey pagoda. West: hexagonal wind pavilion.
	var pg := basis * Vector3(11.5, 0, 9.0) + Vector3(0, t1, 0)
	k.pagoda(pg, 5, 4.6, yaw)
	var pv := basis * Vector3(-11.5, 0, 9.0) + Vector3(0, t1, 0)
	k.pavilion(pv - Vector3(0, 0.45, 0), 2.6, 6, 3.0, yaw, 0)
	# Wind gate at the foot of the grand stair.
	var foot := basis * Vector3(0, 0, 15.0 + (t1 + 0.2) * 1.6 + 4.0)
	foot.y = _ground(root, foot)
	k.wind_gate(foot, 6.0, 5.0, yaw)
	# Lantern rows and ribbon poles.
	for sx in [-1.0, 1.0]:
		for i in 3:
			k.lantern_post(basis * Vector3(sx * 6.0, 0, 12.0 - i * 6.0) + Vector3(0, t1, 0), yaw + (PI if sx > 0 else 0.0))
		var rp := basis * Vector3(sx * 15.5, 0, 13.5) + Vector3(0, t1, 0)
		k.pillar(rp, 8.0, 0.12, StructureKit.INK_WOOD, 5)
		for j in 3:
			k.ribbon(rp + Vector3(0, 7.8 - j * 0.1, 0), 4.0 - j * 0.7, 0.26, [StructureKit.CINNABAR_LIGHT, StructureKit.JADE, StructureKit.GOLD][j], yaw + j)
	# Incense brazier in the lower court.
	var bz := basis * Vector3(0, 0, 6.0) + Vector3(0, t1, 0)
	StructureKit.prism_into(k.b, bz, bz + Vector3(0, 0.9, 0), 0.9, 1.1, 8, StructureKit.id(StructureKit.GOLD * 0.7, StructureKit.GILT))
	k.build(root, "Temple", 2600.0)
	_night_lights(root, k.lamps, 3)
	var chest := Chest.create(poi["id"] + ":altar", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = c2 + Vector3(0, t2 + 0.15, 0) + basis * Vector3(0, 0, -2.2)
	chest.rotation.y = yaw
	var stone := LoreStone.new()
	stone.lore_key = poi.get("lore", "LORE_TEMPLE")
	stone.title_key = poi["name_key"]
	root.add_child(stone)
	stone.position = bz + basis * Vector3(3.0, 0, 0)
	_beacon(poi, root, basis * Vector3(-14.0, 0, -9.0) + Vector3(0, t1, 0))
	var spawns: Array = []
	var npcs: Array = poi.get("npcs", [])
	for i in npcs.size():
		var np := basis * Vector3(npcs[i][1], 0, npcs[i][2])
		var sp := {"entity": StringName(npcs[i][0]), "pos": root.global_position + np + Vector3(0, t1 + 0.3, 0), "group": poi["id"], "id": "%s:%d" % [poi["id"], i]}
		if (npcs[i] as Array).size() > 3:
			sp["flag"] = String(npcs[i][3])
		spawns.append(sp)
	return spawns


# --- Wayside shrine: small pavilion with a wind stone, lanterns, ribbons -------------------------
func _shrine(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var yaw: float = poi.get("yaw", 0.0)
	var g := _ground(root, Vector3.ZERO)
	var top := k.terrace(Vector3(0, g, 0), 8.0, 8.0, 0.6, yaw, [0], true, 2.5)
	k.pavilion(Vector3(0, g + top - 0.45, 0), 2.4, 6, 2.8, yaw, 0)
	# Wind stone: a pale standing stone with a glowing band.
	k.block(Vector3(0, g + top + 0.8, 0), Vector3(0.7, 1.6, 0.5), StructureKit.WHITE_STONE, yaw)
	k.rune(Vector3(0, g + top + 1.1, 0), Vector3(0.74, 0.08, 0.54), yaw)
	var basis := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		k.lantern_post(basis * Vector3(sx * 3.4, 0, 3.4) + Vector3(0, g + top, 0), yaw)
	k.build(root, "Shrine", 1000.0)
	_night_lights(root, k.lamps, 1)
	var stone := LoreStone.new()
	stone.lore_key = poi.get("lore", "LORE_SHRINE")
	stone.title_key = poi["name_key"]
	root.add_child(stone)
	stone.position = Vector3(0, g + top, 0) + basis * Vector3(0, 0, 1.0)
	if poi.has("loot"):
		var chest := Chest.create(poi["id"] + ":offering", StringName(poi["loot"]), poi.get("reward", []))
		root.add_child(chest)
		chest.position = Vector3(0, g + top, 0) + basis * Vector3(0, 0, -1.2)
	_beacon(poi, root, Vector3(0, g + top, 0) + basis * Vector3(2.6, 0, -2.6))
	return []


# --- Arched bridge with a covered gallery at its crown ------------------------------------------
func _bridge(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var yaw: float = poi.get("yaw", 0.0)
	var span: float = poi.get("span", 60.0)
	var rise: float = poi.get("rise", 6.0)
	var width := 4.2
	var basis := Basis(Vector3.UP, yaw)
	var segs := int(span / 1.8)
	var prev := Vector3.ZERO
	for i in segs + 1:
		var t := float(i) / segs
		var x := -span * 0.5 + span * t
		var y := 4.0 * rise * t * (1.0 - t)
		var p := basis * Vector3(x, y, 0)
		if i > 0:
			var mid := (prev + p) * 0.5
			var dir := (p - prev)
			var along := dir.normalized()
			var side := basis * Vector3(0, 0, 1)
			var up := along.cross(side).normalized() * -1.0
			if up.y < 0.0:
				up = -up
			k.block_xf(Transform3D(Basis(along, up, side), mid - up * 0.25), Vector3(dir.length() + 0.05, 0.5, width), StructureKit.WHITE_STONE * (0.92 + 0.06 * (i % 2)), true)
			# Balustrade on both sides
			for sz in [-1.0, 1.0]:
				k.balustrade(prev + side * sz * (width * 0.5 - 0.15), p + side * sz * (width * 0.5 - 0.15), 0.9)
		prev = p
	# Piers with cutwaters down to the river bed.
	for t: float in [0.25, 0.5, 0.75]:
		var x := -span * 0.5 + span * t
		var y := 4.0 * rise * t * (1.0 - t)
		var base := basis * Vector3(x, -root.global_position.y - 6.0, 0)
		var top_y := y - 0.5
		var h := top_y - base.y
		k.block(base + Vector3(0, h * 0.5, 0), Vector3(2.6, h, width + 0.8), StructureKit.COOL_STONE, yaw)
		k.block(base + Vector3(0, h * 0.5 - 1.0, 0) + basis * Vector3(0, 0, width * 0.5 + 0.9), Vector3(1.8, h - 2.0, 1.8), StructureKit.COOL_STONE * 0.9, yaw + PI * 0.25, false)
	# Abutments
	for sx in [-1.0, 1.0]:
		var e := basis * Vector3(sx * (span * 0.5 + 2.0), 0, 0)
		var eg := _ground(root, e)
		var bottom := minf(eg, 0.0) - 3.0
		k.block(e + Vector3(0, bottom * 0.5 - 0.1, 0), Vector3(4.5, -bottom, width + 1.2), StructureKit.COOL_STONE, yaw)
		k.lantern_post(basis * Vector3(sx * (span * 0.5 - 0.5), 0, width * 0.5 + 0.4), yaw)
	# Covered gallery at the crown.
	var crown := Vector3(0, rise, 0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.column(crown + basis * Vector3(sx * 2.6, -0.05, sz * (width * 0.5 - 0.3)), 3.2, 0.22)
	k.hip_roof(crown + Vector3(0, 3.6, 0), 8.6, width + 2.4, 1.6, yaw)
	for sz in [-1.0, 1.0]:
		k.ribbon(crown + basis * Vector3(0, 3.3, sz * (width * 0.5 + 0.9)), 2.6, 0.22, StructureKit.CINNABAR_LIGHT if sz > 0 else StructureKit.JADE, yaw)
	k.near_range = 200.0
	k.build(root, "Bridge", 1400.0)
	_night_lights(root, k.lamps, 2)
	return []


# --- Overgrown ruins: collapsed hall, broken columns, a buried roof ---------------------------------
func _ruins(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(poi["id"])
	var g := _ground(root, Vector3.ZERO)
	var top := k.terrace(Vector3(0, g, 0), 24.0, 18.0, 0.9, 0.2, [0, 2], false, 3.0)
	var basis := Basis(Vector3.UP, 0.2)
	# Broken colonnade
	for i in 6:
		for side in [-1.0, 1.0]:
			var p := basis * Vector3(-9.0 + i * 3.6, 0, side * 6.0) + Vector3(0, g + top, 0)
			var h := rng.randf_range(0.8, 5.0) if rng.randf() < 0.75 else 5.0
			k.column(p, h, 0.34)
			if h < 2.0:
				# Fallen drum nearby
				var q := p + basis * Vector3(rng.randf_range(-1.5, 1.5), 0.35, side * -1.6)
				k.block_xf(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5), q), Vector3(0.7, 1.4, 0.7), StructureKit.CINNABAR * 0.8, true)
	# Lintel still standing on the intact pair
	k.block_xf(Transform3D(basis, basis * Vector3(9.0, 5.2, 6.0) + Vector3(0, g + top, 0)), Vector3(1.0, 0.4, 0.5), StructureKit.CINNABAR, false)
	# Collapsed roof: a hip roof sunk into the ground, tilted.
	var roof_c := basis * Vector3(1.5, 0, -1.0) + Vector3(0, g + top - 0.8, 0)
	k.hip_roof(roof_c, 12.0, 8.0, 3.0, 0.2 + 0.12)
	# Half walls
	k.wall(basis * Vector3(-11, 0, -8) + Vector3(0, g + top, 0), basis * Vector3(-3, 0, -8) + Vector3(0, g + top, 0), 2.2, 0.6, StructureKit.WHITE_STONE * 0.85, false)
	k.wall(basis * Vector3(6, 0, 8) + Vector3(0, g + top, 0), basis * Vector3(11, 0, 8) + Vector3(0, g + top, 0), 1.4, 0.6, StructureKit.WHITE_STONE * 0.85, false)
	for i in 5:
		k.rock(basis * Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-9, 9)) + Vector3(0, g + top + 0.3, 0), Vector3(0.9, 0.6, 0.8) * rng.randf_range(0.7, 1.4), StructureKit.WHITE_STONE * 0.8)
	k.build(root, "Ruins", 1200.0)
	var chest := Chest.create(poi["id"] + ":cache", StringName(poi.get("loot", "chest_common")), poi.get("reward", []))
	root.add_child(chest)
	chest.position = basis * Vector3(-6.0, 0, -5.0) + Vector3(0, g + top, 0)
	if poi.has("lore"):
		var stone := LoreStone.new()
		stone.lore_key = poi["lore"]
		stone.title_key = poi["name_key"]
		root.add_child(stone)
		stone.position = basis * Vector3(0, 0, 9.5) + Vector3(0, g + top, 0)
	var spawns: Array = []
	var guards: Array = poi.get("guards", [])
	for i in guards.size():
		spawns.append(_spawn(root, guards[i], basis * Vector3(-6.0 + i * 4.0, 0, 2.0), poi["id"], i, poi["id"]))
	return spawns


# --- Sunscar Oasis: nomad tents, a shade pavilion, palms around the pool -------------------------
func _oasis(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var sand_cloth := [Color(0.82, 0.42, 0.24), Color(0.92, 0.78, 0.52), Color(0.36, 0.52, 0.56)]
	var tents := [[Vector3(-9, 0, -4), 0.5], [Vector3(8, 0, -7), -0.4], [Vector3(-6, 0, 9), 2.3], [Vector3(10, 0, 6), -2.0]]
	for i in tents.size():
		var c: Vector3 = tents[i][0]
		c.y = _ground(root, c)
		for off in [Vector3(-1.9, 0, -2.2), Vector3(1.9, 0, -2.2), Vector3(1.9, 0, 2.2), Vector3(-1.9, 0, 2.2)]:
			k.pillar(c + Basis(Vector3.UP, tents[i][1]) * off, 2.2, 0.08, StructureKit.INK_WOOD, 4)
		k.roof(c + Vector3(0, 2.2, 0), 4.2, 5.0, 1.4, sand_cloth[i % 3], tents[i][1])
		k.ribbon(c + Basis(Vector3.UP, tents[i][1]) * Vector3(2.2, 3.4, 0), 1.6, 0.18, sand_cloth[(i + 1) % 3], tents[i][1])
	# Shade pavilion at the water's edge (the nomads borrowed Warden stones)
	var pv := Vector3(0, _ground(root, Vector3(0, 0, -12)), -12)
	k.pavilion(pv, 2.6, 6, 3.0, 0.2, 0)
	for lp in [Vector3(4, 0, 2), Vector3(-4, 0, 2), Vector3(0, 0, 8)]:
		lp.y = _ground(root, lp)
		k.lantern_post(lp, randf() * TAU)
	k.build(root, "Oasis", 900.0)
	_night_lights(root, k.lamps, 2)
	# Palms (shared vegetation meshes, one instance each)
	var palm := MeshKit.get_mesh(&"palm")
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var pp := Vector3(cos(a) * 17.0, 0, sin(a) * 17.0)
		pp.y = _ground(root, pp) - 0.3
		var mi := MeshInstance3D.new()
		mi.mesh = palm
		mi.material_override = WorldMaterials.get_mat(&"foliage")
		mi.visibility_range_end = 700.0
		root.add_child(mi)
		mi.position = pp
		mi.rotation.y = a * 3.0
		mi.scale = Vector3.ONE * (1.0 + (i % 3) * 0.15)
	var fire := Campfire.new()
	root.add_child(fire)
	fire.position = Vector3(0, _ground(root, Vector3(0, 0, 2)), 2)
	var stone := LoreStone.new()
	stone.lore_key = poi.get("lore", "LORE_OASIS")
	stone.title_key = poi["name_key"]
	root.add_child(stone)
	stone.position = pv + Vector3(0, 0.45, 1.5)
	return _people(poi, root)


# --- Boss arena: a ring of broken Warden pillars around a paved floor ---------------------------
func _arena(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	k.near_range = 240.0
	var r: float = poi.get("radius", 22.0)
	var veil: bool = poi.get("style", "desert") == "veil"
	var stone: Color = Color(0.36, 0.33, 0.46) if veil else Color(0.84, 0.64, 0.44)
	var g := _ground(root, Vector3.ZERO)
	# Paved floor with inlaid rings
	StructureKit.prism_into(k.b, Vector3(0, g - 2.0, 0), Vector3(0, g + 0.25, 0), r + 1.5, r + 1.0, 24, StructureKit.id(stone * 0.85, 1.0))
	StructureKit.prism_into(k.far, Vector3(0, g - 2.0, 0), Vector3(0, g + 0.25, 0), r + 1.5, r + 1.0, 12, StructureKit.id(stone * 0.85, 1.0))
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = r + 1.0
	floor_shape.height = 2.25
	k.shapes.append([Transform3D(Basis(), Vector3(0, g - 0.875, 0)), floor_shape])
	for ring_r in [r * 0.35, r * 0.7]:
		k.rune(Vector3(0, g + 0.27, 0) + Vector3(ring_r, 0, 0), Vector3(0.3, 0.02, 0.3))
		for i in 24:
			var a := TAU * i / 24.0
			StructureKit.box_into(k.b, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * ring_r, g + 0.27, sin(a) * ring_r)), Vector3(0.25, 0.04, ring_r * TAU / 24.0 * 0.9), StructureKit.id(StructureKit.GOLD * 0.8 if not veil else Color(0.45, 0.95, 0.85), StructureKit.GILT if not veil else StructureKit.LAMP))
	# Ring of pillars, some broken, lintels on the intact pairs
	var n := 12
	for i in n:
		var a := TAU * i / n
		var p := Vector3(cos(a) * (r + 0.4), g + 0.25, sin(a) * (r + 0.4))
		var h := 7.0 if i % 3 != 1 else 2.0 + (i % 5) * 0.6
		k.drum(p, h, 0.75, 0.6, 8, stone)
		var cs := CylinderShape3D.new()
		cs.radius = 0.75
		cs.height = h
		k.shapes.append([Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), cs])
		if h > 6.0:
			k.block(p + Vector3(0, h + 0.3, 0), Vector3(1.8, 0.6, 1.8), stone * 1.1, -a)
			k.ribbon(p + Vector3(0, h - 0.2, 0) + Vector3(cos(a), 0, sin(a)) * 0.8, 3.0, 0.3, Color(0.55, 0.35, 0.85) if veil else StructureKit.CINNABAR_LIGHT, -a + PI * 0.5)
	if veil:
		# Still-crystals erupting around the island
		for i in 10:
			var a := TAU * i / 10.0 + 0.2
			var cp := Vector3(cos(a), 0, sin(a)) * (r + 6.0 + (i % 3) * 3.0)
			cp.y = _ground(root, cp) - 0.5
			var mi := MeshInstance3D.new()
			mi.mesh = MeshKit.get_mesh(&"crystal")
			mi.material_override = WorldMaterials.get_mat(&"crystal")
			mi.scale = Vector3.ONE * (1.4 + (i % 4) * 0.4)
			mi.visibility_range_end = 1500.0
			root.add_child(mi)
			mi.position = cp
	k.build(root, "Arena", 2200.0)
	return []


# --- Veil anchor: a hush-pillar on the crater rim, guarded by shades ------------------------------
func _anchor(poi: Dictionary, root: Node3D) -> Array:
	var g := _ground(root, Vector3.ZERO)
	var a := VeilAnchor.new()
	a.flag_id = poi.get("flag", poi["id"])
	root.add_child(a)
	a.position = Vector3(0, g, 0)
	var k := StructureKit.new(hash(poi["id"]))
	for i in 5:
		var ang := TAU * i / 5.0
		var p := Vector3(cos(ang) * 6.0, 0, sin(ang) * 6.0)
		p.y = _ground(root, p)
		k.drum(p, 1.6 + (i % 2) * 1.4, 0.45, 0.3, 5, Color(0.34, 0.3, 0.44))
	k.build(root, "AnchorRing", 900.0)
	var spawns: Array = []
	var guards: Array = poi.get("guards", [])
	for i in guards.size():
		var ang := TAU * i / maxf(guards.size(), 1)
		spawns.append(_spawn(root, guards[i], Vector3(cos(ang) * 4.0, 0, sin(ang) * 4.0), poi["id"], i, poi["id"]))
	return spawns


# --- Drifting isles: floating rock islands with crystals over the still lake ----------------------
func _floating_isles(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	k.near_range = 260.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(poi["id"])
	var top := Vector3.ZERO
	var count: int = poi.get("count", 7)
	for i in count:
		var t := float(i) / maxf(count - 1, 1)
		# A rising spiral: each isle reachable from the previous by glide/jade.
		var a := t * TAU * 1.2
		var p := Vector3(cos(a) * (40.0 - t * 22.0), 18.0 + t * 52.0, sin(a) * (40.0 - t * 22.0))
		var s := rng.randf_range(4.0, 7.0) * (1.0 - t * 0.3)
		k.rock(p, Vector3(s, s * 0.45, s * 0.9), Color(0.38, 0.34, 0.48), false)
		k.rock(p + Vector3(0, -s * 0.55, 0), Vector3(s * 0.6, s * 0.7, s * 0.55), Color(0.3, 0.27, 0.4), false)
		k.block(p + Vector3(0, s * 0.3, 0), Vector3(s * 1.3, 0.6, s * 1.1), Color(0.3, 0.42, 0.34), rng.randf() * TAU)
		var cs := CylinderShape3D.new()
		cs.radius = s * 0.75
		cs.height = s * 0.7
		k.shapes.append([Transform3D(Basis(), p), cs])
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.get_mesh(&"crystal")
		mi.material_override = WorldMaterials.get_mat(&"crystal")
		mi.visibility_range_end = 1500.0
		root.add_child(mi)
		mi.position = p + Vector3(s * 0.3, s * 0.3, 0)
		top = p + Vector3(0, s * 0.3 + 0.35, 0)
	k.build(root, "Isles", 2400.0)
	var chest := Chest.create(poi["id"] + ":crown", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = top
	var lev := LevityZone.new()
	lev.radius = poi.get("levity_radius", 110.0)
	root.add_child(lev)
	return []


# --- NPC camp: a tent or two, a cook fire, a banner; flavour props by style --------------------
func _npc_camp(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var yaw: float = poi.get("yaw", 0.0)
	var basis := Basis(Vector3.UP, yaw)
	var style: String = poi.get("style", "camp")
	var cloths := {"fisher": Color(0.36, 0.52, 0.56), "hunter": Color(0.45, 0.5, 0.3), "climber": Color(0.8, 0.45, 0.25),
		"pilgrim": Color(0.72, 0.62, 0.82), "scholar": Color(0.82, 0.74, 0.52), "hermit": Color(0.55, 0.5, 0.4)}
	var cloth: Color = cloths.get(style, CLOTH)
	for i in int(poi.get("tents", 1)):
		var c := basis * Vector3(-4.5 + i * 7.0, 0, -3.5)
		c.y = _ground(root, c)
		var ty := yaw + (0.3 if i % 2 == 0 else -0.25)
		for off in [Vector3(-1.6, 0, -2.0), Vector3(1.6, 0, -2.0), Vector3(1.6, 0, 2.0), Vector3(-1.6, 0, 2.0)]:
			k.pillar(c + Basis(Vector3.UP, ty) * off, 1.9, 0.07, StructureKit.INK_WOOD, 4)
		k.roof(c + Vector3(0, 1.9, 0), 3.6, 4.4, 1.3, cloth, ty)
	var lp := basis * Vector3(3.5, 0, 2.5)
	lp.y = _ground(root, lp)
	k.lantern_post(lp, yaw)
	var bp := basis * Vector3(-3.0, 0, 3.0)
	bp.y = _ground(root, bp)
	k.pillar(bp, 4.5, 0.08, StructureKit.INK_WOOD, 5)
	k.ribbon(bp + Vector3(0, 4.4, 0), 2.2, 0.22, cloth.lightened(0.25), yaw)
	var fp := basis * Vector3(4.5, 0, -2.0)
	fp.y = _ground(root, fp)
	match style:
		"fisher":
			k.pillar(fp + basis * Vector3(-1.4, 0, 0), 1.8, 0.06, StructureKit.INK_WOOD, 4)
			k.pillar(fp + basis * Vector3(1.4, 0, 0), 1.8, 0.06, StructureKit.INK_WOOD, 4)
			k.block_xf(Transform3D(basis, fp + Vector3(0, 1.8, 0)), Vector3(3.0, 0.08, 0.08), StructureKit.INK_WOOD, false)
			k.block_xf(Transform3D(basis, fp + Vector3(0, 1.15, 0)), Vector3(2.6, 1.1, 0.03), Color(0.52, 0.58, 0.55), false, StructureKit.CLOTH)
			var hull := basis * Vector3(-6.5, 0, 1.0)
			hull.y = _ground(root, hull)
			k.block_xf(Transform3D(basis * Basis(Vector3.FORWARD, PI), hull + Vector3(0, 0.35, 0)), Vector3(1.3, 0.6, 3.6), WOOD, true)
		"hunter":
			k.pillar(fp + basis * Vector3(-1.1, 0, 0), 2.2, 0.07, StructureKit.INK_WOOD, 4)
			k.pillar(fp + basis * Vector3(1.1, 0, 0), 2.2, 0.07, StructureKit.INK_WOOD, 4)
			k.block_xf(Transform3D(basis, fp + Vector3(0, 1.4, 0)), Vector3(1.9, 1.4, 0.05), Color(0.62, 0.45, 0.3), false, StructureKit.CLOTH)
			k.pillar(basis * Vector3(-6.0, 0, 0) + Vector3(0, _ground(root, basis * Vector3(-6.0, 0, 0)), 0), 2.0, 0.09, StructureKit.INK_WOOD, 4)
		"climber":
			for i in 3:
				var rc := fp + basis * Vector3(-0.8 + i * 0.8, 0.15, 0)
				StructureKit.prism_into(k.b, rc, rc + Vector3(0, 0.3, 0), 0.35, 0.35, 8, StructureKit.id(Color(0.78, 0.66, 0.42), StructureKit.MATTE))
			k.rock(basis * Vector3(-6.5, 1.4, -1.0) + Vector3(0, _ground(root, basis * Vector3(-6.5, 0, -1.0)), 0), Vector3(2.4, 2.6, 2.2), StructureKit.COOL_STONE)
		"pilgrim":
			var a := basis * Vector3(-6.0, 0, -1.0)
			var b2 := basis * Vector3(6.0, 0, -1.0)
			a.y = _ground(root, a)
			b2.y = _ground(root, b2)
			k.pillar(a, 3.4, 0.06, StructureKit.INK_WOOD, 4)
			k.pillar(b2, 3.4, 0.06, StructureKit.INK_WOOD, 4)
			for i in 9:
				var t := (i + 0.5) / 9.0
				var q := a.lerp(b2, t) + Vector3(0, 3.3 - sin(t * PI) * 0.6, 0)
				k.ribbon(q, 0.55, 0.3, [StructureKit.CINNABAR_LIGHT, StructureKit.GOLD, StructureKit.JADE, StructureKit.PAPER][i % 4], yaw)
		"scholar", "hermit":
			k.block_xf(Transform3D(basis, fp + Vector3(0, 0.45, 0)), Vector3(1.8, 0.9, 0.9), WOOD_LIGHT, true)
			StructureKit.prism_into(k.b, fp + basis * Vector3(-0.4, 0.95, 0), fp + basis * Vector3(0.3, 0.95, 0), 0.06, 0.06, 6, StructureKit.id(StructureKit.PAPER, StructureKit.MATTE))
	k.build(root, "Camp", 800.0)
	_night_lights(root, k.lamps, 1)
	var fire := Campfire.new()
	root.add_child(fire)
	fire.position = basis * Vector3(0, 0, 2.5) + Vector3(0, _ground(root, basis * Vector3(0, 0, 2.5)), 0)
	if poi.has("loot"):
		var chest := Chest.create(poi["id"] + ":stash", StringName(poi["loot"]), poi.get("reward", []))
		root.add_child(chest)
		var cp := basis * Vector3(-4.5, 0, -6.0)
		chest.position = cp + Vector3(0, _ground(root, cp), 0)
	return _npc_spawns(poi, root)


# --- Grotto: a ring of boulders under a slab roof, one mouth; glowmoss inside -------------------
func _cave(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(poi["id"])
	var yaw: float = poi.get("yaw", 0.0)
	var r: float = poi.get("radius", 9.0)
	var basis := Basis(Vector3.UP, yaw)
	var rock_col := Color(String(poi.get("rock_color", "#6f6a62")))
	var n := 14
	for i in n:
		var a := TAU * i / n
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.42:
			continue   # the mouth faces local +z
		var p := basis * Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = _ground(root, p) + 1.5
		k.rock(p, Vector3(3.2, 3.2, 2.6) * rng.randf_range(0.9, 1.15), rock_col)
		var p2 := basis * Vector3(cos(a) * r * 0.9, 0, sin(a) * r * 0.9)
		p2.y = _ground(root, p2) + 4.3
		k.rock(p2, Vector3(2.8, 2.0, 2.5), rock_col * 0.9, false)
	var g := _ground(root, Vector3.ZERO)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		k.rock(Vector3(cos(a) * r * 0.45, g + 6.1, sin(a) * r * 0.45), Vector3(r * 0.6, 1.3, r * 0.6), rock_col * 0.85, false)
	k.block(Vector3(0, g + 6.3, 0), Vector3(r * 1.9, 1.0, r * 1.9), rock_col * 0.8, yaw, true)
	# Mouth lintel: two stacked boulders framing the way in
	for sx in [-1.0, 1.0]:
		var m := basis * Vector3(sx * 2.8, 0, r + 0.6)
		m.y = _ground(root, m) + 1.2
		k.rock(m, Vector3(1.6, 2.4, 1.6), rock_col)
	# Glowmoss patches (glow runes) and a dim cold light inside
	for i in 6:
		var a := rng.randf() * TAU
		var q := Vector3(cos(a) * r * 0.7, 0, sin(a) * r * 0.7)
		q.y = _ground(root, q) + rng.randf_range(0.2, 2.5)
		k.rune(q, Vector3(0.5, 0.06, 0.4), a)
	k.build(root, "Grotto", 700.0)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.9, 0.8)
	light.light_energy = 1.8
	light.omni_range = r * 1.4
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	light.distance_fade_length = 20.0
	root.add_child(light)
	light.position = Vector3(0, g + 3.0, 0)
	if poi.has("loot"):
		var chest := Chest.create(poi["id"] + ":hoard", StringName(poi["loot"]), poi.get("reward", []))
		root.add_child(chest)
		var cp := basis * Vector3(0, 0, -r * 0.55)
		chest.position = cp + Vector3(0, _ground(root, cp), 0)
	var nodes: Array = poi.get("nodes", [])
	for i in nodes.size():
		var nd: Dictionary = DB.resource_nodes.get(StringName(nodes[i][0]), {})
		var nid := "%s:node%d" % [poi["id"], i]
		if nd.is_empty() or WorldState.is_harvested(nid):
			continue
		var rn := ResourceNode.create(nd, nid)
		root.add_child(rn)
		var np := Vector3(nodes[i][1], 0, nodes[i][2])
		rn.position = np + Vector3(0, _ground(root, np), 0)
	return _npc_spawns(poi, root)


# --- Road warden post: gatehouse, watch platform, palisade, banner -----------------------------------
func _post(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var yaw: float = poi.get("yaw", 0.0)
	var basis := Basis(Vector3.UP, yaw)
	var g := _ground(root, Vector3.ZERO)
	var top := k.terrace(Vector3(0, g, 0), 8.0, 6.5, 0.5, yaw, [0], false, 2.0)
	k.hall(Vector3(0, g + top, 0), 5.5, 4.2, 2.8, yaw, StructureKit.ROOF_LIGHT)
	var wp := basis * Vector3(7.0, 0, -2.0)
	wp.y = _ground(root, wp)
	for off in [Vector3(-1.1, 0, -1.1), Vector3(1.1, 0, -1.1), Vector3(1.1, 0, 1.1), Vector3(-1.1, 0, 1.1)]:
		k.block(wp + basis * off + Vector3(0, 3.0, 0), Vector3(0.3, 6.0, 0.3), WOOD, yaw)
	k.block(wp + Vector3(0, 6.1, 0), Vector3(3.0, 0.25, 3.0), WOOD_LIGHT, yaw)
	k.hip_roof(wp + Vector3(0, 8.0, 0), 3.4, 3.4, 1.0, yaw, StructureKit.ROOF)
	for i in 7:
		var p := basis * Vector3(-9.0 + i * 1.3, 0, 5.5)
		p.y = _ground(root, p)
		k.block(p + Vector3(0, 1.3, 0), Vector3(0.4, 2.6, 0.4), WOOD, yaw)
	var bp := basis * Vector3(-5.0, 0, -4.0)
	bp.y = _ground(root, bp)
	k.pillar(bp, 6.0, 0.09, StructureKit.INK_WOOD, 5)
	k.ribbon(bp + Vector3(0, 5.9, 0), 3.0, 0.4, StructureKit.CINNABAR_LIGHT, yaw)
	for sx in [-1.0, 1.0]:
		var lp := basis * Vector3(sx * 4.0, 0, 4.0)
		lp.y = _ground(root, lp)
		k.lantern_post(lp, yaw)
	k.build(root, "Post", 900.0)
	_night_lights(root, k.lamps, 1)
	var fire := Campfire.new()
	root.add_child(fire)
	var fp := basis * Vector3(3.0, 0, 3.5)
	fire.position = fp + Vector3(0, _ground(root, fp), 0)
	return _npc_spawns(poi, root)


# --- Vantrel Depot: the vehicle maker's desert garage ------------------------------------------------------
## A long low hangar of weathered silver panels on a stone apron, three bays
## (two hold dead hulks: a promise of what can be restored), and the
## restoration bench that opens the Garage.
func _depot(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var yaw: float = poi.get("yaw", 0.0)
	var basis := Basis(Vector3.UP, yaw)
	var g := _ground(root, Vector3.ZERO)
	var silver := Color(0.62, 0.63, 0.64)
	var silver_dark := Color(0.42, 0.43, 0.45)
	var soot := Color(0.12, 0.12, 0.13)
	k.block(Vector3(0, g - 0.6, 0), Vector3(24.0, 1.4, 14.0), StructureKit.COOL_STONE * 0.95, yaw)
	# Hangar: back wall, bay dividers, and a shallow ribbed roof.
	var back := basis * Vector3(0, 0, 5.5)
	k.block(back + Vector3(0, g + 2.6, 0), Vector3(20.0, 5.2, 0.5), silver_dark, yaw)
	for i in 4:
		var x := -10.0 + i * 6.66
		var pc := basis * Vector3(x, 0, 1.5)
		k.block(pc + Vector3(0, g + 2.6, 0), Vector3(0.45, 5.2, 8.5), silver, yaw)
	for i in 9:
		var z := -2.8 + i * 1.05
		var rp := basis * Vector3(0, 0, z)
		k.block(rp + Vector3(0, g + 5.35 + i * 0.07, 0), Vector3(20.8, 0.22, 1.0), silver if i % 2 == 0 else silver_dark, yaw, true, 0.02)
	# Brand badge over the middle bay: a disc cut by a chevron, in soot iron.
	var bc := basis * Vector3(0, 0, -2.9)
	k.drum(bc + Vector3(0, g + 5.9, 0), 0.25, 1.1, 1.1, 10, soot)
	k.block(bc + Vector3(-0.4, g + 6.05, 0), Vector3(0.35, 0.3, 1.6), silver, yaw + 0.7, false)
	k.block(bc + Vector3(0.4, g + 6.05, 0), Vector3(0.35, 0.3, 1.6), silver, yaw - 0.7, false)
	# Dead hulks under tarps in the side bays.
	for sx in [-1.0, 1.0]:
		var hp := basis * Vector3(sx * 6.6, 0, 2.0)
		k.block(hp + Vector3(0, g + 0.7, 0), Vector3(1.4, 1.2, 3.0), Color(0.36, 0.33, 0.28), yaw + sx * 0.06)
		k.block(hp + Vector3(0, g + 0.35, -1.3), Vector3(0.4, 0.7, 0.7), soot, yaw)
		k.block(hp + Vector3(0, g + 0.35, 1.3), Vector3(0.4, 0.7, 0.7), soot, yaw)
	for sx in [-1.0, 1.0]:
		k.lantern_post(basis * Vector3(sx * 11.0, 0, -4.5) + Vector3(0, g, 0), yaw)
	k.build(root, "Depot", 1200.0)
	_night_lights(root, k.lamps, 1)
	var bench := VehicleBench.new()
	root.add_child(bench)
	var bp := basis * Vector3(0, 0, 3.8)
	bench.position = bp + Vector3(0, g, 0)
	bench.rotation.y = yaw + PI
	return []


# --- Old quarry: cut blocks, a scarred rock face, a timber crane -------------------------------------
func _quarry(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(poi["id"])
	var yaw: float = poi.get("yaw", 0.0)
	var basis := Basis(Vector3.UP, yaw)
	for i in 7:
		var p := basis * Vector3(-12.0 + i * 4.0, 0, -12.0 + rng.randf_range(-1.5, 1.5))
		p.y = _ground(root, p) + 3.0
		k.rock(p, Vector3(3.4, 5.0, 2.8), STONE_DARK)
	for i in 9:
		var p := basis * Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-6, 8))
		p.y = _ground(root, p)
		var h := rng.randf_range(0.6, 1.4)
		k.block(p + Vector3(0, h * 0.5, 0), Vector3(rng.randf_range(1.2, 2.2), h, rng.randf_range(0.9, 1.6)), STONE * rng.randf_range(0.9, 1.05), yaw + rng.randf() * 0.4)
	var cp := basis * Vector3(8.0, 0, -6.0)
	cp.y = _ground(root, cp)
	k.pillar(cp, 7.0, 0.16, StructureKit.INK_WOOD, 5)
	k.block_xf(Transform3D(basis, cp + basis * Vector3(-2.2, 7.0, 0)), Vector3(5.0, 0.25, 0.25), StructureKit.INK_WOOD, false)
	StructureKit.prism_into(k.b, cp + basis * Vector3(-4.4, 7.0, 0), cp + basis * Vector3(-4.4, 3.2, 0), 0.03, 0.03, 4, StructureKit.id(Color(0.7, 0.62, 0.45), StructureKit.MATTE))
	k.build(root, "Quarry", 900.0)
	if poi.has("loot"):
		var chest := Chest.create(poi["id"] + ":cache", StringName(poi["loot"]), poi.get("reward", []))
		root.add_child(chest)
		var chp := basis * Vector3(-6.0, 0, -8.0)
		chest.position = chp + Vector3(0, _ground(root, chp), 0)
	var nodes: Array = poi.get("nodes", [])
	for i in nodes.size():
		var nd: Dictionary = DB.resource_nodes.get(StringName(nodes[i][0]), {})
		var nid := "%s:node%d" % [poi["id"], i]
		if nd.is_empty() or WorldState.is_harvested(nid):
			continue
		var rn := ResourceNode.create(nd, nid)
		root.add_child(rn)
		var np := Vector3(nodes[i][1], 0, nodes[i][2])
		rn.position = np + Vector3(0, _ground(root, np), 0)
	return _npc_spawns(poi, root)
