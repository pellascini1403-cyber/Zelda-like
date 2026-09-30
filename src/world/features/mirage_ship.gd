class_name MirageShip
extends Node3D
## The pale ship: a silhouette under full sail that stands in the mist at
## dawn and is gone by the time you reach it. Seen only at first light in a
## thick bank; it thins as you come close. Where it stood, the sea leaves
## something behind (a discovery).

const DAWN := [4.5, 7.5]

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


static func showing(pos: Vector3, tree: SceneTree) -> bool:
	var h := Clock.hour
	return h >= DAWN[0] and h < DAWN[1] and MistBank.density_at(pos, tree) > 0.4


func _ready() -> void:
	add_to_group(&"mirages")
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0.86, 0.9, 0.95, 0.0)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hull := [
		[ShapeKit.box(Vector3(5.5, 3.0, 22.0)), Transform3D(Basis(), Vector3(0, 1.0, 0))],
		[ShapeKit.box(Vector3(4.0, 2.0, 5.0)), Transform3D(Basis(), Vector3(0, 3.4, 8.0))],
	]
	for mz: float in [-6.0, 1.5]:
		hull.append([ShapeKit.cyl(0.18, 0.25, 18.0, 5), Transform3D(Basis(), Vector3(0, 11.0, mz))])
		hull.append([ShapeKit.box(Vector3(0.1, 9.0, 7.0)), Transform3D(Basis(), Vector3(0.3, 12.0, mz))])
	_mesh = MeshInstance3D.new()
	_mesh.mesh = ShapeKit.merged(hull)
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visibility_range_end = 900.0
	add_child(_mesh)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 6 != 0:
		return
	var a := 0.0
	if MirageShip.showing(global_position, get_tree()) and Game.player:
		var d := Game.player.global_position.distance_to(global_position)
		a = 0.55 * smoothstep(14.0, 60.0, d)
	_mat.albedo_color.a = a
	_mesh.visible = a > 0.01
	rotation.y += 0.002
