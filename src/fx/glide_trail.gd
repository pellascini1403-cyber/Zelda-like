class_name GlideTrail
extends MeshInstance3D
## Two thin wind ribbons streaming from the Vela's wing tips while gliding.
## Faint white by default; a glider-trail cosmetic tints them. Effect only:
## the character and the glider model keep their own colours.

const MAX_SAMPLES := 22
const LIFE := 0.55

var p: Player
var _left: Array = []    # [pos, time]
var _right: Array = []
var _im: ImmediateMesh
static var _mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.vertex_color_use_as_albedo = true
	material_override = _mat


func _process(_delta: float) -> void:
	global_transform = Transform3D()
	var now := Time.get_ticks_msec() * 0.001
	if p and p.state_name() == &"glide":
		var right := Basis(Vector3.UP, p.facing_yaw) * Vector3.RIGHT
		var top := p.global_position + Vector3.UP * 2.05
		_left.append([top - right * 1.15, now])
		_right.append([top + right * 1.15, now])
	for arr: Array in [_left, _right]:
		while not arr.is_empty() and (now - float(arr[0][1]) > LIFE or arr.size() > MAX_SAMPLES):
			arr.pop_front()
	_im.clear_surfaces()
	if _left.size() < 2:
		return
	var tinted := not PlayerData.cosmetic_in("glider_trail").is_empty()
	var col := PlayerData.cosmetic_color("glider_trail", Color(0.92, 0.97, 1.0))
	var peak := 0.55 if tinted else 0.22
	for arr: Array in [_left, _right]:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in arr.size():
			var s: Array = arr[i]
			var age := clampf((now - float(s[1])) / LIFE, 0.0, 1.0)
			var a := (1.0 - age) * peak
			var w := 0.05 + 0.07 * (1.0 - age)
			_im.surface_set_color(Color(col, a))
			_im.surface_add_vertex(s[0] + Vector3.UP * w)
			_im.surface_set_color(Color(col, a * 0.4))
			_im.surface_add_vertex(s[0] - Vector3.UP * w)
		_im.surface_end()
