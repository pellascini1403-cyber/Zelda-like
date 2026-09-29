extends SceneTree
## Dev utility: finds cliff edges suitable for waterfalls (big drop over a
## short horizontal distance). Prints JSON-ready candidates.
## godot --headless -s tools/find_falls.gd


func _init() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var gen := WorldGen.from_world_data(world)
	var found: Array = []
	var x := -900.0
	while x < 900.0:
		var z := -900.0
		while z < 900.0:
			var h := gen.height(x, z)
			if h > 20.0 and h < 170.0 and gen.desert_k(x, z) < 0.2 and gen.veil_k(x, z) < 0.2:
				for k in 8:
					var a := TAU * k / 8.0
					var d := Vector2(cos(a), sin(a))
					var h2 := gen.height(x + d.x * 10.0, z + d.y * 10.0)
					var h3 := gen.height(x + d.x * 22.0, z + d.y * 22.0)
					var drop := h - h3
					if drop > 16.0 and h - h2 > 9.0 and absf(h3 - gen.height(x + d.x * 30.0, z + d.y * 30.0)) < 3.0:
						found.append([drop, x, z, x + d.x * 24.0, z + d.y * 24.0, h, h3])
			z += 16.0
		x += 16.0
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var picked: Array = []
	for f in found:
		var ok := true
		for p in picked:
			if Vector2(f[1], f[2]).distance_to(Vector2(p[1], p[2])) < 140.0:
				ok = false
		if ok:
			picked.append(f)
		if picked.size() >= 12:
			break
	for f in picked:
		print("drop %.0f top [%.0f,%.0f] h%.0f -> bottom [%.0f,%.0f] h%.0f" % [f[0], f[1], f[2], f[5], f[3], f[4], f[6]])
	quit()
