class_name GliderVisual
extends RefCounted
## The Vela de Brisa: a wide kite-sail on a bent-reed frame, held above and
## behind the shoulders. Original silhouette (a swept crescent sail with a
## tail streamer), replaceable by a user model at res://assets/models/vela.tscn.

const USER_MODEL := "res://assets/models/vela.tscn"


static func build() -> Node3D:
	if ResourceLoader.exists(USER_MODEL):
		return (load(USER_MODEL) as PackedScene).instantiate()
	var root := Node3D.new()
	root.name = "Vela"
	var b := MeshKit.Builder.new()
	var sail := Color(0.93, 0.86, 0.68)
	var sail_edge := Color(0.78, 0.42, 0.28)
	var frame := Color(0.42, 0.3, 0.2)
	# Crescent sail: fan of triangles from the mast tip, swept back.
	var tip := Vector3(0, 1.05, -0.2)
	var segs := 8
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / segs
		var x := lerpf(-1.9, 1.9, t)
		var sweep := pow(absf(x) / 1.9, 1.6) * 0.75
		pts.append(Vector3(x, 0.55 - sweep * 0.35, 0.25 + sweep))
	for i in segs:
		var c := sail if i % 2 == 0 else sail * 0.94
		b.tri(tip, pts[i + 1], pts[i], c)
		b.tri(tip, pts[i], pts[i + 1], c * 0.85)
	# Edge band
	for i in segs:
		var a := pts[i]
		var bb := pts[i + 1]
		b.quad(a, bb, bb + Vector3(0, -0.07, 0.03), a + Vector3(0, -0.07, 0.03), sail_edge)
		b.quad(a + Vector3(0, -0.07, 0.03), bb + Vector3(0, -0.07, 0.03), bb, a, sail_edge * 0.8)
	# Mast and cross spar
	b.cylinder(Vector3(0, 0.0, 0.0), 1.1, 0.025, 0.02, 4, frame)
	b.box(Vector3(0, 0.5, 0.32), Vector3(3.6, 0.035, 0.035), frame)
	# Tail streamer
	b.quad(Vector3(-0.05, 0.95, -0.15), Vector3(0.05, 0.95, -0.15), Vector3(0.03, 0.4, 0.9), Vector3(-0.03, 0.4, 0.9), sail_edge)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	mi.material_override = mat
	root.add_child(mi)
	return root
