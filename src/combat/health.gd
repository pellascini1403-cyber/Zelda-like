class_name Health
extends Node
## Health + poise + elemental statuses for creatures and destructible props.
##
## Status effects are the glue of the systemic sandbox:
##   burning  -> damage over time, spreads fire to flammable things nearby
##   wet      -> immune to burning, takes double electric damage
##   shocked  -> brief stun, drops guard
##   chilled  -> slowed

signal damaged(info: DamageInfo)
signal died(info: DamageInfo)
signal staggered
signal status_changed(status: StringName, active: bool)

@export var max_health := 50.0
@export var max_poise := 10.0
@export var defense := 0.0
var health := 50.0
var poise := 10.0
var dead := false
var invulnerable := false
## element -> multiplier
var element_mult: Dictionary = {}
## status -> remaining seconds
var statuses: Dictionary = {}

var _poise_regen_delay := 0.0
var _burn_tick := 0.0


func setup(max_hp: float, max_p: float, def: float, mult: Dictionary) -> void:
	max_health = max_hp
	health = max_hp
	max_poise = max_p
	poise = max_p
	defense = def
	element_mult = mult
	dead = false
	statuses.clear()


func apply_damage(info: DamageInfo) -> float:
	if dead or invulnerable:
		return 0.0
	var mult: float = element_mult.get(String(info.element), 1.0)
	if info.element == &"electric" and has_status(&"wet"):
		mult *= 2.0
	var dmg := maxf(info.amount * mult - defense, info.amount * mult * 0.2)
	health -= dmg
	_poise_regen_delay = 2.0
	poise -= info.poise_damage
	match info.element:
		&"fire":
			if not has_status(&"wet"):
				add_status(&"burning", 4.0)
		&"electric":
			add_status(&"shocked", 0.8)
		&"cold", &"ice":
			add_status(&"chilled", 4.0)
		&"web":
			add_status(&"webbed", 2.5)
		&"water":
			add_status(&"wet", 6.0)
	damaged.emit(info)
	if health <= 0.0:
		health = 0.0
		dead = true
		died.emit(info)
	elif poise <= 0.0:
		poise = max_poise
		staggered.emit()
	return dmg


func heal(amount: float) -> void:
	if not dead:
		health = minf(health + amount, max_health)


func add_status(s: StringName, duration: float) -> void:
	if s == &"burning" and has_status(&"wet"):
		return
	if s == &"wet" and has_status(&"burning"):
		remove_status(&"burning")
	var had := statuses.has(s)
	statuses[s] = maxf(statuses.get(s, 0.0), duration)
	if not had:
		status_changed.emit(s, true)


func remove_status(s: StringName) -> void:
	if statuses.erase(s):
		status_changed.emit(s, false)


func has_status(s: StringName) -> bool:
	return statuses.has(s)


func ratio() -> float:
	return health / maxf(max_health, 1.0)


func tick(delta: float) -> void:
	if dead:
		return
	if _poise_regen_delay > 0.0:
		_poise_regen_delay -= delta
	else:
		poise = minf(poise + max_poise * 0.5 * delta, max_poise)
	for s in statuses.keys():
		statuses[s] -= delta
		if statuses[s] <= 0.0:
			remove_status(s)
	if has_status(&"burning"):
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			var d := DamageInfo.make(3.0, null, Vector3.ZERO, &"")
			d.kind = &"environment"
			d.poise_damage = 0.0
			# Route through the owner so the player's persistent vitals apply.
			if not CombatUtils.deal(get_parent(), d):
				apply_damage(d)
	# Rain keeps things wet (and therefore fire-proof but conductive).
	if Weather.rain > 0.3:
		add_status(&"wet", 3.0)
