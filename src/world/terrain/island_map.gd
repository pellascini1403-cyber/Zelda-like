class_name IslandMap
extends RefCounted
## Low resolution height field of the whole island (8 m per texel).
##
## Built once on a worker thread and cached in user:// (it is deterministic),
## then shared by: HorizonTiles (far LOD tier), the water shader
## (shoreline / depth tint) and the map screen.

const RES := 385
const HEIGHT_OFFSET := -40.0
const HEIGHT_SCALE := 340.0
const CACHE_VERSION := 5

var heights := PackedFloat32Array()
var texture: ImageTexture
var map_image: Image


static func cache_path(seed_value: int) -> String:
	return "user://cache/island_%d_v%d.bin" % [seed_value, CACHE_VERSION]


## Heavy: call from a worker thread.
func build(world: Dictionary) -> void:
	_build_heights(world)
	map_image = _paint_map(WorldGen.from_world_data(world))


func _build_heights(world: Dictionary) -> void:
	var seed_value := int(world.get("seed", 1337))
	var path := cache_path(seed_value)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f and f.get_length() == RES * RES * 4:
			heights = f.get_buffer(RES * RES * 4).to_float32_array()
			return
	var gen := WorldGen.from_world_data(world)
	heights.resize(RES * RES)
	var span := WorldGen.WORLD_HALF * 2.0
	for j in RES:
		for i in RES:
			var x := -WorldGen.WORLD_HALF + span * i / (RES - 1)
			var z := -WorldGen.WORLD_HALF + span * j / (RES - 1)
			heights[j * RES + i] = gen.height(x, z)
	DirAccess.make_dir_recursive_absolute("user://cache")
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out:
		out.store_buffer(heights.to_byte_array())


## Main thread: create the GPU height texture.
func finalize() -> void:
	var img := Image.create(RES, RES, false, Image.FORMAT_RH)
	for j in RES:
		for i in RES:
			var v := (heights[j * RES + i] - HEIGHT_OFFSET) / HEIGHT_SCALE
			img.set_pixel(i, j, Color(clampf(v, 0.0, 1.0), 0, 0))
	texture = ImageTexture.create_from_image(img)


func height_at(x: float, z: float) -> float:
	var fx := clampf((x + WorldGen.WORLD_HALF) / (WorldGen.WORLD_HALF * 2.0) * (RES - 1), 0.0, RES - 1.001)
	var fz := clampf((z + WorldGen.WORLD_HALF) / (WorldGen.WORLD_HALF * 2.0) * (RES - 1), 0.0, RES - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := heights[iz * RES + ix]
	var b := heights[iz * RES + ix + 1]
	var c := heights[(iz + 1) * RES + ix]
	var d := heights[(iz + 1) * RES + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


## Painted parchment-style map used by the map screen.
func _paint_map(gen: WorldGen) -> Image:
	var size := RES - 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var sea_deep := Color(0.16, 0.3, 0.42)
	var sea := Color(0.3, 0.5, 0.58)
	var sand := Color(0.86, 0.8, 0.62)
	var grass := Color(0.52, 0.62, 0.38)
	var forest := Color(0.3, 0.44, 0.28)
	var rock := Color(0.58, 0.54, 0.48)
	var snow := Color(0.94, 0.94, 0.92)
	var span := WorldGen.WORLD_HALF * 2.0
	for j in size:
		for i in size:
			var h := heights[j * RES + i]
			var x := -WorldGen.WORLD_HALF + span * i / (RES - 1)
			var z := -WorldGen.WORLD_HALF + span * j / (RES - 1)
			var c: Color
			if h < 0.0:
				c = sea.lerp(sea_deep, clampf(-h / 18.0, 0.0, 1.0))
			elif h < 2.5:
				c = sand
			else:
				var slope := absf(h - heights[j * RES + i + 1]) + absf(h - heights[(j + 1) * RES + i])
				c = grass.lerp(forest, gen.forest_density(x, z))
				c = c.lerp(rock, clampf((slope - 3.0) / 6.0, 0.0, 1.0))
				c = c.lerp(rock, smoothstep(90.0, 140.0, h))
				c = c.lerp(snow, smoothstep(150.0, 175.0, h))
				# Contour lines every 20 m
				if fmod(h, 20.0) < 1.4:
					c = c.darkened(0.18)
				# Hill shading
				var shade := clampf((heights[j * RES + maxi(i - 1, 0)] - h) * 0.08, -0.25, 0.25)
				c = c.lightened(shade) if shade > 0.0 else c.darkened(-shade)
			img.set_pixel(i, j, c)
	return img
