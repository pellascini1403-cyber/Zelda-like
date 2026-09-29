class_name ShopPanel
extends CanvasLayer
## Merchant trade (data/shops.json): buy stock with glimmer, sell carried
## items at the shop's rate. Stock counts persist per shop in WorldState.
## Pauses the game while open.

var _root: Control
var _buy: VBoxContainer
var _sell: VBoxContainer
var _title: Label
var _purse: Label
var _shop: Dictionary = {}


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	_root.add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UITheme.title("", 34)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_purse = UITheme.label("", 24, UITheme.ACCENT)
	head.add_child(_purse)
	var close := UITheme.button(tr("BTN_LEAVE"), 58)
	close.custom_minimum_size.x = 160
	close.pressed.connect(close_panel)
	head.add_child(close)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	v.add_child(cols)
	_buy = _column(cols, tr("SHOP_BUY"))
	_sell = _column(cols, tr("SHOP_SELL"))


func _column(parent: Control, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UITheme.title(title, 24, UITheme.ACCENT_2))
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(s)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(list)
	return list


func open(npc: Node3D) -> void:
	var npc_id: StringName = (npc as Creature).type.id if npc is Creature else &""
	for id in DB.shops:
		if StringName(DB.shops[id].get("npc", "")) == npc_id:
			_shop = DB.shops[id]
	if _shop.is_empty():
		return
	visible = true
	Game.set_paused(true)
	_title.text = tr(_shop.get("name_key", ""))
	refresh()
	Audio.play_ui(&"menu_open", -6.0)


func close_panel() -> void:
	visible = false
	Game.set_paused(false)


func _stock_key(item_id: String) -> String:
	return "shop_%s_%s" % [_shop["id"], item_id]


func stock_left(entry: Dictionary) -> int:
	var sold: int = WorldState.flags.get(_stock_key(entry["id"]), 0)
	return maxi(int(entry.get("count", 1)) - sold, 0)


func refresh() -> void:
	_purse.text = tr("SHOP_PURSE") % PlayerData.glimmer
	for c in _buy.get_children():
		c.queue_free()
	for c in _sell.get_children():
		c.queue_free()
	for entry in _shop.get("stock", []):
		if entry.has("requires_flag") and not WorldState.flags.has(entry["requires_flag"]):
			continue
		var it := DB.item(StringName(entry["id"]))
		if it == null:
			continue
		var left := stock_left(entry)
		var price := int(entry["price"])
		var b := UITheme.button("%s   ×%d   —   %d ✦" % [tr(it.name_key), left, price], 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = ItemIcons.icon_for(it)
		b.add_theme_constant_override("icon_max_width", 36)
		b.disabled = left <= 0 or PlayerData.glimmer < price
		b.pressed.connect(func() -> void: _buy_item(entry))
		_buy.add_child(b)
	var rate := float(_shop.get("sell_rate", 0.5))
	for stack in PlayerData.inventory.stacks:
		var it := DB.item(stack.id)
		if it == null or it.category == &"key" or PlayerData.is_equipped(stack):
			continue
		var price := maxi(int(round(it.value * rate)), 1)
		var b := UITheme.button("%s   ×%d   +%d ✦" % [tr(it.name_key), stack.count, price], 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = ItemIcons.icon_for(it)
		b.add_theme_constant_override("icon_max_width", 32)
		b.pressed.connect(func() -> void: _sell_item(stack, price))
		_sell.add_child(b)


func _buy_item(entry: Dictionary) -> void:
	var price := int(entry["price"])
	if PlayerData.glimmer < price or stock_left(entry) <= 0:
		return
	PlayerData.glimmer -= price
	PlayerData.inventory.add(StringName(entry["id"]), 1)
	EventBus.item_acquired.emit(StringName(entry["id"]), 1)
	WorldState.flags[_stock_key(entry["id"])] = int(WorldState.flags.get(_stock_key(entry["id"]), 0)) + 1
	Audio.play_ui(&"coin", -4.0)
	refresh()


func _sell_item(stack: ItemStack, price: int) -> void:
	PlayerData.inventory.remove_stack(stack, 1)
	PlayerData.glimmer += price
	Audio.play_ui(&"coin", -6.0)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("menu"):
		close_panel()
		get_viewport().set_input_as_handled()
