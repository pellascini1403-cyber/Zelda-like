class_name AmbientLife
extends Node3D
## Background fauna that makes places read as alive without costing AI:
## flocks of gulls, sparrows, ravens and bats, fish schools in the lake and
## the sea, fireflies, butterflies, Veil motes, crabs and sand skitters.
## Groups come from data/fauna.json (region, period, weather, density).
##
## Simulation tiers (mobile first):
##   Tier 1  cells within `ambient_distance`: one MultiMesh per group,
##           cheap closed-form motion + scatter; capped by `ambient_groups`
##   Tier 2  cells further out: existence only (seeded hash, no nodes)
##   Tier 3  everything else: nothing
## No physics bodies, no per-animal nodes. Groups scatter from the player,
## from noise (combat, explosions) and — bats — from fire.

const CELL := 48.0
const REFRESH := 1.0

var gen: WorldGen
var _defs: Array = []
var _live: Dictionary = {}   # key "cx:cz:id" -> Group
var _timer := 0.0
var _meshes: Dictionary = {}
var _mats: Dictionary = {}


class Group:
	var key := ""
	var def: Dictionary
	var center := Vector3.ZERO
	var ground := 0.0
	var mm: MultiMeshInstance3D
	var n := 0
	var seeds: PackedFloat32Array = []   # 4 per instance: phase, radius k, height k, speed k
	var scare := 0.0
	var away := Vector3.ZERO
	var targets: PackedVector3Array = []  # skitters
	var pos: PackedVector3Array = []


func _ready() -> void:
	add_to_group(&"ambient_life")
	_defs = DB.fauna
	EventBus.noise_emitted.connect(_on_noise)


## Groups that could exist in the cell whose centre is `c` right now.
func groups_for_cell(cx: int, cz: int) -> Array:
	var out: Array = []
	var x := (cx + 0.5) * CELL
	var z := (cz + 0.5) * CELL
	var h := gen.height(x, z)
	var region := String(gen.region_at(x, z))
	for d: Dictionary in _defs:
		if not region in d.get("regions", []):
			continue
		if not conditions_ok(d):
			continue
		var kind := String(d.get("kind", "flock"))
		if kind == "school" and h > WorldGen.SEA_LEVEL - 1.5:
			continue
		if kind != "school" and kind != "flock" and h < WorldGen.SEA_LEVEL + 0.3:
			continue
		if d.get("shore", false) and h > WorldGen.SEA_LEVEL + 3.0:
			continue
		if kind == "skitter" and not d.get("shore", false) and gen.normal(x, z).y < 0.8:
			continue
		var roll := float(absi(hash("%d:%d:%s" % [cx, cz, d["id"]])) % 1000) / 1000.0
		if roll < float(d.get("density", 0.3)):
			out.append(d)
	return out


static func conditions_ok(d: Dictionary) -> bool:
	var period := String(d.get("period", "any"))
	if period == "night" and not Clock.is_night():
		return false
	if period == "day" and Clock.is_night():
		return false
	var w := String(Weather.target)
	if d.has("weather") and not w in d["weather"]:
		return false
	if w in d.get("not_weather", []):
		return false
	return true


func _process(delta: float) -> void:
	if gen == null or Game.player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_refresh()
	var ppos := Game.player.global_position
	var now := Time.get_ticks_msec() * 0.001
	for g: Group in _live.values():
		_animate(g, ppos, now, delta)


func _refresh() -> void:
	var q := Quality.current()
	var dist := float(q.get("ambient_distance", 90.0))
	var cap := int(q.get("ambient_groups", 4))
	var p := Game.player.global_position
	var r := int(ceil(dist / CELL))
	var pcx := int(floor(p.x / CELL))
	var pcz := int(floor(p.z / CELL))
	var wanted: Array = []   # [dist, key, def, cx, cz]
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var cx := pcx + dx
			var cz := pcz + dz
			var c := Vector3((cx + 0.5) * CELL, 0, (cz + 0.5) * CELL)
			var d := Vector2(c.x - p.x, c.z - p.z).length()
			if d > dist:
				continue
			for def: Dictionary in groups_for_cell(cx, cz):
				wanted.append([d, "%d:%d:%s" % [cx, cz, def["id"]], def, cx, cz])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	wanted = wanted.slice(0, cap)
	var keep := {}
	for w in wanted:
		keep[w[1]] = true
		if not _live.has(w[1]):
			_live[w[1]] = _build(w[1], w[2], w[3], w[4])
	for k in _live.keys():
		if not keep.has(k):
			(_live[k] as Group).mm.queue_free()
			_live.erase(k)


func live_count() -> int:
	return _live.size()


func live_ids() -> Array:
	var out: Array = []
	for g: Group in _live.values():
		out.append(String(g.def["id"]))
	return out


func _build(key: String, d: Dictionary, cx: int, cz: int) -> Group:
	var g := Group.new()
	g.key = key
	g.def = d
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	g.center = Vector3((cx + rng.randf_range(0.25, 0.75)) * CELL, 0, (cz + rng.randf_range(0.25, 0.75)) * CELL)
	g.ground = gen.height(g.center.x, g.center.z)
	g.center.y = g.ground
	var cnt: Array = d.get("count", [5, 8])
	g.n = rng.randi_range(int(cnt[0]), int(cnt[1]))
	g.seeds.resize(g.n * 4)
	for i in g.n:
		g.seeds[i * 4] = rng.randf() * TAU
		g.seeds[i * 4 + 1] = rng.randf_range(0.35, 1.0)
		g.seeds[i * 4 + 2] = rng.randf()
		g.seeds[i * 4 + 3] = rng.randf_range(0.8, 1.25)
	if String(d.get("kind", "")) == "skitter":
		g.pos.resize(g.n)
		g.targets.resize(g.n)
		for i in g.n:
			var a := g.seeds[i * 4] 
			g.pos[i] = g.center + Vector3(cos(a), 0, sin(a)) * float(d.get("radius", 5.0)) * g.seeds[i * 4 + 1]
			g.targets[i] = g.pos[i]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh(String(d.get("mesh", "bird")))
	mm.instance_count = g.n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat(String(d.get("color", "#ffffff")), d.get("glow", false))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Fauna_" + String(d["id"])
	add_child(mi)
	g.mm = mi
	return g


func _animate(g: Group, ppos: Vector3, now: float, delta: float) -> void:
	var d := g.def
	var kind := String(d.get("kind", "flock"))
	var R := float(d.get("radius", 8.0))
	var spd := float(d.get("speed", 1.0))
	var scare_r := float(d.get("scare", 0.0))
	var to_p := Vector3(g.center.x - ppos.x, 0, g.center.z - ppos.z)
	if scare_r > 0.0 and to_p.length() < scare_r + R * 0.5 and absf(ppos.y - g.center.y) < 12.0:
		g.scare = 1.0
		g.away = to_p.normalized() if to_p.length() > 0.1 else Vector3.RIGHT
	elif d.get("fire_shy", false) and g.scare < 0.5 and Engine.get_process_frames() % 30 == 0:
		for h in get_tree().get_nodes_in_group(&"heat_source"):
			var hp := (h as Node3D).global_position
			if Vector2(hp.x - g.center.x, hp.z - g.center.z).length() < R + 5.0:
				g.scare = 1.0
				g.away = Vector3(g.center.x - hp.x, 0, g.center.z - hp.z).normalized()
	g.scare = maxf(g.scare - delta * 0.18, 0.0)
	var mm := g.mm.multimesh
	var s := g.scare
	for i in g.n:
		var ph := g.seeds[i * 4]
		var rk := g.seeds[i * 4 + 1]
		var hk := g.seeds[i * 4 + 2]
		var sk := g.seeds[i * 4 + 3]
		var p := Vector3.ZERO
		var yaw := 0.0
		var flap := 1.0
		match kind:
			"flock":
				var hr: Array = d.get("height", [4, 8])
				var a := ph + now * spd * sk
				var rad := R * rk * (1.0 + s * 1.2)
				p = g.center + Vector3(cos(a), 0, sin(a)) * rad + g.away * s * 18.0
				p.y = g.ground + lerpf(float(hr[0]), float(hr[1]), hk) + s * 14.0 + sin(now * 1.3 + ph) * 0.6
				yaw = -a
				flap = 0.35 + absf(sin(now * (9.0 + s * 8.0) * sk + ph)) * 0.9
			"school":
				var dr: Array = d.get("depth", [0.8, 2.5])
				var depth := lerpf(float(dr[0]), float(dr[1]), hk)
				if d.get("dawn_dusk_shallow", false) and (absf(Clock.hour - 6.5) < 1.5 or absf(Clock.hour - 19.0) < 1.5):
					depth *= 0.4
				var a := ph + now * spd * sk * (1.0 + s * 3.0)
				p = g.center + Vector3(cos(a) * R * rk, 0, sin(a) * R * rk * 0.6) + g.away * s * 9.0
				p.y = maxf(WorldGen.SEA_LEVEL - depth, g.ground + 0.3)
				yaw = -a
				flap = 1.0 + sin(now * 10.0 + ph) * 0.12
			"motes":
				var hr2: Array = d.get("height", [0.5, 2.0])
				var t := now * spd * sk
				p = g.center + Vector3(sin(t + ph) * R * rk, 0, cos(t * 0.8 + ph * 1.7) * R * rk) + g.away * s * 6.0
				p.y = g.ground + lerpf(float(hr2[0]), float(hr2[1]), hk) + sin(t * 2.1 + ph) * 0.4 + s * 3.0
				yaw = t
				flap = 0.3 + absf(sin(now * 14.0 + ph)) * 0.9 if String(d.get("mesh", "")) == "butterfly" else (0.6 + 0.4 * sin(now * 3.0 + ph * 5.0) if d.get("glow", false) else 1.0)
			"skitter":
				var cur := g.pos[i]
				var tgt := g.targets[i]
				var flee := Vector3(cur.x - ppos.x, 0, cur.z - ppos.z)
				if scare_r > 0.0 and flee.length() < scare_r:
					tgt = cur + flee.normalized() * 4.0
					g.targets[i] = tgt
				elif cur.distance_to(tgt) < 0.3 and fmod(now + ph, 3.0) < delta * 2.0:
					var a2 := randf() * TAU
					tgt = g.center + Vector3(cos(a2), 0, sin(a2)) * R * randf()
					g.targets[i] = tgt
				var step := (tgt - cur)
				step.y = 0.0
				if step.length() > 0.05:
					cur += step.normalized() * minf(step.length(), spd * (2.0 if flee.length() < scare_r else 1.0) * delta)
					yaw = atan2(-step.x, -step.z)
				if Engine.get_process_frames() % 12 == i % 12:
					cur.y = gen.height(cur.x, cur.z)
				g.pos[i] = cur
				p = cur
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(flap, 1.0, 1.0) if kind != "motes" or d.get("mesh", "") == "butterfly" else Vector3.ONE * flap)
		mm.set_instance_transform(i, Transform3D(basis, p))


func _on_noise(pos: Vector3, radius: float, _source: Node) -> void:
	for g: Group in _live.values():
		if float(g.def.get("scare", 0.0)) <= 0.0:
			continue
		var to := Vector3(g.center.x - pos.x, 0, g.center.z - pos.z)
		if to.length() < radius + float(g.def.get("radius", 6.0)):
			g.scare = 1.0
			g.away = to.normalized() if to.length() > 0.1 else Vector3.FORWARD


# --- Shared meshes / materials ------------------------------------------------------------
func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"bird", "bat", "butterfly":
			# Two wing triangles and a sliver of body; flapping = x scale.
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var span: float = {"bird": 0.45, "bat": 0.32, "butterfly": 0.14}[kind]
			var chord: float = {"bird": 0.18, "bat": 0.16, "butterfly": 0.12}[kind]
			for sx: float in [-1.0, 1.0]:
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(0, 0, -chord * 0.5))
				st.add_vertex(Vector3(sx * span, 0.05, chord * 0.2))
				st.add_vertex(Vector3(0, 0, chord * 0.6))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(-0.03, 0, -chord))
			st.add_vertex(Vector3(0.03, 0, -chord))
			st.add_vertex(Vector3(0, 0, chord * 1.2))
			m = st.commit()
		"fish":
			var cm := CapsuleMesh.new()
			cm.radius = 0.07
			cm.height = 0.42
			cm.radial_segments = 6
			cm.rings = 2
			var arr := cm.get_mesh_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for vi in verts.size():
				var v := verts[vi]
				verts[vi] = Vector3(v.x * 0.6, v.z, v.y)   # lie along -z, flattened
			arr[Mesh.ARRAY_VERTEX] = verts
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m = am
		"crab":
			m = ShapeKit.box(Vector3(0.22, 0.08, 0.16))
		_:
			m = ShapeKit.sphere(0.08, 4)
	_meshes[kind] = m
	return m


func _mat(hex: String, glow: bool) -> Material:
	var k := hex + str(glow)
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = 3.5
	_mats[k] = m
	return m
