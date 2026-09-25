extends GutTest
## Colonists, landers, food and habitats (SPEC 4.1), and the dust storm (SPEC 3, 4.2).

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
	sim.state.terraform = 10.0
	_run(defs.colony.lander_descent_time + 0.5)


func test_lander_arrives_at_first_milestone_and_builds_habitat_one() -> void:
	watch_signals(sim)
	sim.state.terraform = 9.9
	_run(1.0)
	assert_signal_not_emitted(sim, "lander_coming")
	_land_first_lander()
	assert_signal_emit_count(sim, "lander_coming", 1)
	assert_signal_emitted_with_parameters(sim, "lander_landed", [2])
	assert_eq(sim.state.landers, 1)
	assert_true(sim.state.is_built(&"habitat_1"), "first habitat comes free")
	assert_eq(sim.colonists.size(), 2)
	assert_eq(sim.state.meals.size(), 2)


func test_landers_catch_up_one_at_a_time() -> void:
	sim.state.terraform = 60.0
	_run(defs.colony.lander_descent_time + 0.5)
	assert_eq(sim.state.landers, 1)
	_run(3 * (defs.colony.lander_descent_time + 0.1))
	assert_eq(sim.state.landers, 4, "10, 25, 40 and 55%")
	assert_eq(sim.state.meals.size(), 4, "habitat 1 holds four")
	assert_eq(sim.state.colonists_waiting, 4)


func test_building_a_habitat_moves_waiting_colonists_in() -> void:
	sim.state.terraform = 40.0
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
	sim.state.food = 10.0
	assert_eq(Colony.machine_speed(sim, &"smelter"), 1.0, "still walking over")
	_run(30.0)
	assert_true(sim.colonists.all(func(c): return c.working))
	assert_almost_eq(Colony.machine_speed(sim, &"smelter"), 1.0 + 2 * defs.colony.machine_boost, 0.0001)


func test_colonists_eat_from_the_food_store() -> void:
	_land_first_lander()
	sim.state.food = 1.0
	_run(defs.colony.meal_interval + 1.0)
	assert_eq(sim.state.food, 0.0, "one ate, the other went hungry")
	assert_eq(Colony.hungry_count(sim), 1)
	var hungry: Colony.Colonist = sim.colonists.filter(func(c): return c.hungry)[0]
	assert_false(hungry.working, "hungry colonists stop working")
	sim.state.food = 3.0
	_run(0.1)
	assert_eq(Colony.hungry_count(sim), 0, "fed as soon as food arrives")
	assert_eq(sim.colonists.size(), 2, "nobody ever leaves")


func test_deliveries_keep_five_minutes_of_food_then_sell() -> void:
	_land_first_lander()
	var target := Colony.food_target(sim)
	assert_eq(target, ceilf(2 * defs.colony.food_reserve_seconds / defs.colony.meal_interval))
	for i in int(target) + 2:
		sim.deliver_item(&"seedpod", Vector3.ZERO)
	assert_eq(sim.state.food, target)
	assert_eq(sim.state.credits, 2 * defs.item(&"seedpod").sell_value)


func test_colony_survives_a_save_round_trip() -> void:
	sim.state.built[&"electrolyser"] = true
	_land_first_lander()
	sim.state.food = 4.0
	var copy := SaveManager.state_from_save_dict(JSON.parse_string(JSON.stringify(SaveManager.make_save_dict(sim.state), "", true, true)))
	var sim2 := GameSim.new(defs, copy)
	assert_eq(sim2.colonists.size(), 2)
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
