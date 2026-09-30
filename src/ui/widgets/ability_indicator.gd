class_name AbilityIndicator
extends Control
## Selected Wind Warden ability (desktop / gamepad): a HUD disc with the
## ability glyph, cooldown sweep and key hint. Touch uses the matching
## button in TouchControls instead.

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(76, 96)
	size = custom_minimum_size
	_font = UITheme.font()


func _process(_delta: float) -> void:
	var p := Game.player as Player
	visible = p != null and p.abilities != null and p.abilities.selected != &"" and not (InputRouter.using_touch or Debug.force_touch_ui)
	if visible:
		queue_redraw()


func _draw() -> void:
	var p := Game.player as Player
	var id := p.abilities.selected
	var d: Dictionary = DB.abilities.get(id, {})
	var c := Vector2(size.x * 0.5, 38)
	HudArt.disc(self, c, 34)
	UIArt.glyph(self, String(d.get("glyph", "")), c, 38, HudArt.WHITE)
	HudArt.cooldown(self, c, 34, p.abilities.cooldown_ratio(id))
	var t := "[V]"
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
	HudArt.text(self, _font, Vector2(c.x - w * 0.5, 90), t, 15)
