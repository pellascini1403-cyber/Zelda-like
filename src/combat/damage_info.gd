class_name DamageInfo
extends RefCounted
## Everything a hit carries. Built by attackers, consumed by Health.

var amount: float = 0.0
var source: Node3D
var element: StringName = &""
var knockback: Vector3 = Vector3.ZERO
var poise_damage: float = 0.0
var blockable: bool = true
var is_critical: bool = false
## "melee", "projectile", "explosion", "fall", "environment"
var kind: StringName = &"melee"


static func make(amt: float, src: Node3D, knock: Vector3 = Vector3.ZERO, elem: StringName = &"") -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amt
	d.source = src
	d.knockback = knock
	d.element = elem
	d.poise_damage = amt
	return d
