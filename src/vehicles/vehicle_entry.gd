class_name VehicleEntry
extends Interactable
## "Drive" prompt on a parked vehicle.

var vehicle: Vehicle


func _ready() -> void:
	radius = 1.9
	super._ready()


func prompt_key() -> String:
	return "PROMPT_DRIVE"


func can_interact() -> bool:
	return vehicle != null and vehicle.driver == null and vehicle.disabled_for <= 0.0


func interact(player: Player) -> void:
	player.enter_vehicle(vehicle)
