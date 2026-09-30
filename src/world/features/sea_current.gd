class_name SeaCurrent
extends Node3D
## A strip of moving water: swimmers, divers and boats drift along it.
## Ride it out to an islet a swimmer could never reach alone; fight it on
## the way back (or pick another route). Seen as foam streaks on the water.

var length := 120.0
var width := 16.0
var strength := 3.5
var _p: CPUParticles3D


static func create(len: float, w: float, s: float) -> SeaCurrent:
	var c := SeaCurrent.new()
	c.length = len
	c.width = w
	c.strength = s
	return c


func _ready() -> void:
	add_to_group(&"currents")
	_p = CPUParticles3D.new()
	_p.amount = Quality.particle_amount(int(clampf(length * 0.25, 12.0, 40.0)))
	_p.lifetime = length / maxf(strength * 1.6, 1.0)
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.emission_box_extents = Vector3(width * 0.5, 0.05, 1.0)
	_p.direction = Vector3(0, 0, -1)
	_p.spread = 3.0
	_p.gravity = Vector3.ZERO
	_p.initial_velocity_min = strength * 1.4
	_p.initial_velocity_max = strength * 1.8
	var q := QuadMesh.new()
	q.size = Vector2(0.25, 1.6)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 1.0, 1.0, 0.55)
	m.albedo_texture = FireSource._dot()
	q.material = m
	_p.mesh = q
	_p.position = Vector3(0, 0.08, 0)
	_p.visibility_aabb = AABB(Vector3(-width, -1, -length), Vector3(width * 2, 2, length * 1.2))
	add_child(_p)


## Flow vector (m/s) at a point: the sum of every current it is inside.
static func drift_at(pos: Vector3, tree: SceneTree) -> Vector3:
	var out := Vector3.ZERO
	if pos.y > WorldGen.SEA_LEVEL + 1.5:
		return out
	for n in tree.get_nodes_in_group(&"currents"):
		var c := n as SeaCurrent
		var local := c.global_transform.affine_inverse() * pos
		# Local -z is the flow; the strip runs from z=0 to z=-length.
		if local.z < 0.0 and local.z > -c.length and absf(local.x) < c.width * 0.5:
			var edge := 1.0 - smoothstep(c.width * 0.3, c.width * 0.5, absf(local.x))
			out += -c.global_basis.z.normalized() * c.strength * edge
	out.y = 0.0
	return out
