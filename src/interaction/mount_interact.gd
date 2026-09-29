class_name MountInteract
extends Interactable
## "Mount" prompt on a rideable creature.

var mount: Mount


func _ready() -> void:
	radius = 1.6
	super._ready()


func prompt_key() -> String:
	return "PROMPT_MOUNT"


func can_interact() -> bool:
	return mount != null and not mount.dead and mount.rider == null


func interact(player: Player) -> void:
	player.ride(mount)
