extends SceneTree
## Dev utility: prints candidate sites for landmark architecture (broad,
## gently sloped hill shoulders with a view) and river crossing profiles.
## godot --headless -s tools/find_sites.gd


func _init() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var gen := WorldGen.from_world_data(world)
	var found: Array = []
	var x := -800.0
	while x < 800.0:
		var z := -800.0
		while z < 800.0:
			var h := gen.height(x, z)
			if h > 25.0 and h < 140.0 and gen.desert_k(x, z) < 0.1 and gen.veil_k(x, z) < 0.1:
				var flat := 0.0
				var lower := 0.0
				for k in 8:
					var a := TAU * k / 8.0
					flat = maxf(flat, absf(gen.height(x + cos(a) * 14.0, z + sin(a) * 14.0) - h))
					lower += h - gen.height(x + cos(a) * 80.0, z + sin(a) * 80.0)
				if flat < 5.0:
					found.append([lower / 8.0 - flat * 2.0, x, z, h, flat])
			z += 20.0
		x += 20.0
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var picked: Array = []
	for f in found:
		var ok := true
		for p in picked:
			if Vector2(f[1], f[2]).distance_to(Vector2(p[1], p[2])) < 160.0:
				ok = false
		for poi in world["pois"]:
			if Vector2(f[1], f[2]).distance_to(Vector2(poi["pos"][0], poi["pos"][1])) < 120.0:
				ok = false
		if ok:
			picked.append(f)
		if picked.size() >= 14:
			break
	for f in picked:
		print("site score %.0f at [%.0f,%.0f] h%.1f flat%.1f" % f)
	for zz in [300.0, 420.0, 470.0, 520.0]:
		var line := "river z=%d:" % int(zz)
		var xx := -420.0
		while xx < -220.0:
			line += " %d:%.0f" % [int(xx), gen.height(xx, zz)]
			xx += 10.0
		print(line)
	quit()
