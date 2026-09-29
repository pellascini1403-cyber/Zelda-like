class_name Telegraph
extends MeshInstance3D
## Pooled ground warning for heavy attacks (disc / line / cone). The fill
## grows during the windup and snaps to full at impact, so the player reads
## "where" and "when" at a glance. Rendered as one flat additive quad.

enum Shape { DISC, LINE, CONE }

const POOL := 12
static var _pool: Array[Telegraph] = []
static var _root: Node3D
static var _mesh: QuadMesh

var _t := 0.0
var _dur := 1.0
var _linger := 0.25
var _mat: ShaderMaterial
var _follow: Node3D


static func _ensure(ctx: Node) -> bool:
	if _root != null and is_instance_valid(_root) and _root.is_inside_tree():
		return true
	if ctx == null or not ctx.is_inside_tree():
		return false
	_pool.clear()
	_root = Node3D.new()
	_root.name = "TelegraphPool"
	ctx.get_tree().current_scene.add_child(_root)
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(2, 2)
	_mesh.orientation = PlaneMesh.FACE_Y
	var shader: Shader = load("res://assets/shaders/telegraph.gdshader")
	for i in POOL:
		var t := Telegraph.new()
		t.mesh = _mesh
		t._mat = ShaderMaterial.new()
		t._mat.shader = shader
		t.material_override = t._mat
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		t.set_process(false)
		_root.add_child(t)
		_pool.append(t)
	return true


static func _take(ctx: Node) -> Telegraph:
	if not _ensure(ctx):
		return null
	for t in _pool:
		if not t.visible:
			return t
	return _pool[0]


static func _ground(ctx: Node, pos: Vector3) -> Vector3:
	var space := (ctx as Node3D).get_world_3d().direct_space_state if ctx is Node3D else null
	if space:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 3.0, pos + Vector3.DOWN * 8.0, 1))
		if not hit.is_empty():
			return hit["position"] + Vector3.UP * 0.12
	return pos + Vector3.UP * 0.12


## Disc of `radius` at `pos`, filling over `duration` seconds.
static func disc(ctx: Node, pos: Vector3, radius: float, duration: float, color: Color = Color(1.0, 0.45, 0.2)) -> Telegraph:
	var t := _take(ctx)
	if t == null:
		return null
	t._start(_ground(ctx, pos), Basis().scaled(Vector3(radius, 1, radius)), Shape.DISC, duration, color)
	return t


## Rectangle from `from` along `dir` (length × width): charges, beams.
static func line(ctx: Node, from: Vector3, dir: Vector3, length: float, width: float, duration: float, color: Color = Color(1.0, 0.45, 0.2)) -> Telegraph:
	var t := _take(ctx)
	if t == null:
		return null
	dir.y = 0.0
	dir = dir.normalized()
	var yaw := atan2(dir.x, dir.z)
	var basis := Basis(Vector3.UP, yaw) * Basis().scaled(Vector3(width * 0.5, 1, length * 0.5))
	t._start(_ground(ctx, from + dir * length * 0.5), basis, Shape.LINE, duration, color)
	return t


## Cone (sweep) of `reach` and total angle `arc_deg` facing `dir`.
static func cone(ctx: Node, origin: Vector3, dir: Vector3, reach: float, arc_deg: float, duration: float, color: Color = Color(1.0, 0.45, 0.2)) -> Telegraph:
	var t := _take(ctx)
	if t == null:
		return null
	dir.y = 0.0
	dir = dir.normalized()
	var yaw := atan2(dir.x, dir.z)
	# The quad's UV.y runs 0→1 along +Z: shift so the origin sits at the apex.
	var basis := Basis(Vector3.UP, yaw) * Basis().scaled(Vector3(reach, 1, reach * 0.5))
	t._start(_ground(ctx, origin + dir * reach * 0.5), basis, Shape.CONE, duration, color)
	t._mat.set_shader_parameter("arc", deg_to_rad(arc_deg * 0.5))
	return t


func _start(pos: Vector3, basis: Basis, shape: int, duration: float, color: Color) -> void:
	global_transform = Transform3D(basis, pos)
	_mat.set_shader_parameter("shape", float(shape))
	_mat.set_shader_parameter("tint", color)
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("fade", 1.0)
	_t = 0.0
	_dur = maxf(duration, 0.05)
	visible = true
	set_process(true)


## Ends early (attack interrupted).
func cancel() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	if _t <= _dur:
		_mat.set_shader_parameter("progress", _t / _dur)
	else:
		_mat.set_shader_parameter("progress", 1.0)
		_mat.set_shader_parameter("fade", 1.0 - (_t - _dur) / _linger)
		if _t > _dur + _linger:
			cancel()
