extends GutTest
## Economy rules against the prototype's numbers.

var defs: GameDefs
var planet: PlanetDef
var smelter: MachineDef
var greenhouse: MachineDef


func before_each() -> void:
	defs = load("res://data/game.tres")
	planet = defs.planet(0)
	smelter = load("res://data/machines/smelter.tres")
	greenhouse = load("res://data/machines/greenhouse.tres")


func test_pack_capacity_and_speed_scale_with_upgrades() -> void:
	var s := WorldState.new()
	assert_eq(Economy.pack_capacity(defs, s), 8)
	s.pack_level = 3
	assert_eq(Economy.pack_capacity(defs, s), 20)
	s.boots_level = 2
	assert_almost_eq(Economy.move_speed(defs, s), 6.0 * 1.24, 0.0001)


func test_upgrade_costs_match_prototype() -> void:
	assert_eq(Economy.upgrade_cost(defs.pack_upgrade, 0), 15)
	assert_eq(Economy.upgrade_cost(defs.pack_upgrade, 4), 75)
	assert_eq(Economy.upgrade_cost(defs.pack_upgrade, 10), -1, "maxed")
	assert_eq(Economy.upgrade_cost(defs.boots_upgrade, 5), 120)
	assert_eq(Economy.upgrade_cost(defs.boots_upgrade, 6), -1)


func test_drone_costs_grow_by_1_55() -> void:
	assert_eq(Economy.drone_cost(defs, 1, 12), 40)
	assert_eq(Economy.drone_cost(defs, 2, 12), 62)
	assert_eq(Economy.drone_cost(defs, 3, 12), 96)
	assert_eq(Economy.drone_cost(defs, 12, 12), -1)


func test_raw_resources_cannot_be_sold() -> void:
	var s := WorldState.new()
	assert_eq(Economy.deliver(s, defs.item(&"regolith"), planet), -1.0)
	assert_eq(s.credits, 0.0)


func test_delivery_pays_and_terraforms_per_planet() -> void:
	var pod := defs.item(&"seedpod")
	var s := WorldState.new()
	assert_eq(Economy.deliver(s, pod, planet), 9.0)
	assert_eq(s.credits, 9.0)
	assert_almost_eq(s.terraform, pod.terraform_value / planet.terraform_divisor, 0.0001)
	var s2 := WorldState.new()
	var p2 := defs.planet(1)
	Economy.deliver(s2, pod, p2)
	assert_almost_eq(s2.credits, 9.0 * p2.pay_multiplier, 0.0001)
	assert_almost_eq(s2.terraform, pod.terraform_value / p2.terraform_divisor, 0.0001)


func test_the_hub_sells_food_like_anything_else() -> void:
	var s := WorldState.new()
	assert_eq(Economy.deliver(s, defs.item(&"seedpod"), planet), 9.0)
	assert_eq(s.food, 0.0, "only the SUPPLY pad keeps food")


func test_supplied_food_terraforms_but_pays_nothing() -> void:
	var pod := defs.item(&"seedpod")
	var s := WorldState.new()
	Economy.supply(s, pod, planet)
	Economy.supply(s, pod, planet)
	assert_eq(s.food, 2.0)
	assert_eq(s.credits, 0.0)
	assert_almost_eq(s.terraform, pod.terraform_value * 2 / planet.terraform_divisor, 0.0001)
	assert_eq(s.stat(&"supplied"), 2)


func test_colonists_speed_machines_up() -> void:
	var smelter: MachineDef = planet.machines[0]
	var s := WorldState.new()
	s.queues[&"smelter"] = {&"regolith": 1}
	Economy.step_machine(s, smelter, 0.01)
	assert_eq(Economy.step_machine(s, smelter, smelter.recipe.time / 1.5 + 0.01, 1.5), 1, "50% faster")


func test_terraform_caps_at_100() -> void:
	var s := WorldState.new()
	s.growth = 99.99
	Economy.deliver(s, defs.item(&"seedpod"), planet)
	assert_eq(s.terraform, 100.0)


func test_feed_takes_topmost_matching_item_only() -> void:
	var s := WorldState.new()
	s.stack.assign([&"regolith", &"ice", &"regolith", &"ice"])
	assert_eq(Economy.feed_one(s, smelter), &"regolith")
	assert_eq(s.stack, [&"regolith", &"ice", &"ice"] as Array[StringName])
	assert_eq(s.queued(&"smelter", &"regolith"), 1)
	assert_eq(s.stat(&"fed"), 1)


func test_feed_respects_queue_cap() -> void:
	var s := WorldState.new()
	s.queues[&"smelter"] = {&"regolith": 20}
	s.stack.assign([&"regolith"])
	assert_eq(Economy.feed_one(s, smelter), &"")
	assert_eq(s.stack.size(), 1)


func test_machine_consumes_recipe_and_produces_after_time() -> void:
	var s := WorldState.new()
	s.queues[&"greenhouse"] = {&"plate": 2, &"o2": 1}
	Economy.step_machine(s, greenhouse, 0.1)
	assert_eq(s.queued(&"greenhouse", &"plate"), 1)
	assert_eq(s.queued(&"greenhouse", &"o2"), 0)
	assert_eq(Economy.step_machine(s, greenhouse, 1.0), 0)
	assert_eq(Economy.step_machine(s, greenhouse, 0.8), 1)
	assert_eq(s.outputs[&"greenhouse"], 1)
	assert_eq(s.stat(&"produced_seedpod"), 1)


func test_full_output_pauses_machine() -> void:
	var s := WorldState.new()
	s.queues[&"smelter"] = {&"regolith": 5}
	s.outputs[&"smelter"] = 40
	Economy.step_machine(s, smelter, 0.1)
	assert_eq(s.queued(&"smelter", &"regolith"), 5)
	assert_eq(s.busy[&"smelter"], 0.0)


func test_upgraded_machine_holds_more_output() -> void:
	var s := WorldState.new()
	s.queues[&"smelter"] = {&"regolith": 5}
	s.outputs[&"smelter"] = 40
	s.machine_levels[&"smelter"] = 1
	Economy.step_machine(s, smelter, 0.1)
	assert_eq(s.queued(&"smelter", &"regolith"), 4, "room for 10 more at Mk II")
	assert_eq(Economy.machine_upgrade_cost(s, smelter), smelter.upgrade_costs[1])
	s.machine_levels[&"smelter"] = smelter.upgrade_costs.size()
	assert_eq(Economy.machine_upgrade_cost(s, smelter), -1)


func test_take_output_respects_pack() -> void:
	var s := WorldState.new()
	s.outputs[&"smelter"] = 2
	assert_true(Economy.take_output(s, smelter, 1))
	assert_false(Economy.take_output(s, smelter, 1), "pack full")
	assert_eq(s.stack, [&"plate"] as Array[StringName])


func test_pay_chunks() -> void:
	assert_eq(Economy.pay_chunk(150, 0, 1000.0, 35), 5)
	assert_eq(Economy.pay_chunk(25, 0, 1000.0, 35), 1)
	assert_eq(Economy.pay_chunk(150, 148, 1000.0, 35), 2, "never overpays")
	assert_eq(Economy.pay_chunk(150, 0, 3.7, 35), 3, "only whole credits you have")
	assert_eq(Economy.pay_chunk(150, 0, 0.5, 35), 0)
