class_name ReactState
extends AIState
## Staggered (poise broken / parried). Open for punishment.


func id() -> StringName:
	return &"react"


func enter() -> void:
	c.stop()
	c.visual.play_action(&"hit", 0.5)


func tick(_delta: float) -> StringName:
	if b.stagger_time <= 0.0:
		return &"chase" if c.kind_is_hostile() else &"flee"
	return &""
