class_name JournalPanel
extends HBoxContainer
## Quest journal. Left: what you can do now — active quests grouped by kind
## (story, tales, discoveries, bounties & trials), then RUMOURS (people who
## have something for you, and where they are), then completed quests.
## Right: the selected quest — region, difficulty, rough length, a one-line
## story, current objectives (bonus ones marked), rewards, and buttons to
## track it or restart its current stage (never a dead end).

const GROUPS := [["main", "JOURNAL_MAIN"], ["side", "JOURNAL_SIDE"], ["discovery", "JOURNAL_DISCOVERIES"], ["bounty", "JOURNAL_BOUNTIES"]]
const DURATION_KEYS := {"short": "DURATION_SHORT", "medium": "DURATION_MEDIUM", "long": "DURATION_LONG"}

var _list: VBoxContainer
var _title: Label
var _meta: Label
var _desc: Label
var _objs: VBoxContainer
var _rewards: Label
var _track: Button
var _restart: Button
var _selected: StringName = &""
var _show_done := false
var _show_atlas := false


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
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
	_meta = UITheme.label("", 18, UITheme.ACCENT_2)
	v.add_child(_meta)
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
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	v.add_child(buttons)
	_track = UITheme.button(tr("BTN_TRACK"), 58)
	_track.custom_minimum_size.x = 220
	_track.pressed.connect(func() -> void:
		Quests.set_tracked(_selected)
		refresh())
	buttons.add_child(_track)
	_restart = UITheme.button(tr("BTN_RESTART_STAGE"), 58)
	_restart.custom_minimum_size.x = 220
	_restart.pressed.connect(func() -> void:
		Quests.restart_stage(_selected)
		refresh())
	buttons.add_child(_restart)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var active := Quests.active_quests()
	var rumors := Quests.rumors()
	if _selected == &"" or not (String(_selected).begins_with("atlas:") or Quests.is_active(_selected) or Quests.is_completed(_selected) or _selected in rumors):
		_selected = Quests.tracked if Quests.tracked != &"" else (active[0] if not active.is_empty() else &"")
	if active.is_empty():
		_list.add_child(UITheme.label(tr("JOURNAL_NONE"), 18, UITheme.TEXT_DIM))
	for g in GROUPS:
		var ids: Array[StringName] = []
		for id in active:
			var t := String(Quests.defs[id].get("type", "side"))
			if t == g[0] or (g[0] == "bounty" and t == "challenge"):
				ids.append(id)
		if ids.is_empty():
			continue
		_list.add_child(UITheme.title(tr(g[1]), 22, UITheme.ACCENT_2))
		for id in ids:
			_list.add_child(_entry(id, false))
	if not rumors.is_empty():
		_list.add_child(UITheme.title(tr("JOURNAL_RUMORS"), 22, UITheme.ACCENT_2))
		for id in rumors:
			_list.add_child(_entry(id, false, true))
	var done := Quests.completed_quests()
	if not done.is_empty():
		var tog := UITheme.button(tr("JOURNAL_DONE") + "  (%d)" % done.size() + ("  ▾" if _show_done else "  ▸"), 50)
		tog.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tog.pressed.connect(func() -> void:
			_show_done = not _show_done
			refresh())
		_list.add_child(tog)
		if _show_done:
			for id in done:
				_list.add_child(_entry(id, true))
	_atlas_list()
	_show(_selected)


## Atlas: the optional wonders, found or only rumoured, by region.
func _atlas_list() -> void:
	if DB.discovery_order.is_empty():
		return
	var tog := UITheme.button(tr("JOURNAL_ATLAS") + "  (%d/%d)" % [DiscoveryDirector.found_count(), DB.discovery_order.size()] + ("  ▾" if _show_atlas else "  ▸"), 50)
	tog.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tog.pressed.connect(func() -> void:
		_show_atlas = not _show_atlas
		refresh())
	_list.add_child(tog)
	if not _show_atlas:
		return
	var by_region := {}
	for id: StringName in DB.discovery_order:
		var rg := String(DB.discoveries[id].get("region", ""))
		if not by_region.has(rg):
			by_region[rg] = []
		by_region[rg].append(id)
	for rg: String in by_region:
		var reg := DB.region(StringName(rg))
		_list.add_child(UITheme.label("%s  %d/%d" % [tr(reg.name_key) if reg else rg, DiscoveryDirector.found_count(rg), (by_region[rg] as Array).size()], 18, UITheme.ACCENT_2))
		for id: StringName in by_region[rg]:
			var found := DiscoveryDirector.is_found(id)
			var icon := String(DB.discoveries[id].get("icon", "✦"))
			var b := UITheme.button((icon + " " + tr(String(DB.discoveries[id].get("name_key", "")))) if found else icon + " ？", 48)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.button_pressed = String(_selected) == "atlas:" + String(id)
			if not found:
				b.modulate = Color(1, 1, 1, 0.7)
			b.pressed.connect(func() -> void:
				_selected = StringName("atlas:" + String(id))
				refresh())
			_list.add_child(b)


func _show_discovery(id: StringName) -> void:
	var d: Dictionary = DB.discoveries.get(id, {})
	var found := DiscoveryDirector.is_found(id)
	var reg := DB.region(StringName(d.get("region", "")))
	_title.text = tr(String(d.get("name_key", ""))) if found else tr("ATLAS_UNKNOWN")
	_meta.text = (tr(reg.name_key) if reg else "") + "  ·  " + tr("JOURNAL_ATLAS")
	_desc.text = tr(String(d.get("desc_key", ""))) if found else tr(String(d.get("hint_key", "ATLAS_NO_HINT")))
	# How it is found: always shown — the conditions are the clue.
	_objs.add_child(UITheme.label(tr("ATLAS_CONDITIONS") % DiscoveryDirector.condition_text(d), 20, UITheme.ACCENT_2))
	_objs.add_child(UITheme.label(("✦ " + tr("ATLAS_FOUND")) if found else ("· " + tr("ATLAS_UNKNOWN")), 20, UITheme.GOOD if found else UITheme.TEXT_DIM))
	var parts := Rewards.describe(d.get("reward", {}))
	_rewards.text = (tr("JOURNAL_REWARDS") + "  " + " · ".join(parts)) if found and not parts.is_empty() else ""
	_track.visible = false
	_restart.visible = false


func _entry(id: StringName, done: bool, rumor: bool = false) -> Button:
	var q: Dictionary = Quests.defs[id]
	var prefix := "◆ " if q.get("type", "side") == "main" else ("… " if rumor else "◇ ")
	var b := UITheme.button(prefix + tr(q.get("title_key", "")), 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = id == _selected
	if done or rumor:
		b.modulate = Color(1, 1, 1, 0.62 if done else 0.8)
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
		_meta.text = ""
		_desc.text = tr("JOURNAL_EMPTY_HINT")
		_rewards.text = ""
		_track.visible = false
		_restart.visible = false
		return
	if String(id).begins_with("atlas:"):
		_show_discovery(StringName(String(id).trim_prefix("atlas:")))
		return
	var q: Dictionary = Quests.defs[id]
	_title.text = tr(q.get("title_key", ""))
	_meta.text = meta_line(q)
	_desc.text = tr(q.get("desc_key", ""))
	if Quests.is_completed(id):
		_objs.add_child(UITheme.label("◇ " + tr("QUEST_COMPLETED"), 20, UITheme.GOOD))
	elif not Quests.is_active(id):
		# Rumour: who has it, and where to find them.
		var st := String(q.get("start", ""))
		if st.begins_with("talk:"):
			var npc := DB.entity(StringName(st.trim_prefix("talk:")))
			var where := _home_name(st.trim_prefix("talk:"))
			_objs.add_child(UITheme.label("… " + (tr("JOURNAL_RUMOR_AT") % [tr(npc.name_key) if npc else "?", where]), 20, UITheme.TEXT))
	else:
		for o in Quests.objective_lines(id):
			var t: String = ("◇ " if o["done"] else "◆ ") + (tr("JOURNAL_BONUS") + " " if o["optional"] else "") + o["text"]
			if int(o["need"]) > 1:
				t += "  %d/%d" % [o["count"], o["need"]]
			_objs.add_child(UITheme.label(t, 20, (UITheme.TEXT if not o["optional"] else UITheme.ACCENT_2) if not o["done"] else UITheme.TEXT_DIM))
	var parts := Rewards.describe(q.get("rewards", {}))
	var bonus := Rewards.describe(q.get("bonus_rewards", {}))
	var txt := (tr("JOURNAL_REWARDS") + "  " + " · ".join(parts)) if not parts.is_empty() else ""
	if not bonus.is_empty():
		txt += "\n" + tr("JOURNAL_BONUS") + "  " + " · ".join(bonus)
	_rewards.text = txt
	_track.visible = Quests.is_active(id)
	_track.disabled = Quests.tracked == id
	_track.text = tr("BTN_TRACKING") if Quests.tracked == id else tr("BTN_TRACK")
	_restart.visible = Quests.is_active(id) and _has_restartable_stage(id)


## "Valley · ◆◆◇◇◇ · ~10 min" — where, how hard, how long.
static func meta_line(q: Dictionary) -> String:
	var parts := PackedStringArray()
	var reg := DB.region(StringName(q.get("region", "")))
	if reg:
		parts.append(TranslationServer.translate(reg.name_key))
	var d := clampi(int(q.get("difficulty", 1)), 1, 5)
	parts.append("◆".repeat(d) + "◇".repeat(5 - d))
	parts.append(TranslationServer.translate(DURATION_KEYS.get(String(q.get("duration", "short")), "DURATION_SHORT")))
	if q.get("repeatable", false):
		parts.append(TranslationServer.translate("JOURNAL_REPEATABLE"))
	return "  ·  ".join(parts)


func _home_name(npc_id: String) -> String:
	for poi in DB.world.get("pois", []):
		for n in poi.get("npcs", []):
			if String(n[0]) == npc_id:
				return tr(poi["name_key"])
	return "?"


## Stages with live content (encounters, spawned enemies, placed objects)
## can be reset from the journal if something went wrong.
func _has_restartable_stage(id: StringName) -> bool:
	return not (Quests.current_stage(id).get("spawns", []) as Array).is_empty()
