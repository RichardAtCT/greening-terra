class_name DroneView
extends Node3D
## A hovering hauler. Mirrors one DroneBrain.Drone from the sim.

const MESH := preload("res://assets/meshes/drone.res")

var drone: DroneBrain.Drone
var hover_height := 2.4

var _cargo: ItemStackView
var _shadow: MeshInstance3D
var _phase := 0.0

static var _shadow_mat: StandardMaterial3D


func setup(p_drone: DroneBrain.Drone, defs: GameDefs) -> void:
	drone = p_drone
	hover_height = defs.tuning.drone_hover_height
	_phase = randf() * TAU
	if _shadow_mat == null:
		_shadow_mat = ItemVisuals.unshaded(Color(0, 0, 0, 0.28))
	# One baked, vertex-coloured mesh: one draw call per drone.
	var mi := MeshInstance3D.new()
	mi.mesh = MESH
	mi.position.y = -0.2
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


func update_view(delta: float) -> void:
	_phase += delta * 3.0
	position = Vector3(drone.position.x, hover_height + sin(_phase) * 0.15, drone.position.y)
	rotation.y = drone.heading
	_shadow.global_position = Vector3(drone.position.x, 0.06, drone.position.y)
	_cargo.show_items(drone.cargo)
