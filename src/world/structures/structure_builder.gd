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
	push_warning("StructureBuilder: unknown POI type " + kind)
	return []


func _ground(root: Node3D, local: Vector3) -> float:
	var w := root.global_position + local
	return gen.height(w.x, w.z) - root.global_position.y


func _spawn(root: Node3D, entity: String, local: Vector3, group: String, idx: int, poi_id: String) -> Dictionary:
	var pos := root.global_position + Vector3(local.x, 0, local.z)
	pos.y = gen.height(pos.x, pos.z) + 0.3
	return {"entity": StringName(entity), "pos": pos, "group": group, "id": "%s:%d" % [poi_id, idx]}


# --- Village: Aldea Brezo ------------------------------------------------------------------------
func _village(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var houses := [[Vector3(-12, 0, -8), 0.2], [Vector3(10, 0, -10), -0.3], [Vector3(-14, 0, 10), 1.4], [Vector3(13, 0, 9), -1.2]]
	for h in houses:
		_house(k, h[0], h[1])
	# Watermill-like tower with a cone roof (village landmark visible far away)
	var tower := Vector3(0, 0, -20)
	k.pillar(tower, 9.0, 2.2, STONE, 10)
	k.cone_roof(tower + Vector3(0, 9.0, 0), 3.0, 4.0, CLOTH)
	# Well
	k.pillar(Vector3(4, 0, 2), 0.9, 1.0, STONE_DARK, 10)
	k.block(Vector3(4, 2.2, 2), Vector3(2.4, 0.2, 0.4), WOOD)
	k.block(Vector3(3.0, 1.2, 2), Vector3(0.2, 2.2, 0.2), WOOD)
	k.block(Vector3(5.0, 1.2, 2), Vector3(0.2, 2.2, 0.2), WOOD)
	# Fences
	for i in 14:
		var a := TAU * i / 14.0
		if i % 7 == 3:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * 26.0
		p.y = _ground(root, p)
		k.block(p + Vector3(0, 0.6, 0), Vector3(0.18, 1.2, 0.18), WOOD)
		var q := Vector3(cos(a + TAU / 14.0), 0, sin(a + TAU / 14.0)) * 26.0
		q.y = _ground(root, q)
		var mid := (p + q) * 0.5 + Vector3(0, 0.8, 0)
		k.block(mid, Vector3(0.1, 0.12, p.distance_to(q)), WOOD_LIGHT, atan2(q.x - p.x, q.z - p.z), false)
	k.build(root, "VillageMesh", 900.0)

	var fire := Campfire.new()
	root.add_child(fire)
	fire.position = Vector3(0, _ground(root, Vector3.ZERO), 5)
	var stone := LoreStone.new()
	stone.lore_key = "LORE_VILLAGE_STONE"
	stone.title_key = "LORE_TITLE_VILLAGE"
	root.add_child(stone)
	stone.position = Vector3(-4, _ground(root, Vector3(-4, 0, -14)), -14)
	# Lanterns (lit at night by EnvironmentController via group)
	for lp in [Vector3(-6, 0, 0), Vector3(7, 0, -3), Vector3(-2, 0, 12)]:
		_lantern(root, lp + Vector3(0, _ground(root, lp), 0))
	for i in 3:
		var crate := PhysicsProp.create(&"crate")
		root.add_child(crate)
		crate.position = Vector3(-9 + i * 1.1, _ground(root, Vector3(-9, 0, -3)) + 0.55 + (1.05 if i == 2 else 0.0), -3 if i < 2 else -3)
		if i == 2:
			crate.position.x = -8.45
	var spawns: Array = []
	var npcs: Array = poi.get("npcs", [])
	for i in npcs.size():
		spawns.append(_spawn(root, npcs[i][0], Vector3(npcs[i][1], 0, npcs[i][2]), poi["id"], i, poi["id"]))
	return spawns


func _house(k: StructureKit, c: Vector3, yaw: float) -> void:
	var w := 6.0
	var d := 5.0
	var h := 3.2
	var basis := Basis(Vector3.UP, yaw)
	var corners := [Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2)]
	for i in 4:
		var a: Vector3 = c + basis * corners[i]
		var bb: Vector3 = c + basis * corners[(i + 1) % 4]
		if i == 2:
			# Door gap on the front wall
			var mid_a := a.lerp(bb, 0.4)
			var mid_b := a.lerp(bb, 0.6)
			k.wall(a, mid_a, h, 0.35, PLASTER)
			k.wall(mid_b, bb, h, 0.35, PLASTER)
			k.block((mid_a + mid_b) * 0.5 + Vector3(0, h - 0.4, 0), Vector3(0.35, 0.8, mid_a.distance_to(mid_b)), WOOD, atan2(bb.x - a.x, bb.z - a.z))
		else:
			k.wall(a, bb, h, 0.35, PLASTER)
	# Timber corner posts & stone plinth
	for cc in corners:
		k.block(c + basis * cc + Vector3(0, h * 0.5, 0), Vector3(0.4, h, 0.4), WOOD, yaw)
	k.block(c + Vector3(0, 0.15, 0), Vector3(w + 0.6, 0.3, d + 0.6), STONE_DARK, yaw)
	k.roof(c + Vector3(0, h, 0), w, d, 2.2, THATCH, yaw + PI * 0.5)


func _lantern(root: Node3D, pos: Vector3) -> void:
	var k := StructureKit.new()
	k.block(Vector3(0, 1.2, 0), Vector3(0.14, 2.4, 0.14), WOOD)
	k.block(Vector3(0, 2.5, 0), Vector3(0.35, 0.35, 0.35), Color(1.0, 0.85, 0.5), 0.0, false, 0.0)
	var n := k.build(root, "Lantern")
	n.position = pos
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.0
	light.omni_range = 9.0
	light.position.y = 2.5
	light.add_to_group(&"night_lights")
	n.add_child(light)


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
	var col := MOSS if poi.get("style", "moss") == "moss" else STONE
	for x in size:
		for z in size:
			var base := origin + Vector3(x * cell, 0, z * cell)
			var w: Array = walls[x][z]
			if w[0]:
				k.wall(base, base + Vector3(cell, 0, 0), wall_h, 0.8, col)
			if w[3]:
				k.wall(base, base + Vector3(0, 0, cell), wall_h, 0.8, col)
			if x == size - 1 and w[1]:
				k.wall(base + Vector3(cell, 0, 0), base + Vector3(cell, 0, cell), wall_h, 0.8, col)
			if z == size - 1 and w[2]:
				k.wall(base + Vector3(0, 0, cell), base + Vector3(cell, 0, cell), wall_h, 0.8, col)
	# Corner posts give the ruin its broken-crown silhouette.
	for x in size + 1:
		for z in size + 1:
			if rng.randf() < 0.35:
				k.block(origin + Vector3(x * cell, wall_h + 0.5, z * cell), Vector3(1.0, 1.0 + rng.randf() * 1.5, 1.0), STONE_DARK)
	# Entrance arch with runes
	var gate := origin + Vector3(-0.6, 0, mid * cell + cell * 0.5)
	k.block(gate + Vector3(0, wall_h * 0.6, -cell * 0.55), Vector3(1.4, wall_h * 1.2, 1.2), STONE)
	k.block(gate + Vector3(0, wall_h * 0.6, cell * 0.55), Vector3(1.4, wall_h * 1.2, 1.2), STONE)
	k.block(gate + Vector3(0, wall_h * 1.25, 0), Vector3(1.6, 1.0, cell * 1.7), STONE)
	k.rune(gate + Vector3(-0.75, wall_h * 1.25, 0), Vector3(0.05, 0.3, 2.2))
	k.rune(gate + Vector3(-0.75, wall_h * 0.9, -cell * 0.55), Vector3(0.05, 1.2, 0.2))
	k.rune(gate + Vector3(-0.75, wall_h * 0.9, cell * 0.55), Vector3(0.05, 1.2, 0.2))
	# Floor slab
	k.block(Vector3(0, -0.2, 0), Vector3(size * cell + 1.0, 0.5, size * cell + 1.0), STONE_DARK, 0.0, true, 0.0)
	k.build(root, "Maze", 1200.0)

	# Grand chest in the heart, small chests in dead ends.
	var grand := Chest.create(poi["id"] + ":grand", StringName(poi.get("loot", "chest_grand")), poi.get("reward", []), true)
	root.add_child(grand)
	grand.position = origin + Vector3((mid + 0.5) * cell, 0.05, (mid + 0.5) * cell)
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
	stone.position = gate + Vector3(-3.0, 0, 2.5)
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
			k.b.cylinder(pos + off, seg_h + 0.3, dr, dr * 0.93, 7, STONE * (0.9 + 0.1 * t), STONE_DARK, 0.12, rng.randi())
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
	var bark := Color(0.38, 0.28, 0.2)
	var trunk_h := 34.0
	# Buttress roots
	for i in 6:
		var a := TAU * i / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		k.block(d * 3.2 + Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 4.5), bark * 0.9, a, true)
	k.pillar(Vector3(0, -1, 0), trunk_h * 0.5, 3.6, bark, 12)
	k.pillar(Vector3(0, trunk_h * 0.5 - 1.0, 0), trunk_h * 0.5, 3.0, bark * 1.05, 12)
	# Canopy platforms (walkable) + leaf masses (visual)
	var leaf := Color(0.3, 0.5, 0.2)
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		var y := trunk_h - 6.0 + (i % 2) * 5.0
		k.block(d * 5.0 + Vector3(0, y, 0), Vector3(1.4, 1.2, 8.0), bark, a + PI * 0.5)
		k.b.blob(d * 9.0 + Vector3(0, y + 3.5, 0), Vector3(6.0, 4.0, 6.0), leaf * 1.1, leaf * 0.55, 1, 0.18, i)
	k.b.blob(Vector3(0, trunk_h + 5.0, 0), Vector3(10.0, 6.0, 10.0), leaf * 1.15, leaf * 0.6, 1, 0.15, 9)
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
	for i in 7:
		var a := TAU * i / 7.0
		var p := Vector3(cos(a), 0, sin(a)) * 5.0
		p.y = _ground(root, p)
		k.pillar(p, 3.5 + (i % 3) * 1.2, 0.5, STONE, 6)
	k.block(Vector3(0, _ground(root, Vector3.ZERO) + 0.2, 0), Vector3(7, 0.4, 7), STONE_DARK, 0.3)
	k.rune(Vector3(0, _ground(root, Vector3.ZERO) + 0.45, 0), Vector3(2.0, 0.05, 0.25), 0.3)
	k.build(root, "Overlook", 1200.0)
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
	stone.position = Vector3(0, _ground(root, Vector3.ZERO) + 0.4, -2)
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
	var k := StructureKit.new(hash(poi["id"]))
	var h := 18.0
	for i in 4:
		var a := TAU * i / 4.0 + 0.785
		var d := Vector3(cos(a), 0, sin(a)) * 3.2
		var th := h - (4.0 if i == 1 else 0.0)
		k.wall(d, Vector3(cos(a + TAU / 4.0), 0, sin(a + TAU / 4.0)) * 3.2, th, 0.7, STONE)
	k.block(Vector3(0, h * 0.55, 0), Vector3(4.0, 0.4, 4.0), WOOD)
	k.rock(Vector3(5, 0.5, 2), Vector3(1.5, 1.0, 1.4), STONE_DARK)
	k.rock(Vector3(-4, 0.4, 4), Vector3(1.1, 0.8, 1.3), STONE_DARK)
	k.build(root, "Watchtower", 1400.0)
	var stone := LoreStone.new()
	stone.lore_key = poi.get("lore", "LORE_TOWER")
	stone.title_key = poi["name_key"]
	root.add_child(stone)
	stone.position = Vector3(0, h * 0.55 + 0.2, 0)
	return []


# --- Summit cairn -----------------------------------------------------------------------------------------------
func _summit(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var y := _ground(root, Vector3.ZERO)
	for i in 5:
		k.rock(Vector3(0, y + 0.5 + i * 0.7, 0), Vector3(1.4 - i * 0.22, 0.45, 1.3 - i * 0.2), STONE * (1.0 + i * 0.03))
	k.block(Vector3(0, y + 4.2, 0), Vector3(0.12, 2.0, 0.12), WOOD, 0.0, false)
	k.block(Vector3(0.45, y + 4.8, 0), Vector3(0.9, 0.6, 0.03), CLOTH, 0.0, false)
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
