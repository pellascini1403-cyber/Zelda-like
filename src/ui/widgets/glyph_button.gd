class_name GlyphButton
extends Button
## Round HUD button drawn with its definitive PNG (map, journal, bag,
## pause). Presses with a small scale "bow".

var glyph := ""


static func make(glyph_name: String, diameter: float = HudArt.BUTTON_D) -> GlyphButton:
	var b := GlyphButton.new()
	b.glyph = glyph_name
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.pressed.connect(func() -> void: Audio.play_ui(&"ui_click", -8.0))
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(0.9, 0.9), 0.06))
	b.button_up.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	return b


func _draw() -> void:
	var tex: Texture2D = HudArt.BUTTONS.get(glyph)
	if tex == null:
		return
	var d := minf(size.x, size.y)
	var s := HudArt.fit(tex, d)
	draw_texture_rect(tex, Rect2((size - s) * 0.5, s), false)
