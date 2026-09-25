extends GutTest
## GameSim: the prototype loop driven with a scripted player position.

const DT := 1.0 / 60.0

var defs: GameDefs
var sim: GameSim


func before_each() -> void:
	defs = load("res://data/game.tres")
	sim = GameSim.new(defs, GameSim.new_planet_state(defs, 0))


func _stand(pos: Vector2, seconds: float) -> void:
	for i in roundi(seconds / DT):
		sim.step(DT, pos)


func test_smelter_starts_built_and_others_do_not() -> void:
	assert_true(sim.state.is_built(&"smelter"))
	assert_false(sim.state.is_built(&"electrolyser"))
	assert_true(sim.pad_visible(sim.pad(&"in_smelter")))
	assert_false(sim.pad_visible(sim.pad(&"in_electrolyser")))
	assert_true(sim.pad_visible(sim.pad(&"build_electrolyser")))


func test_digging_fills_pack_one_item_per_interval() -> void:
	_stand(Vector2(-15, 5), 0.5)
	assert_eq(sim.state.stack.size(), 2, "0.2 s per item")
	_stand(Vector2(-15, 5), 10.0)
	assert_eq(sim.state.stack.size(), 8, "stops at pack capacity")
	assert_true(sim.state.stack.all(func(s): return s == &"regolith"))


func test_emptied_node_respawns() -> void:
	sim.state.pack_level = 10
	_stand(Vector2(-18.5, 4.5), 1.25)
	var node := -1
	for i in sim.nodes.size():
		if sim.nodes[i].position == Vector2(-18.5, 4.5):
			node = i
	assert_eq(sim.state.node_stock[node], 0)
	_stand(Vector2(0, 30), 5.1)
	assert_eq(sim.state.node_stock[node], 6)


func test_full_manual_loop_earns_credits() -> void:
	_stand(Vector2(-15, 5), 2.0)
	assert_eq(sim.state.stack.size(), 6, "one node holds 6 regolith")
	_stand(sim.pad(&"in_smelter").position, 1.0)
	assert_eq(sim.state.stack.size(), 0, "fed everything")
	_stand(Vector2(0, 30), 10.0)
	_stand(sim.pad(&"out_smelter").position, 1.0)
	assert_eq(sim.state.count_carried(&"plate"), 6)
	_stand(sim.pad(&"depot").position, 1.0)
	assert_eq(sim.state.credits, 12.0)
	assert_almost_eq(sim.state.terraform, 0.9, 0.0001)
	assert_eq(sim.state.tutorial_step, 4, "tutorial reached the Electrolyser step")


func test_pay_pad_builds_when_fully_paid_and_keeps_partial_payments() -> void:
	sim.state.credits = 10.0
	_stand(sim.pad(&"build_electrolyser").position, 1.0)
	assert_eq(sim.state.paid[&"build_electrolyser"], 10)
	assert_false(sim.state.is_built(&"electrolyser"))
	_stand(Vector2(0, 30), 0.5)
	sim.state.credits = 100.0
	_stand(sim.pad(&"build_electrolyser").position, 2.0)
	assert_true(sim.state.is_built(&"electrolyser"))
	assert_eq(sim.state.credits, 85.0)


func test_drone_bay_gives_a_free_hauler_that_feeds_the_smelter() -> void:
	sim.state.credits = 60.0
	_stand(sim.pad(&"build_bay").position, 3.0)
	assert_true(sim.state.is_built(&"bay"))
	assert_eq(sim.drones.size(), 1)
	_stand(Vector2(0, 30), 30.0)
	assert_gt(sim.state.stat(&"produced_plate"), 0, "hauler dug regolith into the smelter")


func test_haulers_run_the_whole_chain_and_terraform() -> void:
	for id in [&"electrolyser", &"greenhouse", &"bay"]:
		sim.state.built[id] = true
	sim.state.drones = 6
	sim = GameSim.new(defs, sim.state)
	_stand(Vector2(0, 30), 240.0)
	assert_gt(sim.state.stat(&"produced_seedpod"), 0)
	assert_gt(sim.state.terraform, 5.0)


func test_win_fires_once_at_100() -> void:
	watch_signals(sim)
	sim.state.terraform = 100.0
	sim.step(DT, Vector2(0, 30))
	sim.step(DT, Vector2(0, 30))
	assert_signal_emit_count(sim, "planet_won", 1)


func test_hint_switches_to_saving_text() -> void:
	sim.state.tutorial_step = 4
	assert_string_starts_with(Tutorial.hint_text(sim), "Keep delivering plates")
	sim.state.credits = 25.0
	assert_string_starts_with(Tutorial.hint_text(sim), "Save ₵25")
	assert_eq(Tutorial.step_label(sim), "5/9")


func test_world_state_round_trips_through_dict() -> void:
	_stand(Vector2(-15, 5), 1.0)
	sim.state.queues[&"smelter"] = {&"regolith": 3}
	var copy := WorldState.from_dict(JSON.parse_string(JSON.stringify(sim.state.to_dict())))
	assert_eq(copy.to_dict(), sim.state.to_dict())
	assert_eq(copy.stack[0], &"regolith")
	assert_eq(copy.queued(&"smelter", &"regolith"), 3)
