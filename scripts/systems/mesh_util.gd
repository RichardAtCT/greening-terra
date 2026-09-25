class_name MeshUtil
extends RefCounted
## Small procedural mesh helpers for the low-poly, flat-shaded placeholder look.


## Flat-shaded mesh from triangles (every 3 points is a face, clockwise seen from outside, as Godot expects).
static func flat_mesh(points: PackedVector3Array, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(points.size())
	for i in range(0, points.size(), 3):
		var n := (points[i + 2] - points[i]).cross(points[i + 1] - points[i]).normalized()
		normals[i] = n
		normals[i + 1] = n
		normals[i + 2] = n
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Triangle soup of a primitive mesh, transformed (so meshes can be merged and flat-shaded).
static func triangles_of(mesh: Mesh, xform := Transform3D.IDENTITY) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var out := PackedVector3Array()
	if idx.is_empty():
		for v in verts:
			out.append(xform * v)
	else:
		for i in idx:
			out.append(xform * verts[i])
	return out


static func icosahedron(radius: float) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5],
		[2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var pts := PackedVector3Array()
	for f in faces:
		for i in f:
			pts.append((v[i] as Vector3).normalized() * radius)
	return flat_mesh(_flip(pts))


static func octahedron(radius: float) -> ArrayMesh:
	var px := Vector3(radius, 0, 0)
	var py := Vector3(0, radius, 0)
	var pz := Vector3(0, 0, radius)
	var pts := PackedVector3Array()
	for sx in [1, -1]:
		for sy in [1, -1]:
			for sz in [1, -1]:
				var a: Vector3 = px * sx
				var b: Vector3 = py * sy
				var c: Vector3 = pz * sz
				# Keep outward winding for every octant.
				if sx * sy * sz > 0:
					pts.append_array([a, b, c])
				else:
					pts.append_array([a, c, b])
	return flat_mesh(_flip(pts))


## Flat disc lying on the ground (normal up), like THREE.CircleGeometry rotated flat.
static func disc(radius: float, segments: int) -> ArrayMesh:
	var pts := PackedVector3Array()
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		pts.append_array([Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)) * radius, Vector3(cos(a0), 0, sin(a0)) * radius])
	return flat_mesh(_flip(pts))


## Unit disc lying on the ground, split into rings so a shader can move its inner vertices (lakes).
static func water_disc(rings: int, segments: int) -> ArrayMesh:
	var pts := PackedVector3Array()
	for i in rings:
		var r0 := float(i) / rings
		var r1 := float(i + 1) / rings
		for j in segments:
			var a0 := TAU * j / segments
			var a1 := TAU * (j + 1) / segments
			var i0 := Vector3(cos(a0), 0, sin(a0)) * r0
			var i1 := Vector3(cos(a1), 0, sin(a1)) * r0
			var o0 := Vector3(cos(a0), 0, sin(a0)) * r1
			var o1 := Vector3(cos(a1), 0, sin(a1)) * r1
			if i == 0:
				pts.append_array([Vector3.ZERO, o0, o1])
			else:
				pts.append_array([i0, o0, o1, i0, o1, i1])
	return flat_mesh(pts)


## Flat ring on the ground.
static func ring(inner: float, outer: float, segments: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var i0 := Vector3(cos(a0), 0, sin(a0)) * inner
		var i1 := Vector3(cos(a1), 0, sin(a1)) * inner
		var o0 := Vector3(cos(a0), 0, sin(a0)) * outer
		var o1 := Vector3(cos(a1), 0, sin(a1)) * outer
		pts.append_array([i0, o1, o0, i0, i1, o1])
	return _flip(pts)


## Low-poly tree: brown trunk and white crown (tinted per instance by MultiMesh colour).
static func tree() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.1
	trunk.bottom_radius = 0.15
	trunk.height = 0.8
	trunk.radial_segments = 5
	trunk.rings = 0
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 0.75
	crown.height = 1.9
	crown.radial_segments = 6
	crown.rings = 0
	var a := triangles_of(trunk, Transform3D(Basis(), Vector3(0, 0.4, 0)))
	var b := triangles_of(crown, Transform3D(Basis(), Vector3(0, 1.65, 0)))
	var colors := PackedColorArray()
	for i in a.size():
		colors.append(Color(0.45, 0.32, 0.24))
	for i in b.size():
		colors.append(Color.WHITE)
	a.append_array(b)
	return flat_mesh(a, colors)


## Reverses triangle winding (the hand-written shapes above are listed counter-clockwise;
## Godot's front faces are clockwise, which is what flat_mesh and the built-in primitives use).
static func _flip(pts: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(0, pts.size(), 3):
		out.append_array([pts[i], pts[i + 2], pts[i + 1]])
	return out


## Merges parts into one flat-shaded, vertex-coloured mesh (one draw call).
## Each part is [mesh: Mesh, xform: Transform3D, color: Color].
static func merge(parts: Array) -> ArrayMesh:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for part in parts:
		var tri := triangles_of(part[0], part[1])
		pts.append_array(tri)
		for i in tri.size():
			cols.append(part[2])
	return flat_mesh(pts, cols)
