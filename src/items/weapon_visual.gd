class_name WeaponVisual
extends RefCounted
## In-hand weapon representation. Uses ItemData.model when provided by the
## user; otherwise a neutral procedural stand-in shaped by weapon type so the
## reach reads correctly during development.


static func build(it: ItemData) -> Node3D:
	if it == null:
		return Node3D.new()
	if it.model != "" and ResourceLoader.exists(it.model):
		return (load(it.model) as PackedScene).instantiate()
	var root := Node3D.new()
	root.name = "Weapon_" + String(it.id)
	var b := MeshKit.Builder.new()
	var wood := Color(0.45, 0.32, 0.2)
	var metal := Color(0.62, 0.64, 0.68)
	var reach: float = it.w("reach", 1.8)
	match String(it.w("type", "sword")):
		"sword":
			b.box(Vector3(0, -0.06, 0), Vector3(0.05, 0.22, 0.05), wood)
			b.box(Vector3(0, 0.07, 0), Vector3(0.24, 0.04, 0.06), metal * 0.8)
			b.box(Vector3(0, 0.1 + reach * 0.28, 0), Vector3(0.07, reach * 0.55, 0.02), metal)
		"spear":
			b.box(Vector3(0, reach * 0.3, 0), Vector3(0.045, reach * 1.1, 0.045), wood)
			b.cylinder(Vector3(0, reach * 0.85, 0), 0.35, 0.07, 0.0, 4, metal)
		"hammer":
			b.box(Vector3(0, reach * 0.25, 0), Vector3(0.06, reach * 0.8, 0.06), wood)
			b.box(Vector3(0, reach * 0.66, 0), Vector3(0.42, 0.24, 0.24), metal * 0.85)
		"club":
			b.cylinder(Vector3(0, -0.1, 0), reach * 0.55, 0.035, 0.09, 5, wood, wood * 1.15, 0.2, 3)
		"rod":
			b.cylinder(Vector3(0, -0.1, 0), reach * 0.6, 0.03, 0.04, 5, wood)
			b.blob(Vector3(0, reach * 0.52, 0), Vector3(0.09, 0.12, 0.09), Color(1.0, 0.5, 0.2), Color(0.8, 0.25, 0.1), 0, 0.1, 2)
		_:
			b.box(Vector3(0, reach * 0.3, 0), Vector3(0.06, reach * 0.6, 0.06), metal)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = WorldMaterials.get_mat(&"vertex_color")
	# Grip points forward from the hand.
	mi.rotation_degrees = Vector3(-80, 0, 0)
	root.add_child(mi)
	return root
