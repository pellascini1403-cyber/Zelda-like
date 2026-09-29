extends SceneTree
## Dev utility: prints terrain heights at candidate positions (no pads).
## godot --headless -s tools/print_heights.gd -- x,z x,z ...


func _init() -> void:
	var gen := WorldGen.new(1337, [])
	for arg in OS.get_cmdline_user_args():
		var p := arg.split(",")
		var x := p[0].to_float()
		var z := p[1].to_float()
		print("%s -> h=%.1f region=%s n.y=%.2f" % [arg, gen.height(x, z), gen.region_at(x, z), gen.normal(x, z, 2.0).y])
	quit()
