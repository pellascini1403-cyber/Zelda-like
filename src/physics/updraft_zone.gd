class_name UpdraftZone
extends Node3D
## Permanent thermal column (cliff winds, vents). Visible as drifting motes so
## the player can read it from a distance and plan a glide.

var radius := 6.0
var height := 60.0
var strength := 11.0


func _ready() -> void:
	add_to_group(&"updraft")
	var p := CPUParticles3D.new()
	p.amount = Quality.particle_amount(40)
	p.lifetime = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = height / 5.0
	p.initial_velocity_max = height / 4.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.98, 1.0, 0.35)
	quad.material = m
	p.mesh = quad
	p.visibility_aabb = AABB(Vector3(-radius, 0, -radius), Vector3(radius * 2, height, radius * 2))
	add_child(p)


func lift_at(pos: Vector3) -> float:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	var h := pos.y - global_position.y
	if d > radius or h < -2.0 or h > height:
		return 0.0
	return strength * (1.0 - d / radius * 0.5) * (1.0 - smoothstep(height * 0.7, height, h))
