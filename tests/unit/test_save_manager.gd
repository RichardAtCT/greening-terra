extends GutTest
## SaveManager: save round-trip, migration and text export/import.

var defs: GameDefs


func before_each() -> void:
	defs = load("res://data/game.tres")


func after_each() -> void:
	DirAccess.remove_absolute(SaveManager.profile_path(96))


func _played_state() -> WorldState:
	var sim := GameSim.new(defs, GameSim.new_planet_state(defs, 1, 2, 3))
	var bot := BotPlayer.new(sim)
	for i in 3000:
		bot.step(1.0 / 30.0)
	return sim.state


## Godot's JSON can come back one bit off in a float's last digit, so compare at 14 digits.
func _same(a: WorldState, b: WorldState) -> String:
	return "" if JSON.stringify(a.to_dict(), "", true) == JSON.stringify(b.to_dict(), "", true) else "states differ"


func test_save_and_load_round_trip() -> void:
	var state := _played_state()
	assert_true(SaveManager.save_state(96, state))
	var loaded := SaveManager.load_state(96)
	assert_not_null(loaded)
	assert_eq(_same(loaded, state), "")


func test_loaded_state_resumes_play() -> void:
	var state := _played_state()
	SaveManager.save_state(96, state)
	var sim := GameSim.new(defs, SaveManager.load_state(96))
	assert_eq(sim.drones.size(), state.drones, "haulers respawn from the save")
	for i in 300:
		sim.step(1.0 / 30.0, Vector2(0, 30))
	assert_true(true, "no errors stepping a loaded game")


func test_missing_or_garbage_save_is_null() -> void:
	assert_null(SaveManager.load_state(96))
	assert_null(SaveManager.state_from_save_dict("nope"))
	assert_null(SaveManager.state_from_save_dict({"version": 1}))


func test_migrates_unversioned_save() -> void:
	var data := {"world": GameSim.new_planet_state(defs, 0).to_dict()}
	var migrated := SaveManager.migrate(data)
	assert_eq(migrated.version, SaveManager.SAVE_VERSION)
	assert_not_null(SaveManager.state_from_save_dict(data))


func test_migrates_version_one_save_with_an_empty_colony() -> void:
	var world := GameSim.new_planet_state(defs, 0).to_dict()
	world["terraform"] = 30.0
	for key in ["landers", "lander_t", "colonists_waiting", "housed", "food", "hazard_phase", "hazard_t", "hazard_wait", "hazard_count"]:
		world.erase(key)
	var state := SaveManager.state_from_save_dict({"version": 1, "world": world})
	assert_not_null(state)
	assert_eq(state.landers, 0)
	assert_eq(state.lander_t, -1.0)
	assert_eq(state.housed, 0)
	var sim := GameSim.new(defs, state)
	for i in roundi(20.0 * 30.0):
		sim.step(1.0 / 30.0, Vector2(0, 30))
	assert_eq(state.landers, 0, "landers wait for food, as on a new planet")


func test_migrates_version_three_colony_to_a_head_count() -> void:
	var world := GameSim.new_planet_state(defs, 0).to_dict()
	world.erase("housed")
	world["landers"] = 2
	world["meals"] = [40.0, 0.0, 12.5, 90.0]
	world["food"] = 6.0
	world["built"] = {"habitat_1": true}
	var state := SaveManager.state_from_save_dict({"version": 3, "world": world})
	assert_eq(state.housed, 4, "everyone who had a meal timer is still at home")
	assert_eq(state.food, 6.0, "the old food store counts towards the next lander")
	var sim := GameSim.new(defs, state)
	assert_eq(sim.colonists.size(), 4)


func test_export_import_text_round_trip() -> void:
	var state := _played_state()
	var text := SaveManager.export_text(state)
	assert_string_starts_with(text, "GT1:")
	var back := SaveManager.import_text("  " + text + "\n")
	assert_not_null(back)
	assert_eq(_same(back, state), "")


func test_import_rejects_junk() -> void:
	assert_null(SaveManager.import_text("hello"))
	assert_null(SaveManager.import_text("GT1:!!!not base64"))
	assert_null(SaveManager.import_text("GT1:" + Marshalls.utf8_to_base64("[1,2,3]")))
