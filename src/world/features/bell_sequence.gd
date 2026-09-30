class_name BellSequence
extends Node
## Rings of several quest objects (bells, levers) that together set one
## flag: the sunken shrine opens when all three drowned bells have rung.

var bells: PackedStringArray = []
var flag := ""


static func create(bell_ids: PackedStringArray, flag_id: String) -> BellSequence:
	var s := BellSequence.new()
	s.bells = bell_ids
	s.flag = flag_id
	return s


func _ready() -> void:
	EventBus.quest_object_used.connect(func(_o: StringName, _g: StringName) -> void: check())


func rung() -> int:
	var n := 0
	for b in bells:
		if WorldState.flags.has("qo:" + b):
			n += 1
	return n


func check() -> void:
	if WorldState.flags.has(flag):
		return
	var n := rung()
	if n >= bells.size():
		Quests.set_flag(StringName(flag))
		EventBus.toast.emit(tr("TOAST_BELLS_DONE"))
	elif n > 0:
		EventBus.toast.emit(tr("TOAST_BELLS_PROGRESS") % [n, bells.size()])
