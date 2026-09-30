class_name StealBehavior
extends AIBehavior
## On a hit it snatches glimmer and runs. Catch it (it tires) and it drops
## everything, with interest; lose it and the glimmer is gone.
## Tuning: steal_amount, escape_distance.

var stolen := 0


func _init(brain: AIBrain) -> void:
	super(brain)
	c.died_signal.connect(_on_died)


func states() -> Array:
	return [ThiefFleeState.new(b)]


func on_hit(body: Node) -> void:
	if body != Game.player or stolen > 0 or PlayerData.glimmer <= 0:
		return
	stolen = mini(PlayerData.glimmer, int(param("steal_amount", 15)))
	PlayerData.glimmer -= stolen
	EventBus.toast.emit(TranslationServer.translate("TOAST_STOLEN") % stolen)
	Audio.play_at(&"coin", c.global_position, 0.0)


func pre_tick(_delta: float) -> StringName:
	if stolen > 0 and b.current.id() in [&"chase", &"attack", &"search"]:
		return &"thief_flee"
	return &""


func _on_died(_cr: Creature) -> void:
	if stolen > 0:
		var back := stolen + maxi(3, stolen / 4)
		PlayerData.glimmer += back
		EventBus.toast.emit(TranslationServer.translate("TOAST_RECOVERED") % back)
		Audio.play_ui(&"coin", -4.0)
		stolen = 0


class ThiefFleeState:
	extends AIState

	func id() -> StringName:
		return &"thief_flee"

	func anim() -> StringName:
		return &"run"

	func tick(_delta: float) -> StringName:
		var pl := Game.player
		if pl == null:
			return &""
		var away := c.global_position - pl.global_position
		away.y = 0.0
		if away.length() < 0.1:
			away = c.facing_dir()
		# Sprints first, then tires: the chase is winnable.
		var speed := c.type.run_speed * (1.35 if t < 6.0 else 0.8)
		c.go_to(c.global_position + away.normalized() * 8.0, speed)
		if away.length() > float(c.type.ai_value("escape_distance", 55.0)):
			Effects.sparks(c, c.global_position + Vector3.UP, ArtStyle.vfx_color(c.type), 0.4)
			c.dead = true
			c.queue_free()
		return &""
