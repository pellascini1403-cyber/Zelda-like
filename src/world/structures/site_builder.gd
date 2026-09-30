class_name SiteBuilder
extends RefCounted
## Region set pieces for the expansion (forest, lake...). Each one is built
## around a rule of its region, not just a shape: the canopy walk is a
## climb-and-glide route, the Hollow Tree has three ways in decided by the
## weather, the Moon Shrine only answers at night. Called by StructureBuilder
## for the matching POI types; returns creature spawns like every builder.

const BARK := Color(0.36, 0.27, 0.21)
const BARK_DARK := Color(0.25, 0.19, 0.15)
const PLANK := Color(0.55, 0.42, 0.28)
const ROPE := Color(0.72, 0.62, 0.42)
const LEAF := Color(0.3, 0.5, 0.32)
const MOSS := Color(0.34, 0.46, 0.28)
const MOON_STONE := Color(0.78, 0.8, 0.86)

var sb: StructureBuilder
var gen: WorldGen


func _init(builder: StructureBuilder) -> void:
	sb = builder
	gen = builder.gen


func _g(root: Node3D, x: float, z: float) -> float:
	return sb._ground(root, Vector3(x, 0, z))


## World-space spawn with an absolute local height (decks, galleries).
func _spawn_at(root: Node3D, entity: String, local: Vector3, poi_id: String, idx: int) -> Dictionary:
	return {"entity": StringName(entity), "pos": root.global_position + local + Vector3.UP * 0.4, "group": poi_id, "id": "%s:%d" % [poi_id, idx]}


# --- Canopy Walk ------------------------------------------------------------------------------------
## Four giant trunks linked by rope bridges at three heights and a crow's
## nest on top. You get up by climbing the trunks (weavers wait on the
## decks and hunt climbers); the nest looks straight at the Hollow Tree's
## open crown — the glide there is the canopy's reason to exist.
func canopy_walk(poi: Dictionary, root: Node3D) -> Array:
	var k := StructureKit.new(hash(poi["id"]))
	var trunks := {"a": Vector3(-10, 0, -6), "b": Vector3(8, 0, -12), "c": Vector3(12, 0, 8), "d": Vector3(-6, 0, 12)}
	var top := {}
	for key: String in trunks:
		var t: Vector3 = trunks[key]
		var g := _g(root, t.x, t.z)
		t.y = g
		trunks[key] = t
		# Trunk c is the old dead giant: a bare snag carrying the crow's nest
		# (open sky around it — the glide starts clean).
		var h := 40.2 if key == "c" else 45.0 + float(hash(key) % 5)
		# Flared roots, then a tall tapering trunk.
		for i in 5:
			var a := TAU * i / 5.0 + 0.3
			k.block(t + Vector3(cos(a) * 1.6, 1.0, sin(a) * 1.6), Vector3(0.8, 2.2, 2.6), BARK_DARK, a)
		k.pillar(t + Vector3(0, -1, 0), h * 0.55, 2.2, BARK * 1.25, 12)
		k.pillar(t + Vector3(0, h * 0.55 - 1.0, 0), h * 0.45, 1.7, BARK * 1.25, 12)
		if key != "c":
			k.canopy(t + Vector3(0, h + 2.0, 0), Vector3(7.0, 4.5, 7.0), LEAF * 1.1, LEAF * 0.55, hash(key))
		top[key] = t.y + h
	# Decks: [trunk, height above that trunk's ground]
	# Every ten metres a deck to rest on: a 40 m climb in four stages.
	var decks := [["a", 12.0], ["b", 12.0], ["d", 12.0], ["b", 22.0], ["c", 22.0], ["a", 32.0], ["c", 32.0]]
	var deck_pos := {}
	for dk: Array in decks:
		var t: Vector3 = trunks[dk[0]]
		var y := t.y + float(dk[1])
		k.block(Vector3(t.x, y, t.z), Vector3(7.0, 0.35, 7.0), PLANK, 0.2)
		for s in 4:
			var a := TAU * s / 4.0 + 0.2
			k.block(Vector3(t.x, y, t.z) + Vector3(cos(a), 0, sin(a)) * 3.3 + Vector3(0, 0.5, 0), Vector3(0.12, 1.0, 6.2), ROPE, a + PI * 0.5, false)
		deck_pos["%s%d" % [dk[0], int(dk[1])]] = Vector3(t.x, y, t.z)
	# Bridges between decks at the same height.
	for br: Array in [["a12", "b12"], ["a12", "d12"], ["b22", "c22"], ["c32", "a32"]]:
		_bridge(k, deck_pos[br[0]], deck_pos[br[1]])
	# Crow's nest on trunk c.
	var c: Vector3 = trunks["c"]
	var nest := Vector3(c.x, c.y + 40.0, c.z)
	k.block(nest, Vector3(6.0, 0.4, 6.0), PLANK)
	for s in 4:
		var a := TAU * s / 4.0
		k.block(nest + Vector3(cos(a), 0, sin(a)) * 2.9 + Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 5.8), ROPE, a + PI * 0.5)
	k.ribbon(nest + Vector3(0, 3.0, 0), 3.0, 0.3, StructureKit.CINNABAR_LIGHT, 0.4)
	k.build(root, "CanopyWalk", 1800.0)
	var chest := Chest.create(poi["id"] + ":nest", &"chest_common", poi.get("reward", []))
	root.add_child(chest)
	chest.position = nest + Vector3(2.2, 0.2, 0.8)
	# Weavers: one waits on a low deck, one guards the high bridge, one the
	# trunk you are most likely to climb.
	return [
		_spawn_at(root, "ENEMY_CRAG_WEAVER", deck_pos["b22"], poi["id"], 0),
		_spawn_at(root, "ENEMY_CRAG_WEAVER", deck_pos["a32"], poi["id"], 1),
		_spawn_at(root, "ENEMY_CRAG_WEAVER", deck_pos["d12"], poi["id"], 2),
	]


func _bridge(k: StructureKit, a: Vector3, b: Vector3) -> void:
	var dir := (b - a)
	dir.y = 0.0
	var dist := dir.length()
	var n := int(dist / 1.1)
	var yaw := atan2(dir.x, dir.z)
	for i in range(1, n):
		var f := float(i) / n
		var p := a.lerp(b, f)
		# Easy start and end: skip the planks inside the decks.
		if (p - a).length() < 3.3 or (p - b).length() < 3.3:
			continue
		p.y -= sin(f * PI) * 0.9
		k.block(p, Vector3(1.5, 0.16, 0.9), PLANK * (0.9 + 0.2 * (i % 2)), yaw)
		for sx in [-1.0, 1.0]:
			var side: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * 0.8 * sx
			k.block(p + side + Vector3(0, 0.55, 0), Vector3(0.06, 1.0, 0.06), ROPE, yaw, false)
	# Hand ropes (collide: you don't fall off by walking into them).
	for sx in [-1.0, 1.0]:
		var side: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * 0.85 * sx
		var mid: Vector3 = (a + b) * 0.5 + side + Vector3(0, 0.4, 0)
		k.block(mid, Vector3(0.1, 0.9, dist - 6.0), ROPE, yaw)


# --- Hollow Tree + Weeping Grove ------------------------------------------------------------------
## A living tree so big it has an inside: a shaft of slick bark (no grip),
## a gallery ring half-way up, and at its heart a pit of roots below the
## ground. Three ways in, chosen by the forest's rules:
##   * dry weather: burn the brambles choking the ground door (fire)
##   * rain: the grove's bellcaps swell — bounce up to the knot-hole (rain)
##   * any weather: glide in through the open crown from the Canopy Walk
func hollow_tree(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var bark := StructureKit.new(hash(id))
	bark.slick = true
	var k := StructureKit.new(hash(id) + 1)
	var g := _g(root, 0, 0)
	var R := 9.0
	var H := 26.0
	var segs := 18
	var seg_w := TAU * R / segs + 0.4
	var door_a := 0.0            # east (+x)
	var hole_a := PI             # west (-x), towards the grove
	var hole_y := 10.5
	for i in segs:
		var a := TAU * i / segs
		var p := Vector3(cos(a) * R, 0, sin(a) * R)
		var yaw := -a + PI * 0.5
		var col := BARK * (0.9 + 0.15 * sin(i * 1.7))
		if absf(wrapf(a - door_a, -PI, PI)) < 0.2:
			bark.block(p + Vector3(0, g + 4.5 + (H - 4.5) * 0.5, 0), Vector3(seg_w, H - 4.5, 1.6), col, yaw)
		elif absf(wrapf(a - hole_a, -PI, PI)) < 0.2:
			bark.block(p + Vector3(0, g + (hole_y - 0.2) * 0.5 - 2.0, 0), Vector3(seg_w, hole_y + 3.8, 1.6), col, yaw)
			var above := hole_y + 3.2
			bark.block(p + Vector3(0, g + above + (H - above) * 0.5, 0), Vector3(seg_w, H - above, 1.6), col, yaw)
		else:
			bark.block(p + Vector3(0, g + H * 0.5 - 2.0, 0), Vector3(seg_w, H + 4.0, 1.6), col, yaw)
	# Crown: a torn rim of leaves around the open top (the glide target).
	for i in 7:
		var a := TAU * i / 7.0
		k.canopy(Vector3(cos(a) * (R + 3.0), g + H + 2.0, sin(a) * (R + 3.0)), Vector3(5.5, 4.0, 5.5), LEAF, LEAF * 0.5, i + 3)
	# Buttress roots outside; the west ones form the root ledge the second
	# bellcap sits on.
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		if absf(wrapf(a - door_a, -PI, PI)) < 0.4:
			continue
		k.block(Vector3(cos(a) * (R + 1.8), g + 1.2, sin(a) * (R + 1.8)), Vector3(1.6, 2.6, 4.2), BARK_DARK, -a + PI * 0.5)
	var ledge := Vector3(-(R + 3.2), g + 5.0, 2.4)
	k.block(ledge + Vector3(0, -2.5, 0), Vector3(3.0, 5.0, 3.0), BARK_DARK, 0.3)
	# Gallery ring inside, at the knot-hole's height; a root ladder down.
	var gy := g + hole_y - 0.4
	for i in 14:
		var a := TAU * i / 14.0
		k.block(Vector3(cos(a) * (R - 2.0), gy, sin(a) * (R - 2.0)), Vector3(3.8, 0.4, 3.0), PLANK, -a + PI * 0.5)
	for i in 10:
		var y := gy - 1.2 * i
		k.block(Vector3(R - 2.6, y, -2.2), Vector3(0.5, 0.35, 1.8), BARK_DARK)
	k.pillar(Vector3(R - 3.2, g - 7.5, -2.2), hole_y + 7.0, 0.35, BARK_DARK, 6)
	# Root stairs from the door down into the heart pit.
	for i in 9:
		var a := 0.15 + i * 0.36
		var r := R - 2.2 - i * 0.28
		k.block(Vector3(cos(a) * r, g - 0.6 - i * 0.78, sin(a) * r), Vector3(2.2, 0.5, 1.6), BARK_DARK, -a)
	# The Heartroot: a knot of pale roots glowing in the dark.
	var heart := Vector3(0, g - 7.0, 0)
	for i in 6:
		var a := TAU * i / 6.0
		k.block(heart + Vector3(cos(a) * 1.6, 0.8, sin(a) * 1.6), Vector3(0.5, 2.4, 0.5), Color(0.85, 0.82, 0.7), a)
		k.rune(heart + Vector3(cos(a) * 1.6, 1.7, sin(a) * 1.6), Vector3(0.3, 0.05, 0.3), a)
	bark.build(root, "HollowBark", 1600.0)
	k.build(root, "HollowTree", 1200.0)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 1.0, 0.8)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	light.distance_fade_length = 15.0
	root.add_child(light)
	light.position = heart + Vector3(0, 2.5, 0)
	var chest := Chest.create(id + ":heart", &"chest_common", poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = heart + Vector3(0, 0.1, 0)
	for i in 3:
		var nid := "%s:moss%d" % [id, i]
		if not WorldState.is_harvested(nid):
			var rn := ResourceNode.create(DB.resource_nodes.get(&"glowmoss", {}), nid)
			root.add_child(rn)
			var a := 1.0 + i * 2.1
			rn.position = heart + Vector3(cos(a) * 3.2, 0.2, sin(a) * 3.2)
	# Ground door: brambles.
	var br := BrambleWall.create(id + ":door", Vector3(3.6, 4.4, 1.6))
	root.add_child(br)
	br.position = Vector3(R + 0.2, g, 0)
	br.rotation.y = PI * 0.5
	# The Weeping Grove on the west side: a bellcap ladder to the knot-hole.
	var b1 := Bellcap.create(id + ":cap1", 1.5)
	root.add_child(b1)
	b1.position = Vector3(-(R + 6.5), _g(root, -(R + 6.5), 4.0), 4.0)
	var b2 := Bellcap.create(id + ":cap2", 1.3)
	root.add_child(b2)
	b2.position = ledge
	for i in 5:
		var a := PI + (i - 2) * 0.35
		var d := R + 12.0 + (i % 2) * 5.0
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		var bc := Bellcap.create("%s:grove%d" % [id, i], 0.9 + (i % 3) * 0.25)
		root.add_child(bc)
		bc.position = p + Vector3(0, _g(root, p.x, p.z), 0)
	_weeping_willows(root, id)
	return [
		_spawn_at(root, "ENEMY_CAVE_WEAVER", heart + Vector3(3.0, 0, -2.0), id, 0),
		_spawn_at(root, "ENEMY_CAVE_WEAVER", heart + Vector3(-2.5, 0, 2.5), id, 1),
		_spawn_at(root, "ENEMY_BRAMBLE_CARAPACE", Vector3(R + 7.0, _g(root, R + 7.0, 3.0), 3.0), id, 2),
	]


## Drooping trees with long hanging strands around the grove: they read
## "wet place" from afar, and hide the bellcaps until you walk in.
func _weeping_willows(root: Node3D, id: String) -> void:
	var k := StructureKit.new(hash(id) + 7)
	for i in 5:
		var a := PI + (i - 2) * 0.5
		var d := 24.0 + (i % 2) * 6.0
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = _g(root, p.x, p.z)
		k.pillar(p + Vector3(0, -0.5, 0), 7.0, 0.55, BARK, 8)
		k.canopy(p + Vector3(0, 8.0, 0), Vector3(4.5, 2.4, 4.5), MOSS * 1.2, MOSS * 0.6, i + 11)
		for s in 10:
			var sa := TAU * s / 10.0
			k.ribbon(p + Vector3(cos(sa) * 3.6, 7.8, sin(sa) * 3.6), 5.0, 0.22, MOSS * (0.9 + 0.1 * (s % 3)), sa)
	k.build(root, "WeepingGrove", 900.0)


# --- Moon Shrine -------------------------------------------------------------------------------------
## Not another pavilion: a round moon-pool ringed by standing stones, with a
## sealed round gate in the rock behind. At night the glowcaps around the
## ring open; three of them offered to the pool roll the moon gate aside.
## The glowcap trail (poi "trail") leads here from the heart of the wood.
func moon_shrine(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var g := _g(root, 0, 0)
	var yaw: float = poi.get("yaw", 0.0)
	var basis := Basis(Vector3.UP, yaw)
	# Round terrace + basin.
	k.drum(Vector3(0, g - 1.0, 0), 1.3, 7.2, 7.6, 20, StructureKit.WHITE_STONE)
	k._collide_cyl(Vector3(0, g - 1.0, 0), 1.3, 7.4)
	k.drum(Vector3(0, g + 0.25, 0), 0.25, 3.2, 3.4, 20, MOON_STONE)
	for i in 8:
		var a := TAU * i / 8.0
		k.block(Vector3(cos(a) * 6.0, g + 1.3, sin(a) * 6.0), Vector3(0.9, 2.6, 0.6), MOON_STONE * (0.95 + 0.05 * (i % 2)), -a)
		k.rune(Vector3(cos(a) * 5.7, g + 2.0, sin(a) * 5.7), Vector3(0.35, 0.06, 0.3), -a)
	# Rock mound with the round gate (local -z side).
	var back := basis * Vector3(0, 0, -11.0)
	for i in 9:
		var a := PI * i / 8.0
		var p := back + basis * Vector3(cos(a) * 6.0, 0, sin(a) * -3.0)
		k.rock(p + Vector3(0, _g(root, p.x, p.z) + 2.2, 0), Vector3(3.4, 5.0, 3.4), Color(0.44, 0.47, 0.42))
	k.rock(back + Vector3(0, g + 6.0, -1.5), Vector3(9.0, 3.0, 7.0), Color(0.4, 0.43, 0.38), false)
	# The chamber behind the gate.
	var ch := back + basis * Vector3(0, 0, -3.5)
	k.block(ch + Vector3(0, g - 0.2, 0), Vector3(5.0, 0.4, 5.0), MOON_STONE, yaw)
	k.block(ch + Vector3(0, g + 3.4, 0), Vector3(5.4, 0.6, 5.4), Color(0.4, 0.43, 0.38), yaw)
	for sx in [-1.0, 1.0]:
		k.block(ch + basis * Vector3(sx * 2.6, 0, 0) + Vector3(0, g + 1.6, 0), Vector3(0.6, 3.4, 5.0), Color(0.42, 0.45, 0.4), yaw)
	k.block(ch + basis * Vector3(0, 0, -2.6) + Vector3(0, g + 1.6, 0), Vector3(5.0, 3.4, 0.6), Color(0.42, 0.45, 0.4), yaw)
	k.rune(ch + basis * Vector3(0, 0, -2.2) + Vector3(0, g + 1.8, 0), Vector3(1.4, 0.08, 1.0), yaw)
	k.build(root, "MoonShrine", 1200.0)
	var gate := FlagGate.create(String(poi.get("gate_flag", "moon_gate_open")), Vector3(3.0, 3.0, 0.6), MOON_STONE, true)
	root.add_child(gate)
	gate.position = back + Vector3(0, g, 0)
	gate.rotation.y = yaw
	var chest := Chest.create(id + ":moon", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = ch + Vector3(0, g, 0)
	chest.rotation.y = yaw
	# The offering bowl at the pool's edge (night only, three glowcaps).
	var offer := QuestObject.create({"id": id + ":offering", "look": "offering", "needs_item": "glowcap", "needs_count": 3,
		"conditions": {"period": "night"}, "hint_key": "HINT_MOON_NIGHT", "reward": {"flag": String(poi.get("gate_flag", "moon_gate_open"))},
		"discover": String(poi.get("discovery", "")), "lines": ["LINE_MOON_GATE"], "speaker": "POI_MOON_SHRINE"})
	root.add_child(offer)
	offer.position = basis * Vector3(0, 0, -3.8) + Vector3(0, g + 0.45, 0)
	# Glowcaps at the stones' feet and along the trail.
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var gc := Glowcap.create("%s:cap%d" % [id, i])
		root.add_child(gc)
		gc.position = Vector3(cos(a) * 4.8, g + 0.25, sin(a) * 4.8)
	var trail: Array = poi.get("trail", [])
	for i in trail.size():
		var tp: Array = trail[i]
		var gc := Glowcap.create("%s:trail%d" % [id, i])
		root.add_child(gc)
		gc.position = Vector3(tp[0], _g(root, tp[0], tp[1]), tp[1])
	return []


# --- Sunken Shrine (lake bed) -------------------------------------------------------------------------
## A hall that slid into the lake. The front door is buried under a fallen
## pillar; you get in through the broken roof or a crack in the side wall.
## Three drowned bells (one inside, one on the terrace, one under the
## rubble by the crack) must ring before the sanctum's stone slides open.
## An air pocket's bubble column lets you catch your breath in between; an
## eel keeps the waters. At night the drowned lanterns glow up through the
## water — the way to spot it from the surface.
func sunken_shrine(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var g := _g(root, 0, 0)
	var stone := Color(0.52, 0.58, 0.56)
	var dark := Color(0.34, 0.4, 0.4)
	# Floor and terrace.
	k.block(Vector3(0, g - 0.3, 0), Vector3(16.0, 0.6, 12.0), stone)
	k.block(Vector3(0, g - 0.2, 8.5), Vector3(10.0, 0.4, 5.0), dark)
	# Walls: back (-z) whole; sides with the crack on +x; front (+z) with the
	# door, buried.
	k.block(Vector3(0, g + 2.5, -6.0), Vector3(16.0, 5.0, 0.8), stone)
	k.block(Vector3(-8.0, g + 2.5, 0), Vector3(0.8, 5.0, 12.0), stone)
	k.block(Vector3(8.0, g + 2.5, -3.5), Vector3(0.8, 5.0, 5.0), stone)
	k.block(Vector3(8.0, g + 3.8, 2.8), Vector3(0.8, 2.4, 6.4), stone)     # crack below (y 0..2.6)
	for sx in [-1.0, 1.0]:
		k.block(Vector3(sx * 5.0, g + 2.5, 6.0), Vector3(6.0, 5.0, 0.8), stone)
	k.block(Vector3(0, g + 4.3, 6.0), Vector3(4.0, 1.4, 0.8), stone)
	k.rock(Vector3(0, g + 1.3, 6.8), Vector3(4.6, 2.6, 2.0), dark)          # the fallen pillar
	# Roof: only the back half survived (the way in from above).
	k.block(Vector3(0, g + 5.3, -3.0), Vector3(16.8, 0.6, 6.8), dark)
	for i in 4:
		k.block(Vector3(-6.0 + i * 4.0, g + 5.1, 3.0 + (i % 2) * 1.5), Vector3(2.2, 0.4, 1.4), dark, 0.4 * i, false)
	# Columns, one fallen across the hall.
	for i in 3:
		k.column(Vector3(-4.5 + i * 4.5, g, -1.0), 4.8, 0.45, stone)
	k.block(Vector3(3.0, g + 0.5, 2.5), Vector3(0.9, 0.9, 6.0), stone, 0.6)
	# Sanctum at the back (behind the gate), and the drowned lanterns.
	k.block(Vector3(0, g - 0.3, -9.0), Vector3(6.0, 0.6, 5.0), stone)
	k.block(Vector3(0, g + 2.2, -11.4), Vector3(6.0, 4.4, 0.6), stone)
	for sx in [-1.0, 1.0]:
		k.block(Vector3(sx * 3.0, g + 2.2, -9.0), Vector3(0.6, 4.4, 5.0), stone)
	k.block(Vector3(0, g + 4.6, -9.0), Vector3(6.6, 0.5, 5.6), dark)
	for p: Vector3 in [Vector3(-7.4, 3.5, 5.4), Vector3(7.4, 3.5, 5.4), Vector3(-7.4, 3.5, -5.4), Vector3(7.4, 3.5, -5.4), Vector3(0, 3.8, -10.9)]:
		k.rune(p + Vector3(0, g, 0), Vector3(0.6, 0.08, 0.6))
	k.build(root, "SunkenShrine", 900.0)
	var gate := FlagGate.create(String(poi.get("gate_flag", "sunken_bells")), Vector3(3.2, 3.6, 0.5), stone * 0.9)
	root.add_child(gate)
	gate.position = Vector3(0, g, -6.5)
	var chest := Chest.create(id + ":sanctum", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = Vector3(0, g, -9.5)
	# Bells.
	var ids := PackedStringArray()
	var spots := [Vector3(-5.0, 0, -3.0), Vector3(0, 0, 9.5), Vector3(10.0, 0, 3.0)]
	for i in spots.size():
		var bid := "%s:bell%d" % [id, i]
		ids.append(bid)
		var bell := QuestObject.create({"id": bid, "look": "bell", "radius": 2.0, "sound": "chime", "element": "wind", "hide_used": false})
		root.add_child(bell)
		var sp: Vector3 = spots[i]
		bell.position = sp + Vector3(0, _g(root, sp.x, sp.z) if absf(sp.x) > 8.5 else g, 0)
	root.add_child(BellSequence.create(ids, String(poi.get("gate_flag", "sunken_bells"))))
	var vent := AirVent.new()
	root.add_child(vent)
	vent.position = Vector3(-6.0, g, 3.5)
	return [_spawn_at(root, "ENEMY_MIRE_EEL", Vector3(0, WorldGen.SEA_LEVEL - 2.0 - root.global_position.y, 16.0), id, 0)]
