class_name WeaponTrail
extends MeshInstance3D
## Ribbon left by the blade during swings: samples the weapon's base and tip
## every frame while the owner is swinging and rebuilds a short strip that
## fades along its length. One ImmediateMesh, one additive material.

const MAX_SAMPLES := 14
const LIFE := 0.16

var p: Player
var _samples: Array = []   # [base, tip, time]
var _im: ImmediateMesh
var _color := Color(1.0, 0.92, 0.75)
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
		_mat.no_depth_test = false
	material_override = _mat


func _process(_delta: float) -> void:
	global_transform = Transform3D()
	var now := Time.get_ticks_msec() * 0.001
	if p and p.combat and p.combat.is_swinging():
		var hand := p.visual.get_socket(&"hand_r")
		if hand:
			var base := hand.global_position
			var out := base - p.chest_position()
			out.y *= 0.4
			var tip := base + out.normalized() * float(p.combat.wstat("reach", 1.8)) * 0.85
			_samples.append([base, tip, now])
			var el := StringName(p.combat.wstat("element", ""))
			_color = ElementFX.color(el) if el != &"" else PlayerData.cosmetic_color("trail", Color(1.0, 0.94, 0.8))
	while not _samples.is_empty() and (now - float(_samples[0][2]) > LIFE or _samples.size() > MAX_SAMPLES):
		_samples.pop_front()
	_im.clear_surfaces()
	if _samples.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _samples.size():
		var s: Array = _samples[i]
		var age := clampf((now - float(s[2])) / LIFE, 0.0, 1.0)
		var a := (1.0 - age) * float(i) / (_samples.size() - 1) * 0.75
		_im.surface_set_color(Color(_color, a * 0.2))
		_im.surface_add_vertex(s[0])
		_im.surface_set_color(Color(_color, a))
		_im.surface_add_vertex(s[1])
	_im.surface_end()
