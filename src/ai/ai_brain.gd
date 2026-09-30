class_name AIBrain
extends RefCounted
## Modular state machine. States are small classes under src/ai/states/;
## each returns the next state name or &"". The brain owns shared memory
## (target, cooldowns, stagger) and exposes hooks the body calls.
##
## Enemy states: idle, patrol, investigate, chase, attack, retreat, search,
## flee, sleep, react. Animals and NPCs register subsets.

var c: Creature
var states: Dictionary = {}
var current: AIState
var cooldowns: Dictionary = {}
var stagger_time := 0.0
var aggro := false
var behaviors: Array[AIBehavior] = []
## Module hooks read by the stock states: a swarm member waiting its turn
## may not start an attack; `chase_offset` shifts the chase goal (orbits);
## `flee_from` (if finite) is what the next flee runs from.
var attack_blocked := false
var chase_offset := Vector3.ZERO
var flee_from := Vector3.INF


func _init(creature: Creature) -> void:
	c = creature
	_register()
	var start := _initial_state()
	for name in c.type.behaviors:
		var m := AIBehavior.make(name, self)
		if m == null:
			continue
		behaviors.append(m)
		for s: AIState in m.states():
			states[s.id()] = s
		if m.initial_state() != &"":
			start = m.initial_state()
	current = states.get(start, states.values()[0])
	current.enter()


## Override to choose the state set.
func _register() -> void:
	for s: AIState in [IdleState.new(self), PatrolState.new(self), InvestigateState.new(self), ChaseState.new(self),
			AttackState.new(self), RetreatState.new(self), SearchState.new(self), FleeState.new(self),
			SleepState.new(self), ReactState.new(self)]:
		states[s.id()] = s


func _initial_state() -> StringName:
	return &"patrol"


func tick(delta: float) -> void:
	for k in cooldowns.keys():
		cooldowns[k] -= delta
		if cooldowns[k] <= 0.0:
			cooldowns.erase(k)
	if stagger_time > 0.0:
		stagger_time -= delta
		if current.id() != &"react" and not current.id() in _stagger_states:
			var alt := &""
			for m in behaviors:
				alt = m.on_stagger()
				if alt != &"":
					break
			change(alt if alt != &"" else &"react")
	for m in behaviors:
		var forced := m.pre_tick(delta)
		if forced != &"" and forced != current.id():
			change(forced)
			break
	current.t += delta
	var next := current.tick(delta)
	if next != &"":
		change(next)


func change(next: StringName) -> void:
	if not states.has(next) or next == current.id():
		return
	current.exit()
	current = states[next]
	current.t = 0.0
	current.enter()
	var is_aggro := next in [&"chase", &"attack", &"retreat", &"swoop", &"surface", &"burrowing", &"thief_flee"] and c.kind_is_hostile()
	if is_aggro != aggro:
		aggro = is_aggro
		Game.register_aggro(c, aggro)


var _stagger_states: Array[StringName] = [&"flipped"]


func filter_damage(info: DamageInfo) -> void:
	for m in behaviors:
		m.filter_damage(info)


func notify_hit(body: Node) -> void:
	for m in behaviors:
		m.on_hit(body)


func attack_element(a: AttackData) -> StringName:
	for m in behaviors:
		var e := m.attack_element(a)
		if e != &"":
			return e
	return a.element


func has_module(script: Script) -> bool:
	for m in behaviors:
		if m.get_script() == script:
			return true
	return false


func state_name() -> StringName:
	return current.id()


func anim_state() -> StringName:
	return current.anim()


func is_unaware() -> bool:
	return current.id() in [&"idle", &"patrol", &"sleep", &"lurk", &"cling"] and c.perception.awareness < 0.5


func is_sleeping() -> bool:
	return current.id() == &"sleep"


# --- Hooks -----------------------------------------------------------------------------------
func on_hurt(source: Node3D) -> void:
	if source == Game.player:
		c.perception.alert(source.global_position)
		alert_group(source.global_position)


func on_stagger(duration: float) -> void:
	stagger_time = maxf(stagger_time, duration)


## Nearby members of the same camp / pack join in.
func alert_group(pos: Vector3) -> void:
	if c.group_id == "":
		return
	for other in c.get_tree().get_nodes_in_group(&"creatures"):
		if other != c and other is Creature and (other as Creature).group_id == c.group_id and not (other as Creature).dead:
			if (other as Creature).global_position.distance_to(c.global_position) < 30.0:
				(other as Creature).perception.alert(pos)


func cooldown_ready(key: StringName) -> bool:
	return not cooldowns.has(key)


func set_cooldown(key: StringName, t: float) -> void:
	cooldowns[key] = t


## Picks an attack that fits the current distance (weighted random).
func pick_attack(dist: float) -> AttackData:
	var options: Array[AttackData] = []
	var total := 0.0
	for a in c.type.attacks:
		if a.type == &"module":
			continue
		if dist >= a.range_min and dist <= a.range_max and cooldown_ready(a.id):
			options.append(a)
			total += a.weight
	if options.is_empty():
		return null
	var roll := randf() * total
	for a in options:
		roll -= a.weight
		if roll <= 0.0:
			return a
	return options[0]


## A module-owned attack by id (type "module": never picked by chase).
func attack_by_id(id: StringName) -> AttackData:
	for a in c.type.attacks:
		if a.id == id:
			return a
	return null


func max_attack_range() -> float:
	var r := 1.5
	for a in c.type.attacks:
		r = maxf(r, a.range_max)
	return r
