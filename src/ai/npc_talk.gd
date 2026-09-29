class_name NPCTalk
extends Interactable
## Talk trigger attached to an NPC. Lines come from EntityType.dialogue:
## { "default": [keys...], "night": [keys...], "flag:<name>": [keys...] }

var npc: NPC


func _ready() -> void:
	radius = 1.4
	super._ready()


func prompt_key() -> String:
	return "PROMPT_TALK"


func interact(_player: Player) -> void:
	var d: Dictionary = npc.type.dialogue
	var lines: Array = d.get("default", [])
	for key in d:
		if String(key).begins_with("flag:") and WorldState.flags.has(String(key).trim_prefix("flag:")):
			lines = d[key]
	if Clock.is_night() and d.has("night"):
		lines = d["night"]
	(npc.brain as NPCBrain).talking = true
	# Quests may override the line set (offer, hint, turn-in).
	var quest_lines := Quests.talk_lines(npc.type.id)
	EventBus.npc_talked.emit(npc.type.id)
	EventBus.dialogue_requested.emit(npc.type.name_key, quest_lines if not quest_lines.is_empty() else PackedStringArray(lines))
	var give: String = d.get("gift", "")
	var flag := "gift_" + String(npc.type.id)
	if give != "" and not WorldState.flags.has(flag):
		WorldState.flags[flag] = true
		PlayerData.inventory.add(StringName(give), 1)
		EventBus.item_acquired.emit(StringName(give), 1)
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(npc):
		(npc.brain as NPCBrain).talking = false
