class_name Afterimage
extends Node3D
## Ghost copies of a visual (perfect dodge, gust step): every MeshInstance3D
## under the source is copied with a translucent jade material and fades.
## Works for placeholders and final models alike (it only copies meshes).

static var _mat: StandardMaterial3D


static func spawn(source: Node3D, color: Color = Color(0.5, 1.0, 0.85), life: float = 0.45) -> void:
	if source == null or not source.is_inside_tree():
		return
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var ghost := Afterimage.new()
	source.get_tree().current_scene.add_child(ghost)
	var m := _mat.duplicate() as StandardMaterial3D
	m.albedo_color = Color(color, 0.45)
	for mi in source.find_children("*", "MeshInstance3D", true, false):
		var src := mi as MeshInstance3D
		if src.mesh == null or not src.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = src.mesh
		copy.material_override = m
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = src.global_transform
	var t := ghost.create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, life)
	t.tween_callback(ghost.queue_free)
