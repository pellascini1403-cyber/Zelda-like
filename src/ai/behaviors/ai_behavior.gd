class_name AIBehavior
extends RefCounted
## A behaviour module: one reusable way of fighting or moving that any
## creature can opt into from data (`ai.behaviors: ["swoop", ...]`), with
## its tuning next to the other AI values. Modules never replace the state
## machine; they add states, pre-empt a state when their moment comes, or
## filter incoming damage. Several modules combine on one creature.
##
##   ambush        waits hidden near home, bursts out at close range
##   swoop         flyer: circles high, telegraphs its shadow, dives
##   front_armor   blocks hits from the front; a stagger flips it over
##   submerge      swimmer: invisible under water, surfaces to strike
##   burrow        travels under the sand, erupts under the target
##   drop_from_above  climber: waits on walls, drops on who passes below
##   phase         fades out of reach and back in
##   steal         snatches glimmer on a hit and runs
##   ignite        leaves burning ground; rain snuffs its flame
##   fire_shy      scatters away from fire and burning weapons
##   swarm         packs orbit the target and strike one at a time
##   storm_charged in storms: electric attacks, sparks, more damage
##   surfacer      big swimmers rise to breathe (spout), then sink
##   stalker       keeps its distance in the mist, closes in when you stop
##   current_rider rides sea currents to reposition, strikes downstream

var b: AIBrain
var c: Creature


func _init(brain: AIBrain) -> void:
	b = brain
	c = brain.c


## Extra states this module owns.
func states() -> Array:
	return []


## State to start in instead of the brain's default ("" = no opinion).
func initial_state() -> StringName:
	return &""


## Called every brain tick before the current state. Return a state name to
## switch to it right now, or &"".
func pre_tick(_delta: float) -> StringName:
	return &""


## Adjust (or cancel) incoming damage before Health sees it.
func filter_damage(_info: DamageInfo) -> void:
	pass


## A stagger landed. Return a state to go to instead of `react` (or &"").
func on_stagger() -> StringName:
	return &""


## One of this creature's attacks connected.
func on_hit(_body: Node) -> void:
	pass


## Attack element override (storm_charged...). &"" = keep the attack's own.
func attack_element(_a: AttackData) -> StringName:
	return &""


func param(key: String, default_value: Variant) -> Variant:
	return c.type.ai_value(key, default_value)


func player() -> Player:
	return Game.player as Player


static func make(name: String, brain: AIBrain) -> AIBehavior:
	match name:
		"ambush": return AmbushBehavior.new(brain)
		"swoop": return SwoopBehavior.new(brain)
		"front_armor": return FrontArmorBehavior.new(brain)
		"submerge": return SubmergeBehavior.new(brain)
		"burrow": return BurrowBehavior.new(brain)
		"drop_from_above": return DropBehavior.new(brain)
		"phase": return PhaseBehavior.new(brain)
		"steal": return StealBehavior.new(brain)
		"ignite": return IgniteBehavior.new(brain)
		"fire_shy": return FireShyBehavior.new(brain)
		"swarm": return SwarmBehavior.new(brain)
		"storm_charged": return StormChargedBehavior.new(brain)
		"surfacer": return SurfacerBehavior.new(brain)
		"stalker": return StalkerBehavior.new(brain)
		"current_rider": return CurrentRiderBehavior.new(brain)
	push_warning("AIBehavior: unknown behaviour " + name)
	return null


const KNOWN := ["ambush", "swoop", "front_armor", "submerge", "burrow", "drop_from_above", "phase", "steal",
	"ignite", "fire_shy", "swarm", "storm_charged", "surfacer", "stalker", "current_rider"]
