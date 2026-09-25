class_name NodeBatch
extends Node3D
## Draws every resource node in one MultiMesh per resource (the node's baked model tinted by its
## colour), so a planet's fifteen or so rock and crystal clusters cost three draw calls.

var _groups: Array[Dictionary] = []


func setup(views: Array[ResourceNodeView]) -> void:
	var by_def := {}
	for v in views:
		if not by_def.has(v.def):
			by_def[v.def] = []
		by_def[v.def].append(v)
	for def: ResourceNodeDef in by_def:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = def.mesh if def.mesh else _placeholder(def)
		mm.instance_count = by_def[def].size()
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Nodes_" + def.item
		mmi.multimesh = mm
		mmi.material_override = _material(def)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_groups.append({"mm": mm, "views": by_def[def]})
	update_view()


func update_view() -> void:
	for g in _groups:
		var mm: MultiMesh = g.mm
		var views: Array = g.views
		for i in views.size():
			mm.set_instance_transform(i, (views[i] as ResourceNodeView).model_transform())


## The baked model is vertex-coloured greys, tinted by the node's colour.
static func _material(def: ResourceNodeDef) -> StandardMaterial3D:
	var mat := ItemVisuals.lambert(def.color)
	mat.vertex_color_use_as_albedo = def.mesh != null
	mat.vertex_color_is_srgb = true
	if def.emissive != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = def.emissive
	return mat


## Three rocks (or crystals) merged, for a node with no baked model.
static func _placeholder(def: ResourceNodeDef) -> Mesh:
	var crystal := def.translucent
	var mesh := MeshUtil.octahedron(0.55) if crystal else MeshUtil.icosahedron(0.55)
	var parts := []
	for i in 3:
		var a := float(i) / 3.0 * TAU
		var basis := Basis.from_euler(Vector3(i * 0.9, i * 1.7, i * 0.4)) * Basis.from_scale(Vector3(1, 1.5 if crystal else 0.8, 1))
		parts.append([mesh, Transform3D(basis, Vector3(cos(a) * 0.45, 0.35 + i * 0.1, sin(a) * 0.45)), Color.WHITE])
	return MeshUtil.merge(parts)
