extends SceneTree
## Dev utility: highest point within a radius (no POI pads applied).
## godot --headless -s tools/find_peak.gd -- cx,cz radius


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var c := a[0].split(",")
	var cx := c[0].to_float()
	var cz := c[1].to_float()
	var r := a[1].to_float()
	var gen := WorldGen.new(1337, [])
	var best := Vector3(0, -INF, 0)
	var z := cz - r
	while z <= cz + r:
		var x := cx - r
		while x <= cx + r:
			var h := gen.height(x, z)
			if h > best.y:
				best = Vector3(x, h, z)
			x += 3.0
		z += 3.0
	print("peak at %.0f,%.0f h=%.1f" % [best.x, best.z, best.y])
	quit()
