class_name SeaCurrent
extends Node3D
## A strip of moving water: swimmers, divers and boats drift along it.
## Ride it out to an islet a swimmer could never reach alone; fight it on
## the way back (or pick another route). Seen as foam streaks on the water.

var length := 120.0
var width := 16.0
var strength := 3.5
## Tidal currents run hard on the flood and the ebb and go slack at high
## and low water (Tide.flow): the same strait is a road or a wall by the hour.
var tidal := false
## Some currents carry glowing plankton: they shine at night.
var glows := false
var _p: CPUParticles3D
var _mat: StandardMaterial3D


static func create(len: float, w: float, s: float) -> SeaCurrent:
	var c := SeaCurrent.new()
	c.length = len
	c.width = w
	c.strength = s
	return c


func _ready() -> void:
	add_to_group(&"currents")
	_p = CPUParticles3D.new()
	_p.amount = Quality.particle_amount(int(clampf(length * 0.3, 12.0, 110.0)))
	_p.lifetime = length / maxf(strength * 1.6, 1.0)
	# Filled from the start: a current that just streamed in already shows
	# its whole foam line, not a trickle from its head.
	_p.preprocess = _p.lifetime
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.emission_box_extents = Vector3(width * 0.5, 0.05, 1.0)
	_p.direction = Vector3(0, 0, -1)
	_p.spread = 3.0
	_p.gravity = Vector3.ZERO
	_p.initial_velocity_min = strength * 1.4
	_p.initial_velocity_max = strength * 1.8
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 4.5)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 1.0, 1.0, 0.75)
	m.albedo_texture = FireSource._dot()
	_mat = m
	q.material = m
	_p.mesh = q
	_p.position = Vector3(0, 0.08, 0)
	_p.visibility_aabb = AABB(Vector3(-width, -1, -length), Vector3(width * 2, 2, length * 1.2))
	add_child(_p)


## Strength right now (tidal ones follow the tide's flow).
func strength_now() -> float:
	return strength * (lerpf(0.2, 1.35, Tide.flow()) if tidal else 1.0)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 20 != 0:
		return
	var k := strength_now() / maxf(strength, 0.01)
	_p.speed_scale = clampf(k, 0.2, 1.4)
	if glows:
		var night := 1.0 - Clock.daylight()
		_mat.albedo_color = Color(0.95, 1.0, 1.0, 0.75).lerp(Color(0.35, 1.0, 0.9, 0.9), night)
		_mat.emission_enabled = night > 0.2
		_mat.emission = Color(0.2, 0.9, 0.8) * night * 2.0


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
			out += -c.global_basis.z.normalized() * c.strength_now() * edge
	for n in tree.get_nodes_in_group(&"whirlpools"):
		out += (n as Whirlpool).drift_at(pos)
	out.y = 0.0
	return out


## The drift a swimmer feels: current-riding gear ("current_ride") lets
## you ride a current harder and cut across one you are fighting.
static func player_drift(pos: Vector3, move: Vector3, tree: SceneTree) -> Vector3:
	var d := drift_at(pos, tree)
	var k := PlayerData.armor_bonus("current_ride")
	if k <= 0.0 or d == Vector3.ZERO:
		return d
	return d * (1.0 + k) if move.dot(d) > 0.0 else d * maxf(0.25, 1.0 - k * 0.7)


## Which current (if any) a point sits in: the strongest one.
static func current_at(pos: Vector3, tree: SceneTree) -> SeaCurrent:
	var best: SeaCurrent = null
	var bs := 0.0
	for n in tree.get_nodes_in_group(&"currents"):
		var c := n as SeaCurrent
		var local := c.global_transform.affine_inverse() * pos
		if local.z < 0.0 and local.z > -c.length and absf(local.x) < c.width * 0.5 and c.strength_now() > bs:
			bs = c.strength_now()
			best = c
	return best
