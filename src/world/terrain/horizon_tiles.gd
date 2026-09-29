class_name HorizonTiles
extends Node3D
## Far terrain tier (LOD2 / impostor tier): the whole island as 12x12 tiles
## of 256 m at 8 m resolution, plus sparse low-poly "impostor" trees so
## forests still read on the horizon.
##
## A tile hides itself as soon as all sixteen streamed sectors it covers are
## loaded (while partially covered it simply sits 0.8 m below the detailed
## terrain), so detailed and far terrain never fight. Tiles are individually
## frustum-culled; the whole island costs ~130k triangles of which only the
## visible fraction is drawn.

const TILE := 256.0
const TILES := 12
const TEXELS_PER_TILE := 32
const Y_OFFSET := -0.8

var _tiles: Dictionary = {}      # Vector2i -> Node3D
var _covered: Dictionary = {}    # Vector2i tile -> number of covered sectors


## Heavy part, run on a worker thread. Returns plain arrays per tile.
static func build_data(island: IslandMap, world: Dictionary) -> Array:
	var gen := WorldGen.from_world_data(world)
	var out: Array = []
	var res := IslandMap.RES
	var cell := WorldGen.WORLD_HALF * 2.0 / (res - 1)
	for tz in TILES:
		for tx in TILES:
			var n := TEXELS_PER_TILE + 1
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			verts.resize(n * n)
			norms.resize(n * n)
			cols.resize(n * n)
			var ox := -WorldGen.WORLD_HALF + tx * TILE
			var oz := -WorldGen.WORLD_HALF + tz * TILE
			var land := false
			for j in n:
				for i in n:
					var ti := tx * TEXELS_PER_TILE + i
					var tj := tz * TEXELS_PER_TILE + j
					var h := island.heights[tj * res + ti]
					var hl := island.heights[tj * res + maxi(ti - 1, 0)]
					var hr := island.heights[tj * res + mini(ti + 1, res - 1)]
					var hd := island.heights[maxi(tj - 1, 0) * res + ti]
					var hu := island.heights[mini(tj + 1, res - 1) * res + ti]
					verts[j * n + i] = Vector3(i * cell, h + Y_OFFSET, j * cell)
					norms[j * n + i] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
					var wx := ox + i * cell
					var wz := oz + j * cell
					cols[j * n + i] = Color(gen.forest_density(wx, wz), 0.0, gen.wet_mask(wx, wz, h), gen.desert_k(wx, wz))
					land = land or h > -2.0
			var idx := PackedInt32Array()
			for j in n - 1:
				for i in n - 1:
					var a := j * n + i
					idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
			# Impostor trees on a jittered 20 m grid
			var trees: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = WorldGen.chunk_seed(tx, tz, 77)
			if land:
				var g := 20.0
				for gz in int(TILE / g):
					for gx in int(TILE / g):
						var lx := (gx + rng.randf()) * g
						var lz := (gz + rng.randf()) * g
						var wx := ox + lx
						var wz := oz + lz
						var h := island.height_at(wx, wz)
						if h < 2.5 or h > gen.snow_line() + 20.0:
							continue
						var f := gen.forest_density(wx, wz)
						if gen.desert_k(wx, wz) > 0.5 or gen.veil_k(wx, wz) > 0.5:
							if rng.randf() > 0.03:
								continue
						elif rng.randf() > 0.04 + f * 0.9:
							continue
						var s := rng.randf_range(1.0, 1.5)
						var species := ChunkBuilder._tree_species(gen, wx, wz, h, Vector3.UP, 0.0, rng.randf())
						if species == &"":
							species = &"broadleaf"
						trees.append([species, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(lx, h - 0.4, lz))])
			out.append({"tile": Vector2i(tx, tz), "origin": Vector3(ox, 0, oz), "verts": verts, "norms": norms, "cols": cols, "idx": idx, "trees": trees, "land": land})
	return out


## Main thread: turn data into nodes.
func apply(data: Array) -> void:
	for d in data:
		var root := Node3D.new()
		root.name = "Tile_%d_%d" % [d["tile"].x, d["tile"].y]
		root.position = d["origin"]
		add_child(root)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = d["verts"]
		arrays[Mesh.ARRAY_NORMAL] = d["norms"]
		arrays[Mesh.ARRAY_COLOR] = d["cols"]
		arrays[Mesh.ARRAY_INDEX] = d["idx"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = WorldMaterials.get_mat(&"terrain")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var by_species := {}
		for t in d["trees"]:
			if not by_species.has(t[0]):
				by_species[t[0]] = []
			by_species[t[0]].append(t[1])
		for species in by_species:
			_add_trees(root, by_species[species], MeshKit.TREES[species][1], &"crystal" if species == &"crystal" else &"foliage")
		_tiles[d["tile"]] = root


func _add_trees(root: Node3D, transforms: Array, mesh_key: StringName, mat_key: StringName) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = MeshKit.get_mesh(mesh_key)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_custom_data(i, Color(randf(), 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = WorldMaterials.get_mat(mat_key)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 1300.0
	root.add_child(mmi)


static func tile_of_chunk(chunk: Vector2i) -> Vector2i:
	var per := int(TILE / ChunkBuilder.CHUNK_SIZE)
	var half := int(WorldGen.WORLD_HALF / ChunkBuilder.CHUNK_SIZE)
	return Vector2i((chunk.x + half) / per, (chunk.y + half) / per)


## Called by the streamer when a sector gains/loses detailed terrain.
func set_sector_covered(chunk: Vector2i, covered: bool) -> void:
	var t := tile_of_chunk(chunk)
	var n: int = _covered.get(t, 0) + (1 if covered else -1)
	_covered[t] = maxi(n, 0)
	var node: Node3D = _tiles.get(t)
	if node:
		var per := int(TILE / ChunkBuilder.CHUNK_SIZE)
		node.visible = _covered[t] < per * per


func tile_count() -> int:
	return _tiles.size()


func visible_count() -> int:
	var n := 0
	for t in _tiles.values():
		if (t as Node3D).visible:
			n += 1
	return n
