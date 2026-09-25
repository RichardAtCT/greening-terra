class_name BuildingView
extends Node3D
## A building placeholder: the model, a wireframe ghost shown until it's built, a label and collision.

var model: Node3D
var ghost: MeshInstance3D
var label: WorldLabel
var glow_mat: StandardMaterial3D
var in_stack: ItemStackView
var out_stack: ItemStackView


func setup(scene: PackedScene, pos: Vector2, collide_radius: float, label_height: float, label_scale: float) -> void:
	position = Vector3(pos.x, 0, pos.y)
	model = scene.instantiate()
	add_child(model)
	var glow := model.get_node_or_null("Glow") as MeshInstance3D
	if glow == null:
		glow = model.get_node_or_null("Blink") as MeshInstance3D
	if glow:
		# Each building pulses on its own, so give it its own copy of the glow material.
		glow_mat = (glow.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
		glow.material_override = glow_mat
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = collide_radius
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	body.add_child(shape)
	add_child(body)
	label = WorldLabel.new()
	label.scale_m = label_scale
	label.position.y = label_height
	add_child(label)


func add_ghost(footprint: Vector3) -> void:
	ghost = MeshInstance3D.new()
	ghost.mesh = _box_edges(footprint)
	ghost.material_override = ItemVisuals.unshaded(Color(Color("f2b35b"), 0.5))
	ghost.position.y = footprint.y * 0.5
	add_child(ghost)


## Adds IN/OUT pad item stacks at the given world offsets (relative to this building).
func add_pad_stacks(defs: GameDefs, in_offset: Vector2, out_offset: Vector2) -> void:
	in_stack = _stack(defs, in_offset)
	out_stack = _stack(defs, out_offset)


func set_built(built: bool) -> void:
	model.visible = built
	if ghost:
		ghost.visible = not built
	if in_stack:
		in_stack.visible = built
		out_stack.visible = built


func set_glow(alpha: float) -> void:
	if glow_mat:
		glow_mat.albedo_color.a = alpha


func _stack(defs: GameDefs, offset: Vector2) -> ItemStackView:
	var s := ItemStackView.new()
	s.defs = defs
	s.max_shown = defs.tuning.pad_stack_max
	s.layout = ItemStackView.Layout.PAD
	s.position = Vector3(offset.x, 0.1, offset.y)
	add_child(s)
	return s


static func _box_edges(size: Vector3) -> ArrayMesh:
	var h := size * 0.5
	var c := []
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				c.append(Vector3(x * h.x, y * h.y, z * h.z))
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var pts := PackedVector3Array()
	for e in edges:
		pts.append(c[e[0]])
		pts.append(c[e[1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return m
