extends GutTest
## Colonists, landers called by food, and habitats (SPEC 4.1), and the dust storm (SPEC 3, 4.2).

const DT := 1.0 / 30.0

var defs: GameDefs
var sim: GameSim


func before_each() -> void:
	defs = load("res://data/game.tres")
	sim = GameSim.new(defs, GameSim.new_planet_state(defs, 0))


func _run(seconds: float, pos := Vector2(0, 30)) -> void:
	for i in roundi(seconds / DT):
		sim.step(DT, pos)


func _land_first_lander() -> void:
	sim.state.food = sim.planet.lander_costs[0]
	_run(defs.colony.lander_descent_time + 0.5)


## Stands on the SUPPLY pad carrying `pods` seedpods (and a plate, which stays on the back).
func _supply(pods: int, seconds := 5.0) -> void:
	sim.state.built[&"greenhouse"] = true
	sim.state.stack.assign([&"plate"])
	for i in pods:
		sim.state.stack.append(&"seedpod")
	_run(seconds, sim.pad(&"supply").position)


func test_supply_pad_opens_with_the_greenhouse() -> void:
	var pad := sim.pad(&"supply")
	assert_not_null(pad)
	assert_eq(pad.position, sim.planet.lander_position + sim.planet.supply_pad_offset)
	assert_false(sim.pad_visible(pad), "no food to bring yet")
	sim.state.built[&"greenhouse"] = true
	assert_true(sim.pad_visible(pad))
	assert_eq(sim.supply_pad_label(), "%d POD" % sim.planet.lander_costs[0])


func test_food_on_the_supply_pad_calls_a_lander() -> void:
	watch_signals(sim)
	var cost := sim.planet.lander_costs[0]
	_supply(cost - 1)
	assert_eq(sim.state.food, cost - 1.0)
	assert_eq(sim.state.stack, [&"plate"] as Array[StringName], "only food leaves the back")
	assert_eq(sim.state.credits, 0.0, "supplied food isn't sold")
	assert_gt(sim.state.terraform, 0.0, "but still terraforms")
	assert_signal_emit_count(sim, "supplied", cost - 1)
	assert_signal_not_emitted(sim, "lander_coming")
	_supply(1, 0.5)
	assert_signal_emit_count(sim, "lander_coming", 1)
	assert_eq(sim.state.food, 0.0, "the lander takes its food")
	_run(defs.colony.lander_descent_time + 0.5)
	assert_signal_emitted_with_parameters(sim, "lander_landed", [2])
	assert_eq(sim.state.landers, 1)
	assert_true(sim.state.is_built(&"habitat_1"), "first habitat comes free")
	assert_eq(sim.colonists.size(), 2)
	assert_eq(sim.state.housed, 2)


func test_supply_pad_takes_no_more_than_the_next_lander_needs() -> void:
	var costs := sim.planet.lander_costs
	_supply(costs[0] + costs[1] + 5, 3.0)
	assert_gt(sim.state.lander_t, 0.0, "the first is coming down")
	assert_eq(sim.state.food, float(costs[1]), "the pad fills up for the second")
	assert_eq(sim.state.count_carried(&"seedpod"), 5, "and leaves the rest on the back")
	assert_eq(sim.supply_pad_label(), "%d POD" % costs[1])
	_run(defs.colony.lander_descent_time)
	assert_eq(sim.state.landers, 1)
	assert_gt(sim.state.lander_t, 0.0, "the second is called as soon as the first lands")
	assert_eq(sim.state.food, 0.0)


func test_tutorial_points_at_the_supply_pad_until_the_first_lander() -> void:
	sim.state.built[&"greenhouse"] = true
	var steps := sim.tutorial_steps()
	var i := -1
	for k in steps.size():
		if steps[k].text.contains("SUPPLY"):
			i = k
	assert_gt(i, 0)
	assert_eq(steps[i].target, sim.pad(&"supply").position, "the marker sits on the pad")
	sim.state.tutorial_step = i
	_supply(sim.planet.lander_costs[0], 1.0)
	assert_eq(sim.state.tutorial_step, i, "not done until the lander lands")
	_run(defs.colony.lander_descent_time)
	assert_eq(sim.state.stat(&"landed"), 1)
	assert_gt(sim.state.tutorial_step, i)


func test_hub_sells_food_and_never_calls_landers() -> void:
	sim.state.built[&"greenhouse"] = true
	for i in 30:
		sim.deliver_item(&"seedpod", Vector3.ZERO)
	_run(1.0)
	assert_eq(sim.state.credits, 30 * defs.item(&"seedpod").sell_value)
	assert_eq(sim.state.food, 0.0)
	assert_eq(sim.state.lander_t, -1.0)


func test_landers_come_one_at_a_time() -> void:
	var costs := sim.planet.lander_costs
	sim.state.food = costs[0] + costs[1] + costs[2] + costs[3]
	_run(defs.colony.lander_descent_time + 0.5)
	assert_eq(sim.state.landers, 1)
	_run(3 * (defs.colony.lander_descent_time + 0.1))
	assert_eq(sim.state.landers, 4)
	assert_eq(sim.state.food, 0.0)
	assert_eq(sim.state.housed, 4, "habitat 1 holds four")
	assert_eq(sim.state.colonists_waiting, 4)


func test_supply_pad_goes_once_every_lander_is_called() -> void:
	sim.state.built[&"greenhouse"] = true
	sim.state.landers = sim.planet.lander_costs.size() - 1
	sim.state.lander_t = 2.0
	assert_eq(Colony.lander_cost(sim), -1)
	assert_false(sim.pad_visible(sim.pad(&"supply")))


func test_building_a_habitat_moves_waiting_colonists_in() -> void:
	var costs := sim.planet.lander_costs
	sim.state.food = costs[0] + costs[1] + costs[2]
	_run(3 * (defs.colony.lander_descent_time + 0.1) + 0.5)
	assert_eq(sim.state.colonists_waiting, 2)
	var pad := sim.pad(&"build_habitat_2")
	assert_true(sim.pad_visible(pad), "second habitat offered once the first exists")
	assert_false(sim.pad_visible(sim.pad(&"build_habitat_3")), "one at a time")
	sim.state.credits = 500.0
	_run(3.0, pad.position)
	assert_true(sim.state.is_built(&"habitat_2"))
	assert_eq(sim.state.colonists_waiting, 0)
	assert_eq(sim.colonists.size(), 6)


func test_colonists_spread_over_machines_two_at_most() -> void:
	for id in [&"electrolyser", &"greenhouse"]:
		sim.state.built[id] = true
	sim.state.built[&"habitat_1"] = true
	sim.state.built[&"habitat_2"] = true
	sim.state.colonists_waiting = 8
	Colony.house(sim)
	_run(0.1)
	var per := {}
	for c in sim.colonists:
		if c.machine:
			per[c.machine.id] = per.get(c.machine.id, 0) + 1
	assert_eq(per, {&"smelter": 2, &"electrolyser": 2, &"greenhouse": 2})
	assert_eq(sim.colonists.filter(func(c): return c.machine == null).size(), 2, "the rest are off duty")


func test_working_colonists_speed_up_their_machine() -> void:
	_land_first_lander()
	assert_eq(Colony.machine_speed(sim, &"smelter"), 1.0, "still walking over")
	_run(30.0)
	assert_true(sim.colonists.all(func(c): return c.working))
	assert_almost_eq(Colony.machine_speed(sim, &"smelter"), 1.0 + 2 * defs.colony.machine_boost, 0.0001)


func test_colonists_keep_working_with_no_food_about() -> void:
	_land_first_lander()
	_run(600.0)
	assert_eq(sim.state.food, 0.0)
	assert_true(sim.colonists.all(func(c): return c.working), "colonists don't eat")


func test_colony_survives_a_save_round_trip() -> void:
	sim.state.built[&"electrolyser"] = true
	_land_first_lander()
	sim.state.food = 4.0
	var copy := SaveManager.state_from_save_dict(JSON.parse_string(JSON.stringify(SaveManager.make_save_dict(sim.state), "", true, true)))
	var sim2 := GameSim.new(defs, copy)
	assert_eq(sim2.colonists.size(), 2)
	assert_eq(sim2.state.housed, 2)
	assert_eq(sim2.state.food, 4.0)
	assert_eq(sim2.state.landers, 1)
	for c in sim2.colonists:
		assert_not_null(c.machine, "back at work straight away")


# --- Dust storm ----------------------------------------------------------------------------

func test_no_storm_before_fifteen_percent() -> void:
	sim.state.terraform = 14.0
	_run(700.0)
	assert_eq(sim.state.hazard_count, 0)
	assert_eq(sim.state.hazard_phase, HazardDirector.Phase.NONE)


func test_storm_is_telegraphed_then_slows_the_player() -> void:
	var h := sim.planet.hazard
	watch_signals(sim)
	sim.state.terraform = 20.0
	var normal := sim.move_speed()
	var gap := HazardDirector.gap(h, sim.planet.seed, 0, 20.0)
	assert_between(gap, h.interval_min, h.interval_max * h.interval_growth)
	_run(gap + 0.5)
	assert_eq(sim.state.hazard_phase, HazardDirector.Phase.WARNING)
	assert_eq(sim.move_speed(), normal, "a warning doesn't slow you yet")
	_run(h.telegraph_time)
	assert_eq(sim.state.hazard_phase, HazardDirector.Phase.ACTIVE)
	assert_almost_eq(sim.move_speed(), normal * h.player_speed, 0.0001)
	assert_gt(HazardDirector.intensity(sim), 0.0)
	_run(h.duration)
	assert_eq(sim.state.hazard_phase, HazardDirector.Phase.NONE)
	assert_eq(sim.state.hazard_count, 1)
	assert_eq(sim.move_speed(), normal)
	assert_signal_emit_count(sim, "hazard_changed", 3)


func test_storms_stop_at_sixty_percent() -> void:
	sim.state.terraform = 60.0
	_run(800.0)
	assert_eq(sim.state.hazard_count, 0)


func test_storms_come_less_often_as_the_air_thickens() -> void:
	var h := sim.planet.hazard
	assert_gt(HazardDirector.gap(h, 11, 3, 59.0), HazardDirector.gap(h, 11, 3, 15.0))


func test_storms_never_take_items_or_credits() -> void:
	sim.state.terraform = 20.0
	sim.state.credits = 50.0
	sim.state.stack.assign([&"plate", &"plate"])
	sim.state.hazard_phase = HazardDirector.Phase.ACTIVE
	sim.state.hazard_t = 5.0
	_run(6.0)
	assert_eq(sim.state.credits, 50.0)
	assert_eq(sim.state.stack.size(), 2)
