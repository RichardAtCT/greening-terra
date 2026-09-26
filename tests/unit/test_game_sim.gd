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
	assert_almost_eq(sim.state.terraform, 6 * defs.item(&"plate").terraform_value / sim.planet.terraform_divisor, 0.0001)
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
	assert_gt(sim.state.stat(&"produced_seedpod"), 20)
	assert_gt(sim.state.stat(&"delivered"), 100)
	assert_gt(sim.state.terraform, 0.0)


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
	assert_eq(Tutorial.step_label(sim), "5/11")


func test_world_state_round_trips_through_dict() -> void:
	_stand(Vector2(-15, 5), 1.0)
	sim.state.queues[&"smelter"] = {&"regolith": 3}
	sim.state.machine_levels[&"smelter"] = 2
	sim.state.hauler_level = 3
	var copy := WorldState.from_dict(JSON.parse_string(JSON.stringify(sim.state.to_dict(), "", true, true)))
	assert_eq(copy.to_dict(), sim.state.to_dict())
	assert_eq(copy.stack[0], &"regolith")
	assert_eq(copy.machine_level(&"smelter"), 2)
	assert_eq(copy.hauler_level, 3)
	assert_eq(copy.queued(&"smelter", &"regolith"), 3)


func test_bot_player_progresses_through_the_build_order() -> void:
	var bot := BotPlayer.new(sim)
	for i in roundi(360.0 / DT):
		bot.step(DT)
	assert_true(sim.state.is_built(&"electrolyser"))
	assert_true(sim.state.is_built(&"bay"))
	assert_true(sim.state.is_built(&"greenhouse"))
	assert_gt(sim.state.drones, 1)


func _build_chain() -> void:
	for m in sim.planet.machines:
		sim.state.built[m.id] = true


func test_upgrade_pads_open_once_the_chain_stands() -> void:
	sim.state.built[&"electrolyser"] = true
	assert_false(sim.pad_visible(sim.pad(&"upgrade_smelter")), "not before the Greenhouse")
	_build_chain()
	for m in sim.planet.machines:
		assert_true(sim.pad_visible(sim.pad(StringName("upgrade_" + m.id))), m.id)


func test_upgrading_a_machine_makes_it_faster_until_max() -> void:
	_build_chain()
	var gh := sim.machine_def(&"greenhouse")
	var p := sim.pad(&"upgrade_greenhouse")
	assert_eq(sim.upgrade_pad_label(p), "MK II ₵%d" % gh.upgrade_costs[0])
	sim.state.credits = 100000.0
	_stand(p.position, 3.0)
	assert_eq(sim.state.machine_level(&"greenhouse"), 1)
	assert_eq(sim.machine_title(gh), "Greenhouse Mk II")
	assert_almost_eq(sim.machine_speed(gh), 1.0 + gh.upgrade_speed, 0.0001)
	assert_eq(Economy.output_cap(sim.state, gh), gh.output_cap + gh.upgrade_output_cap)
	assert_eq(sim.state.stat(&"machine_upgrades"), 1)
	_stand(p.position, 20.0)
	assert_eq(sim.state.machine_level(&"greenhouse"), gh.upgrade_costs.size(), "stops at the last mark")
	assert_false(sim.pad_visible(p), "pad goes once maxed")
	assert_eq(sim.upgrade_pad_label(p), "MAX")


func test_hint_says_how_to_call_the_next_lander() -> void:
	sim.state.tutorial_step = sim.tutorial_steps().size() - 1
	assert_string_starts_with(Tutorial.hint_text(sim), "Upgrade machines", "nothing to supply before the Greenhouse")
	sim.state.built[&"greenhouse"] = true
	sim.state.landers = 1
	sim.state.food = 7.0
	assert_string_starts_with(Tutorial.hint_text(sim), "Carry seedpods to SUPPLY to call 2 colonists (7/12).")
	sim.state.colonists_waiting = 2
	assert_string_starts_with(Tutorial.hint_text(sim), "2 colonists need a Habitat.")
	sim.state.colonists_waiting = 0
	sim.state.landers = sim.planet.lander_costs.size()
	assert_eq(Colony.lander_cost(sim), -1)
	assert_string_starts_with(Tutorial.hint_text(sim), "Upgrade machines")


func test_hauler_upgrades_alternate_cargo_and_speed() -> void:
	_build_chain()
	sim.state.built[&"bay"] = true
	var p := sim.pad(&"upgrade_haulers")
	assert_true(sim.pad_visible(p))
	var t := defs.tuning
	assert_eq(sim.upgrade_pad_label(p), "+%d CARGO ₵%d" % [t.hauler_upgrade_cargo, defs.hauler_upgrade.cost(0)])
	var speed := sim.drone_speed()
	sim.state.credits = 100000.0
	_stand(p.position, 3.0)
	assert_eq(sim.state.hauler_level, 1)
	assert_eq(sim.drone_capacity(), t.drone_capacity + t.hauler_upgrade_cargo)
	assert_almost_eq(sim.drone_speed(), speed, 0.0001, "the first one is cargo")
	assert_string_starts_with(sim.upgrade_pad_label(p), "+%d%% SPEED" % roundi(t.hauler_upgrade_speed * 100.0))
	_stand(p.position, 3.0)
	assert_eq(sim.state.hauler_level, 2)
	assert_almost_eq(sim.drone_speed(), speed * (1.0 + t.hauler_upgrade_speed), 0.0001)
	_stand(p.position, 30.0)
	assert_eq(sim.state.hauler_level, defs.hauler_upgrade.max_level, "stops at max")
	assert_false(sim.pad_visible(p))


func test_buy_pad_goes_at_the_hauler_cap() -> void:
	sim.state.built[&"bay"] = true
	sim.state.drones = sim.planet.max_drones - 1
	assert_true(sim.pad_visible(sim.pad(&"buy_drone")))
	sim.state.drones = sim.planet.max_drones
	assert_false(sim.pad_visible(sim.pad(&"buy_drone")))


func test_pay_pad_rests_after_a_purchase() -> void:
	var p := sim.pad(&"pack")
	sim.state.credits = 100000.0
	# The first level (₵15) takes about 0.7 s; the pad then rests for pay_rest.
	_stand(p.position, 0.8 + defs.tuning.pay_rest * 0.5)
	assert_eq(sim.state.pack_level, 1, "standing still doesn't buy a second level straight away")
	assert_true(sim.pad_resting(p))
	assert_eq(sim.state.paid.get(&"pack", 0), 0, "no credits drained while resting")
	_stand(p.position, 3.0)
	assert_eq(sim.state.pack_level, 2, "buys again once the rest is over")


func _carry(item: StringName, n: int) -> void:
	for i in n:
		sim.state.stack.append(item)


func test_swap_pad_shows_with_the_greenhouse_until_mk_ii() -> void:
	var p := sim.pad(&"swap_greenhouse")
	assert_not_null(p)
	assert_eq(p.label, "2 FOR 1")
	assert_false(sim.pad_visible(p), "not before the Greenhouse")
	sim.state.built[&"greenhouse"] = true
	assert_true(sim.pad_visible(p))
	sim.state.machine_levels[&"greenhouse"] = 1
	assert_false(sim.pad_visible(p), "gone at Mk II")
	assert_null(sim.pad(&"swap_smelter"), "single-input machines have none")


func test_swap_pad_levels_what_you_carry() -> void:
	sim.state.built[&"greenhouse"] = true
	_carry(&"plate", 8)
	_stand(sim.pad(&"swap_greenhouse").position, 2.0)
	# 8/0 -> 6/1 -> 4/2 -> 2/3: it stops before swinging the other way.
	assert_eq(sim.state.count_carried(&"plate"), 2)
	assert_eq(sim.state.count_carried(&"o2"), 3)
	assert_eq(sim.state.stat(&"swapped"), 3)


func test_swap_pad_counts_the_greenhouse_queue() -> void:
	sim.state.built[&"greenhouse"] = true
	sim.state.queues[&"greenhouse"] = {&"o2": 10, &"plate": 0}
	_carry(&"plate", 4)
	assert_true(Economy.swap_trade(sim.state, sim.machine_def(&"greenhouse")).is_empty(),
		"the Greenhouse is short of plates, and plates are all we carry")
	sim.state.stack.clear()
	sim.state.queues[&"greenhouse"] = {&"o2": 0, &"plate": 10}
	_carry(&"plate", 4)
	_stand(sim.pad(&"swap_greenhouse").position, 2.0)
	assert_eq(sim.state.count_carried(&"o2"), 2, "plates swapped while it helped")
	assert_eq(sim.state.count_carried(&"plate"), 0)


func test_hint_points_at_the_swap_pad_while_the_greenhouse_is_short() -> void:
	sim.state.built[&"greenhouse"] = true
	sim.state.tutorial_step = 8
	_carry(&"plate", 4)
	assert_eq(Tutorial.hint_text(sim), "Out of O₂? Swap 2 plates for 1 O₂ on the SWAP pad.")
	sim.state.queues[&"greenhouse"] = {&"o2": 3, &"plate": 0}
	assert_false(Tutorial.hint_text(sim).contains("SWAP"), "not while it has O₂ queued")
