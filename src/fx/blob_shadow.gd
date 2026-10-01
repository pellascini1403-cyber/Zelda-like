class_name BlobShadow
extends MeshInstance3D
## Contact shadow under an entity: a soft cool disc laid on the ground below
## it (one short ray down), shrinking and fading with height so jumps and
## fliers keep a ground cue. Presentation only; one shared material.

const MAX_HEIGHT := 9.0
const CAMERA_RANGE := 45.0

static var _mesh: QuadMesh
static var _mat: ShaderMaterial

var radius := 0.5
var _tick := 0
var _every := 1


static func create(r: float, every_frames: int) -> BlobShadow:
	var b := BlobShadow.new()
	b.radius = r
	b._every = every_frames
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2.ONE
		_mesh.orientation = PlaneMesh.FACE_Y
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://assets/shaders/contact_shadow.gdshader")
		_mat.render_priority = -1
	b.mesh = _mesh
	b.material_override = _mat
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.top_level = true
	b.name = "BlobShadow"
	return b


func _ready() -> void:
	_tick = randi() % maxi(_every, 1)


func _process(_delta: float) -> void:
	_tick += 1
	if _tick % _every != 0:
		return
	var owner3d := get_parent() as Node3D
	if owner3d == null or not owner3d.is_visible_in_tree():
		visible = false
		return
	var origin := owner3d.global_position
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(origin) > CAMERA_RANGE:
		visible = false
		return
	var space := owner3d.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.4, origin + Vector3.DOWN * MAX_HEIGHT, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		visible = false
		return
	var h: float = origin.y - (hit.position as Vector3).y
	var k := 1.0 - clampf(h / MAX_HEIGHT, 0.0, 1.0)
	visible = k > 0.05
	var n: Vector3 = hit.normal
	var basis := Basis(Quaternion(Vector3.UP, n)) if n.dot(Vector3.UP) < 0.999 else Basis()
	var s := radius * 2.4 * lerpf(0.55, 1.0, k)
	global_transform = Transform3D(basis.scaled(Vector3(s, 1.0, s)), (hit.position as Vector3) + n * 0.04)
