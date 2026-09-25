class_name PlayerController
extends CharacterBody3D
## Walks the astronaut from joystick + keyboard input, turns it to face where it's going, and bobs its legs.

@export var tuning: PlayerTuning
@export var joystick: TouchJoystick
## The visual model, rotated to face the movement direction (built looking down +Z).
@export var model: Node3D
@export var body: Node3D
@export var leg_left: Node3D
@export var leg_right: Node3D

## Current walk speed (base speed times boots), set by whoever owns the game rules.
var move_speed: float = 0.0
## Where fed items leave the back stack, in model space.
const STACK_TOP := Vector3(0, 1.5, -0.5)
## False while a menu or the win screen is open.
var controls_enabled := true
var moving := false

var _walk_time := 0.0
var _leg_rest := Vector3.ZERO
var _body_rest := Vector3.ZERO


func _ready() -> void:
	if move_speed <= 0.0:
		move_speed = tuning.move_speed
	if leg_left:
		_leg_rest = leg_left.position
	if body:
		_body_rest = body.position


func _physics_process(delta: float) -> void:
	var stick := read_stick() if controls_enabled else Vector2.ZERO
	var v := Movement.ground_velocity(stick, move_speed, tuning.input_deadzone)
	velocity = v
	move_and_slide()
	global_position = Movement.clamp_to_radius(global_position, tuning.world_radius)
	global_position.y = 0.0
	moving = v != Vector3.ZERO
	if moving and model:
		model.rotation.y = Movement.turn_toward(model.rotation.y, Movement.facing_yaw(v), tuning.turn_rate, delta)


func _process(delta: float) -> void:
	_walk_time += delta
	var wob := sin(_walk_time * 14.0) if moving else 0.0
	if leg_left:
		leg_left.position.y = _leg_rest.y + maxf(0.0, wob) * 0.12
		leg_right.position.y = _leg_rest.y + maxf(0.0, -wob) * 0.12
	if body:
		body.position.y = _body_rest.y + (absf(wob) * 0.05 if moving else 0.0)


## Joystick and keys add together, as in the prototype.
func read_stick() -> Vector2:
	var keys := Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down"))
	var joy := joystick.value if joystick else Vector2.ZERO
	return joy + keys


func ground_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## World position of the top of the back stack (where fed items fly from).
func stack_top() -> Vector3:
	return model.to_global(STACK_TOP) if model else global_position + Vector3.UP * STACK_TOP.y
