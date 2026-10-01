class_name TideBar
extends StaticBody3D
## A sandbar / causeway stone that is dry at low tide and drowned at high
## tide: walk out at low water, swim at high.

const DRY_TOP := 0.35
const DROWNED_TOP := -1.7

var size := Vector3(4.0, 1.0, 4.0)
var _mesh: MeshInstance3D
static var _mat: StandardMaterial3D


static func create(bar_size: Vector3) -> TideBar:
	var b := TideBar.new()
	b.size = bar_size
	return b


func _ready() -> void:
	add_to_group(&"tide_bars")
	collision_layer = 1
	collision_mask = 0
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.78, 0.7, 0.52)
		_mat.roughness = 0.4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = ShapeKit.box(size)
	_mesh.material_override = _mat
	_mesh.visibility_range_end = 400.0
	add_child(_mesh)


static func top_for(level: float) -> float:
	# level 0 = low water: dry; 1 = high water: drowned.
	return lerpf(DRY_TOP, DROWNED_TOP, smoothstep(0.2, 0.55, level))


var _snapped := false


func _physics_process(delta: float) -> void:
	var want := top_for(Tide.level()) - size.y * 0.5
	if not _snapped:
		_snapped = true
		global_position.y = want
		return
	if Engine.get_physics_frames() % 10 != 0:
		return
	global_position.y = move_toward(global_position.y, want, delta * 10.0 * 0.4)
