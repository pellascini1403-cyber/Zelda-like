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


func build(poi: Dictionary, root: Node3D) -> Array:
	var kind: String = poi["type"]
	match kind:
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
	var spawns: Array = []
	var npcs: Array = poi.get("npcs", [])
	for i in npcs.size():
		spawns.append(_spawn(root, npcs[i][0], Vector3(npcs[i][1], 0, npcs[i][2]), poi["id"], i, poi["id"]))
	return spawns


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
	var col := Color(0.7, 0.74, 0.62) if poi.get("style", "moss") == "moss" else StructureKit.WHITE_STONE
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
	var spawns: Array = []
	var npcs: Array = poi.get("npcs", [])
	for i in npcs.size():
		var np := basis * Vector3(npcs[i][1], 0, npcs[i][2])
		spawns.append({"entity": StringName(npcs[i][0]), "pos": root.global_position + np + Vector3(0, t1 + 0.3, 0), "group": poi["id"], "id": "%s:%d" % [poi["id"], i]})
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
