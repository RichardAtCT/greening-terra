class_name GuideMarker
extends Node3D
## Bobbing cone and ground ring over the objective, plus an arrow at the player's feet pointing to it.

const AMBER := Color("f2b35b")

var _marker: Node3D
var _cone: MeshInstance3D
var _arrow: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	_marker = Node3D.new()
	add_child(_marker)
	_cone = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 0.0
	cone.height = 0.7
	cone.radial_segments = 4
	cone.rings = 0
	_cone.mesh = cone
	_cone.material_override = ItemVisuals.unshaded(AMBER)
	_marker.add_child(_cone)
	var ring := MeshInstance3D.new()
	ring.mesh = MeshUtil.flat_mesh(MeshUtil.ring(1.05, 1.2, 32))
	var ring_mat := ItemVisuals.unshaded(Color(AMBER, 0.7))
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_mat
	ring.position.y = 0.12
	_marker.add_child(ring)
	_arrow = MeshInstance3D.new()
	_arrow.mesh = MeshUtil.flat_mesh(PackedVector3Array([Vector3(0, 0, 0.42), Vector3(-0.26, 0, 0), Vector3(0.26, 0, 0)]))
	var arrow_mat := ItemVisuals.unshaded(Color(AMBER, 0.9))
	arrow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arrow.material_override = arrow_mat
	add_child(_arrow)
	for mi in [_cone, ring, _arrow]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Points at target (x, z) from the player's position; hides when has_target is false.
func update_guide(has_target: bool, target: Vector2, player: Vector2, delta: float) -> void:
	_time += delta
	_marker.visible = has_target
	if not has_target:
		_arrow.visible = false
		return
	_marker.position = Vector3(target.x, 0, target.y)
	_cone.position.y = 3.0 + sin(_time * 4.0) * 0.25
	var d := target - player
	var dist := d.length()
	_arrow.visible = dist > 3.5
	if _arrow.visible:
		var dir := d / dist
		_arrow.position = Vector3(player.x + dir.x * 1.5, 0.08, player.y + dir.y * 1.5)
		_arrow.rotation.y = atan2(dir.x, dir.y)
