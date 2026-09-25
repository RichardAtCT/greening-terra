class_name ResourceNodeView
extends Node3D
## A diggable cluster of three rocks or crystals that shrinks as it empties and shakes when dug.

var _shake := 0.0
var _time := 0.0


func setup(def: ResourceNodeDef, pos: Vector2, rng: RandomNumberGenerator) -> void:
	position = Vector3(pos.x, 0, pos.y)
	var crystal := def.translucent
	var mesh := MeshUtil.octahedron(0.55) if crystal else MeshUtil.icosahedron(0.55)
	var mat := ItemVisuals.lambert(def.color)
	if def.emissive != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = def.emissive
	if crystal:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.88
	# Three rocks merged into one mesh, so each node is a single draw call.
	var parts := []
	for i in 3:
		var a := float(i) / 3.0 * TAU + rng.randf()
		var basis := Basis.from_euler(Vector3(rng.randf() * 3, rng.randf() * 3, rng.randf() * 3))
		basis = basis * Basis.from_scale(Vector3(1, 1.5 if crystal else 0.8, 1))
		parts.append([mesh, Transform3D(basis, Vector3(cos(a) * 0.45, 0.35 + i * 0.1, sin(a) * 0.45)), Color.WHITE])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshUtil.merge(parts)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func dug() -> void:
	_shake = 0.2


func update_view(stock: int, max_stock: int, delta: float) -> void:
	_time += delta
	var s := 0.001 if stock <= 0 else 0.45 + 0.55 * float(stock) / max_stock
	scale = Vector3.ONE * s
	if _shake > 0.0:
		_shake -= delta
		rotation.y = sin(_time * 60.0) * 0.08
