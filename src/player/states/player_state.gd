class_name PlayerState
extends RefCounted
## Base class for player movement states. States are tiny: they read intent
## from the player, move the body, and return the name of the next state
## (or &"" to stay). Shared physics helpers live on Player.

var p: Player
var time_in_state := 0.0


func _init(player: Player) -> void:
	p = player


func state_name() -> StringName:
	return &"base"


func enter(_prev: StringName) -> void:
	pass


func exit() -> void:
	pass


func physics(_delta: float) -> StringName:
	return &""


## Visual/animation label for this state.
func anim() -> StringName:
	return state_name()


func allows_attack() -> bool:
	return false


func allows_block() -> bool:
	return false
