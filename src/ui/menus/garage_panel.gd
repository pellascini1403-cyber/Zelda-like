class_name GaragePanel
extends Control
## Garage (pause menu tab, and the Vantrel Depot bench): the three premium
## vehicles. See one turn on the stand, read what it is for, how it is
## obtained and what is still missing; equip, summon, restore it at the
## bench (quest parts + materials + glimmer) or get it from the store.
## Store purchases are optional: nothing in the story needs a vehicle.

var at_bench := false
var _list: VBoxContainer
var _info: VBoxContainer
var _selected: StringName = &""
var _stand: Node3D
var _view: SubViewport
var _preview: VehicleVisual
var _spin := 0.0
var _unveil := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 18)
	add_child(h)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = 270
	_list.add_theme_constant_override("separation", 10)
	h.add_child(_list)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_stretch_ratio = 1.1
	h.add_child(mid)
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(vc)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_2X
	vc.add_child(_view)
	_build_stand()
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 8)
	scroll.add_child(_info)
	EventBus.vehicle_acquired.connect(func(id: StringName, _s: String) -> void:
		if is_visible_in_tree():
			_selected = id
			_unveil = 1.0
			refresh())
	Platform.purchase_completed.connect(func(_id: String, _ok: bool) -> void:
		if is_visible_in_tree():
			refresh())


## A dark stand under warm studio light (shows the worn silver honestly).
func _build_stand() -> void:
	var root := Node3D.new()
	_view.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.47, 0.52)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.95, 0.88)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.75, 0.82, 1.0)
	root.add_child(rim)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = ShapeKit.cyl(2.2, 2.3, 0.12, 32)
	floor_mi.position.y = -0.06
	floor_mi.material_override = VehicleVisual.mat("dark")
	root.add_child(floor_mi)
	_stand = Node3D.new()
	root.add_child(_stand)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.55, 4.6)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	cam.fov = 45.0
	root.add_child(cam)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _stand == null:
		return
	_spin += delta * (0.45 + _unveil * 6.0)
	_unveil = move_toward(_unveil, 0.0, delta * 0.8)
	_stand.rotation.y = _spin
	if _preview:
		_preview.update_motion(0.0, 0.0, 0.0, true, delta)


func refresh() -> void:
	var ids: Array = DB.vehicles.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return int(DB.vehicles[a].get("order", 0)) < int(DB.vehicles[b].get("order", 0)))
	if _selected == &"" or not DB.vehicles.has(_selected):
		_selected = PlayerData.vehicle_equipped if PlayerData.vehicle_equipped != &"" else ids[0]
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(UITheme.title(tr("GARAGE_BRAND"), 22, UITheme.ACCENT_2))
	for id: StringName in ids:
		var d: Dictionary = DB.vehicles[id]
		var status := tr("GARAGE_EQUIPPED") if PlayerData.vehicle_equipped == id and PlayerData.owns_vehicle(id) else (tr("GARAGE_OWNED") if PlayerData.owns_vehicle(id) else tr("GARAGE_LOCKED"))
		var b := UITheme.button("%s\n%s" % [tr(d.get("name_key", "")), status], 76)
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.pressed.connect(func() -> void:
			_selected = id
			Audio.play_ui(&"ui_click", -8.0)
			refresh())
		_list.add_child(b)
	if not at_bench:
		_list.add_child(UITheme.label(tr("GARAGE_BENCH_HINT"), 16, UITheme.TEXT_DIM))
	_show_preview()
	_fill_info()


func _show_preview() -> void:
	if _preview and _preview.def.get("id", "") == String(_selected):
		return
	if _preview:
		_preview.queue_free()
	_preview = VehicleVisual.new()
	_stand.add_child(_preview)
	_preview.setup(DB.vehicles[_selected])
	var len := float(DB.vehicles[_selected].get("collider", {}).get("length", 2.0))
	_preview.scale = Vector3.ONE * clampf(2.6 / maxf(len, 1.7), 0.8, 1.3)


func _fill_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var id := _selected
	var d: Dictionary = DB.vehicles[id]
	var owned := PlayerData.owns_vehicle(id)
	_info.add_child(UITheme.title(tr(d.get("name_key", "")), 32))
	_info.add_child(UITheme.label(tr(d.get("role_key", "")), 19, UITheme.ACCENT))
	var desc := UITheme.label(tr(d.get("desc_key", "")), 18, UITheme.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(desc)
	# Characteristics: five diamonds each (concept values, same scale for all).
	var stats: Dictionary = d.get("stats", {})
	for s in ["speed", "agility", "jump", "combat", "water"]:
		var n := int(stats.get(s, 0))
		var pips := ""
		for i in 5:
			pips += "◆" if i < n else "◇"
		var row := HBoxContainer.new()
		var name_l := UITheme.label(tr("GARAGE_STAT_" + s.to_upper()), 18, UITheme.TEXT_DIM)
		name_l.custom_minimum_size.x = 150
		row.add_child(name_l)
		row.add_child(UITheme.label(pips if n > 0 else "—", 18, UITheme.ACCENT_2))
		_info.add_child(row)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 10)
	if owned:
		var src := String(PlayerData.vehicles.get(String(id), "earned"))
		_info.add_child(UITheme.label(tr("GARAGE_STATUS_STORE") if src == "store" else tr("GARAGE_STATUS_EARNED"), 18, UITheme.ACCENT))
		var eq := UITheme.button(tr("GARAGE_EQUIPPED") if PlayerData.vehicle_equipped == id else tr("GARAGE_EQUIP"), 60)
		eq.disabled = PlayerData.vehicle_equipped == id
		eq.pressed.connect(func() -> void:
			PlayerData.equip_vehicle(id)
			Audio.play_ui(&"ui_click", -6.0)
			refresh())
		buttons.add_child(eq)
		var sm := UITheme.button(tr("GARAGE_SUMMON"), 60)
		sm.pressed.connect(func() -> void:
			PlayerData.equip_vehicle(id)
			var menu := _pause_menu()
			if menu:
				menu.close_menu()
			if Game.player and VehicleManager.instance:
				VehicleManager.instance.summon(Game.player as Player))
		buttons.add_child(sm)
	else:
		_how_to_get(id, d, buttons)
	_info.add_child(buttons)


## Requirement checklist + restore (bench) + optional store purchase.
func _how_to_get(id: StringName, d: Dictionary, buttons: HFlowContainer) -> void:
	_info.add_child(UITheme.title(tr("GARAGE_HOW"), 22, UITheme.ACCENT_2))
	var acq: Dictionary = d.get("acquire", {})
	var st := VehicleManager.restore_status(id)
	var qid := StringName(acq.get("quest", ""))
	var qdef: Dictionary = Quests.defs.get(qid, {})
	var qname := tr(String(qdef.get("title_key", ""))) if not qdef.is_empty() else String(qid)
	_check(tr("GARAGE_REQ_QUEST") % qname, st["quest_done"])
	var missing := {}
	for m: Dictionary in st["missing"]:
		missing[m["id"]] = m
	for it in acq.get("items", []):
		var item := DB.item(StringName(it["id"]))
		var have := PlayerData.inventory.count_of(StringName(it["id"]))
		var need := int(it.get("count", 1))
		_check("%s  %d / %d" % [tr(item.name_key) if item else String(it["id"]), mini(have, need), need], not missing.has(it["id"]))
	var g := int(acq.get("glimmer", 0))
	_check(tr("GARAGE_REQ_GLIMMER") % [mini(PlayerData.glimmer, g), g], int(st["glimmer_short"]) == 0)
	var rb := UITheme.button(tr("GARAGE_RESTORE"), 60)
	rb.disabled = not (at_bench and st["ok"])
	rb.pressed.connect(func() -> void:
		if VehicleManager.restore(id):
			Audio.play_ui(&"quest_complete", -2.0)
		refresh())
	buttons.add_child(rb)
	if not at_bench:
		_info.add_child(UITheme.label(tr("GARAGE_RESTORE_WHERE"), 16, UITheme.TEXT_DIM))
	# Store: optional, clearly labelled, never the only way.
	var pid := String(d.get("product", ""))
	if pid != "":
		var price: String = Platform.price_label(pid)
		var bb := UITheme.button(tr("GARAGE_BUY") + ("  " + price if price != "" else ""), 60)
		bb.disabled = not Platform.store_available()
		bb.pressed.connect(func() -> void: Platform.purchase(pid))
		buttons.add_child(bb)
		var rs := UITheme.button(tr("GARAGE_RESTORE_PURCHASES"), 60)
		rs.pressed.connect(func() -> void:
			Platform.restore_purchases()
			refresh())
		buttons.add_child(rs)
		var note := UITheme.label(tr("GARAGE_OPTIONAL") if Platform.store_available() else tr("GARAGE_STORE_OFF"), 15, UITheme.TEXT_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(note)


func _check(text: String, done: bool) -> void:
	_info.add_child(UITheme.label(("✓  " if done else "·  ") + text, 18, UITheme.ACCENT if done else UITheme.TEXT))


func _pause_menu() -> PauseMenu:
	var n: Node = self
	while n and not n is PauseMenu:
		n = n.get_parent()
	return n as PauseMenu
