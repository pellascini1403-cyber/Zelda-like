extends Node
## Art review: renders every vehicle (and the three together) from fixed
## angles on a neutral stand. Run: godot -- --studio <dir> [--water]

var _out := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--studio")
	_out = args[i + 1] if i >= 0 and args.size() > i + 1 else "user://studio"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var root := Node3D.new()
	get_tree().root.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.8, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.66)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.66, 0.55)
	ground.material_override = gm
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	var water := "--water" in OS.get_cmdline_user_args()
	var ids: Array = DB.vehicles.keys()
	for id in ids:
		var vis := VehicleVisual.new()
		root.add_child(vis)
		vis.setup(DB.vehicles[id])
		if water:
			vis.set_water_blend(1.0)
		for ang in [[0, "side"], [40, "front34"], [150, "rear34"], [90, "front"]]:
			vis.rotation.y = deg_to_rad(float(ang[0]) + 90.0)
			var len := float(DB.vehicles[id].get("collider", {}).get("length", 2.0))
			var dist := 3.2 + len * 1.3
			cam.position = Vector3(0, 1.6, dist)
			cam.look_at(Vector3(0, 0.75, 0))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [id, ang[1]]))
		vis.queue_free()
		await get_tree().process_frame
	# Family shot: all three side by side.
	var x := -3.4
	for id in ids:
		var vis := VehicleVisual.new()
		root.add_child(vis)
		vis.setup(DB.vehicles[id])
		vis.position = Vector3(x, 0, 0)
		vis.rotation.y = deg_to_rad(125.0)
		x += 3.4
	cam.position = Vector3(0, 2.4, 9.5)
	cam.look_at(Vector3(0, 0.8, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("family.png"))
	print("studio done: ", _out)
	get_tree().quit()
