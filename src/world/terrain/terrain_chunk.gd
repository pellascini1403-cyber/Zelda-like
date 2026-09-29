class_name TerrainChunk
extends Node3D
## One 64 m streamed sector. Owns its terrain mesh, collision (LOD0 only),
## vegetation MultiMeshes and gameplay content (resource nodes, spawns).

signal gameplay_ready(chunk: TerrainChunk, slots: Array)
signal gameplay_released(chunk: TerrainChunk)

var coord: Vector2i
var lod: int = -1
var pending_lod: int = -1
var has_gameplay: bool = false
var region: StringName = &"valley"

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _veg_root: Node3D
var _gameplay_root: Node3D


func setup(c: Vector2i) -> void:
	coord = c
	name = "Chunk_%d_%d" % [c.x, c.y]
	position = Vector3(c.x * ChunkBuilder.CHUNK_SIZE, 0, c.y * ChunkBuilder.CHUNK_SIZE)


func apply(data: Dictionary, veg_distance: float) -> void:
	lod = data["lod"]
	_apply_mesh(data)
	_apply_collision(data)
	_apply_vegetation(data, veg_distance)
	_apply_gameplay(data)


func _apply_mesh(data: Dictionary) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["verts"]
	arrays[Mesh.ARRAY_NORMAL] = data["norms"]
	arrays[Mesh.ARRAY_COLOR] = data["cols"]
	arrays[Mesh.ARRAY_INDEX] = data["idx"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, WorldMaterials.get_mat(&"terrain"))
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Terrain"
		add_child(_mesh_instance)
	_mesh_instance.mesh = mesh
	# Terrain far away does not need to cast shadows.
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_collision(data: Dictionary) -> void:
	if lod != 0:
		if _body:
			_body.queue_free()
			_body = null
		return
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		_body.collision_layer = 1
		_body.collision_mask = 0
		add_child(_body)
		var cs := CollisionShape3D.new()
		cs.name = "Ground"
		cs.shape = HeightMapShape3D.new()
		_body.add_child(cs)
	var n: int = data["grid"]
	var step: float = data["step"]
	var cs: CollisionShape3D = _body.get_node("Ground")
	var shape: HeightMapShape3D = cs.shape
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = data["collision"]
	# HeightMapShape is centered and uses 1 unit spacing: scale & offset.
	cs.scale = Vector3(step, 1.0, step)
	cs.position = Vector3(ChunkBuilder.CHUNK_SIZE * 0.5, 0, ChunkBuilder.CHUNK_SIZE * 0.5)


func _apply_vegetation(data: Dictionary, veg_distance: float) -> void:
	if _veg_root:
		_veg_root.queue_free()
		_veg_root = null
	if not data.has("veg"):
		return
	_veg_root = Node3D.new()
	_veg_root.name = "Vegetation"
	add_child(_veg_root)
	var veg: Dictionary = data["veg"]
	var far := veg_distance * 4.0
	var near := veg_distance * 1.3
	for species in MeshKit.TREES:
		var t: Array = veg.get(species, [])
		if t.is_empty():
			continue
		var def: Array = MeshKit.TREES[species]
		var mat := &"crystal" if species == &"crystal" else &"foliage"
		if lod == 0 and def[0] != def[1]:
			# HLOD: full tree near, simplified tree further out, same sector.
			_add_mm(t, def[0], mat, true, near)
			_add_mm(t, def[1], mat, false, far, near)
		else:
			_add_mm(t, def[1] if lod > 0 else def[0], mat, lod == 0, far)
	_add_mm(veg[&"rock"], &"rock" if lod == 0 else &"rock_lod", &"rock", lod == 0, far if lod == 0 else far * 0.6)
	if lod == 0:
		# Visibility ranges are measured to the sector's centre, so pad them by
		# the sector half-diagonal; the grass shader fades each blade itself.
		var pad := ChunkBuilder.CHUNK_SIZE * 0.72
		for kind in [&"bush", &"fern", &"reeds", &"cactus", &"rock_moss"]:
			_add_mm(veg[kind], kind, &"rock" if kind == &"rock_moss" else &"foliage", false, veg_distance * 1.5 + pad)
		_add_mm(veg[&"grass"], &"grass", &"grass", false, veg_distance + pad)
		_add_mm(veg[&"flower"], &"flower", &"vertex_color", false, veg_distance * 0.8 + pad)
		_add_tree_colliders(veg)


func _add_mm(transforms: Array, mesh_key: StringName, mat_key: StringName, shadows: bool, vis_range: float, vis_begin: float = 0.0) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = MeshKit.get_mesh(mesh_key)
	mm.instance_count = transforms.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord) + hash(mesh_key)
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = WorldMaterials.get_mat(mat_key)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and Quality.shadows_for_vegetation() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_begin = vis_begin
	mmi.visibility_range_end = vis_range
	mmi.visibility_range_end_margin = 10.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	_veg_root.add_child(mmi)


## Trees and boulders get cheap primitive colliders (trunks are climbable).
func _add_tree_colliders(veg: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "VegCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	_veg_root.add_child(body)
	for species in MeshKit.TREES:
		var def: Array = MeshKit.TREES[species]
		for t: Transform3D in veg.get(species, []):
			var s := t.basis.get_scale()
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = float(def[2]) * s.x
			shape.height = float(def[3]) * s.y
			cs.shape = shape
			cs.position = t.origin + Vector3(0, shape.height * 0.5, 0)
			body.add_child(cs)
	for t: Transform3D in veg[&"rock"]:
		var s := t.basis.get_scale()
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.85 * (s.x + s.z) * 0.5
		cs.shape = shape
		cs.position = t.origin + Vector3(0, s.y * 0.2, 0)
		body.add_child(cs)


func _apply_gameplay(data: Dictionary) -> void:
	var wants := data.has("nodes")
	if wants and not has_gameplay:
		has_gameplay = true
		_gameplay_root = Node3D.new()
		_gameplay_root.name = "Gameplay"
		_gameplay_root.top_level = true
		add_child(_gameplay_root)
		var slots: Array = []
		for s in data["nodes"]:
			if s["kind"] == "region":
				region = s["region"]
			else:
				slots.append(s)
		gameplay_ready.emit(self, slots)
	elif not wants and has_gameplay:
		release_gameplay()


func gameplay_root() -> Node3D:
	return _gameplay_root


func release_gameplay() -> void:
	if not has_gameplay:
		return
	has_gameplay = false
	gameplay_released.emit(self)
	if _gameplay_root:
		_gameplay_root.queue_free()
		_gameplay_root = null


func is_collision_ready() -> bool:
	return lod == 0 and _body != null
