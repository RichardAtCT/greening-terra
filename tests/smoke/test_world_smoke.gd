extends GutTest
## Loads the planet scene and runs it for a while without errors.


func before_each() -> void:
	# Never touch a real profile from tests.
	SaveManager.active_profile = 99
	GameState.sim = null
	GameState.start(GameSim.new_planet_state(GameState.defs, 0))


func after_each() -> void:
	DirAccess.remove_absolute(SaveManager.profile_path(99))


func test_planet_runs_and_player_walks_with_joystick() -> void:
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	var player: PlayerController = world.get_node("Player")
	var joystick: TouchJoystick = world.get_node("UI/Joystick")
	var start := player.global_position
	joystick.value = Vector2(1, 0)
	await wait_physics_frames(30)
	assert_gt(player.global_position.x, start.x + 1.0, "player moved right")
	joystick.release()


func test_planet_with_haulers_runs_60_seconds() -> void:
	var s := GameSim.new_planet_state(GameState.defs, 0)
	for id in [&"electrolyser", &"greenhouse", &"bay"]:
		s.built[id] = true
	s.drones = 4
	GameState.start(s)
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	await wait_frames(2)
	# Step the sim fast-forward through the scene's own update path.
	for i in 600:
		world._process(0.1)
	assert_gt(GameState.sim.state.stat(&"produced_plate"), 0)
	assert_eq(world.get_node("Player").get_class(), "CharacterBody3D")
