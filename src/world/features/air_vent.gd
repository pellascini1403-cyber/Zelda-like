class_name AirVent
extends Node3D
## A column of bubbles from the lake bed (an air pocket in a sunken
## ruin): diving into it refills your breath. Placed where a dive needs a
## second wind.

const RADIUS := 1.6
const REFILL := 35.0

var _p: CPUParticles3D


func _ready() -> void:
	add_to_group(&"air_vents")
	_p = CPUParticles3D.new()
	_p.amount = Quality.particle_amount(24)
	_p.lifetime = 2.2
	_p.direction = Vector3.UP
	_p.spread = 6.0
	_p.gravity = Vector3(0, 1.5, 0)
	_p.initial_velocity_min = 1.0
	_p.initial_velocity_max = 2.2
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_p.emission_sphere_radius = 0.5
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FireSource._dot()
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.8)
	q.material = m
	_p.mesh = q
	add_child(_p)


static func refill_at(pos: Vector3, tree: SceneTree) -> bool:
	for v in tree.get_nodes_in_group(&"air_vents"):
		var vp := (v as Node3D).global_position
		if Vector2(pos.x - vp.x, pos.z - vp.z).length() < RADIUS and pos.y > vp.y - 1.0:
			return true
	return false
