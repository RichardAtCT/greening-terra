class_name DroneView
extends Node3D
## A hovering hauler. Mirrors one DroneBrain.Drone from the sim.

var drone: DroneBrain.Drone
var hover_height := 2.4

var _cargo: ItemStackView
var _shadow: MeshInstance3D
var _phase := 0.0

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D
static var _shadow_mat: StandardMaterial3D


func setup(p_drone: DroneBrain.Drone, defs: GameDefs) -> void:
	drone = p_drone
	hover_height = defs.tuning.drone_hover_height
	_phase = randf() * TAU
	if _mesh == null:
		_mesh = _build_mesh()
		_mat = ItemVisuals.lambert(Color.WHITE)
		_mat.vertex_color_use_as_albedo = true
		_shadow_mat = ItemVisuals.unshaded(Color(0, 0, 0, 0.28))
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_cargo = ItemStackView.new()
	_cargo.layout = ItemStackView.Layout.HANGING
	_cargo.defs = defs
	_cargo.position.y = -0.45
	add_child(_cargo)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = MeshUtil.disc(0.45, 14)
	_shadow.material_override = _shadow_mat
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	update_view(0.0)


## Body, ring and eye in one vertex-coloured mesh (one draw call per drone).
static func _build_mesh() -> ArrayMesh:
	var body := SphereMesh.new()
	body.radius = 0.34
	body.height = 0.68
	body.radial_segments = 12
	body.rings = 8
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.58
	ring.rings = 20
	ring.ring_segments = 6
	var eye := SphereMesh.new()
	eye.radius = 0.1
	eye.height = 0.2
	eye.radial_segments = 8
	eye.rings = 6
	return MeshUtil.merge([
		[body, Transform3D.IDENTITY, Color("d9d4cc")],
		[ring, Transform3D.IDENTITY, Color("f2b35b")],
		[eye, Transform3D(Basis(), Vector3(0, 0.02, 0.3)), Color("b4f0ff")],
	])


func update_view(delta: float) -> void:
	_phase += delta * 3.0
	position = Vector3(drone.position.x, hover_height + sin(_phase) * 0.15, drone.position.y)
	rotation.y = drone.heading
	_shadow.global_position = Vector3(drone.position.x, 0.06, drone.position.y)
	_cargo.show_items(drone.cargo)
