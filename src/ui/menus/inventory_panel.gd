class_name InventoryPanel
extends HBoxContainer
## Category tabs + item grid + detail card with context actions
## (equip, use, set quick slot, repair).

var _cat := &"weapon"
var _grid: GridContainer
var _cats: HFlowContainer
var _detail: VBoxContainer
var _name: Label
var _desc: Label
var _stats: Label
var _actions: HBoxContainer
var _equip_row: Label
var _selected: ItemStack


func _ready() -> void:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	_cats = HFlowContainer.new()
	_cats.add_theme_constant_override("h_separation", 10)
	_cats.add_theme_constant_override("v_separation", 10)
	left.add_child(_cats)
	for c in ItemData.CATEGORIES:
		var b := UITheme.button(tr("CAT_" + String(c).to_upper()), 56)
		b.toggle_mode = true
		b.icon = ItemIcons.category_texture(ItemIcons.CATEGORY_ICON[c])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 28)
		b.pressed.connect(func() -> void:
			_cat = c
			_selected = null
			refresh())
		b.set_meta(&"cat", c)
		_cats.add_child(b)
	_equip_row = UITheme.label("", 18, UITheme.TEXT_DIM)
	_equip_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_equip_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	scroll.add_child(_grid)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 0)
	add_child(card)
	_detail = VBoxContainer.new()
	card.add_child(_detail)
	_name = UITheme.label("", 28, UITheme.ACCENT)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_name)
	_desc = UITheme.label("", 20, UITheme.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_desc)
	_stats = UITheme.label("", 20, UITheme.TEXT_DIM)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_stats)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(spacer)
	_actions = HBoxContainer.new()
	_detail.add_child(_actions)
	EventBus.inventory_changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())


func refresh() -> void:
	for b in _cats.get_children():
		(b as Button).button_pressed = b.get_meta(&"cat") == _cat
	for c in _grid.get_children():
		c.queue_free()
	var avail := size.x - 360.0 - 40.0 if size.x > 0.0 else get_viewport_rect().size.x - 520.0
	_grid.columns = clampi(int(avail / 114.0), 3, 8)
	var stacks := PlayerData.inventory.in_category(_cat)
	if _selected and not _selected in PlayerData.inventory.stacks:
		_selected = null
	for s in stacks:
		var slot := ItemSlot.new(s)
		slot.selected = s == _selected
		slot.pressed.connect(func() -> void:
			_selected = s
			refresh())
		_grid.add_child(slot)
	var eq := PackedStringArray()
	for slot_name in PlayerData.EQUIP_SLOTS:
		var st: ItemStack = PlayerData.equipped.get(slot_name)
		eq.append("%s: %s" % [tr("SLOT_" + String(slot_name).to_upper()), tr(st.def().name_key) if st and st.def() else "—"])
	_equip_row.text = "   ".join(eq) + "\n%s %d/%d · %s %d · %s %.0f" % [tr("STAT_HEALTH"), PlayerData.health, PlayerData.max_health, tr("STAT_DEFENSE"), PlayerData.defense(), tr("STAT_ATTACK"), PlayerData.attack_mult() * 100.0] + "%"
	_show_detail()


func _show_detail() -> void:
	for c in _actions.get_children():
		c.queue_free()
	if _selected == null or _selected.def() == null:
		_name.text = tr("CAT_" + String(_cat).to_upper())
		_desc.text = tr("INV_EMPTY_HINT") if PlayerData.inventory.in_category(_cat).is_empty() else tr("INV_SELECT_HINT")
		_stats.text = ""
		return
	var it := _selected.def()
	_name.text = tr(it.name_key)
	_desc.text = tr(it.desc_key)
	var lines := PackedStringArray()
	if it.is_weapon():
		lines.append("%s %d   %s %.1f   %s %.1f m" % [tr("STAT_DAMAGE"), it.w("damage", 0), tr("STAT_SPEED"), it.w("speed", 1.0), tr("STAT_REACH"), it.w("reach", 1.8)])
		lines.append("%s %d / %d" % [tr("STAT_DURABILITY"), _selected.durability(), _selected.max_durability()])
		if _selected.is_heirloom():
			lines.append(tr("STAT_HEIRLOOM"))
		lines.append(tr("CHARGED_" + String(it.w("charged", "spin")).to_upper()))
		if it.has_tag("metal"):
			lines.append(tr("STAT_METAL"))
	if not it.armor.is_empty():
		lines.append("%s %d" % [tr("STAT_DEFENSE"), it.armor.get("defense", 0)])
		for k in ["cold_resist", "heat_resist", "climb_speed", "stamina_regen", "lightning_immune", "speed", "stealth", "breath", "swim_speed"]:
			if it.armor.has(k):
				lines.append(tr("ARMOR_" + k.to_upper()))
		if it.armor.has("set"):
			lines.append(tr("SET_" + String(it.armor["set"]).to_upper()))
	for eff in it.effects:
		match String(eff.get("type", "")):
			"heal": lines.append("%s +%d" % [tr("STAT_HEALTH"), float(eff["amount"]) * float(_selected.data.get("potency", 1.0))])
			"stamina": lines.append("%s +%d" % [tr("STAT_STAMINA"), float(eff["amount"]) * float(_selected.data.get("potency", 1.0))])
			"buff": lines.append(tr("BUFF_" + String(eff["buff"]).to_upper()))
	if _selected.data.has("potency") and it.category == &"food":
		lines.append("%s x%.1f" % [tr("STAT_POTENCY"), _selected.data["potency"]])
	_stats.text = "\n".join(lines)

	if it.is_weapon() or not it.armor.is_empty():
		if PlayerData.is_equipped(_selected):
			if not it.is_weapon():
				_action(tr("ACT_UNEQUIP"), func() -> void: PlayerData.unequip(StringName(it.armor.get("slot", ""))))
		else:
			_action(tr("ACT_EQUIP"), func() -> void: PlayerData.equip(_selected))
	if it.use_action != &"none":
		if it.use_action == &"eat" or it.use_action == &"repair":
			_action(tr("ACT_USE"), func() -> void:
				(Game.player as Player).combat.use_stack(_selected)
				refresh())
		_action(tr("ACT_QUICK"), func() -> void:
			PlayerData.quick_item = it.id
			refresh())


func _action(text: String, cb: Callable) -> void:
	var b := UITheme.button(text, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		cb.call()
		refresh())
	_actions.add_child(b)
