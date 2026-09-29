extends Node
## Authoring helper: prints terrain height, slope, region and surface for
## world coordinates, so hand-placed quest content lands on sensible ground.
## Run:  godot --headless -- --probe x,z x,z ...
##       godot --headless -- --probe-ring x,z,radius,count   (spots around)


func _ready() -> void:
	var gen := WorldGen.from_world_data(DB.world)
	var args := OS.get_cmdline_user_args()
	var mi := args.find("--probe-map")
	if mi >= 0:
		_map(gen, String(args[mi + 1]), float(args[mi + 2]) if args.size() > mi + 2 else 4.0, args.slice(mi + 3))
		get_tree().quit(0)
		return
	var ring := args.find("--probe-ring")
	if ring >= 0:
		for a in args.slice(ring + 1):
			var v := String(a).split(",")
			if v.size() < 4:
				continue
			var cx := float(v[0])
			var cz := float(v[1])
			var r := float(v[2])
			var n := int(v[3])
			for i in n:
				var ang := TAU * i / n
				_line(gen, cx + cos(ang) * r, cz + sin(ang) * r)
	else:
		for a in args.slice(args.find("--probe") + 1):
			var v := String(a).split(",")
			if v.size() >= 2:
				_line(gen, float(v[0]), float(v[1]))
	get_tree().quit(0)


func _line(gen: WorldGen, x: float, z: float) -> void:
	var h := gen.height(x, z)
	var n := gen.normal(x, z)
	print("PROBE %.0f,%.0f h=%.1f slope=%.2f region=%s surface=%d" % [x, z, h, n.y, gen.region_at(x, z), gen.surface_at(x, z, h, n)])


const REGION_TINT := {
	&"valley": Color(0.55, 0.75, 0.4), &"forest": Color(0.25, 0.5, 0.25), &"highlands": Color(0.6, 0.6, 0.62),
	&"lakeshore": Color(0.45, 0.7, 0.65), &"coast": Color(0.85, 0.8, 0.55), &"desert": Color(0.9, 0.72, 0.4),
	&"veil": Color(0.55, 0.4, 0.7),
}


## Overview map: region tint shaded by height, water blue, grid every 100 m
## (bright every 500 m, origin cross), POIs as red dots, extra marks as
## "x,z" args in yellow. Window: optional "x0,z0,x1,z1" as first extra arg.
func _map(gen: WorldGen, path: String, step: float, extra: Array) -> void:
	var x0 := -1100.0
	var z0 := -1300.0
	var x1 := 1700.0
	var z1 := 1100.0
	var marks: Array = []
	for a in extra:
		var v := String(a).split(",")
		if v.size() == 4:
			x0 = float(v[0]); z0 = float(v[1]); x1 = float(v[2]); z1 = float(v[3])
		elif v.size() == 2:
			marks.append(Vector2(float(v[0]), float(v[1])))
	var w := int((x1 - x0) / step)
	var h := int((z1 - z0) / step)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for py in h:
		for px in w:
			var x := x0 + px * step
			var z := z0 + py * step
			var y := gen.height(x, z)
			var c: Color
			if y < WorldGen.SEA_LEVEL:
				c = Color(0.15, 0.3, 0.55).lerp(Color(0.05, 0.1, 0.3), clampf(-y / 20.0, 0.0, 1.0))
			else:
				c = REGION_TINT.get(gen.region_at(x, z), Color.GRAY)
				var shade := gen.height(x + step, z + step) - y
				c = c.darkened(clampf(shade * 0.08, -0.3, 0.4)) if shade > 0.0 else c.lightened(clampf(-shade * 0.06, 0.0, 0.3))
				c = c.lerp(Color.WHITE, clampf((y - 120.0) / 200.0, 0.0, 0.6))
			if fmod(absf(x), 500.0) < step or fmod(absf(z), 500.0) < step:
				c = c.lerp(Color.BLACK, 0.55)
			elif fmod(absf(x), 100.0) < step or fmod(absf(z), 100.0) < step:
				c = c.lerp(Color.BLACK, 0.2)
			img.set_pixel(px, py, c)
	for poi in DB.world.get("pois", []):
		_dot(img, (float(poi["pos"][0]) - x0) / step, (float(poi["pos"][1]) - z0) / step, Color(1, 0.1, 0.1), 3)
	for m: Vector2 in marks:
		_dot(img, (m.x - x0) / step, (m.y - z0) / step, Color(1, 1, 0), 2)
	img.save_png(path)
	print("MAP %s %dx%d origin %.0f,%.0f step %.1f" % [path, w, h, x0, z0, step])


func _dot(img: Image, cx: float, cy: float, c: Color, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := int(cx) + dx
			var y := int(cy) + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)
