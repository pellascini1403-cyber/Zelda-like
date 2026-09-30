class_name Pickup
extends Node3D
## Loose item in the world (loot drops). Walk over it to collect — no button
## needed, keeps the touch flow uninterrupted.

const COLLECT_RADIUS := 1.7

var item_id: StringName
var count := 1
var _t := 0.0
var _check := 0.0
var _mesh: MeshInstance3D
var _vy := 3.0
var _settled := false


static func spawn(parent: Node, pos: Vector3, id: StringName, n: int = 1) -> Pickup:
	var p := Pickup.new()
	p.item_id = id
	p.count = n
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group(&"pickups")
	_mesh = MeshInstance3D.new()
	var it := DB.item(item_id)
	var color := ItemIcons.category_color(it.category if it else &"material")
	var m := BoxMesh.new()
	m.size = Vector3(0.28, 0.28, 0.28)
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat
	_mesh.rotation_degrees = Vector3(45, 0, 45)
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _settled:
		_vy -= 14.0 * delta
		var from := global_position
		var to := from + Vector3(0, _vy * delta - 0.05, 0)
		var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.3, to, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position.y += _vy * delta
		else:
			global_position.y = hit["position"].y + 0.25
			_settled = true
	_mesh.rotation.y += delta * 2.0
	_mesh.position.y = sin(_t * 3.0) * 0.08
	_check -= delta
	if _check > 0.0 or Game.player == null:
		return
	_check = 0.15
	if _t > 0.5 and Game.player.global_position.distance_to(global_position) < COLLECT_RADIUS:
		collect()
	if _t > 300.0:
		queue_free()


func collect() -> void:
	var added := PlayerData.inventory.add(item_id, count)
	if added <= 0:
		EventBus.toast.emit(tr("TOAST_INVENTORY_FULL"))
		_check = 2.0
		return
	EventBus.item_acquired.emit(item_id, added)
	Audio.play_at(&"pickup", global_position, -4.0)
	count -= added
	if count <= 0:
		queue_free()
