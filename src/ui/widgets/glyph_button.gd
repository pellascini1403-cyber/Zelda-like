class_name GlyphButton
extends Button
## Round lacquer button showing a procedural glyph (map, bag, pause...).
## Presses with a small scale "bow".

var glyph := ""
var accent := false


static func make(glyph_name: String, diameter: float = 58.0) -> GlyphButton:
	var b := GlyphButton.new()
	b.glyph = glyph_name
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
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
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	UIArt.disc(self, c, r, accent, is_pressed())
	UIArt.glyph(self, glyph, c, r * 1.1, UIArt.PAPER if not is_hovered() else UIArt.GOLD)
