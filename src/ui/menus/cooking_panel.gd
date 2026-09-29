class_name CookingPanel
extends CanvasLayer
## Camp screen: pick up to 5 ingredients, cook, or rest (skip time).
## Known combinations show their result; new ones show "???" — experiment!

var _root: Control
var _grid: GridContainer
var _pot: HBoxContainer
var _preview: Label
var _cook_btn: Button
var _chosen: Array = []
var _camp: Node3D


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.05, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := UITheme.safe_margins(_root.get_viewport())
	panel.offset_left = m["left"] + 20
	panel.offset_right = -m["right"] - 20
	panel.offset_top = m["top"] + 20
	panel.offset_bottom = -m["bottom"] - 20
	_root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := UITheme.label(tr("CAMP_TITLE"), 30, UITheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	for rest in [["CAMP_REST_MORNING", 6.0], ["CAMP_REST_NOON", 12.0], ["CAMP_REST_NIGHT", 21.0]]:
		var rb := UITheme.button(tr(rest[0]), 56)
		rb.pressed.connect(func() -> void: _rest_until(rest[1]))
		top.add_child(rb)
	var close := UITheme.button(tr("BTN_CLOSE_MENU"), 56)
	close.pressed.connect(close_panel)
	top.add_child(close)
	v.add_child(UITheme.label(tr("CAMP_HINT"), 18, UITheme.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 8
	scroll.add_child(_grid)
	var bottom := HBoxContainer.new()
	v.add_child(bottom)
	_pot = HBoxContainer.new()
	_pot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_pot)
	_preview = UITheme.label("", 22, UITheme.ACCENT_2)
	_preview.custom_minimum_size.x = 300
	bottom.add_child(_preview)
	_cook_btn = UITheme.button(tr("ACT_COOK"), 72)
	_cook_btn.custom_minimum_size.x = 200
	_cook_btn.pressed.connect(_cook)
	bottom.add_child(_cook_btn)


func open(camp: Node3D) -> void:
	_camp = camp
	_chosen.clear()
	visible = true
	Game.set_paused(true)
	_refresh()


func close_panel() -> void:
	visible = false
	Game.set_paused(false)


func _available() -> Dictionary:
	var counts := {}
	for s in PlayerData.inventory.stacks:
		var it := s.def()
		if it and (it.category == &"food" or it.category == &"material") and s.data.is_empty():
			counts[s.id] = counts.get(s.id, 0) + s.count
	for id in _chosen:
		counts[id] = counts.get(id, 0) - 1
	return counts


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var counts := _available()
	_grid.columns = clampi(int((_root.get_viewport_rect().size.x - 120) / 116), 4, 10)
	for id in counts:
		if counts[id] <= 0:
			continue
		var slot := ItemSlot.new(ItemStack.new(id, counts[id]))
		slot.disabled = _chosen.size() >= Cooking.MAX_INGREDIENTS
		slot.tooltip_text = tr(DB.item(id).name_key)
		slot.pressed.connect(func() -> void:
			_chosen.append(id)
			_refresh())
		_grid.add_child(slot)
	for c in _pot.get_children():
		c.queue_free()
	for i in Cooking.MAX_INGREDIENTS:
		var b: Button
		if i < _chosen.size():
			b = ItemSlot.new(ItemStack.new(_chosen[i], 1))
			var idx := i
			b.pressed.connect(func() -> void:
				_chosen.remove_at(idx)
				_refresh())
		else:
			b = Button.new()
			b.custom_minimum_size = Vector2(104, 104)
			b.disabled = true
		_pot.add_child(b)
	if _chosen.is_empty():
		_preview.text = ""
	else:
		var known := Cooking.known_result(_chosen)
		_preview.text = tr(DB.item(StringName(known)).name_key) if known != "" else "???"
	_cook_btn.disabled = _chosen.is_empty()


func _cook() -> void:
	var res := Cooking.cook(_chosen.duplicate())
	_chosen.clear()
	if not res.is_empty():
		EventBus.toast.emit(tr("TOAST_COOKED") % tr(DB.item(res["item"]).name_key))
	_refresh()


func _rest_until(hour: float) -> void:
	var delta := fposmod(hour - Clock.hour, 24.0)
	Clock.advance_hours(delta)
	PlayerData.heal(PlayerData.max_health * 0.5)
	PlayerData.stamina = PlayerData.max_stamina
	Weather.pick_next()
	close_panel()
	EventBus.toast.emit(tr("TOAST_RESTED"))
	SaveSystem.save_game()
