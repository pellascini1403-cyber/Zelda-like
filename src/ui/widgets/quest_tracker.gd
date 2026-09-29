class_name QuestTracker
extends Control
## Tracked quest under the top-right buttons: title in the engraved face,
## current objectives with progress. Briefly glows when it updates.

var _title: Label
var _lines: VBoxContainer
var _glow := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	_title = UITheme.title("", 21, UITheme.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("outline_size", 6)
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
		var t: String = ("◆ " if not o["done"] else "◇ ") + (tr("JOURNAL_BONUS") + " " if o["optional"] else "") + o["text"]
		if int(o["need"]) > 1:
			t += "  %d/%d" % [o["count"], o["need"]]
		var l := UITheme.label(t, 18, UITheme.TEXT if not o["done"] else UITheme.TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		l.add_theme_constant_override("outline_size", 5)
		_lines.add_child(l)


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(_glow - delta * 0.8, 0.0)
		_title.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.3, 1.0), _glow)
