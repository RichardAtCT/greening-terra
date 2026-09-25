extends GutTest
## Movement maths and the M0 tuning data.


func test_joystick_vector_is_clamped_to_unit_length() -> void:
	var v := Movement.joystick_vector(Vector2(100, 100), Vector2(300, 100), 50.0)
	assert_almost_eq(v.length(), 1.0, 0.0001)
	assert_almost_eq(v.x, 1.0, 0.0001)


func test_joystick_vector_partial_deflection() -> void:
	var v := Movement.joystick_vector(Vector2.ZERO, Vector2(0, 25), 50.0)
	assert_almost_eq(v, Vector2(0, 0.5), Vector2(0.0001, 0.0001))


func test_ground_velocity_ignores_deadzone() -> void:
	assert_eq(Movement.ground_velocity(Vector2(0.05, 0), 6.0, 0.08), Vector3.ZERO)


func test_ground_velocity_maps_screen_down_to_positive_z() -> void:
	var v := Movement.ground_velocity(Vector2(0, 1), 6.0, 0.08)
	assert_almost_eq(v, Vector3(0, 0, 6), Vector3(0.0001, 0.0001, 0.0001))


func test_ground_velocity_caps_combined_input_at_full_speed() -> void:
	# Joystick plus keys can exceed length 1; speed must not.
	var v := Movement.ground_velocity(Vector2(1, 1), 6.0, 0.08)
	assert_almost_eq(v.length(), 6.0, 0.0001)


func test_turn_toward_takes_the_short_way_round() -> void:
	var yaw := Movement.turn_toward(deg_to_rad(170), deg_to_rad(-170), 1.0, 0.5)
	assert_gt(yaw, deg_to_rad(170))


func test_clamp_to_radius() -> void:
	var p := Movement.clamp_to_radius(Vector3(80, 0, 0), 40.0)
	assert_almost_eq(p.x, 40.0, 0.0001)
	assert_eq(Movement.clamp_to_radius(Vector3(3, 0, 4), 40.0), Vector3(3, 0, 4))


func test_fov_widens_for_portrait_and_is_clamped() -> void:
	assert_almost_eq(Movement.vertical_fov_for_aspect(16.0 / 9.0, 20.0, 42.0, 70.0), 42.0, 0.0001)
	assert_almost_eq(Movement.vertical_fov_for_aspect(390.0 / 844.0, 20.0, 42.0, 70.0), 70.0, 0.0001)
	var mid := Movement.vertical_fov_for_aspect(0.8, 20.0, 42.0, 70.0)
	assert_between(mid, 42.0, 70.0)


func test_tuning_resources_load_with_prototype_values() -> void:
	var player: PlayerTuning = load("res://data/player_tuning.tres")
	var camera: CameraTuning = load("res://data/camera_tuning.tres")
	var joystick: JoystickTuning = load("res://data/joystick_tuning.tres")
	assert_eq(player.move_speed, 6.0)
	assert_eq(camera.offset, Vector3(0, 13.5, 11))
	assert_eq(joystick.radius, 50.0)
