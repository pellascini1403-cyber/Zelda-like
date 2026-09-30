class_name Whirlpool
extends Node3D
## A small maelstrom where two tidal currents meet: it spins swimmers and
## boats around and draws them in, hardest on the flood and ebb, nearly
## still at slack water. Whatever the sea loses ends up on the bed below
## its eye — a diver who lets it take them finds it.

var radius := 18.0
var strength := 3.0
var _ring: MeshInstance3D
var _funnel: MeshInstance3D
var _foam: CPUParticles3D


static func create(r: float, s: float) -> Whirlpool:
	var w := Whirlpool.new()
	w.radius = r
	w.strength = s
	return w


func power() -> float:
	return strength * lerpf(0.25, 1.3, Tide.flow())


## Swirl + inward pull at a point (xz only).
func drift_at(pos: Vector3) -> Vector3:
	var d := Vector3(pos.x - global_position.x, 0, pos.z - global_position.z)
	var dist := d.length()
	if dist > radius or dist < 0.01:
		return Vector3.ZERO
	var k := 1.0 - dist / radius
	var inward := -d / dist
	var swirl := Vector3(-inward.z, 0, inward.x)
	return (swirl * (0.8 + k) + inward * 0.6 * k) * power()


func _ready() -> void:
	add_to_group(&"whirlpools")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.97, 1.0, 0.45)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MeshInstance3D.new()
	_ring.mesh = ShapeKit.torus(radius * 0.45, radius * 0.55)
	_ring.material_override = m
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visibility_range_end = 500.0
	add_child(_ring)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.1, 0.25, 0.32, 0.55)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_funnel = MeshInstance3D.new()
	_funnel.mesh = ShapeKit.cone(radius * 0.35, 2.5, 12)
	_funnel.rotation.x = PI
	_funnel.position.y = -1.2
	_funnel.material_override = fm
	_funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_funnel.visibility_range_end = 300.0
	add_child(_funnel)
	_foam = CPUParticles3D.new()
	_foam.amount = Quality.particle_amount(28)
	_foam.lifetime = 3.0
	_foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_foam.emission_ring_axis = Vector3.UP
	_foam.emission_ring_radius = radius * 0.7
	_foam.emission_ring_inner_radius = radius * 0.3
	_foam.emission_ring_height = 0.1
	_foam.gravity = Vector3.ZERO
	_foam.orbit_velocity_min = 0.25
	_foam.orbit_velocity_max = 0.4
	_foam.radial_accel_min = -1.5
	_foam.radial_accel_max = -0.5
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_texture = FireSource._dot()
	pm.albedo_color = Color(1, 1, 1, 0.6)
	q.material = pm
	_foam.mesh = q
	_foam.position.y = 0.1
	_foam.visibility_aabb = AABB(Vector3(-radius, -1, -radius), Vector3(radius * 2, 2, radius * 2))
	add_child(_foam)


func _process(delta: float) -> void:
	var p := power() / maxf(strength, 0.01)
	_ring.rotation.y += delta * 0.9 * p
	_funnel.rotation.y -= delta * 1.6 * p
	_funnel.scale = Vector3(1.0, clampf(p, 0.2, 1.3), 1.0)
	_foam.speed_scale = clampf(p, 0.25, 1.4)
