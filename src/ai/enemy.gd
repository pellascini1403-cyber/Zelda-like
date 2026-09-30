class_name Enemy
extends Creature
## Hostile creature. Behaviour is entirely data-driven (EntityType.ai /
## attacks); species differ by numbers and attack sets, not by code.


func _on_built() -> void:
	add_to_group(&"creatures")
	if not hidden:
		add_to_group(&"enemies")
	respawn_hours = float(type.ai_value("respawn_hours", 72.0))
	if not EventBus.time_period_changed.is_connected(_on_period):
		EventBus.time_period_changed.connect(_on_period)


## Night-only creatures (wisps) dissolve at dawn unless mid-fight; day-only
## ones at dusk. They are not "killed": no loot, no respawn timer.
func _on_period(_period: StringName) -> void:
	if dead or type == null or (brain and brain.aggro):
		return
	var wrong := (type.active_period == &"night" and not Clock.is_night()) or (type.active_period == &"day" and Clock.is_night())
	if wrong:
		dead = true
		Effects.sparks(self, global_position + Vector3.UP * type.collider_height * 0.5, ArtStyle.vfx_color(type), 0.5)
		queue_free()


func _make_brain() -> AIBrain:
	return AIBrain.new(self)
