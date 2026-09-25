class_name DroneView
extends Node3D
## A hovering hauler. Mirrors one DroneBrain.Drone from the sim.

var drone: DroneBrain.Drone
var hover_height := 2.4

var _cargo: ItemStackView
var _shadow: MeshInstance3D
var _phase := 0.0

static var _body_mat: StandardMaterial3D
static var _ring_mat: StandardMaterial3D
static var _eye_mat: StandardMaterial3D
static var _shadow_mat: StandardMaterial3D


func setup(p_drone: DroneBrain.Drone, defs: GameDefs) -> void:
	drone = p_drone
	hover_height = defs.tuning.drone_hover_height
	_phase = randf() * TAU
	if _body_mat == null:
		_body_mat = ItemVisuals.lambert(Color("d9d4cc"))
		_ring_mat = ItemVisuals.lambert(Color("f2b35b"))
		_eye_mat = ItemVisuals.unshaded(Color("8fe3ff"))
		_shadow_mat = ItemVisuals.unshaded(Color(0, 0, 0, 0.28))
	var body := SphereMesh.new()
	body.radius = 0.34
	body.height = 0.68
	body.radial_segments = 12
	body.rings = 8
	_add(body, _body_mat, Vector3.ZERO)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.58
	ring.rings = 20
	ring.ring_segments = 6
	_add(ring, _ring_mat, Vector3.ZERO)
	var eye := SphereMesh.new()
	eye.radius = 0.1
	eye.height = 0.2
	eye.radial_segments = 8
	eye.rings = 6
	_add(eye, _eye_mat, Vector3(0, 0.02, 0.3))
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


func _add(mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func update_view(delta: float) -> void:
	_phase += delta * 3.0
	position = Vector3(drone.position.x, hover_height + sin(_phase) * 0.15, drone.position.y)
	rotation.y = drone.heading
	_shadow.global_position = Vector3(drone.position.x, 0.04, drone.position.y)
	_cargo.show_items(drone.cargo)
