class_name Waterfall
extends Node3D
## A cliff waterfall from data/world.json "falls": a ribbon mesh that hugs
## the rock face from the lip to its pool, the pool surface, foam splash and
## rising spray, and a looping 3D sound (only audible nearby).

var def: Dictionary
var _gen: WorldGen
var _splash: GPUParticles3D
var _sound: AudioStreamPlayer3D


static func create(d: Dictionary, gen: WorldGen) -> Waterfall:
	var w := Waterfall.new()
	w.def = d
	w._gen = gen
	return w


func _ready() -> void:
	var top := Vector2(def["top"][0], def["top"][1])
	var bottom := Vector2(def["bottom"][0], def["bottom"][1])
	var width: float = def.get("width", 6.0)
	var pool_y: float = def.get("pool_y", 0.0)
	var dir := (bottom - top).normalized()
	var side := Vector2(-dir.y, dir.x) * width * 0.5
	# Ribbon: sample the slope from lip to pool, lifted off the rock.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	var rows: Array = []
	for i in steps + 1:
		var t := float(i) / steps
		var p := top.lerp(bottom, t)
		var h := _gen.height(p.x, p.y) + 0.7
		if i == steps:
			h = pool_y + 0.05
		var spread := 1.0 + t * 0.35
		rows.append([Vector3(p.x - side.x * spread, h, p.y - side.y * spread), Vector3(p.x + side.x * spread, h, p.y + side.y * spread), t])
	for i in steps:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		_quad(st, a[0], a[1], b[1], b[0], a[2], b[2])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/waterfall.gdshader")
	m.set_shader_parameter("noise_tex", WorldMaterials.noise_texture())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 1400.0
	add_child(mi)

	# Pool surface (sea-level falls pour straight into the river instead).
	var foot := Vector3(bottom.x, pool_y, bottom.y)
	if pool_y > 0.5:
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		var r: float = def.get("pool_radius", 9.0)
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.05
		disc.radial_segments = 24
		disc.rings = 1
		pool.mesh = disc
		pool.material_override = WorldMaterials.get_mat(&"water")
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.position = foot
		pool.visibility_range_end = 900.0
		add_child(pool)

	_splash = GPUParticles3D.new()
	_splash.amount = Quality.particle_amount(60)
	_splash.lifetime = 2.2
	_splash.position = foot + Vector3(0, 0.3, 0)
	_splash.visibility_aabb = AABB(Vector3(-12, -2, -12), Vector3(24, 16, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.5, 0.2, 1.5)
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -0.6, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.2, Color(1, 1, 1, 0.45))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	_splash.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	_splash.draw_pass_1 = q
	_splash.visibility_range_end = 160.0
	add_child(_splash)

	_sound = AudioStreamPlayer3D.new()
	_sound.stream = load("res://assets/audio/amb_waterfall.wav") if ResourceLoader.exists("res://assets/audio/amb_waterfall.wav") else null
	_sound.bus = &"Ambience"
	_sound.unit_size = 14.0
	_sound.max_distance = 110.0
	_sound.position = foot + Vector3(0, 4, 0)
	add_child(_sound)


func _process(_delta: float) -> void:
	# Only simulate/play when close (distance-based cost).
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var near := cam.global_position.distance_to(_splash.global_position) < 150.0
	_splash.emitting = near
	if _sound.stream:
		if near and not _sound.playing:
			_sound.play()
		elif not near and _sound.playing:
			_sound.stop()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ta: float, tb: float) -> void:
	for v in [[a, Vector2(0, ta)], [b, Vector2(1, ta)], [c, Vector2(1, tb)], [a, Vector2(0, ta)], [c, Vector2(1, tb)], [d, Vector2(0, tb)]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])
