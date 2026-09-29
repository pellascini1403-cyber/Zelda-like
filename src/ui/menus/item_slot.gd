class_name ItemSlot
extends Button
## Touch-sized inventory cell: icon tinted by category, count, durability,
## equipped marker.

var stack: ItemStack
var selected := false


func _init(s: ItemStack = null) -> void:
	stack = s
	custom_minimum_size = Vector2(104, 104)
	focus_mode = Control.FOCUS_NONE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", 56)


func _ready() -> void:
	if stack and stack.def():
		icon = ItemIcons.icon_for(stack.def())
		add_theme_color_override("icon_normal_color", ItemIcons.category_color(stack.def().category))
		add_theme_color_override("icon_hover_color", ItemIcons.category_color(stack.def().category).lightened(0.2))
		add_theme_color_override("icon_pressed_color", ItemIcons.category_color(stack.def().category).lightened(0.3))


func _draw() -> void:
	if stack == null:
		return
	var f := get_theme_default_font()
	if stack.count > 1:
		var t := str(stack.count)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_RIGHT, -1, 20).x
		draw_string(f, Vector2(size.x - w - 10, size.y - 10), t, HORIZONTAL_ALIGNMENT_RIGHT, -1, 20, UITheme.TEXT)
	var it := stack.def()
	if it and it.is_weapon():
		var r := stack.durability_ratio()
		var col := UITheme.GOOD if r > 0.5 else (UITheme.ACCENT if r > 0.25 else UITheme.DANGER)
		draw_rect(Rect2(10, size.y - 12, (size.x - 20), 5), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(10, size.y - 12, (size.x - 20) * r, 5), col)
	if PlayerData.is_equipped(stack):
		draw_circle(Vector2(18, 18), 8, UITheme.ACCENT)
	if stack.id == PlayerData.quick_item:
		draw_circle(Vector2(size.x - 18, 18), 8, UITheme.ACCENT_2)
	if selected:
		draw_style_box(UITheme.box(Color(0, 0, 0, 0), 14, UITheme.ACCENT, 3), Rect2(Vector2.ZERO, size))
