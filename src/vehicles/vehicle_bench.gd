class_name VehicleBench
extends Interactable
## Vantrel Depot restoration bench: opens the Garage with restoration on.
## A long soot-iron bench with a worn silver top and a hoist frame.

func _ready() -> void:
	radius = 2.0
	super._ready()
	add_to_group(&"vehicle_benches")
	var root := Node3D.new()
	add_child(root)
	var parts := [
		["dark", ShapeKit.box(Vector3(2.6, 0.9, 1.0)), VehicleVisual.xf(Vector3(0, 0.45, 0))],
		["silver", ShapeKit.box(Vector3(2.8, 0.08, 1.15)), VehicleVisual.xf(Vector3(0, 0.94, 0))],
		["dark", ShapeKit.box(Vector3(0.12, 2.6, 0.12)), VehicleVisual.xf(Vector3(-1.3, 1.3, 0.5))],
		["dark", ShapeKit.box(Vector3(0.12, 2.6, 0.12)), VehicleVisual.xf(Vector3(1.3, 1.3, 0.5))],
		["silver", ShapeKit.box(Vector3(2.8, 0.14, 0.18)), VehicleVisual.xf(Vector3(0, 2.6, 0.5))],
		["dark", ShapeKit.cyl(0.02, 0.02, 1.2, 5), VehicleVisual.xf(Vector3(0.4, 2.0, 0.5))],
		["silver", ShapeKit.box(Vector3(0.3, 0.2, 0.2)), VehicleVisual.xf(Vector3(0.4, 1.35, 0.5))],
		["dark", ShapeKit.cyl(0.09, 0.09, 0.02, 10), VehicleVisual.xf(Vector3(0, 0.6, -0.51), Vector3(90, 0, 0))],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[1]
		mi.transform = part[2]
		mi.material_override = VehicleVisual.mat(part[0])
		root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 1.0, 1.15)
	cs.shape = box
	cs.position.y = 0.5
	body.add_child(cs)
	add_child(body)


func prompt_key() -> String:
	return "PROMPT_GARAGE"


func interact(player: Player) -> void:
	player.start_busy(&"interact", 0.3)
	Audio.play_at(&"vehicle_start", global_position, -8.0)
	EventBus.panel_requested.emit(&"garage", "bench")
