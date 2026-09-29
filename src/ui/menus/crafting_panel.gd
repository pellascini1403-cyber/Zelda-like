class_name CraftingPanel
extends ScrollContainer
## Recipe list: ingredients with have/need counts, one big Craft button.

var _list: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var recipes := Crafting.recipes()
	recipes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Crafting.can_craft(a) and not Crafting.can_craft(b))
	for r in recipes:
		var row := PanelContainer.new()
		_list.add_child(row)
		var h := HBoxContainer.new()
		row.add_child(h)
		var it := DB.item(StringName(r["result"]))
		var ic := TextureRect.new()
		ic.texture = ItemIcons.icon_for(it)
		ic.custom_minimum_size = Vector2(56, 56)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = ItemIcons.category_color(it.category)
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var title := "%s ×%d" % [tr(it.name_key), int(r.get("count", 1))]
		v.add_child(UITheme.label(title, 24, UITheme.ACCENT))
		var req := Crafting.requirements(r)
		var parts := PackedStringArray()
		for id in req:
			parts.append("%s %d/%d" % [tr(DB.item(id).name_key), PlayerData.inventory.count_of(id), req[id]])
		var st: String = r.get("station", "")
		if st != "":
			parts.append(tr("CRAFT_NEEDS_" + st.to_upper()))
		var l := UITheme.label(" · ".join(parts), 18, UITheme.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		var b := UITheme.button(tr("ACT_CRAFT"), 60)
		b.custom_minimum_size.x = 160
		b.disabled = not Crafting.can_craft(r)
		b.pressed.connect(func() -> void:
			Crafting.craft(r)
			refresh())
		h.add_child(b)
