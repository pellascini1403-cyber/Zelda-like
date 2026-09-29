class_name Cue
extends RefCounted
## Distant visual cues that pull the eye without a map icon: a smoke column
## over a camp, a pale mist plume over a hidden pool, a light pillar over
## something strange. Cheap (one particle system or one mesh each).


static func make(kind: String) -> Node3D:
	var big := kind == "beacon"
	if big:
		kind = "pillar"
	var root := Node3D.new()
	root.name = "Cue_" + kind
	match kind:
		"pillar":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.9 if big else 0.3
			cyl.bottom_radius = 2.4 if big else 1.2
			cyl.height = 160.0 if big else 80.0
			cyl.cap_top = false
			cyl.cap_bottom = false
			cyl.radial_segments = 8
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/shaders/wind_seal.gdshader")
			var mi := MeshInstance3D.new()
			mi.mesh = cyl
			mi.material_override = mat
			mi.position.y = cyl.height * 0.5
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 1400.0
			root.add_child(mi)
		_:
			var p := CPUParticles3D.new()
			p.amount = Quality.particle_amount(22)
			p.lifetime = 9.0
			p.preprocess = 9.0
			p.direction = Vector3.UP
			p.spread = 6.0
			p.initial_velocity_min = 2.5
			p.initial_velocity_max = 3.5
			p.gravity = Vector3(0.6, 0.4, 0.2)
			p.scale_amount_min = 5.0
			p.scale_amount_max = 9.0
			p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 70, 40))
			var quad := QuadMesh.new()
			quad.size = Vector2(1.6, 1.6)
			var m := StandardMaterial3D.new()
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.vertex_color_use_as_albedo = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			quad.material = m
			p.mesh = quad
			var g := Gradient.new()
			var tone := Color(0.22, 0.2, 0.2) if kind == "smoke" else Color(0.85, 0.85, 0.8)
			g.set_color(0, Color(tone, 0.0))
			g.add_point(0.15, Color(tone, 0.62))
			g.set_color(g.get_point_count() - 1, Color(tone.lightened(0.3), 0.0))
			p.color_ramp = g
			root.add_child(p)
	return root
