class_name CameraTuning
extends Resource
## Follow-camera numbers. Defaults mirror the prototype (camOff, lerp, resize()).

## Camera position relative to the followed target.
@export var offset: Vector3 = Vector3(0.0, 13.5, 11.0)
## How quickly the camera catches up with the target (lerp factor per second).
@export var follow_rate: float = 6.0
## The camera looks at the target raised by this much.
@export var look_height: float = 0.5
## Half of the horizontal field of view the camera tries to keep, in degrees.
@export var horizontal_half_fov_deg: float = 20.0
## Vertical field of view limits, in degrees.
@export var fov_min_deg: float = 42.0
@export var fov_max_deg: float = 70.0
