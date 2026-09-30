class_name HudArt
extends RefCounted
## The in-game HUD's definitive art: the user's PNGs in assets/ui/hud
## (cropped pixel-exact from the delivered sheets, never redrawn) and the
## HUD palette. Only four colours may appear on the HUD: celeste, black,
## white and black at 20 %. Sizes are the reference layout's, measured at
## the 1280x720 base viewport.

const CELESTE := Color8(78, 240, 252)
const BLACK := Color(0, 0, 0)
const WHITE := Color(1, 1, 1)
const SHADE := Color(0, 0, 0, 0.2)

const HEART := preload("res://assets/ui/hud/heart.png")
const COMPASS_BAR := preload("res://assets/ui/hud/compass_bar.png")
const COMPASS_CENTER := preload("res://assets/ui/hud/compass_center.png")
const QUEST_DIAMOND := preload("res://assets/ui/hud/quest_diamond.png")
const BUTTONS := {
	"map": preload("res://assets/ui/hud/btn_map.png"),
	"journal": preload("res://assets/ui/hud/btn_journal.png"),
	"bag": preload("res://assets/ui/hud/btn_bag.png"),
	"pause": preload("res://assets/ui/hud/btn_pause.png"),
}

# Reference layout (1280x720).
const HEART_W := 37.0
const HEART_PITCH := 49.0
const BUTTON_D := 57.0
const BUTTON_GAP := 13.0
const COMPASS_SIZE := Vector2(567, 57)
const CENTER_W := 20.0
const DIAMOND_W := 18.0


## Size of `tex` scaled to `w` wide, keeping the PNG's proportions.
static func fit(tex: Texture2D, w: float) -> Vector2:
	return Vector2(w, w * tex.get_height() / tex.get_width())


## Outlined HUD label: white text, black outline.
static func label(text: String, size: int, title := false) -> Label:
	var l := UITheme.title(text, size, WHITE) if title else UITheme.label(text, size, WHITE)
	l.add_theme_color_override("font_outline_color", BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


## Round HUD disc (touch buttons, ability): black 20 %; a celeste ring
## while pressed.
static func disc(ci: CanvasItem, c: Vector2, r: float, pressed := false, alpha := 1.0) -> void:
	ci.draw_circle(c, r, Color(SHADE, SHADE.a * alpha))
	if pressed:
		ci.draw_arc(c, r - 1.5, 0, TAU, 48, Color(CELESTE, alpha), 3.0, true)


## Cooldown sweep over a disc: black 20 %.
static func cooldown(ci: CanvasItem, c: Vector2, r: float, ratio: float) -> void:
	if not is_finite(ratio) or not c.is_finite() or r < 1.0 or ratio <= 0.02:
		return
	if ratio >= 0.995:
		ci.draw_circle(c, r, SHADE)
		return
	var pts := PackedVector2Array([c])
	for i in 33:
		var a := -PI * 0.5 + TAU * ratio * float(i) / 32.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, SHADE)


## Rounded progress bar: black 20 % track, celeste fill.
static func bar(ci: CanvasItem, r: Rect2, ratio: float, alpha := 1.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.anti_aliasing = true
	sb.bg_color = Color(SHADE, SHADE.a * alpha)
	ci.draw_style_box(sb, r)
	var w := r.size.x * clampf(ratio, 0.0, 1.0) if is_finite(ratio) else 0.0
	if w >= 1.0:
		sb.bg_color = Color(CELESTE, alpha)
		ci.draw_style_box(sb, Rect2(r.position, Vector2(maxf(w, r.size.y), r.size.y)))


## Outlined string (white on a black outline) at `pos` (baseline).
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, alpha := 1.0, col := WHITE, width := -1.0) -> void:
	ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, 5, Color(BLACK, alpha))
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, Color(col, alpha))
