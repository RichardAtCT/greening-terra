class_name FollowCamera
extends Camera3D
## Fixed-angle camera that eases after its target, matching the prototype's framing.

@export var tuning: CameraTuning
@export var target: Node3D

var _focus: Vector3 = Vector3.ZERO


func _ready() -> void:
	# The camera moves every rendered frame itself, so it must not be physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if target:
		_focus = target.global_position
	get_viewport().size_changed.connect(_update_fov)
	_update_fov()
	_place()


func _process(delta: float) -> void:
	if target:
		var goal := target.get_global_transform_interpolated().origin
		_focus = _focus.lerp(goal, minf(1.0, delta * tuning.follow_rate))
	_place()


func _place() -> void:
	global_position = _focus + tuning.offset
	look_at(_focus + Vector3(0.0, tuning.look_height, 0.0), Vector3.UP)


func _update_fov() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.y <= 0.0:
		return
	keep_aspect = Camera3D.KEEP_HEIGHT
	fov = Movement.vertical_fov_for_aspect(size.x / size.y, tuning.horizontal_half_fov_deg,
			tuning.fov_min_deg, tuning.fov_max_deg)


## Jumps straight to the target (after spawning or loading), skipping the ease-in.
func snap_to_target() -> void:
	if target:
		_focus = target.global_position
	_place()
