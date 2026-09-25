class_name DroneSwarm
extends Node3D
## Every hauler in three kinds of MultiMesh: the hulls, their ground shadows, and one per cargo
## item type. That's a handful of draw calls for all twelve (M3 used two or three per hauler).
## Mirrors the sim's DroneBrain.Drone list.

const MESH := preload("res://assets/meshes/drone.res")
## Cargo hangs below the hull, one item every CARGO_STEP metres.
const CARGO_TOP := -0.45
const CARGO_STEP := 0.3

var defs: GameDefs
var drones: Array[DroneBrain.Drone] = []

var _hulls: MultiMesh
var _shadows: MultiMesh
var _cargo: Dictionary = {}
var _phase: PackedFloat32Array = []


func setup(p_defs: GameDefs, max_drones: int) -> void:
	defs = p_defs
	_hulls = _multimesh("Hulls", MESH, max_drones, null)
	_shadows = _multimesh("Shadows", MeshUtil.disc(0.45, 14), max_drones, ItemVisuals.unshaded(Color(0, 0, 0, 0.28)))
	for item in defs.items:
		_cargo[item.id] = _multimesh("Cargo_" + item.id, ItemVisuals.mesh(item.shape), max_drones * defs.tuning.drone_capacity, ItemVisuals.material(item))


func add(d: DroneBrain.Drone) -> void:
	drones.append(d)
	_phase.append(randf() * TAU)
	var need := drones.size()
	if need > _hulls.instance_count:
		# More haulers than planned for (a bonus in M5): grow the buffers.
		for mm in [_hulls, _shadows]:
			mm.instance_count = need
		for id in _cargo:
			_cargo[id].instance_count = need * defs.tuning.drone_capacity
	update_view(0.0)


func update_view(delta: float) -> void:
	var hover := defs.tuning.drone_hover_height
	var counts := {}
	for i in drones.size():
		var d := drones[i]
		_phase[i] += delta * 3.0
		var pos := Vector3(d.position.x, hover + sin(_phase[i]) * 0.15, d.position.y)
		var basis := Basis(Vector3.UP, d.heading)
		_hulls.set_instance_transform(i, Transform3D(basis, pos + Vector3(0, -0.2, 0)))
		_shadows.set_instance_transform(i, Transform3D(Basis(), Vector3(d.position.x, 0.06, d.position.y)))
		for k in d.cargo.size():
			var id: StringName = d.cargo[k]
			var mm: MultiMesh = _cargo.get(id)
			if mm == null:
				continue
			var n: int = counts.get(id, 0)
			if n < mm.instance_count:
				mm.set_instance_transform(n, Transform3D(basis, pos + Vector3(0, CARGO_TOP - k * CARGO_STEP, 0)))
				counts[id] = n + 1
	_hulls.visible_instance_count = drones.size()
	_shadows.visible_instance_count = drones.size()
	for id in _cargo:
		_cargo[id].visible_instance_count = counts.get(id, 0)


func _multimesh(node_name: String, mesh: Mesh, count: int, material: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = maxi(count, 1)
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	if material:
		mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Haulers roam the whole map; don't let a stale AABB cull them.
	mmi.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 10, 120))
	add_child(mmi)
	return mm
