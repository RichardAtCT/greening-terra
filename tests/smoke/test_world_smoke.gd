extends GutTest
## Loads the M0 test world and checks the player walks when the joystick is held.


func test_player_walks_with_joystick() -> void:
	var world: Node3D = load("res://scenes/world/test_world.tscn").instantiate()
	add_child_autofree(world)
	var player: PlayerController = world.get_node("Player")
	var joystick: TouchJoystick = world.get_node("HUD/Joystick")
	var start := player.global_position
	joystick.value = Vector2(1, 0)
	await wait_physics_frames(30)
	assert_gt(player.global_position.x, start.x + 1.0, "player moved right")
	joystick.release()
