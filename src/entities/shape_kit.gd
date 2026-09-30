class_name ShapeKit
extends RefCounted
## Cached primitive meshes for placeholder characters. Every NPC, enemy and
## animal of the same size shares one mesh resource (mobile: fewer uploads).

static var _cache: Dictionary = {}


static func _k(parts: Array) -> String:
	return ",".join(parts.map(func(x: Variant) -> String: return str(snappedf(float(x), 0.005)) if (x is float or x is int) else str(x)))


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "cap" + _k([radius, height])
	if not _cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = maxf(height, radius * 2.0)
		m.radial_segments = 10
		m.rings = 4
		_cache[key] = m
	return _cache[key]


static func sphere(radius: float, segments: int = 12) -> SphereMesh:
	var key := "sph" + _k([radius, segments])
	if not _cache.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = maxi(segments / 2, 3)
		_cache[key] = m
	return _cache[key]


## Pointed cone along +Y (base at -height/2). The enemy family's spike.
static func cone(radius: float, height: float, segments: int = 5) -> CylinderMesh:
	return cyl(0.0, radius, height, segments)


static func cyl(top: float, bottom: float, height: float, segments: int = 10) -> CylinderMesh:
	var key := "cyl" + _k([top, bottom, height, segments])
	if not _cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_cache[key] = m
	return _cache[key]


static func box(size: Vector3) -> BoxMesh:
	var key := "box" + _k([size.x, size.y, size.z])
	if not _cache.has(key):
		var m := BoxMesh.new()
		m.size = size
		_cache[key] = m
	return _cache[key]


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "tor" + _k([inner, outer])
	if not _cache.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 14
		m.ring_segments = 6
		_cache[key] = m
	return _cache[key]


## Flat angular blade (wings, tatters, fins): a 3-sided prism squashed thin.
static func blade(length: float, width: float, thickness: float = 0.04) -> CylinderMesh:
	var key := "bld" + _k([length, width, thickness])
	if not _cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = width
		m.height = length
		m.radial_segments = 3
		m.rings = 1
		_cache[key] = m
	return _cache[key]


## One mesh from many primitive parts ([[Mesh, Transform3D], ...]): a
## cluster of caps or a thicket of thorns becomes a single draw call.
static func merged(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Array in parts:
		st.append_from(p[0], 0, p[1])
	return st.commit()
