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

const WORLD_HALF := 1024.0
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
const RIVER := [Vector2(-395.0, 200.0), Vector2(-330.0, 380.0), Vector2(-300.0, 560.0), Vector2(-250.0, 760.0), Vector2(-230.0, 960.0)]

enum Surface { GRASS, FOREST_FLOOR, ROCK, SNOW, SAND, DIRT }

var _base := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _mask := FastNoiseLite.new()
## POI pads: Array of [Vector2 center, radius, target height or NAN for "local"]
var _pads: Array = []


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
	_pads = pads


## Builds a sampler with the POI flatten pads from world data.
static func from_world_data(world: Dictionary) -> WorldGen:
	var pads: Array = []
	for poi in world.get("pois", []):
		if poi.has("flatten"):
			var p: Array = poi["pos"]
			pads.append([Vector2(p[0], p[1]), float(poi["flatten"]), float(poi.get("pad_height", NAN))])
	return WorldGen.new(int(world.get("seed", 1337)), pads)


func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	# --- Coastline: warped radial falloff -----------------------------------
	var wx := _warp.get_noise_2d(x, z) * 140.0
	var wz := _warp.get_noise_2d(z + 500.0, x - 300.0) * 140.0
	var d := Vector2(x + wx, z + wz).length() / ISLAND_RADIUS
	var land := 1.0 - smoothstep(0.78, 1.0, d)
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
	if h < 2.5:
		return Surface.SAND
	if forest_density(x, z) > 0.55:
		return Surface.FOREST_FLOOR
	return Surface.GRASS


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
