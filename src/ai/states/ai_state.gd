class_name AIState
extends RefCounted
## Base AI state. Keep states short and single-purpose.

var b: AIBrain
var c: Creature
var t := 0.0


func _init(brain: AIBrain) -> void:
	b = brain
	c = brain.c


func id() -> StringName:
	return &"base"


func anim() -> StringName:
	return &"idle"


func enter() -> void:
	pass


func exit() -> void:
	pass


func tick(_delta: float) -> StringName:
	return &""


# --- Shared transitions -------------------------------------------------------------------
## Standard reaction to the player for hostile creatures.
func hostile_check() -> StringName:
	var p := c.perception
	if p.awareness >= 1.0:
		return &"chase"
	if p.awareness >= 0.45 or p.recently_heard(1.0):
		return &"investigate"
	return &""


func low_health() -> bool:
	return c.health.ratio() <= float(c.type.ai_value("flee_hp", 0.0))


func random_point_near(center: Vector3, radius: float) -> Vector3:
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	return center + Vector3(cos(a) * r, 0, sin(a) * r)
