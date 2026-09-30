extends Node
## Art review: renders creatures on a neutral stand, one 3/4 portrait each
## plus a line-up per family. Run: godot -- --bestiary <dir> [ID ID ...]
## (no ids = every enemy and animal).

var _out := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--bestiary")
	_out = args[i + 1] if i >= 0 and args.size() > i + 1 else "user://bestiary"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred(args.slice(i + 2) if i >= 0 else [])


func _run(ids: Array) -> void:
	var root := Node3D.new()
	get_tree().root.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.8, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.66)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.66, 0.55)
	ground.material_override = gm
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 36.0
	root.add_child(cam)
	if ids.is_empty():
		for id in DB.entities:
			var t: EntityType = DB.entities[id]
			if t.kind in [EntityType.Kind.ENEMY, EntityType.Kind.ANIMAL]:
				ids.append(String(id))
	var line: Array[EntityVisual] = []
	for id in ids:
		var t := DB.entity(StringName(id))
		if t == null:
			continue
		var vis := EntityVisual.new()
		root.add_child(vis)
		vis.setup(t)
		vis.rotation.y = deg_to_rad(-140.0)
		var h := maxf(t.collider_height, t.collider_radius * 2.0) * float(t.visual.get("scale", 1.0))
		var lift := float(t.ai_value("hover", 0.0)) * 0.0
		vis.position.y = lift
		cam.position = Vector3(0, h * 0.75 + 0.6, h * 2.4 + 2.2)
		cam.look_at(Vector3(0, h * 0.45, 0))
		for k in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("%s.png" % id))
		line.append(vis)
		vis.visible = false
	# Line-up: everyone at once, to compare silhouettes and sizes.
	var x := -float(line.size() - 1) * 1.6
	for v in line:
		v.visible = true
		v.position = Vector3(x, 0, 0)
		v.rotation.y = deg_to_rad(-150.0)
		x += 3.2
	cam.fov = 50.0
	cam.position = Vector3(0, 4.0, maxf(line.size() * 2.3, 8.0))
	cam.look_at(Vector3(0, 0.9, 0))
	for k in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("lineup.png"))
	print("bestiary done: ", _out)
	get_tree().quit()
