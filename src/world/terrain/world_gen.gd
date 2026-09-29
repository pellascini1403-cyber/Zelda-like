class_name WorldGen
extends RefCounted
## Deterministic terrain + biome sampler for the island.
##
## Pure function of (x, z): the same query always returns the same answer, on
## any thread. Each worker thread must create its own instance (noise objects
## are not shared). Hand-authored features (mountain, lake, river, flattened
## POI pads) are layered on top of noise so the geography is *designed*, not
## random: every silhouette on the horizon is there on purpose.
##
## Coordinates: meters, origin at island center, -Z is north. Sea level = 0.

const WORLD_HALF := 1536.0
const ISLAND_RADIUS := 900.0
const SEA_LEVEL := 0.0

# Designed landmarks (kept in sync with data/world.json)
const MOUNTAIN_CENTER := Vector2(-60.0, -560.0)
const MOUNTAIN_RADIUS := 360.0
const MOUNTAIN_HEIGHT := 235.0
const LAKE_CENTER := Vector2(-400.0, 70.0)
const LAKE_RADIUS := 150.0
const FOREST_CENTER := Vector2(470.0, 230.0)
const FOREST_RADIUS := 300.0
const PLATEAU_CENTER := Vector2(390.0, -230.0)
# Eastern desert landmass and the north-eastern Veil Reaches (supernatural).
const DESERT_CENTER := Vector2(1170.0, 250.0)
const DESERT_RADIUS := Vector2(470.0, 400.0)
const OASIS_CENTER := Vector2(1080.0, 340.0)
const VEIL_CENTER := Vector2(880.0, -880.0)
const VEIL_RADIUS := 330.0
const RIVER := [Vector2(-395.0, 200.0), Vector2(-330.0, 380.0), Vector2(-300.0, 560.0), Vector2(-250.0, 760.0), Vector2(-230.0, 960.0)]

enum Surface { GRASS, FOREST_FLOOR, ROCK, SNOW, SAND, DIRT }

var _base := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _mask := FastNoiseLite.new()
var _dune := FastNoiseLite.new()
## POI pads: Array of [Vector2 center, radius, target height or NAN for "local"]
var _pads: Array = []
## Waterfall pools carved into the terrain: [Vector2 center, radius, bottom]
var _pools: Array = []
## Trails between places: Array of PackedVector2Array polylines
var _paths: Array = []


func _init(seed_value: int = 1337, pads: Array = []) -> void:
	_base.seed = seed_value
	_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base.frequency = 1.0 / 420.0
	_base.fractal_type = FastNoiseLite.FRACTAL_FBM
	_base.fractal_octaves = 4

	_detail.seed = seed_value + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 1.0 / 38.0
	_detail.fractal_octaves = 2

	_ridge.seed = seed_value + 2
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge.frequency = 1.0 / 140.0
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4

	_warp.seed = seed_value + 3
	_warp.frequency = 1.0 / 260.0

	_mask.seed = seed_value + 4
	_mask.frequency = 1.0 / 180.0
	_dune.seed = seed_value + 5
	_dune.frequency = 1.0 / 90.0
	_pads = pads


## Builds a sampler with the POI flatten pads from world data.
static func from_world_data(world: Dictionary) -> WorldGen:
	var pads: Array = []
	for poi in world.get("pois", []):
		if poi.has("flatten"):
			var p: Array = poi["pos"]
			pads.append([Vector2(p[0], p[1]), float(poi["flatten"]), float(poi.get("pad_height", NAN))])
	var g := WorldGen.new(int(world.get("seed", 1337)), pads)
	for f in world.get("falls", []):
		var b: Array = f["bottom"]
		g._pools.append([Vector2(b[0], b[1]), float(f.get("pool_radius", 9.0)), float(f["pool_y"]) - 1.6])
	var poi_pos := {}
	for poi in world.get("pois", []):
		poi_pos[poi["id"]] = Vector2(poi["pos"][0], poi["pos"][1])
	for path in world.get("paths", []):
		var line := PackedVector2Array()
		for node in path:
			line.append(poi_pos[node] if node is String else Vector2(node[0], node[1]))
		g._paths.append(line)
	return g


func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	# --- Coastline: warped radial falloff -----------------------------------
	var wx := _warp.get_noise_2d(x, z) * 140.0
	var wz := _warp.get_noise_2d(z + 500.0, x - 300.0) * 140.0
	var d := Vector2(x + wx, z + wz).length() / ISLAND_RADIUS
	var land := 1.0 - smoothstep(0.78, 1.0, d)
	var dk := desert_k(x + wx * 0.5, z + wz * 0.5)
	var vk := veil_k(x + wx * 0.5, z + wz * 0.5)
	land = maxf(land, maxf(dk, vk))
	var h := lerpf(-22.0, 5.0, land)

	# --- Rolling hills with terraced rock bands (climbable cliffs) -----------
	var hills := (_base.get_noise_2d(x, z) * 0.5 + 0.5) * 34.0
	var band_mask := smoothstep(0.15, 0.45, _mask.get_noise_2d(x, z))
	hills = lerpf(hills, _terrace(hills, 9.0, 0.18), band_mask)
	h += hills * land
	h += _detail.get_noise_2d(x, z) * 1.6 * land

	# --- Mountain: designed massif with ridges, a shoulder peak, steep faces ---
	# Domain warp breaks the cone into spurs and gullies.
	var mp := p + Vector2(_warp.get_noise_2d(x * 1.7, z * 1.7), _warp.get_noise_2d(z * 1.7 + 77.0, x * 1.7 - 31.0)) * 95.0
	var md := mp.distance_to(MOUNTAIN_CENTER) / MOUNTAIN_RADIUS
	if md < 1.0:
		var m := pow(1.0 - md, 1.6)
		var ridges := _ridge.get_noise_2d(x, z) * 0.5 + 0.5
		var mh := MOUNTAIN_HEIGHT * m + ridges * 80.0 * m * (1.0 - m * 0.45)
		# Shoulder peak to the east gives the massif an asymmetric silhouette.
		var sd := mp.distance_to(MOUNTAIN_CENTER + Vector2(165.0, 85.0)) / 150.0
		if sd < 1.0:
			mh = maxf(mh, 150.0 * pow(1.0 - sd, 1.5) + ridges * 30.0 * (1.0 - sd))
		mh = lerpf(mh, _terrace(mh, 22.0, 0.25), 0.55 * smoothstep(0.1, 0.6, m))
		h += mh

	# --- Desert: dune fields, sandstone mesas, an oasis ------------------------
	if dk > 0.0:
		var u := x * 0.8 + z * 0.35 + _dune.get_noise_2d(x, z) * 60.0
		var dune := pow(absf(sin(u * 0.045)), 1.6) * 7.0 + _dune.get_noise_2d(x * 2.0, z * 2.0) * 3.0
		var mesa_n := _mask.get_noise_2d(x * 0.8 + 3000.0, z * 0.8)
		var mesa := smoothstep(0.32, 0.4, mesa_n) * 34.0
		mesa = lerpf(mesa, _terrace(mesa + 0.01, 11.0, 0.12), 0.7)
		var desert_h := 9.0 + dune + mesa
		var od := p.distance_to(OASIS_CENTER) / 55.0
		if od < 1.8:
			desert_h = lerpf(desert_h, -2.5, smoothstep(1.8, 0.7, od))
		h = lerpf(h, desert_h, smoothstep(0.0, 0.55, dk))

	# --- Veil Reaches: a crater rim around a still, glowing lake ----------------
	if vk > 0.0:
		var vd := p.distance_to(VEIL_CENTER) / VEIL_RADIUS
		var rim := exp(-pow((vd - 0.62) / 0.14, 2.0)) * (62.0 + _ridge.get_noise_2d(x, z) * 30.0)
		var basin := smoothstep(0.55, 0.2, vd) * -16.0
		var spikes := pow(maxf(_ridge.get_noise_2d(x * 2.5, z * 2.5), 0.0), 3.0) * 40.0 * smoothstep(0.9, 0.6, vd)
		var veil_h := 6.0 + rim + basin + spikes
		h = lerpf(h, veil_h, smoothstep(0.0, 0.6, vk))

	# --- Needle plateau: raised table land ------------------------------------
	var pd := p.distance_to(PLATEAU_CENTER) / 230.0
	if pd < 1.0:
		h += 26.0 * smoothstep(1.0, 0.55, pd)

	# --- Lake basin -------------------------------------------------------------
	var ld := p.distance_to(LAKE_CENTER) / LAKE_RADIUS
	if ld < 1.6:
		var bowl := smoothstep(1.6, 0.55, ld)
		h = lerpf(h, -9.0, bowl)

	# --- River channel ------------------------------------------------------------
	var rd := _distance_to_river(p)
	if rd < 40.0:
		var carve := smoothstep(40.0, 7.0, rd)
		h = lerpf(h, minf(h, -3.5), carve)

	# --- POI pads (village, ruins, camps) --------------------------------------
	for pad in _pads:
		var dd: float = p.distance_to(pad[0])
		var r: float = pad[1]
		if dd < r * 1.8:
			var target: float = pad[2]
			if is_nan(target):
				continue
			var k := smoothstep(r * 1.8, r, dd)
			h = lerpf(h, target, k)

	# --- Waterfall pools (after pads: a pad never fills a pool) -----------------
	for pool in _pools:
		var pdist: float = p.distance_to(pool[0])
		if pdist < pool[1] * 1.6:
			h = lerpf(h, minf(h, pool[2]), smoothstep(pool[1] * 1.6, pool[1] * 0.6, pdist))
	return h


func normal(x: float, z: float, e: float = 1.0) -> Vector3:
	var hl := height(x - e, z)
	var hr := height(x + e, z)
	var hd := height(x, z - e)
	var hu := height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


## 0..1 forest density (drives trees, undergrowth and the forest biome).
func forest_density(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var core := 1.0 - smoothstep(0.35, 1.0, p.distance_to(FOREST_CENTER) / FOREST_RADIUS)
	var patches := smoothstep(0.25, 0.6, _mask.get_noise_2d(x + 900.0, z - 400.0)) * 0.55
	return clampf(maxf(core, patches), 0.0, 1.0)


func region_at(x: float, z: float) -> StringName:
	if veil_k(x, z) > 0.45:
		return &"veil"
	if desert_k(x, z) > 0.45:
		return &"desert"
	var h := height(x, z)
	var p := Vector2(x, z)
	if h > 85.0 or p.distance_to(MOUNTAIN_CENTER) < MOUNTAIN_RADIUS * 0.8:
		return &"highlands"
	if p.distance_to(LAKE_CENTER) < LAKE_RADIUS * 1.9 or _distance_to_river(p) < 60.0:
		return &"lakeshore"
	if forest_density(x, z) > 0.55:
		return &"forest"
	if h < 6.0 or p.length() > ISLAND_RADIUS * 0.82:
		return &"coast"
	return &"valley"


func surface_at(x: float, z: float, h: float, n: Vector3) -> Surface:
	if n.y < 0.72:
		return Surface.ROCK
	if h > snow_line() + _detail.get_noise_2d(x, z) * 10.0:
		return Surface.SNOW
	if h < 2.5 or desert_k(x, z) > 0.5:
		return Surface.SAND
	if forest_density(x, z) > 0.55:
		return Surface.FOREST_FLOOR
	return Surface.GRASS


## 0..1 influence of the eastern desert landmass.
func desert_k(x: float, z: float) -> float:
	var q := (Vector2(x, z) - DESERT_CENTER) / DESERT_RADIUS
	return 1.0 - smoothstep(0.65, 1.0, q.length())


## 0..1 influence of the Veil Reaches.
func veil_k(x: float, z: float) -> float:
	return 1.0 - smoothstep(0.7, 1.0, Vector2(x, z).distance_to(VEIL_CENTER) / VEIL_RADIUS)


## Patches where special groves grow (blossom orchards, bamboo stands).
func grove_mask(x: float, z: float) -> float:
	return smoothstep(0.2, 0.45, _dune.get_noise_2d(x * 0.9 + 777.0, z * 0.9 - 333.0))


## 1 on a trail, fading to 0 at its edge (vertex colour mask; no height change).
func path_mask(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for line: PackedVector2Array in _paths:
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	if best > 12.0:
		return 0.0
	best += _detail.get_noise_2d(x * 0.7, z * 0.7) * 1.4
	return 1.0 - smoothstep(0.9, 2.6, best)


## 0..1 dampness near lakes, rivers, pools and shores.
func wet_mask(x: float, z: float, h: float) -> float:
	var p := Vector2(x, z)
	var w := 1.0 - smoothstep(0.0, 22.0, _distance_to_river(p) - 8.0)
	w = maxf(w, 1.0 - smoothstep(LAKE_RADIUS * 1.05, LAKE_RADIUS * 1.45, p.distance_to(LAKE_CENTER)))
	w = maxf(w, 1.0 - smoothstep(60.0, 100.0, p.distance_to(OASIS_CENTER)))
	for pool in _pools:
		w = maxf(w, 1.0 - smoothstep(pool[1], pool[1] * 3.0, p.distance_to(pool[0])))
	w = maxf(w, 1.0 - smoothstep(1.5, 4.0, h))
	return clampf(w, 0.0, 1.0)


func snow_line() -> float:
	return 150.0


func is_climbable_slope(n: Vector3) -> bool:
	return n.y < 0.6


func _terrace(h: float, step: float, softness: float) -> float:
	var t := h / step
	var f := t - floorf(t)
	var s := smoothstep(0.5 - softness, 0.5 + softness, f)
	return (floorf(t) + s) * step


func _distance_to_river(p: Vector2) -> float:
	var best := INF
	for i in RIVER.size() - 1:
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	# Meander
	return best + _detail.get_noise_2d(p.x * 0.3, p.y * 0.3) * 6.0


## Stable hash for deterministic per-chunk placement.
static func chunk_seed(cx: int, cz: int, salt: int = 0) -> int:
	return hash(Vector3i(cx, cz, salt))
