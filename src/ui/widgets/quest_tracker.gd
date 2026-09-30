class_name QuestTracker
extends Control
## Tracked quest under the top-right buttons: title in the engraved face,
## current objectives with progress. Briefly glows when it updates.
## Each pending objective carries the celeste quest diamond (the delivered
## PNG); a finished one keeps the diamond in black at 20 %.

var _title: Label
var _lines: VBoxContainer
var _glow := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	_title = HudArt.label("", 21, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_title)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 0)
	v.add_child(_lines)
	for sig in [EventBus.quest_started, EventBus.quest_updated, EventBus.quest_completed, EventBus.quest_stage_advanced]:
		sig.connect(func(_a = null, _b = null) -> void:
			_glow = 1.0
			refresh())
	EventBus.quest_started.connect(func(id: StringName) -> void:
		var disc := String(Quests.defs[id].get("type", "")) == "discovery"
		EventBus.title_card.emit(tr(Quests.defs[id].get("title_key", "")), tr("QUEST_DISCOVERY" if disc else "QUEST_STARTED")))
	EventBus.quest_completed.connect(func(id: StringName) -> void:
		EventBus.title_card.emit(tr(Quests.defs[id].get("title_key", "")), tr("QUEST_COMPLETED")))
	refresh()


func refresh() -> void:
	var id := Quests.tracked
	visible = id != &"" and Quests.is_active(id)
	if not visible:
		return
	_title.text = tr(Quests.defs[id].get("title_key", ""))
	for c in _lines.get_children():
		c.queue_free()
	for o in Quests.objective_lines(id):
		if o["optional"] and o["done"]:
			continue
		var t: String = (tr("JOURNAL_BONUS") + " " if o["optional"] else "") + o["text"]
		if int(o["need"]) > 1:
			t += "  %d/%d" % [o["count"], o["need"]]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := TextureRect.new()
		mark.texture = HudArt.QUEST_DIAMOND
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mark.custom_minimum_size = HudArt.fit(HudArt.QUEST_DIAMOND, HudArt.DIAMOND_W)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if o["done"]:
			mark.modulate = HudArt.SHADE
		row.add_child(mark)
		var l := HudArt.label(t, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
		_lines.add_child(row)


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(_glow - delta * 0.8, 0.0)
		_title.modulate.a = 1.0 - 0.35 * sin(_glow * PI)
