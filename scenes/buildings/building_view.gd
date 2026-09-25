class_name BuildingView
extends Node3D
## A building: the model, a wireframe ghost shown until it's built, a label and collision. In M5 a
## machine can also wear an overlay (frost in a cold snap, soot once a meteor has hit it) and
## smoke while damaged.

var model: Node3D
var ghost: MeshInstance3D
var label: WorldLabel
var glow_mat: StandardMaterial3D
var in_stack: ItemStackView
var out_stack: ItemStackView

var _built_known := false
var _was_built := false
var _pop_t := -1.0
var _puff: CPUParticles3D
var _overlay: Material
var _smoke: CPUParticles3D


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
	if built and _built_known and not _was_built:
		_celebrate()
	_built_known = true
	_was_built = built
	model.visible = built
	if ghost:
		ghost.visible = not built
	if in_stack:
		in_stack.visible = built
		out_stack.visible = built


## A building finished: it springs up and throws a puff of dust.
func _celebrate() -> void:
	if SaveManager.settings.get("reduced_effects", false):
		return
	_pop_t = 0.0
	if _puff == null:
		_puff = make_puff(GameState.defs.juice.puff_amount, 1.8)
		add_child(_puff)
	_puff.restart()


func _process(delta: float) -> void:
	if _pop_t < 0.0:
		return
	var j := GameState.defs.juice
	_pop_t += delta
	if _pop_t >= j.building_pop_time:
		_pop_t = -1.0
		model.scale = Vector3.ONE
		return
	# Springs up with a little squash: wider while short, narrower while tall.
	var s := 1.0 - (1.0 - j.building_pop_from) * cos(_pop_t * j.building_pop_frequency) * exp(-_pop_t * j.building_pop_decay)
	var w := (1.0 + 1.0 / sqrt(s)) * 0.5 * s
	model.scale = Vector3(w, s, w)


## A one-shot ring of dust (buildings finishing, landers touching down). Call restart() to fire it.
static func make_puff(amount: int, ring_radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = ring_radius
	p.emission_ring_inner_radius = ring_radius * 0.67
	p.emission_ring_height = 0.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -3.0, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var mat := ItemVisuals.unshaded(Color(Color("e8d7c4"), 0.8))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.mesh = q
	p.position.y = 0.2
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Draws the model again with this material over it (frost, soot), or nothing. The extra pass is
## only paid while an overlay is on.
func set_overlay(mat: Material) -> void:
	if mat == _overlay:
		return
	_overlay = mat
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Model":
			(mi as MeshInstance3D).material_overlay = mat


## Smoke rising from a meteor-damaged machine (not with "Fewer effects").
func set_smoking(on: bool) -> void:
	if on and _smoke == null:
		if SaveManager.settings.get("reduced_effects", false):
			return
		_smoke = make_smoke()
		add_child(_smoke)
	if _smoke:
		_smoke.emitting = on


static func make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 14
	p.lifetime = 2.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 18.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0.3, 0.4, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	var mat := ItemVisuals.unshaded(Color(Color("3a3230"), 0.7))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.mesh = q
	p.position.y = 1.6
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


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
