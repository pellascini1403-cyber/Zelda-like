class_name SeaBuilder
extends RefCounted
## Set pieces of the sea (expansion phase 4). Every one answers "how do I
## get in?" with more than one answer: a lighthouse you reach riding a
## current, a spire you climb and glide from, wrecks with deck hatches,
## hull breaches and stern windows, a tide cave whose mouth the tide opens
## and shuts, a castaways' camp that tells its story in objects.

const ROCK := Color(0.42, 0.44, 0.43)
const ROCK_DARK := Color(0.32, 0.34, 0.34)
const HULL := Color(0.4, 0.3, 0.22)
const HULL_DARK := Color(0.28, 0.21, 0.16)
const PLANK := Color(0.55, 0.42, 0.28)
const LIME := Color(0.86, 0.84, 0.78)

var sb: StructureBuilder


func _init(builder: StructureBuilder) -> void:
	sb = builder


func _g(root: Node3D, x: float, z: float) -> float:
	return sb._ground(root, Vector3(x, 0, z))


func _spawn_at(root: Node3D, entity: String, local: Vector3, poi_id: String, idx: int) -> Dictionary:
	return {"entity": StringName(entity), "pos": root.global_position + local + Vector3.UP * 0.4, "group": poi_id, "id": "%s:%d" % [poi_id, idx]}


# --- Lighthouse ---------------------------------------------------------------------------------------
## The Tidewarden Light: a white tower on its rock with an outside stair.
## Dark since the wreck of the Gull's Promise. Relit at night (lever in the
## lamp room), it throws a beam over the south sea — and its keeper's chart
## marks the wrecks. The Gull Current from the south shore ends at its dock:
## a swimmer can make it without a boat.
func lighthouse(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var g := _g(root, 0, 0)
	var H := 22.0
	for i in 5:
		var r := 3.2 - i * 0.25
		k.drum(Vector3(0, g + i * H / 5.0, 0), H / 5.0, r - 0.25, r, 12, LIME if i % 2 == 0 else StructureKit.CINNABAR_LIGHT)
	k._collide_cyl(Vector3(0, g, 0), H, 2.9)
	# Outside stair: a spiral of steps around the tower.
	for i in 44:
		var a := i * 0.36
		var y := g + 0.4 + i * (H - 0.8) / 44.0
		k.block(Vector3(cos(a) * 3.7, y, sin(a) * 3.7), Vector3(1.6, 0.25, 1.0), PLANK, -a)
	# Lamp room.
	var top := g + H
	k.drum(Vector3(0, top, 0), 0.4, 3.6, 3.6, 12, ROCK_DARK)
	k._collide_cyl(Vector3(0, top, 0), 0.4, 3.6)
	for i in 8:
		var a := TAU * i / 8.0
		k.block(Vector3(cos(a) * 2.2, top + 1.6, sin(a) * 2.2), Vector3(0.18, 2.8, 0.18), ROCK_DARK)
	k.cone_roof(Vector3(0, top + 3.0, 0), 2.8, 2.0, StructureKit.CINNABAR)
	# Dock on the current side.
	var dock := Vector3(0, 0, 9.0)
	for i in 5:
		k.block(Vector3(0, 0.45, 6.0 + i * 1.8), Vector3(3.0, 0.25, 1.6), PLANK)
		k.pillar(Vector3(sign(i % 2 - 0.5) * 1.3, -2.0, 6.0 + i * 1.8), 2.6, 0.12, HULL_DARK, 5)
	k.build(root, "Lighthouse", 2500.0)
	var lamp := LighthouseLamp.new()
	lamp.flag = String(poi.get("flag", "lighthouse_lit"))
	root.add_child(lamp)
	lamp.position = Vector3(0, top + 1.5, 0)
	var lever := QuestObject.create({"id": id + ":lamp", "look": "lever", "conditions": {"period": "night"}, "hint_key": "HINT_LAMP_NIGHT",
		"reward": {"flag": lamp.flag, "reveal": poi.get("reveals", [])}, "discover": String(poi.get("discovery", "")),
		"lines": ["LINE_LAMP_LIT"], "speaker": String(poi["name_key"]), "sound": "ignite", "element": "fire", "radius": 1.8})
	root.add_child(lever)
	lever.position = Vector3(1.2, top + 0.4, 0)
	var chest := Chest.create(id + ":keeper", StringName(poi.get("loot", "chest_common")), poi.get("reward", []))
	root.add_child(chest)
	chest.position = Vector3(-1.2, top + 0.4, 0.4)
	return []


# --- Sea spire (Vigil Rock) --------------------------------------------------------------------------------
## A crooked pillar of rock standing out of the sea. Ledges spiral up it
## (a real climb, stamina and all); gale kites nest at the top with the
## keeper's old cache. The sea wind rising up its lee face (an updraft
## placed by the site data) and the height make it the launch point for
## gliding onto the Gull's Promise.
func sea_spire(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var g := _g(root, 0, 0)
	var H := float(poi.get("height", 44.0))
	var y := g - 2.0
	var i := 0
	while y < g + H:
		var r := lerpf(7.0, 3.2, (y - g) / H) + rng.randf_range(-0.6, 0.6)
		var off := Vector3(sin(y * 0.09) * 1.6, 0, cos(y * 0.07) * 1.2)
		k.rock(off + Vector3(0, y + 2.5, 0), Vector3(r * 2.0, 5.2, r * 1.8), ROCK * (0.9 + 0.1 * (i % 3)))
		# A ledge every few metres, turning around the spire.
		var a := i * 1.9
		k.block(off + Vector3(cos(a) * (r + 0.8), y + 4.6, sin(a) * (r + 0.8)), Vector3(2.4, 0.5, 2.0), ROCK_DARK, -a)
		y += 4.5
		i += 1
	var top := Vector3(sin((g + H) * 0.09) * 1.6, g + H + 3.0, cos((g + H) * 0.07) * 1.2)
	k.block(top, Vector3(6.0, 0.8, 6.0), ROCK_DARK)
	# Nest of sticks and bones on top.
	for j in 10:
		var a := TAU * j / 10.0
		k.block(top + Vector3(cos(a) * 2.4, 0.6, sin(a) * 2.4), Vector3(0.25, 0.3, 2.2), HULL_DARK, a)
	k.build(root, "SeaSpire", 3000.0)
	var chest := Chest.create(id + ":nest", StringName(poi.get("loot", "chest_common")), poi.get("reward", []))
	root.add_child(chest)
	chest.position = top + Vector3(0.8, 0.45, 0.4)
	return [_spawn_at(root, "ENEMY_GALE_KITE", top + Vector3(3, 6, 0), id, 0), _spawn_at(root, "ENEMY_GALE_KITE", top + Vector3(-3, 8, 2), id, 1)]


# --- Wreck ---------------------------------------------------------------------------------------------------
## A reusable wreck: hull shell, deck with a hatch, two holds, a stern
## cabin, a broken mast. Parameters decide how it lies:
##   "length", "beam", "roll"/"pitch" (deg), "sunk": deck height relative
##   to the water (negative = under water), "breach": hole in the hull side
##   (dive in), "cabin_gate": the cabin door is jammed until a lever in the
##   hold is pulled (flag), "vent": air pocket in the hold, "guardian".
## Entries: the deck hatch (from a boat, a glide or a climb), the breach
## (from under water), the stern windows (swim in at the waterline).
func wreck(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var L := float(poi.get("length", 24.0))
	var B := float(poi.get("beam", 7.0))
	var holder := Node3D.new()
	holder.name = "WreckFrame"
	root.add_child(holder)
	var floor_y := _g(root, 0, 0)
	var deck_y := WorldGen.SEA_LEVEL + float(poi.get("sunk", -1.0)) - root.global_position.y
	deck_y = maxf(deck_y, floor_y + 3.5)
	holder.position = Vector3(0, deck_y, 0)
	holder.rotation = Vector3(deg_to_rad(float(poi.get("pitch", 4.0))), deg_to_rad(float(poi.get("yaw", 20.0))), deg_to_rad(float(poi.get("roll", 12.0))))
	var k := StructureKit.new(hash(id))
	var n := int(L / 2.0)
	var breach := int(poi.get("breach", 3))
	for i in n:
		var z := -L * 0.5 + (i + 0.5) * L / n
		var t := absf(z) / (L * 0.5)
		var w := B * 0.5 * (1.0 - pow(t, 2.2) * 0.75)
		for sx in [-1.0, 1.0]:
			if sx > 0.0 and i == breach:
				# The breach: an open hull plate on the starboard side.
				k.block(Vector3(sx * w, -0.6, z), Vector3(0.35, 1.0, L / n), HULL_DARK)
				continue
			k.block(Vector3(sx * w, -1.9, z), Vector3(0.35, 3.8, L / n), HULL * (0.9 + 0.1 * (i % 2)))
		k.block(Vector3(0, -3.7, z), Vector3(w * 2.0, 0.35, L / n), HULL_DARK)
		# Deck, with the hatch left open over the fore hold.
		if i != n / 3:
			k.block(Vector3(0, 0.0, z), Vector3(w * 2.0, 0.25, L / n), PLANK * (0.85 + 0.15 * (i % 2)))
	# Hold bulkhead and the stern cabin.
	k.block(Vector3(0, -1.9, 0), Vector3(B * 0.9, 3.8, 0.3), HULL_DARK)
	var cz := L * 0.5 - 3.0
	# Cabin front wall with a doorway (the jammed gate fills it); the roof
	# is stove in at the stern: a fourth way in, dropping from a glide.
	var jamb := (B * 0.7 - 1.8) * 0.5
	for sx in [-1.0, 1.0]:
		k.block(Vector3(sx * (0.9 + jamb * 0.5), 1.4, cz - 1.6), Vector3(jamb, 2.8, 0.3), HULL)
	k.block(Vector3(0, 2.55, cz - 1.6), Vector3(1.8, 0.5, 0.3), HULL)
	k.block(Vector3(0, 2.9, cz - 0.95), Vector3(B * 0.75, 0.3, 1.6), HULL_DARK)
	k.block(Vector3(B * 0.22, 2.75, cz + 0.6), Vector3(B * 0.3, 0.25, 1.4), HULL_DARK, 0.3)
	for sx in [-1.0, 1.0]:
		k.block(Vector3(sx * B * 0.35, 1.4, cz), Vector3(0.3, 2.8, 3.6), HULL)
	# Stern windows (swim-in gap between two panes).
	k.block(Vector3(-B * 0.22, 1.4, cz + 1.8), Vector3(B * 0.3, 2.8, 0.3), HULL)
	k.block(Vector3(B * 0.22, 1.4, cz + 1.8), Vector3(B * 0.3, 2.8, 0.3), HULL)
	# Broken mast and a torn sail.
	k.pillar(Vector3(0, 0, -L * 0.15), float(poi.get("mast", 9.0)), 0.3, HULL_DARK, 6)
	k.block(Vector3(0.8, float(poi.get("mast", 9.0)) * 0.7, -L * 0.15), Vector3(0.08, 3.0, 3.0), Color(0.8, 0.76, 0.66), 0.3, false)
	var built := k.build(holder, "Wreck", 1400.0)
	built.name = "WreckHull"
	var gate_flag := String(poi.get("cabin_gate", ""))
	if gate_flag != "":
		var gate := FlagGate.create(gate_flag, Vector3(1.8, 2.4, 0.3), HULL_DARK)
		holder.add_child(gate)
		gate.position = Vector3(0, 0.1, cz - 1.6)
		var lever := QuestObject.create({"id": id + ":lever", "look": "lever", "reward": {"flag": gate_flag}, "radius": 1.8,
			"lines": ["LINE_WRECK_LEVER"], "sound": "grab", "element": "wind"})
		holder.add_child(lever)
		lever.position = Vector3(-B * 0.2, -3.4, -L * 0.3)
	var chest := Chest.create(id + ":captain", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	holder.add_child(chest)
	chest.position = Vector3(0, 0.15, cz)
	var hold_chest := Chest.create(id + ":hold", &"chest_common", [])
	holder.add_child(hold_chest)
	hold_chest.position = Vector3(B * 0.2, -3.45, L * 0.2)
	if poi.get("vent", true):
		var vent := AirVent.new()
		holder.add_child(vent)
		vent.position = Vector3(-B * 0.25, -3.5, L * 0.15)
	for pg in poi.get("pages", []):
		var page := QuestObject.create(pg)
		holder.add_child(page)
		var pp: Array = pg.get("at", [0, 0, 0])
		page.position = Vector3(pp[0], pp[1], pp[2])
	var spawns: Array = []
	var gi := 0
	for gd in poi.get("guardians", []):
		var local := holder.transform * Vector3(gd[1], gd[2], gd[3])
		spawns.append(_spawn_at(root, String(gd[0]), local, id, gi))
		gi += 1
	return spawns


# --- Castaways' camp -----------------------------------------------------------------------------------------
## Not a village: three collapsed shelters, a cold signal pit, a grave with
## a ribbon, a boat hull turned into a roof. The story is in the pages
## scattered around (site data) and in the one who still comes back at dusk.
func castaway_camp(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var g := _g(root, 0, 0)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var c := Vector3(cos(a) * 7.0, 0, sin(a) * 7.0)
		c.y = _g(root, c.x, c.z)
		for sx in [-1.0, 1.0]:
			k.block(c + Vector3(sx * 1.5, 0.6, 0), Vector3(0.25, 1.2 + rng.randf() * 0.6, 2.6), HULL, a)
		k.block(c + Vector3(0.2, 1.2, 0.3), Vector3(3.4, 0.2, 2.8), HULL_DARK, a + 0.3, false)
	# The upturned boat as a roof.
	var boat := Vector3(-2.0, g, 3.0)
	for i in 6:
		k.block(boat + Vector3(0, 1.4 - absf(i - 2.5) * 0.15, -3.0 + i * 1.2), Vector3(2.6 - absf(i - 2.5) * 0.3, 0.2, 1.2), HULL, 0.2)
	for sx in [-1.0, 1.0]:
		k.block(boat + Vector3(sx * 1.2, 0.7, 0), Vector3(0.2, 1.4, 6.0), HULL_DARK, 0.2)
	# Signal pit and the grave.
	for i in 8:
		var a := TAU * i / 8.0
		k.rock(Vector3(cos(a) * 1.4, g + 0.3, sin(a) * 1.4), Vector3(0.6, 0.5, 0.6), ROCK_DARK)
	k.block(Vector3(5.0, g + 0.6, -3.0), Vector3(0.5, 1.2, 0.3), LIME)
	k.ribbon(Vector3(5.0, g + 1.3, -3.0), 1.4, 0.16, StructureKit.CINNABAR_LIGHT, 0.4)
	k.build(root, "CastawayCamp", 1200.0)
	var chest := Chest.create(id + ":stash", StringName(poi.get("loot", "chest_common")), poi.get("reward", []))
	root.add_child(chest)
	chest.position = boat + Vector3(0, 0.05, 0)
	return []


# --- Tide cave (Tide Isle) --------------------------------------------------------------------------------------
## A sea cave whose mouth faces the open water. The tide decides the way
## in: at low water a sandbar (site data) leads to it on foot; at high water
## surf blocks the mouth and only the drowned side tunnel (dive, air
## vent) gets you in; in a storm the blowhole in the roof becomes a rising
## column of air (site data) up to the high chamber.
func tide_cave(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var g := _g(root, 0, 0)
	var r := 10.0
	for i in 16:
		var a := TAU * i / 16.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.35:
			continue   # the mouth (local +z)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		k.rock(p + Vector3(0, g + 2.2, 0), Vector3(4.0, 5.0, 3.4), ROCK)
		k.rock(p * 0.92 + Vector3(0, g + 6.4, 0), Vector3(3.6, 3.0, 3.2), ROCK_DARK, false)
	# Roof with the blowhole in the middle.
	for i in 6:
		var a := TAU * i / 6.0
		k.rock(Vector3(cos(a) * 5.0, g + 8.2, sin(a) * 5.0), Vector3(6.0, 1.6, 6.0), ROCK_DARK)
	# High chamber ledge under the roof (storm route) and the tide pool floor.
	k.block(Vector3(-4.0, g + 6.5, -4.0), Vector3(4.0, 0.6, 4.0), ROCK_DARK)
	k.block(Vector3(0, g - 0.2, 0), Vector3(12.0, 0.4, 12.0), Color(0.62, 0.58, 0.46))
	# Drowned side tunnel: a low arch on the west side into the lagoon.
	k.block(Vector3(-r - 1.5, g - 1.2, 0), Vector3(3.0, 0.4, 3.0), ROCK_DARK)
	k.build(root, "TideCave", 900.0)
	var low := Chest.create(id + ":pool", StringName(poi.get("loot", "chest_common")), poi.get("reward", []))
	root.add_child(low)
	low.position = Vector3(2.0, g, -3.0)
	var high := Chest.create(id + ":ledge", &"chest_rare", poi.get("storm_reward", []), true)
	root.add_child(high)
	high.position = Vector3(-4.0, g + 6.85, -4.0)
	var vent := AirVent.new()
	root.add_child(vent)
	vent.position = Vector3(-r - 1.5, g - 1.0, 0)
	return []


# --- Bell sanctuary (Mist Sea) ------------------------------------------------------------------------------
## A drowned belfry on a knoll in the heart of the mist: a ring of broken
## pillars round the great bell that answers the fog bells. When the whole
## line has been rung, the stone lid of the altar niche grinds aside.
## Found by following the bells, or on a clear afternoon when the mist lifts.
func bell_shrine(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var g := _g(root, 0, 0)
	for i in 7:
		var a := TAU * i / 7.0
		var p := Vector3(cos(a) * 7.5, 0, sin(a) * 7.5)
		p.y = _g(root, p.x, p.z)
		var h := rng.randf_range(1.8, 5.0)
		k.pillar(p, h, 0.45, LIME, 6)
		if i % 3 == 0:
			k.block(p + Vector3(0.6, 0.3, 0.8), Vector3(1.0, 0.6, 2.2), LIME * 0.9, a)
	# Worn flagstones and the altar with its niche (the lid is a FlagGate).
	k.block(Vector3(0, g + 0.1, 0), Vector3(9.0, 0.3, 9.0), ROCK)
	k.block(Vector3(0, g + 0.7, -3.4), Vector3(3.0, 1.0, 1.6), LIME)
	k.build(root, "BellShrine", 1500.0)
	var b: Dictionary = poi.get("bell", {})
	if not b.is_empty():
		var bell := FogBell.create(b)
		root.add_child(bell)
		bell.position = Vector3(0, g + 0.2, 0)
	var chest := Chest.create(id + ":altar", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = Vector3(0, g + 1.25, -3.4)
	var lid_flag := String(b.get("line_flag", ""))
	if lid_flag != "":
		var lid := FlagGate.create(lid_flag, Vector3(1.8, 1.4, 1.4), ROCK_DARK)
		root.add_child(lid)
		lid.position = Vector3(0, g + 1.2, -3.4)
	return []


# --- Sea cave (reusable) ---------------------------------------------------------------------------------------
## A small sea cave in a coastal bluff: from the open water a rock arch
## narrows to a low throat whose roof dips under the surface (dive through;
## an air vent bubbles in the throat), then a dark chamber — water, a dry
## ledge at the back, shells to gather, something living in the roof — and
## a chimney to a high shelf where the cave keeps its secret. Opens to local
## -x (the sea side). Params: "length" of the throat.
func sea_cave(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var k := StructureKit.new(hash(id))
	var s := WorldGen.SEA_LEVEL - root.global_position.y
	var throat := float(poi.get("length", 8.0))
	# Outer arch (-x): high roof over open water.
	for i in 4:
		var x := -10.0 - throat - i * 2.5
		for sz in [-1.0, 1.0]:
			k.rock(Vector3(x, s + 1.0, sz * 4.2), Vector3(3.0, 9.0, 2.2), ROCK)
		k.rock(Vector3(x, s + 6.2, 0), Vector3(3.0, 1.6, 10.0), ROCK_DARK)
	# The throat: side walls and a roof that dips below the waterline.
	for i in int(throat / 2.0):
		var x := -10.0 - i * 2.0
		for sz in [-1.0, 1.0]:
			k.rock(Vector3(x, s - 1.0, sz * 3.2), Vector3(2.2, 9.0, 1.8), ROCK_DARK)
		k.rock(Vector3(x, s + 0.6, 0), Vector3(2.2, 3.4, 7.0), ROCK_DARK)
	# The chamber: a ring wall, a roof, a dry ledge at the back.
	for i in 12:
		var a := TAU * i / 12.0
		if absf(wrapf(a - PI, -PI, PI)) < 0.4:
			continue   # the throat (-x)
		k.rock(Vector3(cos(a) * 8.5, s + 1.5, sin(a) * 7.0), Vector3(3.6, 12.0, 3.2), ROCK)
	for i in 4:
		k.rock(Vector3(-4.5 + i * 3.2, s + 7.6, 0), Vector3(3.6, 1.8, 15.0), ROCK_DARK)
	k.block(Vector3(5.2, s + 0.4, 0), Vector3(4.0, 1.0, 9.0), ROCK)
	# Chimney shelf (the secret): a step of ledges up the back wall.
	for i in 3:
		k.block(Vector3(6.5 - i * 0.6, s + 2.2 + i * 1.6, -4.5 + i * 1.3), Vector3(1.6, 0.4, 1.4), ROCK_DARK)
	k.block(Vector3(5.6, s + 6.4, -1.2), Vector3(2.4, 0.4, 2.4), ROCK_DARK)
	k.build(root, "SeaCave", 800.0)
	# Glowing moss on the chamber roof: the only light inside.
	var moss := StandardMaterial3D.new()
	moss.albedo_color = Color(0.3, 0.8, 0.6)
	moss.emission_enabled = true
	moss.emission = Color(0.25, 0.9, 0.65)
	moss.emission_energy_multiplier = 2.0
	var mparts: Array = []
	for i in 7:
		var a := TAU * i / 7.0
		mparts.append([ShapeKit.sphere(0.35, 6), Transform3D(Basis().scaled(Vector3(1.4, 0.4, 1.0)), Vector3(cos(a) * 5.5, s + 6.6, sin(a) * 4.5))])
	var mm := MeshInstance3D.new()
	mm.mesh = ShapeKit.merged(mparts)
	mm.material_override = moss
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mm)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.95, 0.75)
	glow.light_energy = 1.2
	glow.omni_range = 11.0
	glow.shadow_enabled = false
	glow.position = Vector3(1.0, s + 4.5, 0)
	root.add_child(glow)
	var vent := AirVent.new()
	root.add_child(vent)
	vent.position = Vector3(-10.0 - throat * 0.5, s - 3.0, 0)
	for i in 3:
		var shell := QuestObject.create({"id": "%s:shell_%d" % [id, i], "look": "scroll", "item": String(poi.get("gather", "echo_shell")), "count": 2,
			"prompt": "PROMPT_TAKE", "radius": 1.4, "sound": "grab", "element": "water"})
		root.add_child(shell)
		shell.position = Vector3(4.2 + i * 0.7, s + 0.95, -3.0 + i * 3.0)
	var chest := Chest.create(id + ":shelf", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	root.add_child(chest)
	chest.position = Vector3(5.6, s + 6.65, -1.2)
	var spawns: Array = []
	var gi := 0
	for gd in poi.get("guardians", []):
		spawns.append(_spawn_at(root, String(gd[0]), Vector3(gd[1], s + float(gd[2]), gd[3]), id, gi))
		gi += 1
	return spawns


# --- Standing wreck (wreck variant) ---------------------------------------------------------------------------
## A ship that went down bow-first against a sea wall and stayed standing:
## a wooden tower from the sea bed to a few metres above the water. The only
## dry way in is the broken bow at the top; inside, a shaft straight down in
## the dark — dive, keep your bearings by the light from above, catch your
## breath at the vent half-way, find the strongbox on the bottom and leave by
## the split in the keel. Params: "tilt" (deg, toward local +x), "height".
func standing_wreck(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var s := WorldGen.SEA_LEVEL - root.global_position.y
	var bed := _g(root, 0, 0)
	var top := s + float(poi.get("above", 4.0))
	var H := top - bed
	var holder := Node3D.new()
	holder.name = "StandingWreck"
	root.add_child(holder)
	holder.position = Vector3(0, bed, 0)
	holder.rotation.z = -deg_to_rad(float(poi.get("tilt", 12.0)))
	var k := StructureKit.new(hash(id))
	var W := 4.6
	var D := 3.2
	var n := int(H / 2.0)
	for i in n:
		var y := 1.0 + i * 2.0
		var shade := 0.85 + 0.15 * (i % 2)
		for sx in [-1.0, 1.0]:
			k.block(Vector3(sx * W * 0.5, y, 0), Vector3(0.3, 2.0, D), HULL * shade)
		# The keel split at the bottom (-z face open for 2 m): the way out.
		if i > 0:
			k.block(Vector3(0, y, -D * 0.5), Vector3(W, 2.0, 0.3), HULL_DARK * shade)
		k.block(Vector3(0, y, D * 0.5), Vector3(W, 2.0, 0.3), HULL * shade)
		if i % 3 == 1:
			k.block(Vector3(0, y, 0), Vector3(W * 0.9, 0.2, 0.25), HULL_DARK, 0.0, false)
	# Broken bow sprit sticking out at the top.
	k.block(Vector3(0.6, H + 1.2, 0), Vector3(0.3, 3.0, 0.3), HULL_DARK, 0.4, false)
	k.build(holder, "WreckShaft", 1200.0)
	var vent := AirVent.new()
	holder.add_child(vent)
	vent.position = Vector3(0, H * 0.5, 0)
	var chest := Chest.create(id + ":strongbox", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	holder.add_child(chest)
	chest.position = Vector3(0, 0.6, 0)
	return []


# --- Split wreck (wreck variant) -------------------------------------------------------------------------------
## A ship broken in two. The bow lies aground on the shore, tilted up, dry
## and easy — its log says the stern went down with the strongbox. The
## stern sits on a ledge offshore under the water. What ties them is the
## anchor chain, paid out from the bow's hawse down along the bed to the
## stern: follow it and you find the other half. Params: "stern" [x, y, z]
## local offset of the stern half (y: depth below the water), "yaw" (deg,
## bow: its broken end faces local +z of the hull), "stern_yaw" (deg).
func split_wreck(poi: Dictionary, root: Node3D) -> Array:
	var id: String = poi["id"]
	var s := WorldGen.SEA_LEVEL - root.global_position.y
	var yaw := deg_to_rad(float(poi.get("yaw", 0.0)))
	var st: Array = poi.get("stern", [0, -11, 30])
	# Bow half: aground, nose up.
	var bow := Node3D.new()
	bow.name = "WreckBow"
	root.add_child(bow)
	bow.position = Vector3(0, _g(root, 0, 0) + 1.2, 0)
	bow.rotation = Vector3(deg_to_rad(-14.0), yaw, deg_to_rad(8.0))
	var kb := StructureKit.new(hash(id + "b"))
	_hull_half(kb, 12.0, 6.0, true)
	kb.build(bow, "BowHalf", 1400.0)
	var log_page := QuestObject.create({"id": id + ":log", "look": "scroll", "item": String(poi.get("log_item", "")), "radius": 1.6,
		"prompt": "PROMPT_READ", "lines": [String(poi.get("log_line", ""))], "speaker": String(poi["name_key"]), "sound": "grab"})
	bow.add_child(log_page)
	log_page.position = Vector3(0, 0.35, 6.0)
	var bchest := Chest.create(id + ":bow", &"chest_common", [])
	bow.add_child(bchest)
	bchest.position = Vector3(0.8, 0.2, 8.5)
	# Stern half: on the offshore ledge, broken end facing the bow.
	var stern_local := Vector3(float(st[0]), 0, float(st[2]))
	var stern := Node3D.new()
	stern.name = "WreckStern"
	root.add_child(stern)
	var sy := maxf(_g(root, stern_local.x, stern_local.z) + 3.6, s + float(st[1]))
	stern.position = Vector3(stern_local.x, sy, stern_local.z)
	stern.rotation = Vector3(deg_to_rad(4.0), deg_to_rad(float(poi.get("stern_yaw", 0.0))), deg_to_rad(-16.0))
	var ks := StructureKit.new(hash(id + "s"))
	_hull_half(ks, 13.0, 6.4, false)
	ks.build(stern, "SternHalf", 1400.0)
	var vent := AirVent.new()
	stern.add_child(vent)
	vent.position = Vector3(-1.2, -3.3, 3.0)
	var chest := Chest.create(id + ":strongbox", StringName(poi.get("loot", "chest_rare")), poi.get("reward", []), true)
	stern.add_child(chest)
	chest.position = Vector3(0.8, -3.35, 7.5)
	# The anchor chain from the bow's hawse down the bed to the stern.
	var kc := StructureKit.new(hash(id + "c"))
	var a := bow.global_transform * Vector3(0, -2.0, 0.6) - root.global_position
	var b := stern.global_transform * Vector3(0, -3.0, 0.6) - root.global_position
	var links := int(a.distance_to(b) / 1.1)
	for i in links:
		var t := float(i) / maxf(links - 1, 1)
		var p := a.lerp(b, t)
		p.y = maxf(minf(p.y, lerpf(a.y, b.y, t) - sin(t * PI) * 2.0), _g(root, p.x, p.z) + 0.15)
		kc.block(p, Vector3(0.18, 0.18, 0.7), Color(0.22, 0.2, 0.19), yaw + (0.0 if i % 2 == 0 else PI * 0.5), false)
	kc.build(root, "AnchorChain", 400.0)
	return []


## Half a hull (length L along +z), open at its broken end (z = 0 side for
## the bow's aft end / the stern's fore end). Deck at y = 0.
func _hull_half(k: StructureKit, L: float, B: float, is_bow: bool) -> void:
	var n := int(L / 2.0)
	for i in n:
		var z := (i + 0.5) * L / n
		var t := z / L if is_bow else 0.2
		var w := B * 0.5 * (1.0 - pow(t, 2.2) * (0.8 if is_bow else 0.2))
		var jag := 1.0 if i > 0 else 0.55   # the broken edge is ragged
		for sx in [-1.0, 1.0]:
			k.block(Vector3(sx * w, -1.9 * jag, z), Vector3(0.35, 3.8 * jag, L / n), HULL * (0.9 + 0.1 * (i % 2)))
		k.block(Vector3(0, -3.7, z), Vector3(w * 2.0, 0.35, L / n), HULL_DARK)
		if i > 0 and i != n / 2:
			k.block(Vector3(0, 0.0, z), Vector3(w * 2.0, 0.25, L / n), PLANK * (0.85 + 0.15 * (i % 2)))
	# Closed far end (bow stem / stern transom).
	k.block(Vector3(0, -1.9, L), Vector3(B * (0.35 if is_bow else 0.9), 3.8, 0.35), HULL_DARK)
