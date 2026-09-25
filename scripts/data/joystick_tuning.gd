class_name JoystickTuning
extends Resource
## Floating joystick numbers, in UI units (CSS pixels on web). Defaults mirror the prototype's #joy / #knob.

## Drag distance that counts as full deflection.
@export var radius: float = 50.0
@export var base_diameter: float = 112.0
@export var knob_diameter: float = 46.0
@export var base_border_width: float = 2.0
@export var base_fill: Color = Color(22.0 / 255.0, 12.0 / 255.0, 17.0 / 255.0, 0.25)
@export var base_border: Color = Color(243.0 / 255.0, 230.0 / 255.0, 220.0 / 255.0, 0.35)
@export var knob_fill: Color = Color(243.0 / 255.0, 230.0 / 255.0, 220.0 / 255.0, 0.55)
