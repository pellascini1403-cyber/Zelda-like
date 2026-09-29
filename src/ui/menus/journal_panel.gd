class_name JournalPanel
extends HBoxContainer
## Quest journal: active (main first) and completed quests on the left, the
## selected quest's story, current objectives and rewards on the right.
## "Track" sets the quest shown on the HUD and compass.

var _list: VBoxContainer
var _title: Label
var _desc: Label
var _objs: VBoxContainer
var _rewards: Label
var _track: Button
var _selected: StringName = &""


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	_title = UITheme.title("", 34, UITheme.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 14)
	rule.draw.connect(func() -> void: UIArt.divider(rule, Vector2(0, 7), Vector2(rule.size.x, 7), Color(UIArt.GOLD, 0.7)))
	v.add_child(rule)
	_desc = UITheme.label("", 21, UITheme.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_desc)
	v.add_child(UITheme.title(tr("JOURNAL_OBJECTIVES"), 22, UITheme.ACCENT_2))
	_objs = VBoxContainer.new()
	v.add_child(_objs)
	_rewards = UITheme.label("", 19, UITheme.TEXT_DIM)
	_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_rewards)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_track = UITheme.button(tr("BTN_TRACK"), 58)
	_track.custom_minimum_size.x = 220
	_track.pressed.connect(func() -> void:
		Quests.set_tracked(_selected)
		refresh())
	v.add_child(_track)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var active := Quests.active_quests()
	active.sort_custom(func(a: StringName, b: StringName) -> bool: return Quests.defs[a].get("type", "side") == "main" and Quests.defs[b].get("type", "side") != "main")
	if _selected == &"" or not (Quests.is_active(_selected) or Quests.is_completed(_selected)):
		_selected = Quests.tracked if Quests.tracked != &"" else (active[0] if not active.is_empty() else &"")
	_list.add_child(UITheme.title(tr("JOURNAL_ACTIVE"), 22, UITheme.ACCENT_2))
	if active.is_empty():
		_list.add_child(UITheme.label(tr("JOURNAL_NONE"), 18, UITheme.TEXT_DIM))
	for id in active:
		_list.add_child(_entry(id, false))
	var done := Quests.completed_quests()
	if not done.is_empty():
		_list.add_child(UITheme.title(tr("JOURNAL_DONE"), 22, UITheme.TEXT_DIM))
		for id in done:
			_list.add_child(_entry(id, true))
	_show(_selected)


func _entry(id: StringName, done: bool) -> Button:
	var q: Dictionary = Quests.defs[id]
	var prefix := "◆ " if q.get("type", "side") == "main" else "◇ "
	var b := UITheme.button(prefix + tr(q.get("title_key", "")), 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = id == _selected
	if done:
		b.modulate = Color(1, 1, 1, 0.6)
	if id == Quests.tracked:
		b.add_theme_color_override("font_color", UITheme.ACCENT)
	b.pressed.connect(func() -> void:
		_selected = id
		refresh())
	return b


func _show(id: StringName) -> void:
	for c in _objs.get_children():
		c.queue_free()
	if id == &"":
		_title.text = tr("TAB_JOURNAL")
		_desc.text = tr("JOURNAL_EMPTY_HINT")
		_rewards.text = ""
		_track.visible = false
		return
	var q: Dictionary = Quests.defs[id]
	_title.text = tr(q.get("title_key", ""))
	_desc.text = tr(q.get("desc_key", ""))
	if Quests.is_completed(id):
		_objs.add_child(UITheme.label("◇ " + tr("QUEST_COMPLETED"), 20, UITheme.GOOD))
	else:
		for o in Quests.objective_lines(id):
			var t: String = ("◆ " if not o["done"] else "◇ ") + o["text"]
			if int(o["need"]) > 1:
				t += "  %d/%d" % [o["count"], o["need"]]
			_objs.add_child(UITheme.label(t, 20, UITheme.TEXT if not o["done"] else UITheme.TEXT_DIM))
	var r: Dictionary = q.get("rewards", {})
	var parts := PackedStringArray()
	for it in r.get("items", []):
		var d := DB.item(StringName(it["id"]))
		if d:
			parts.append("%s ×%d" % [tr(d.name_key), int(it.get("count", 1))])
	if r.has("glimmer"):
		parts.append(tr("REWARD_GLIMMER") % int(r["glimmer"]))
	if r.has("ability"):
		parts.append(tr(DB.abilities.get(StringName(r["ability"]), {}).get("name_key", "")))
	if r.has("max_stamina"):
		parts.append(tr("REWARD_STAMINA"))
	if r.has("max_health"):
		parts.append(tr("REWARD_HEALTH"))
	_rewards.text = (tr("JOURNAL_REWARDS") + "  " + " · ".join(parts)) if not parts.is_empty() else ""
	_track.visible = Quests.is_active(id)
	_track.disabled = Quests.tracked == id
	_track.text = tr("BTN_TRACKING") if Quests.tracked == id else tr("BTN_TRACK")
