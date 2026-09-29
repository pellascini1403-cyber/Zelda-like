class_name WaterSurface
extends MeshInstance3D
## One water plane at sea level that follows the camera in fixed steps (so
## the wave pattern never swims). Covers sea, lake and river at once.

const SIZE := 3200.0
const SNAP := 32.0


func setup(height_tex: Texture2D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = 128
	plane.subdivide_depth = 128
	mesh = plane
	var mat := WorldMaterials.get_mat(&"water") as ShaderMaterial
	mat.set_shader_parameter("height_tex", height_tex)
	mat.set_shader_parameter("world_half", WorldGen.WORLD_HALF)
	mat.set_shader_parameter("height_scale", IslandMap.HEIGHT_SCALE)
	mat.set_shader_parameter("height_offset", IslandMap.HEIGHT_OFFSET)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = WorldGen.SEA_LEVEL


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		position.x = snappedf(cam.global_position.x, SNAP)
		position.z = snappedf(cam.global_position.z, SNAP)
