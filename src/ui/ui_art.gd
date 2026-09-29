class_name UIArt
extends RefCounted
## Procedural UI ornaments and icons for the "lacquer & gold" style
## (docs/ART_DIRECTION.md §6). Everything is drawn with CanvasItem
## primitives: crisp at any resolution, no texture memory, trivially
## recoloured. Glyphs are original simple pictograms.

const INK := Color(0.055, 0.07, 0.085, 0.92)
const INK_SOFT := Color(0.07, 0.09, 0.105, 0.72)
const GOLD := Color(0.86, 0.71, 0.38)
const GOLD_DIM := Color(0.86, 0.71, 0.38, 0.45)
const JADE := Color(0.33, 0.62, 0.47)
const JADE_LIGHT := Color(0.56, 0.86, 0.68)
const CINNABAR := Color(0.78, 0.28, 0.21)
const PAPER := Color(0.94, 0.9, 0.81)


## Lacquered disc button: ink body, jade fill when accented/pressed, double
## gold rim, subtle inner highlight.
static func disc(ci: CanvasItem, c: Vector2, r: float, accent: bool, pressed: bool, alpha: float = 1.0) -> void:
	var body := Color(INK, 0.62 * alpha)
	if accent:
		body = Color(JADE.darkened(0.35), 0.72 * alpha)
	if pressed:
		body = Color(JADE, 0.9 * alpha)
	ci.draw_circle(c, r, body)
	ci.draw_arc(c, r, 0, TAU, 56, Color(GOLD, 0.85 * alpha), maxf(r * 0.045, 1.6), true)
	ci.draw_arc(c, r * 0.86, 0, TAU, 56, Color(GOLD, 0.25 * alpha), 1.2, true)
	# Highlight crescent (top-left)
	ci.draw_arc(c, r * 0.93, PI * 1.05, PI * 1.55, 18, Color(1, 1, 1, 0.12 * alpha), r * 0.06, true)


## Cloud-scroll (ruyi-like) corner flourish; `dir` points into the panel.
static func scroll_corner(ci: CanvasItem, p: Vector2, s: float, dir: Vector2, col: Color) -> void:
	var dx := Vector2(dir.x, 0)
	var dy := Vector2(0, dir.y)
	ci.draw_line(p, p + dx * s, col, 1.5, true)
	ci.draw_line(p, p + dy * s, col, 1.5, true)
	var c1 := p + dx * s * 0.28 + dy * s * 0.28
	ci.draw_arc(c1, s * 0.16, 0, TAU, 20, col, 1.4, true)
	ci.draw_arc(c1 + dx * s * 0.2, s * 0.08, 0, TAU, 14, col, 1.2, true)
	ci.draw_arc(c1 + dy * s * 0.2, s * 0.08, 0, TAU, 14, col, 1.2, true)


## Four corners around a rect.
static func corners(ci: CanvasItem, r: Rect2, s: float, col: Color) -> void:
	scroll_corner(ci, r.position, s, Vector2(1, 1), col)
	scroll_corner(ci, Vector2(r.end.x, r.position.y), s, Vector2(-1, 1), col)
	scroll_corner(ci, Vector2(r.position.x, r.end.y), s, Vector2(1, -1), col)
	scroll_corner(ci, r.end, s, Vector2(-1, -1), col)


## Horizontal rule fading at both ends with a diamond in the middle.
static func divider(ci: CanvasItem, a: Vector2, b: Vector2, col: Color) -> void:
	var mid := (a + b) * 0.5
	var steps := 12
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var fade := 1.0 - absf((t0 + t1) - 1.0)
		ci.draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(col, col.a * fade), 1.5, true)
	diamond(ci, mid, 5.0, col)


static func diamond(ci: CanvasItem, c: Vector2, r: float, col: Color, filled: bool = true) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, 1.5, true)


## Brush-stroke bar: tapered ends, ink groove, coloured fill, pale trail.
static func brush_bar(ci: CanvasItem, r: Rect2, ratio: float, col: Color, trail: float = -1.0) -> void:
	_brush(ci, r, 1.0, Color(0, 0, 0, 0.45))
	if trail > ratio:
		_brush(ci, r, trail, Color(1, 0.92, 0.8, 0.55))
	if ratio > 0.0:
		_brush(ci, r, ratio, col)
		# Wet highlight along the top of the stroke
		var hr := Rect2(r.position + Vector2(r.size.y * 0.4, r.size.y * 0.18), Vector2((r.size.x - r.size.y * 0.8) * ratio, r.size.y * 0.16))
		if hr.size.x > 2.0:
			ci.draw_rect(hr, Color(1, 1, 1, 0.18))


static func _brush(ci: CanvasItem, r: Rect2, ratio: float, col: Color) -> void:
	var w := r.size.x * clampf(ratio, 0.0, 1.0)
	if w < 1.0:
		return
	var h := r.size.y
	var x0 := r.position.x
	var y0 := r.position.y
	var taper := minf(h * 0.9, w * 0.5)
	var pts := PackedVector2Array([
		Vector2(x0, y0 + h * 0.55), Vector2(x0 + taper, y0), Vector2(x0 + w - taper * 0.5, y0 + h * 0.06),
		Vector2(x0 + w, y0 + h * 0.45), Vector2(x0 + w - taper * 0.35, y0 + h), Vector2(x0 + taper * 0.7, y0 + h * 0.95),
	])
	ci.draw_colored_polygon(pts, col)


## Radial cooldown veil over a disc (0 = ready).
static func cooldown(ci: CanvasItem, c: Vector2, r: float, ratio: float) -> void:
	if ratio <= 0.001:
		return
	var pts := PackedVector2Array([c])
	var steps := 32
	for i in steps + 1:
		var a := -PI * 0.5 + TAU * ratio * float(i) / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.55))


# --- Glyphs ------------------------------------------------------------------------------------------
## Draws pictogram `name` centred at `c`, fitting a box of size `s`.
static func glyph(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(s * 0.085, 1.8)
	var h := s * 0.5
	match name:
		"attack":   # blade
			ci.draw_line(c + Vector2(-h * 0.7, h * 0.7), c + Vector2(h * 0.75, -h * 0.75), col, w * 1.3, true)
			ci.draw_line(c + Vector2(-h * 0.55, h * 0.2), c + Vector2(-h * 0.2, h * 0.55), col, w, true)
			ci.draw_circle(c + Vector2(-h * 0.78, h * 0.78), w * 0.9, col)
		"jump":     # double chevron up
			for k in 2:
				var y := h * (0.35 - k * 0.55)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.6, y + h * 0.35), c + Vector2(0, y - h * 0.2), c + Vector2(h * 0.6, y + h * 0.35)]), col, w, true)
		"dodge":    # swirl
			var pts := PackedVector2Array()
			for i in 22:
				var t := float(i) / 21.0
				var a := t * TAU * 1.25
				pts.append(c + Vector2(cos(a), sin(a)) * h * (0.15 + t * 0.7))
			ci.draw_polyline(pts, col, w, true)
		"guard":    # shield
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.6, -h * 0.6), c + Vector2(h * 0.6, -h * 0.6), c + Vector2(h * 0.55, h * 0.05), c + Vector2(0, h * 0.75), c + Vector2(-h * 0.55, h * 0.05), c + Vector2(-h * 0.6, -h * 0.6)]), col, w, true)
			ci.draw_line(c + Vector2(0, -h * 0.45), c + Vector2(0, h * 0.5), col, w * 0.8, true)
		"lock":     # reticle
			ci.draw_arc(c, h * 0.55, 0, TAU, 28, col, w, true)
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * h * 0.35, c + d * h * 0.8, col, w, true)
		"item":     # pouch
			ci.draw_arc(c + Vector2(0, h * 0.15), h * 0.5, 0, TAU, 24, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.25, -h * 0.4), c + Vector2(h * 0.25, -h * 0.4), col, w, true)
			ci.draw_line(c + Vector2(-h * 0.15, -h * 0.55), c + Vector2(h * 0.15, -h * 0.25), col, w * 0.8, true)
		"weapon":   # two crossed blades
			ci.draw_line(c + Vector2(-h * 0.6, h * 0.6), c + Vector2(h * 0.6, -h * 0.6), col, w, true)
			ci.draw_line(c + Vector2(h * 0.6, h * 0.6), c + Vector2(-h * 0.6, -h * 0.6), col, w, true)
		"interact": # open hand / dot in ring
			ci.draw_arc(c, h * 0.6, 0, TAU, 24, col, w, true)
			ci.draw_circle(c, h * 0.2, col)
		"drop":     # arrow down
			ci.draw_line(c + Vector2(0, -h * 0.65), c + Vector2(0, h * 0.5), col, w, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.4, h * 0.15), c + Vector2(0, h * 0.6), c + Vector2(h * 0.4, h * 0.15)]), col, w, true)
		"map":      # folded scroll
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.7, -h * 0.5), c + Vector2(-h * 0.25, -h * 0.65), c + Vector2(h * 0.25, -h * 0.5), c + Vector2(h * 0.7, -h * 0.65), c + Vector2(h * 0.7, h * 0.5), c + Vector2(h * 0.25, h * 0.65), c + Vector2(-h * 0.25, h * 0.5), c + Vector2(-h * 0.7, h * 0.65), c + Vector2(-h * 0.7, -h * 0.5)]), col, w * 0.9, true)
			ci.draw_line(c + Vector2(-h * 0.25, -h * 0.65), c + Vector2(-h * 0.25, h * 0.5), col, w * 0.6, true)
			ci.draw_line(c + Vector2(h * 0.25, -h * 0.5), c + Vector2(h * 0.25, h * 0.65), col, w * 0.6, true)
		"bag":      # satchel
			ci.draw_rect(Rect2(c + Vector2(-h * 0.6, -h * 0.25), Vector2(h * 1.2, h * 0.85)), col, false, w)
			ci.draw_arc(c + Vector2(0, -h * 0.25), h * 0.35, PI, TAU, 14, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.6, h * 0.05), c + Vector2(h * 0.6, h * 0.05), col, w * 0.7, true)
		"pause":
			ci.draw_line(c + Vector2(-h * 0.25, -h * 0.5), c + Vector2(-h * 0.25, h * 0.5), col, w * 1.3, true)
			ci.draw_line(c + Vector2(h * 0.25, -h * 0.5), c + Vector2(h * 0.25, h * 0.5), col, w * 1.3, true)
		"journal":  # book with ribbon
			ci.draw_rect(Rect2(c + Vector2(-h * 0.55, -h * 0.65), Vector2(h * 1.1, h * 1.3)), col, false, w)
			ci.draw_line(c + Vector2(h * 0.2, -h * 0.65), c + Vector2(h * 0.2, h * 0.25), col, w * 0.8, true)
		"gust":     # three wind strokes
			for k in 3:
				var y := h * (-0.45 + k * 0.45)
				var seg := h * (1.2 - k * 0.25)
				ci.draw_line(c + Vector2(-h * 0.7, y), c + Vector2(-h * 0.7 + seg, y), col, w, true)
				ci.draw_arc(c + Vector2(-h * 0.7 + seg, y - h * 0.15), h * 0.15, PI * 0.5, PI * 2.0, 10, col, w, true)
		"jade":     # hexagonal slab
			var hex := PackedVector2Array()
			for i in 7:
				var a := TAU * i / 6.0
				hex.append(c + Vector2(cos(a), sin(a) * 0.55) * h * 0.75)
			ci.draw_polyline(hex, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.35, h * 0.45), c + Vector2(-h * 0.35, h * 0.8), col, w * 0.7, true)
			ci.draw_line(c + Vector2(h * 0.35, h * 0.45), c + Vector2(h * 0.35, h * 0.8), col, w * 0.7, true)
		"eye":      # wind sight
			ci.draw_arc(c + Vector2(0, h * 0.5), h * 0.85, PI * 1.2, PI * 1.8, 16, col, w, true)
			ci.draw_arc(c - Vector2(0, h * 0.5), h * 0.85, PI * 0.2, PI * 0.8, 16, col, w, true)
			ci.draw_circle(c, h * 0.2, col)
		"still":    # hourglass ring
			ci.draw_arc(c, h * 0.7, 0, TAU, 28, col, w * 0.8, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.3, -h * 0.4), c + Vector2(h * 0.3, -h * 0.4), c + Vector2(-h * 0.3, h * 0.4), c + Vector2(h * 0.3, h * 0.4), c + Vector2(-h * 0.3, -h * 0.4)]), col, w * 0.8, true)
		"call":     # horn / whistle waves
			ci.draw_circle(c + Vector2(-h * 0.35, 0), h * 0.18, col)
			for k in 3:
				ci.draw_arc(c + Vector2(-h * 0.35, 0), h * (0.35 + k * 0.22), -PI * 0.3, PI * 0.3, 10, col, w * 0.8, true)
		"quest":    # diamond with inner dot
			diamond(ci, c, h * 0.7, col, false)
			ci.draw_circle(c, h * 0.15, col)
		"mount":
			ci.draw_arc(c + Vector2(0, h * 0.2), h * 0.55, PI, TAU, 16, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.55, h * 0.2), c + Vector2(-h * 0.55, h * 0.6), col, w, true)
			ci.draw_line(c + Vector2(h * 0.55, h * 0.2), c + Vector2(h * 0.55, h * 0.6), col, w, true)
		_:
			ci.draw_circle(c, h * 0.3, col)
