class_name LighthouseLamp
extends Node3D
## The lamp of a lighthouse: dark until its flag is set, then a warm light
## and a slow beam sweeping the sea at night — seen from the whole coast.

var flag := ""
var _light: OmniLight3D
var _beam: MeshInstance3D


func _ready() -> void:
	add_to_group(&"lighthouse_lamps")
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.55)
	_light.light_energy = 3.0
	_light.omni_range = 18.0
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 250.0
	_light.distance_fade_length = 80.0
	add_child(_light)
	_beam = MeshInstance3D.new()
	var cone := ShapeKit.cyl(0.4, 6.0, 90.0, 10)
	_beam.mesh = cone
	_beam.rotation = Vector3(PI * 0.5, 0, 0)
	_beam.position = Vector3(0, 0, -45.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.55, 0.12)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = m
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_apply()


func lit() -> bool:
	return WorldState.flags.has(flag)


func _apply() -> void:
	var on := lit() and Clock.daylight() < 0.6
	_light.visible = lit()
	_beam.visible = on


func _process(delta: float) -> void:
	if Engine.get_process_frames() % 20 == 0:
		_apply()
	if _beam.visible:
		rotation.y += delta * 0.5
