class_name PlayerController
extends CharacterBody3D
## Walks the astronaut from joystick + keyboard input and turns it to face where it is going.

@export var tuning: PlayerTuning
@export var joystick: TouchJoystick
## The visual model, rotated to face the movement direction (built looking down +Z).
@export var model: Node3D


func _physics_process(delta: float) -> void:
	var stick := read_stick()
	var v := Movement.ground_velocity(stick, tuning.move_speed, tuning.input_deadzone)
	velocity = v
	move_and_slide()
	global_position = Movement.clamp_to_radius(global_position, tuning.world_radius)
	global_position.y = 0.0
	if v != Vector3.ZERO and model:
		model.rotation.y = Movement.turn_toward(model.rotation.y, Movement.facing_yaw(v), tuning.turn_rate, delta)


## Joystick and keys add together, as in the prototype.
func read_stick() -> Vector2:
	var keys := Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down"))
	var joy := joystick.value if joystick else Vector2.ZERO
	return joy + keys
