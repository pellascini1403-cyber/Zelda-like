class_name NPC
extends Creature
## Villager / merchant / quest giver. Follows an hourly routine (data:
## EntityType.ai.schedule = [[hour, [x, z]], ...]), talks via the dialogue
## box, can't be hurt. NPCs are simulated only while near the player.

var dialogue_area: NPCTalk


func _on_built() -> void:
	add_to_group(&"creatures")
	add_to_group(&"npcs")
	health.invulnerable = true
	dialogue_area = NPCTalk.new()
	dialogue_area.npc = self
	add_child(dialogue_area)


func _make_brain() -> AIBrain:
	return NPCBrain.new(self)


func take_damage(_info: DamageInfo) -> void:
	Audio.play_at(&"npc_ouch", global_position, -6.0)


## Where the routine wants this NPC right now.
func scheduled_position() -> Vector3:
	var sched: Array = type.ai_value("schedule", [])
	if sched.is_empty():
		return home
	var best: Array = sched[sched.size() - 1]
	for entry in sched:
		if Clock.hour >= float(entry[0]):
			best = entry
	var p: Array = best[1]
	return Vector3(home.x + p[0], home.y, home.z + p[1])
