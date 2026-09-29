class_name Explosion
extends RefCounted
## Area blast: damage with falloff, physical impulse, optional fire, noise.


static func trigger(parent: Node, pos: Vector3, radius: float, damage: float, element: StringName, source: Node3D) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var world := (parent as Node3D).get_world_3d() if parent is Node3D else parent.get_viewport().world_3d
	for body in CombatUtils.sphere_query(world, pos, radius, CombatUtils.CREATURE_MASK | CombatUtils.PLAYER_MASK | CombatUtils.PROP_MASK):
		var to := body.global_position - pos
		var falloff := clampf(1.0 - to.length() / radius, 0.25, 1.0)
		var dir := to.normalized() if to.length() > 0.01 else Vector3.UP
		if body is RigidBody3D:
			(body as RigidBody3D).apply_central_impulse((dir + Vector3.UP * 0.6) * 9.0 * falloff * (body as RigidBody3D).mass)
		var info := DamageInfo.make(damage * falloff, source, (dir + Vector3.UP * 0.4) * 9.0 * falloff, element)
		info.kind = &"explosion"
		info.blockable = false
		info.poise_damage = 40.0 * falloff
		CombatUtils.deal(body, info)
	if element == &"fire":
		for i in 3:
			var a := randf() * TAU
			FireSource.ignite_at(parent, pos + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, radius * 0.7), randf_range(4.0, 7.0), 1)
	Effects.hit_spark(parent, pos, true)
	Effects.dust(parent, pos, 3.0)
	_flash(parent, pos, radius)
	Audio.play_at(&"explosion", pos, 4.0, 0.1)
	EventBus.noise_emitted.emit(pos, 30.0, source)
	EventBus.explosion.emit(pos, radius)
	if Game.camera_rig and Game.player:
		var d := Game.player.global_position.distance_to(pos)
		Game.camera_rig.add_trauma(clampf(1.0 - d / 30.0, 0.0, 0.8))


static func _flash(parent: Node, pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius * 0.6
	s.height = radius * 1.2
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.7, 0.3, 0.8)
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = pos
	var t := mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * 1.8, 0.3)
	t.tween_property(m, "albedo_color:a", 0.0, 0.3)
	t.chain().tween_callback(mi.queue_free)
