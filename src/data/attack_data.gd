class_name AttackData
extends Resource
## One attack of an enemy (or a weapon move). Timings are in seconds.

## melee | lunge | projectile | slam | pulse
@export var type: StringName = &"melee"
@export var id: StringName
@export var range_min: float = 0.0
@export var range_max: float = 2.0
@export var windup: float = 0.5
@export var active: float = 0.15
@export var recovery: float = 0.6
@export var cooldown: float = 1.5
@export var damage: float = 10.0
@export var knockback: float = 4.0
@export var poise_damage: float = 10.0
@export var reach: float = 1.8
## Half-angle of the hit arc in degrees.
@export var arc: float = 60.0
@export var radius: float = 0.0
@export var element: StringName = &""
@export var lunge_speed: float = 0.0
@export var projectile_speed: float = 14.0
@export var weight: float = 1.0
@export var blockable: bool = true


static func from_dict(d: Dictionary) -> AttackData:
	var a := AttackData.new()
	a.type = StringName(d.get("type", "melee"))
	a.id = StringName(d.get("id", String(a.type)))
	a.range_min = d.get("range_min", 0.0)
	a.range_max = d.get("range_max", 2.0)
	a.windup = d.get("windup", 0.5)
	a.active = d.get("active", 0.15)
	a.recovery = d.get("recovery", 0.6)
	a.cooldown = d.get("cooldown", 1.5)
	a.damage = d.get("damage", 10.0)
	a.knockback = d.get("knockback", 4.0)
	a.poise_damage = d.get("poise_damage", a.damage)
	a.reach = d.get("reach", a.range_max)
	a.arc = d.get("arc", 60.0)
	a.radius = d.get("radius", 0.0)
	a.element = StringName(d.get("element", ""))
	a.lunge_speed = d.get("lunge_speed", 0.0)
	a.projectile_speed = d.get("projectile_speed", 14.0)
	a.weight = d.get("weight", 1.0)
	a.blockable = d.get("blockable", true)
	return a
