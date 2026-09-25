class_name PlayerTuning
extends Resource
## Player movement numbers. Defaults mirror the prototype (speedOf, turn lerp, world clamp).

## Base walk speed in metres per second, before boots upgrades.
@export var move_speed: float = 6.0
## How quickly the astronaut turns to face its movement direction (lerp factor per second).
@export var turn_rate: float = 14.0
## Input magnitude below this is ignored.
@export var input_deadzone: float = 0.08
## The player is kept inside this distance from the world origin.
@export var world_radius: float = 40.0
