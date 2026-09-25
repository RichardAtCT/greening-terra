class_name TerrainBuilder
extends RefCounted
## Builds the static ground, craters and decor rocks for a planet (deterministic from its seed).

const SIZE := 170.0
const SEGMENTS := 72
const FLAT_RADIUS := 33.0


static func height_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var n := sin(x * 0.21) * cos(z * 0.17) + sin((x - z) * 0.09) * 0.8
	# Inside the play area the facets only dip, so nothing on the ground (pads, moss) is pierced by
	# a bump, even with a 16-bit depth buffer.
	return (r - FLAT_RADIUS) * 0.3 * (0.7 + 0.35 * n) if r > FLAT_RADIUS else minf(0.0, n * 0.05)


## Flat-shaded ground with slightly varied brightness per triangle and mountains beyond the play area.
static func ground_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var step := SIZE / SEGMENTS
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	var half := SIZE * 0.5
	for iz in SEGMENTS:
		for ix in SEGMENTS:
			var x0 := -half + ix * step
			var z0 := -half + iz * step
			var a := Vector3(x0, height_at(x0, z0), z0)
			var b := Vector3(x0 + step, height_at(x0 + step, z0), z0)
			var c := Vector3(x0, height_at(x0, z0 + step), z0 + step)
			var d := Vector3(x0 + step, height_at(x0 + step, z0 + step), z0 + step)
			for tri in [[a, b, c], [b, d, c]]:
				var shade := 0.8 + rng.randf() * 0.2
				for p in tri:
					pts.append(p)
					cols.append(Color(shade, shade, shade))
	return MeshUtil.flat_mesh(pts, cols)


static func is_clear(planet: PlanetDef, x: float, z: float, margin := 0.0) -> bool:
	for zone in planet.clear_zones:
		if Vector2(x - zone.x, z - zone.y).length() <= zone.z + margin:
			return false
	return true


static func is_dry(planet: PlanetDef, x: float, z: float, margin := 0.0) -> bool:
	for lake in planet.lakes:
		if Vector2(x - lake.x, z - lake.y).length() <= lake.z + margin:
			return false
	return true


## Raised-rim craters as one MultiMesh (one draw call).
static func craters_multimesh(planet: PlanetDef, rng: RandomNumberGenerator, mesh: Mesh, count := 14) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var x := 0.0
		var z := 0.0
		for attempt in 200:
			x = (rng.randf() - 0.5) * 60.0
			z = (rng.randf() - 0.5) * 60.0
			if is_clear(planet, x, z, 1.0) and is_dry(planet, x, z, 2.0):
				break
		var s := 0.5 + rng.randf() * 0.9
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 0.6 + rng.randf() * 0.5, s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, -0.02, z)))
	return mm


static func rocks_multimesh(planet: PlanetDef, rng: RandomNumberGenerator, mesh: Mesh, count := 90) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var x := 0.0
		var z := 0.0
		for attempt in 200:
			var a := rng.randf() * TAU
			var r := 6.0 + rng.randf() * 40.0
			x = cos(a) * r
			z = sin(a) * r
			if is_clear(planet, x, z, 0.5) and is_dry(planet, x, z, 1.0):
				break
		var s := 0.35 + rng.randf() * 1.2
		var tilt := Basis.from_euler(Vector3((rng.randf() - 0.5) * 0.4, rng.randf() * TAU, (rng.randf() - 0.5) * 0.4))
		mm.set_instance_transform(i, Transform3D(tilt.scaled(Vector3(s, s * (0.6 + rng.randf() * 0.5), s)), Vector3(x, -0.05 * s, z)))
	return mm
