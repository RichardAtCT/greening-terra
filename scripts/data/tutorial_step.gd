class_name TutorialStep
extends Resource
## One line of the bottom objective bar, with a ground marker.

@export_multiline var text: String
@export var has_target: bool = true
## Marker position (x, z).
@export var target: Vector2
## The step is done when any condition is met.
@export var done_when: Array[TutorialCondition] = []
## While the player can't yet afford this pay pad, show saving_text instead.
@export var saving_for_pad: StringName
@export_multiline var saving_text: String
