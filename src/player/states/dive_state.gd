class_name DiveState
extends PlayerState
## Reduced diving: from the surface, dodge to dive. Move freely, sink
## gently, hold jump to rise; stamina is your breath (it drains, faster
## when dashing). Out of breath you start drowning — rise or find an air
## vent (a bubble column) to refill. Breath gear ("breath" armour, the
## deepwater broth buff) and
## swim gear ("swim_speed") make dives longer and faster.
## Same state for the lake, the coast and the sea.

const SPEED := 3.0
const DASH := 5.2
const SINK := 1.1
const RISE := 3.4
const BREATH_DRAIN := 3.2
const DASH_DRAIN := 9.0
const DROWN_DPS := 6.0

var _drown := 0.0


func state_name() -> StringName:
	return &"dive"


func anim() -> StringName:
	return &"swim"


func enter(_prev: StringName) -> void:
	p.velocity.y = -3.0
	Audio.play_at(&"splash", p.global_position, -2.0)
	p.spawn_splash()
	_drown = 0.0


func physics(delta: float) -> StringName:
	var move := p.move_dir()
	var dashing := p.wants_sprint() and move != Vector3.ZERO and p.vitals.stamina > 0.0
	var gear := 1.0 + PlayerData.armor_bonus("swim_speed")
	p.apply_horizontal(move * (DASH if dashing else SPEED) * gear + SeaCurrent.drift_at(p.global_position, p.get_tree()), 4.0, delta)
	var vy := -SINK
	if Input.is_action_pressed("jump"):
		vy = RISE * gear
	p.velocity.y = move_toward(p.velocity.y, vy, 6.0 * delta)
	p.face_move(delta * 0.6)
	p.move_and_slide()
	p.health.add_status(&"wet", 5.0)
	p.health.remove_status(&"burning")
	if Input.is_action_just_pressed("interact"):
		p.interactor.try_interact()
	# Breath.
	if AirVent.refill_at(p.global_position, p.get_tree()):
		p.vitals.stamina = minf(p.vitals.stamina + AirVent.REFILL * delta, PlayerData.max_stamina)
		if p.vitals.ratio() > 0.35:
			p.vitals.exhausted = false
		_drown = 0.0
	else:
		var drain := (DASH_DRAIN if dashing else BREATH_DRAIN) * clampf(1.0 - PlayerData.breath_bonus(), 0.25, 1.0)
		p.vitals.drain(drain * delta)
	if p.vitals.stamina <= 0.0:
		_drown += delta
		if _drown >= 1.0:
			_drown = 0.0
			var info := DamageInfo.make(DROWN_DPS, null, Vector3.ZERO)
			info.kind = &"environment"
			info.blockable = false
			p.take_damage(info)
			if p.is_dead():
				return &"dead"
	# Back at the surface.
	if p.global_position.y > WorldGen.SEA_LEVEL - SwimState.FLOAT_OFFSET - 0.1 and p.velocity.y >= 0.0:
		return &"swim"
	if p.water_depth() < p.SWIM_DEPTH - 0.25 and p.is_on_floor_probe():
		return &"ground"
	return &""
