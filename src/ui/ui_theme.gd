class_name UITheme
extends RefCounted
## Central UI look. Built in code so text scale (accessibility) and the
## palette live in one place. Replace colors/fonts here to reskin, or supply
## a user theme at res://assets/ui/theme.tres (takes precedence).

const USER_THEME := "res://assets/ui/theme.tres"

const BG := Color(0.07, 0.08, 0.1, 0.86)
const BG_SOFT := Color(0.1, 0.11, 0.14, 0.7)
const PANEL_LINE := Color(1, 1, 1, 0.08)
const TEXT := Color(0.95, 0.93, 0.88)
const TEXT_DIM := Color(0.72, 0.7, 0.66)
const ACCENT := Color(0.96, 0.78, 0.42)
const ACCENT_2 := Color(0.45, 0.8, 0.86)
const DANGER := Color(0.93, 0.36, 0.3)
const GOOD := Color(0.5, 0.86, 0.5)
const HEALTH := Color(0.9, 0.34, 0.32)
const STAMINA := Color(0.55, 0.86, 0.42)

static var _theme: Theme
static var _scale := -1.0


static func text_scale() -> float:
	return clampf(float(Settings.get_value("text_scale")), 0.8, 1.6)


static func fs(base: int) -> int:
	return int(round(base * text_scale()))


static func get_theme() -> Theme:
	if ResourceLoader.exists(USER_THEME):
		return load(USER_THEME)
	if _theme != null and is_equal_approx(_scale, text_scale()):
		return _theme
	_scale = text_scale()
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = fs(22)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.5))
	t.set_stylebox("normal", "Button", box(Color(1, 1, 1, 0.07), 14, Color(1, 1, 1, 0.1)))
	t.set_stylebox("hover", "Button", box(Color(1, 1, 1, 0.12), 14, Color(ACCENT, 0.5)))
	t.set_stylebox("pressed", "Button", box(Color(ACCENT, 0.22), 14, ACCENT))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 14, Color(ACCENT, 0.7)))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), 14, Color(1, 1, 1, 0.04)))
	t.set_stylebox("panel", "PanelContainer", box(BG, 22, PANEL_LINE))
	t.set_stylebox("panel", "Panel", box(BG, 22, PANEL_LINE))
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 10)
	t.set_constant("v_separation", "GridContainer", 10)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.45), 6))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 6))
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.15), 6))
	t.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT, 0.8), 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 6))
	t.set_icon("grabber", "HSlider", _dot(26, ACCENT))
	t.set_icon("grabber_highlight", "HSlider", _dot(30, ACCENT))
	t.set_stylebox("normal", "OptionButton", box(Color(1, 1, 1, 0.07), 14, Color(1, 1, 1, 0.1)))
	t.set_stylebox("hover", "OptionButton", box(Color(1, 1, 1, 0.12), 14, Color(ACCENT, 0.5)))
	t.set_stylebox("pressed", "OptionButton", box(Color(ACCENT, 0.2), 14, ACCENT))
	t.set_stylebox("panel", "PopupMenu", box(Color(0.1, 0.11, 0.14, 0.98), 12, PANEL_LINE))
	t.set_font_size("font_size", "PopupMenu", fs(24))
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0))
	t.set_constant("h_separation", "CheckButton", 14)
	t.set_stylebox("scroll", "VScrollBar", box(Color(1, 1, 1, 0.04), 4))
	t.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.25), 4))
	_theme = t
	return t


static func font() -> Font:
	var base: Font = ThemeDB.fallback_font
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK JP", "Noto Sans CJK KR", "PingFang SC", "Hiragino Sans", "Apple SD Gothic Neo", "Droid Sans Fallback", "Source Han Sans"])
	var v := FontVariation.new()
	v.base_font = base
	v.variation_embolden = 0.2
	var fb: Array[Font] = [cjk]
	v.fallbacks = fb
	return v


static func box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border.a > 0.0:
		s.set_border_width_all(border_w)
		s.border_color = border
	s.anti_aliasing = true
	return s


static func _dot(size: int, c: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(c, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_h: int = 64) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: Audio.play_ui(&"ui_click", -8.0))
	return b


## Safe-area margins (notch, Dynamic Island, rounded corners, home bar).
static func safe_margins(vp: Viewport) -> Dictionary:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vis := vp.get_visible_rect().size
	if win.x <= 0 or safe.size.x <= 0:
		return {"left": 24.0, "right": 24.0, "top": 16.0, "bottom": 16.0}
	var sx := vis.x / win.x
	var sy := vis.y / win.y
	return {
		"left": maxf(safe.position.x * sx, 24.0),
		"top": maxf(safe.position.y * sy, 16.0),
		"right": maxf((win.x - safe.end.x) * sx, 24.0),
		"bottom": maxf((win.y - safe.end.y) * sy, 16.0),
	}
