class_name ItemIcons
extends RefCounted
## Icon lookup. Items reference an SVG under assets/icons/ in data; missing
## icons fall back to the category glyph so content can ship before art.

const CATEGORY_ICON := {
	&"weapon": "res://assets/icons/cat_weapon.svg",
	&"armor": "res://assets/icons/cat_armor.svg",
	&"material": "res://assets/icons/cat_material.svg",
	&"food": "res://assets/icons/cat_food.svg",
	&"tool": "res://assets/icons/cat_tool.svg",
	&"key": "res://assets/icons/cat_key.svg",
}
const CATEGORY_COLOR := {
	&"weapon": Color(0.86, 0.62, 0.42),
	&"armor": Color(0.55, 0.7, 0.9),
	&"material": Color(0.72, 0.78, 0.55),
	&"food": Color(0.95, 0.66, 0.45),
	&"tool": Color(0.8, 0.72, 0.95),
	&"key": Color(1.0, 0.85, 0.4),
}

static var _cache: Dictionary = {}


static func icon_for(it: ItemData) -> Texture2D:
	if it == null:
		return null
	var path := it.icon if it.icon != "" and ResourceLoader.exists(it.icon) else String(CATEGORY_ICON.get(it.category, ""))
	return category_texture(path)


static func category_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func category_color(cat: StringName) -> Color:
	return CATEGORY_COLOR.get(cat, Color.WHITE)
