class_name Campfire
extends Interactable
## Camp: cooking pot, rest (skip time), warmth, crafting station, thermal.
## A permanent FireSource provides light, heat and glider lift; rain can
## smother an uncovered campfire until it stops.

var _fire: FireSource
var _base: Node3D


func _ready() -> void:
	radius = 1.6
	super._ready()
	add_to_group(&"campfire")
	var b := MeshKit.Builder.new()
	for i in 8:
		var a := TAU * i / 8.0
		b.blob(Vector3(cos(a) * 0.75, 0.1, sin(a) * 0.75), Vector3(0.2, 0.14, 0.2), Color(0.5, 0.48, 0.45), Color(0.35, 0.34, 0.32), 0, 0.15, i)
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		b.cylinder(dir * 0.35, 0.12, 0.07, 0.07, 5, Color(0.3, 0.2, 0.13))
	# Pot on a tripod
	for i in 3:
		var a := TAU * i / 3.0
		b.cylinder(Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), 1.3, 0.03, 0.03, 4, Color(0.35, 0.25, 0.16))
	b.blob(Vector3(0, 0.75, 0), Vector3(0.32, 0.26, 0.32), Color(0.28, 0.28, 0.3), Color(0.18, 0.18, 0.2), 1, 0.02, 1)
	_base = MeshInstance3D.new()
	(_base as MeshInstance3D).mesh = b.commit()
	(_base as MeshInstance3D).material_override = WorldMaterials.get_mat(&"vertex_color")
	add_child(_base)
	_fire = FireSource.new()
	_fire.permanent = true
	_fire.spreads = false
	_fire.radius = 0.6
	add_child(_fire)


func prompt_key() -> String:
	return "PROMPT_CAMP"


func interact(player: Player) -> void:
	player.velocity = Vector3.ZERO
	EventBus.station_opened.emit(&"campfire", self)
