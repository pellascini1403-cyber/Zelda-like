class_name FlashOverlay
extends RefCounted
## Hit / telegraph flash for entities: a small additive overlay
## material per visual, attached to its parts only while the flash is on.


const SHADER := preload("res://assets/shaders/flash_overlay.gdshader")


## Sets the flash on `geoms`; returns the visual's overlay material (created
## on first use) so the caller can keep it.
static func apply(geoms: Array[GeometryInstance3D], mat: ShaderMaterial, amount: float, color: Color) -> ShaderMaterial:
	var on := amount > 0.001
	if on and mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
	if mat:
		mat.set_shader_parameter(&"flash", Color(color.r, color.g, color.b, amount))
	for g in geoms:
		if is_instance_valid(g):
			g.material_overlay = mat if on else null
	return mat
