class_name TouchJoystick
extends Control
## Floating virtual joystick: touch (or click) anywhere, then drag. Shows a base and knob where the touch started.

@export var tuning: JoystickTuning

## Current stick deflection, x right and y down, length 0..1.
var value: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_origin = event.position
			_set_drag(event.position)
		elif not event.pressed and event.index == _touch_index:
			release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_set_drag(event.position)


func is_active() -> bool:
	return _touch_index != -1


func release() -> void:
	_touch_index = -1
	value = Vector2.ZERO
	_knob_offset = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	# Like the prototype's blur handler: never leave the player walking after focus is lost.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release()


func _set_drag(pos: Vector2) -> void:
	value = Movement.joystick_vector(_origin, pos, tuning.radius)
	_knob_offset = value * tuning.radius
	queue_redraw()


func _draw() -> void:
	if not is_active():
		return
	var base_r := tuning.base_diameter * 0.5
	draw_circle(_origin, base_r, tuning.base_fill)
	draw_arc(_origin, base_r - tuning.base_border_width * 0.5, 0.0, TAU, 48,
			tuning.base_border, tuning.base_border_width, true)
	draw_circle(_origin + _knob_offset, tuning.knob_diameter * 0.5, tuning.knob_fill)
