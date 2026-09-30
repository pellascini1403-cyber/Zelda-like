class_name FrontArmorBehavior
extends AIBehavior
## A shell or shield in front: hits from the front glance off (sparks, a
## clang) and barely stagger it. Get behind it, or stagger it with slams,
## explosions or a parry: it flips onto its back, helpless and soft.
## Tuning: armor_arc (deg, half-angle), armor_mult, flipped_time.


func states() -> Array:
	return [FlippedState.new(b)]


func filter_damage(info: DamageInfo) -> void:
	if b.current.id() == &"flipped":
		info.amount *= 1.8
		return
	if info.kind in [&"slam", &"explosion", &"environment", &"fall"] or info.source == null:
		return
	var to := info.source.global_position - c.global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		return
	var arc := deg_to_rad(float(param("armor_arc", 70.0)))
	if c.facing_dir().dot(to.normalized()) > cos(arc):
		info.amount *= float(param("armor_mult", 0.1))
		info.poise_damage *= 0.25
		info.knockback *= 0.2
		Effects.sparks(c, c.global_position + Vector3.UP * c.type.collider_height * 0.6 + to.normalized() * c.type.collider_radius, Color(1.0, 0.9, 0.6), 0.2)
		Audio.play_at(&"block", c.global_position, -2.0)
		EventBus.noise_emitted.emit(c.global_position, 6.0, c)


func on_stagger() -> StringName:
	return &"flipped"


class FlippedState:
	extends AIState

	func id() -> StringName:
		return &"flipped"

	func enter() -> void:
		c.stop()
		b.stagger_time = 0.0
		c.visual.rotation.z = PI
		Effects.dust(c, c.global_position, 1.0)

	func exit() -> void:
		c.visual.rotation.z = 0.0

	func tick(_delta: float) -> StringName:
		if t > float(c.type.ai_value("flipped_time", 3.0)):
			c.perception.alert(Game.player.global_position if Game.player else c.global_position)
			return &"chase"
		return &""
