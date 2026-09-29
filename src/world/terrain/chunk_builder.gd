class_name ChunkBuilder
extends RefCounted
## Builds the raw data of one terrain sector. Runs on WorkerThreadPool.
##
## Produces only plain arrays (no nodes, no RIDs) so it is thread-safe; the
## main thread turns the result into nodes inside a per-frame budget.
##
## LOD0 = 2 m grid + collision + full vegetation + gameplay placements
## LOD1 = 4 m grid, trees + rocks (simplified meshes)
## Beyond LOD1, HorizonTiles take over (8 m grid + impostor trees).

const CHUNK_SIZE := 64.0
const LOD_STEP := [2.0, 4.0]
const SKIRT_DEPTH := 6.0


## Bilinear sampler over the already computed height grid (with border), so
## vegetation placement never re-evaluates the noise stack.
class Grid:
	var hs: PackedFloat32Array
	var w: int
	var step: float
	var x0: float
	var z0: float

	func _init(heights: PackedFloat32Array, width: int, s: float, ox: float, oz: float) -> void:
		hs = heights
		w = width
		step = s
		x0 = ox
		z0 = oz

	func height(x: float, z: float) -> float:
		var fx := clampf((x - x0) / step, 0.0, w - 1.001)
		var fz := clampf((z - z0) / step, 0.0, w - 1.001)
		var ix := int(fx)
		var iz := int(fz)
		var tx := fx - ix
		var tz := fz - iz
		var a := hs[iz * w + ix]
		var b := hs[iz * w + ix + 1]
		var c := hs[(iz + 1) * w + ix]
		var d := hs[(iz + 1) * w + ix + 1]
		return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

	func normal(x: float, z: float) -> Vector3:
		var e := step
		return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()


static func build(gen: WorldGen, cx: int, cz: int, lod: int, veg_density: float) -> Dictionary:
	var step: float = LOD_STEP[lod]
	var n := int(CHUNK_SIZE / step) + 1
	var ox := cx * CHUNK_SIZE
	var oz := cz * CHUNK_SIZE

	# Heights with a 1-sample border so normals are seamless across chunks.
	var hs := PackedFloat32Array()
	hs.resize((n + 2) * (n + 2))
	for j in n + 2:
		for i in n + 2:
			hs[j * (n + 2) + i] = gen.height(ox + (i - 1) * step, oz + (j - 1) * step)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	var collision := PackedFloat32Array()
	if lod == 0:
		collision.resize(n * n)
	for j in n:
		for i in n:
			var bi := (j + 1) * (n + 2) + (i + 1)
			var h := hs[bi]
			var x := i * step
			var z := j * step
			var nx := hs[bi - 1] - hs[bi + 1]
			var nz := hs[bi - (n + 2)] - hs[bi + (n + 2)]
			var nrm := Vector3(nx, 2.0 * step, nz).normalized()
			var k := j * n + i
			verts[k] = Vector3(x, h, z)
			norms[k] = nrm
			var wx := ox + x
			var wz := oz + z
			cols[k] = Color(gen.forest_density(wx, wz), 0.0, 0.0, 1.0)
			if lod == 0:
				collision[k] = h

	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])

	_add_skirts(verts, norms, cols, idx, n)

	var result := {
		"cx": cx, "cz": cz, "lod": lod,
		"verts": verts, "norms": norms, "cols": cols, "idx": idx,
		"collision": collision, "grid": n, "step": step,
	}
	if lod <= 1:
		var grid := Grid.new(hs, n + 2, step, ox - step, oz - step)
		result["veg"] = _place_vegetation(gen, grid, cx, cz, lod, veg_density)
	if lod == 0:
		result["nodes"] = _place_gameplay(gen, cx, cz)
	return result


## Vertical skirts hide cracks between neighbouring chunks of different LOD.
static func _add_skirts(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, n: int) -> void:
	var edges := [[], [], [], []]
	for i in n:
		edges[0].append(i)                 # north edge (z = 0)
		edges[1].append((n - 1) * n + i)   # south edge
		edges[2].append(i * n)             # west edge
		edges[3].append(i * n + n - 1)     # east edge
	for e in 4:
		var base := verts.size()
		for k in edges[e]:
			verts.append(verts[k] - Vector3(0, SKIRT_DEPTH, 0))
			norms.append(norms[k])
			cols.append(cols[k])
		var flip: bool = e == 0 or e == 3
		for i in n - 1:
			var a: int = edges[e][i]
			var b: int = edges[e][i + 1]
			var c := base + i
			var d := base + i + 1
			if flip:
				idx.append_array([a, c, b, b, c, d])
			else:
				idx.append_array([a, b, c, b, d, c])


## Deterministic vegetation. Returns { kind: Array[Transform3D] }.
static func _place_vegetation(gen: WorldGen, grid: Grid, cx: int, cz: int, lod: int, density: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldGen.chunk_seed(cx, cz, 11)
	var out := {"pine": [], "broadleaf": [], "bush": [], "rock": [], "grass": [], "flower": []}
	var ox := cx * CHUNK_SIZE
	var oz := cz * CHUNK_SIZE

	# Trees: jittered grid so density is even but organic.
	var cell := 9.0
	var cells := int(CHUNK_SIZE / cell)
	for j in cells:
		for i in cells:
			var x := ox + (i + rng.randf()) * cell
			var z := oz + (j + rng.randf()) * cell
			var roll := rng.randf()
			var h := grid.height(x, z)
			if h < 2.0:
				continue
			var nrm := grid.normal(x, z)
			if nrm.y < 0.8:
				continue
			var forest := gen.forest_density(x, z)
			var alpine := smoothstep(70.0, 110.0, h)
			var chance := 0.03 + forest * 0.55 + alpine * 0.2
			if h > gen.snow_line() + 25.0:
				chance *= 0.15
			if roll > chance:
				continue
			var s := rng.randf_range(0.8, 1.35)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(x - ox, h - 0.2, z - oz))
			if alpine > 0.5 or (forest < 0.3 and rng.randf() < 0.35):
				out["pine"].append(t)
			else:
				out["broadleaf"].append(t)

	# Boulders: rarer, larger, sit on slopes too.
	for k in 3:
		var x := ox + rng.randf() * CHUNK_SIZE
		var z := oz + rng.randf() * CHUNK_SIZE
		if rng.randf() < 0.55:
			var h := grid.height(x, z)
			if h > 0.5:
				var s := rng.randf_range(0.7, 2.6)
				var b := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s))
				out["rock"].append(Transform3D(b, Vector3(x - ox, h - 0.3 * s, z - oz)))

	if lod > 0:
		return out

	# Undergrowth: bushes, grass clumps, flowers (density scales with quality).
	var bush_count := int(18 * density)
	for k in bush_count:
		var x := ox + rng.randf() * CHUNK_SIZE
		var z := oz + rng.randf() * CHUNK_SIZE
		var h := grid.height(x, z)
		if h < 2.5 or h > gen.snow_line():
			continue
		var f := gen.forest_density(x, z)
		if rng.randf() > 0.25 + f * 0.7:
			continue
		var s := rng.randf_range(0.6, 1.3)
		out["bush"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x - ox, h - 0.1, z - oz)))

	var grass_count := int(2000 * density)
	for k in grass_count:
		var lx := rng.randf() * CHUNK_SIZE
		var lz := rng.randf() * CHUNK_SIZE
		var h := grid.height(ox + lx, oz + lz)
		if h < 2.8 or h > gen.snow_line() - 20.0:
			continue
		var nrm := grid.normal(ox + lx, oz + lz)
		if nrm.y < 0.82:
			continue
		var s := rng.randf_range(0.75, 1.3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
		var t := Transform3D(basis, Vector3(lx, h - 0.05, lz))
		if rng.randf() < 0.04:
			out["flower"].append(t)
		else:
			out["grass"].append(t)
	return out


## Gameplay placements for this sector: resource nodes and wildlife/enemy
## spawn points. Stable ids ("cx:cz:k") let WorldState remember harvested nodes.
static func _place_gameplay(gen: WorldGen, cx: int, cz: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldGen.chunk_seed(cx, cz, 23)
	var ox := cx * CHUNK_SIZE + CHUNK_SIZE * 0.5
	var oz := cz * CHUNK_SIZE + CHUNK_SIZE * 0.5
	var region := gen.region_at(ox, oz)
	var out: Array = []
	out.append({"kind": "region", "region": region})
	for k in 7:
		var x := cx * CHUNK_SIZE + rng.randf_range(4.0, CHUNK_SIZE - 4.0)
		var z := cz * CHUNK_SIZE + rng.randf_range(4.0, CHUNK_SIZE - 4.0)
		var h := gen.height(x, z)
		var nrm := gen.normal(x, z, 1.0)
		out.append({
			"kind": "slot", "id": "%d:%d:%d" % [cx, cz, k],
			"pos": Vector3(x, h, z), "normal": nrm, "roll": rng.randf(), "roll2": rng.randf(),
			"region": gen.region_at(x, z),
		})
	return out
