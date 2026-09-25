class_name Movement
extends RefCounted
## Pure movement and camera maths, free of scene state so tests and the balance sim can call it.


## Converts a drag from origin to current into a stick vector with length 0..1.
static func joystick_vector(origin: Vector2, current: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	return (current - origin).limit_length(radius) / radius


## Turns a 2D stick vector (x right, y down the screen) into a ground velocity.
## Like the prototype, anything under the deadzone is no movement, and partial deflection walks slower.
static func ground_velocity(stick: Vector2, speed: float, deadzone: float) -> Vector3:
	var length := stick.length()
	if length <= deadzone:
		return Vector3.ZERO
	var dir := stick / length
	return Vector3(dir.x, 0.0, dir.y) * speed * minf(1.0, length)


## Moves yaw towards target_yaw along the shortest arc, as the prototype's rotation lerp does.
static func turn_toward(yaw: float, target_yaw: float, rate: float, delta: float) -> float:
	return yaw + wrapf(target_yaw - yaw, -PI, PI) * minf(1.0, delta * rate)


## Yaw that faces a model built looking down +Z along the given ground velocity.
static func facing_yaw(velocity: Vector3) -> float:
	return atan2(velocity.x, velocity.z)


## Keeps a ground position within radius of the origin (height untouched).
static func clamp_to_radius(pos: Vector3, radius: float) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	if flat.length() <= radius:
		return pos
	flat = flat.normalized() * radius
	return Vector3(flat.x, pos.y, flat.y)


## Vertical FOV that keeps the horizontal half-angle at half_h_deg for this aspect, clamped.
## Narrow portrait screens get a taller FOV so the sides of the play area stay visible.
static func vertical_fov_for_aspect(aspect: float, half_h_deg: float, min_deg: float, max_deg: float) -> float:
	var want := rad_to_deg(2.0 * atan(tan(deg_to_rad(half_h_deg)) / aspect))
	return clampf(want, min_deg, max_deg)
