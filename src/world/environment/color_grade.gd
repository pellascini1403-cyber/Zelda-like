class_name ColorGrade
extends RefCounted
## Builds the project's colour-grading LUT (17³, generated once at start).
## Applied by the tonemap pass: one 3D texture fetch per pixel, negligible on
## mobile. The grade defines the look more than any single asset:
##   * shadows lean cool (ink blue), highlights lean warm (paper/sun)
##   * yellow-greens are pulled toward jade, reds kept rich (cinnabar)
##   * a soft "print" toe keeps blacks inky rather than crushed.

const SIZE := 17


static func build_lut() -> ImageTexture3D:
	var images: Array[Image] = []
	for b in SIZE:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for g in SIZE:
			for r in SIZE:
				img.set_pixel(r, g, grade(Color(float(r) / (SIZE - 1), float(g) / (SIZE - 1), float(b) / (SIZE - 1))))
		images.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, SIZE, SIZE, SIZE, false, images)
	return tex


static func grade(c: Color) -> Color:
	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	# Split toning
	var shadow_tint := Color(0.9, 0.96, 1.07)
	var high_tint := Color(1.03, 1.0, 0.96)
	var t := smoothstep(0.15, 0.75, lum)
	var tint := shadow_tint.lerp(high_tint, t)
	var o := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b)
	# Jade shift: yellow-green hues move toward blue-green.
	var h := o.h
	if h > 0.17 and h < 0.4 and o.s > 0.15:
		var k := 1.0 - absf(h - 0.28) / 0.12
		o.h = h + 0.035 * k
		o.s = minf(o.s * (1.0 + 0.05 * k), 1.0)
	# Soft toe: lift blacks slightly toward ink blue.
	var toe := 1.0 - smoothstep(0.0, 0.12, lum)
	o = o.lerp(Color(0.05, 0.07, 0.1), toe * 0.35 * (1.0 - lum * 4.0))
	return Color(clampf(o.r, 0.0, 1.0), clampf(o.g, 0.0, 1.0), clampf(o.b, 0.0, 1.0))
