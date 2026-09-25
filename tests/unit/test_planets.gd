extends GutTest
## M5: Orrin b (heat towers, cold snaps), Kessik (toxicity, filters, vents, meteors and repairs),
## planet bonuses, SPEC 4.4's upgrades and the version 3 save.

const DT := 1.0 / 30.0
const ORRIN := 1
const KESSIK := 2

var defs: GameDefs
var sim: GameSim


func before_each() -> void:
	defs = load("res://data/game.tres")


func _start(planet: int, bonuses: Array[StringName] = []) -> void:
	sim = GameSim.new(defs, GameSim.new_planet_state(defs, planet, 0, 0, 0, bonuses))


func _run(seconds: float, pos := Vector2(0, 30)) -> void:
	for i in roundi(seconds / DT):
		sim.step(DT, pos)


func _build(ids: Array) -> void:
	for id in ids:
		sim.state.built[id] = true


func _snap_on() -> void:
	sim.state.hazard_phase = HazardDirector.Phase.ACTIVE
	sim.state.hazard_t = 30.0


# --- Orrin b -----------------------------------------------------------------------------

func test_orrin_has_its_own_chain_and_tutorial() -> void:
	_start(ORRIN)
	var gh := sim.machine_def(&"greenhouse")
	assert_eq(gh.recipe.inputs.size(), 3, "seedpods need plate, O₂ and polymer")
	assert_true(gh.recipe.inputs.has(&"polymer"))
	assert_not_null(sim.machine_def(&"refinery"))
	assert_true(sim.has_nodes_for(&"carbonite"))
	assert_ne(sim.planet.tutorial, defs.planet(0).tutorial)
	assert_eq(sim.planet.hazard.kind, HazardDef.Kind.COLD_SNAP)


func test_heat_tower_has_no_out_pad_and_takes_no_colonists() -> void:
	_start(ORRIN)
	assert_not_null(sim.pad(&"in_heat_tower_1"))
	assert_null(sim.pad(&"out_heat_tower_1"))
	assert_eq(Colony.workers_for(sim, sim.machine_def(&"heat_tower_1")), 0)


func test_burning_tower_warms_the_planet_directly() -> void:
	_start(ORRIN)
	_build([&"heat_tower_1"])
	var tower := sim.machine_def(&"heat_tower_1")
	for i in 3:
		Economy.add_to_queue(sim.state, tower, &"polymer")
	_run(0.1)
	assert_true(sim.is_warm(tower))
	var before := sim.state.growth
	_run(tower.recipe.time * 3.0 + 0.5)
	assert_eq(sim.state.stat(&"heat"), 3)
	assert_almost_eq(sim.state.growth - before, 3.0 * tower.recipe.terraform / sim.planet.terraform_divisor, 0.0001)
	assert_false(sim.is_warm(tower), "out of polymer, it goes cold")


func test_cold_snap_halves_machines_outside_a_warm_tower() -> void:
	_start(ORRIN)
	_build([&"heat_tower_1", &"electrolyser"])
	var smelter := sim.machine_def(&"smelter")
	var electrolyser := sim.machine_def(&"electrolyser")
	assert_eq(sim.machine_speed(smelter), 1.0)
	_snap_on()
	assert_eq(sim.machine_speed(smelter), sim.planet.hazard.machine_speed, "no tower burning yet")
	sim.state.busy[&"heat_tower_1"] = 3.0
	assert_eq(sim.machine_speed(smelter), 1.0, "tower 1 covers the smelter")
	assert_eq(sim.machine_speed(electrolyser), sim.planet.hazard.machine_speed, "but not the electrolyser")
	assert_true(HazardDirector.is_frozen(sim, electrolyser))


func test_every_orrin_machine_is_covered_by_some_heat_plot() -> void:
	_start(ORRIN)
	for m in sim.planet.machines:
		if m.is_heat_tower():
			continue
		var covered := false
		for t in sim.planet.machines:
			if t.is_heat_tower() and t.position.distance_to(m.position) <= t.heat_radius:
				covered = true
		assert_true(covered, String(m.id))


# --- Kessik ------------------------------------------------------------------------------

func test_toxicity_caps_terraform_and_filters_release_it() -> void:
	_start(KESSIK)
	assert_eq(sim.state.toxicity, 100.0)
	var pod := defs.item(&"biomass")
	for i in 20:
		sim.deliver_item(&"biomass", Vector3.ZERO)
	assert_gt(sim.state.growth, 0.0, "growth is banked")
	assert_eq(sim.state.terraform, 0.0, "but capped by the toxins")
	var filter := defs.item(&"filter")
	var n := ceili(99.0 / filter.detox_value)
	for i in n:
		sim.deliver_item(&"filter", Vector3.ZERO)
	assert_almost_eq(sim.state.terraform, sim.state.growth, 0.0001, "the banked growth shows")
	assert_true(pod.food_value > 0.0)
	assert_eq(sim.food_item(), &"biomass", "biomass is Kessik's food")


func test_machines_on_vents_run_faster() -> void:
	_start(KESSIK)
	_build([&"ice_melter"])
	assert_true(sim.on_vent(sim.machine_def(&"ice_melter")))
	assert_false(sim.on_vent(sim.machine_def(&"smelter")))
	assert_almost_eq(sim.machine_speed(sim.machine_def(&"ice_melter")), 1.0 + sim.planet.vent_boost, 0.0001)


func test_meteors_mark_points_then_damage_a_machine_but_never_the_plate_maker() -> void:
	_start(KESSIK)
	_build([&"scrubber", &"electrolyser", &"ice_melter", &"algae_pond"])
	watch_signals(sim)
	sim.state.terraform = 20.0
	sim.state.hazard_wait = 0.01
	_run(0.1)
	assert_eq(sim.state.hazard_phase, HazardDirector.Phase.WARNING)
	assert_eq(sim.state.impacts.size(), sim.planet.hazard.meteor_count, "impact points shown ahead")
	for p in sim.state.impacts:
		assert_gt(p.distance_to(sim.planet.hub_position), sim.planet.hub_collide_radius, "never the hub")
	_run(sim.planet.hazard.telegraph_time + sim.planet.hazard.duration + 0.2)
	assert_signal_emitted(sim, "meteors_landed")
	assert_eq(sim.state.damaged.size(), sim.planet.hazard.meteor_hits)
	assert_false(sim.state.is_damaged(&"smelter"), "plates are always makeable, so repair is possible")
	var id: StringName = sim.state.damaged.keys()[0]
	assert_eq(sim.machine_speed(sim.machine_def(id)), 0.0, "a damaged machine stops")
	assert_true(sim.pad_visible(sim.pad(StringName("repair_" + id))))
	assert_false(sim.pad_visible(sim.pad(StringName("upgrade_" + id))))


func test_standing_on_repair_with_plates_fixes_the_machine() -> void:
	_start(KESSIK)
	_build([&"scrubber"])
	sim.state.damaged[&"scrubber"] = true
	var pad := sim.pad(&"repair_scrubber")
	sim.state.stack.assign([&"plate", &"plate", &"plate", &"sulphur"])
	_run(1.0, pad.position)
	assert_eq(sim.state.repairs[&"scrubber"], 3, "only plates go in")
	assert_eq(sim.state.stack, [&"sulphur"] as Array[StringName])
	assert_true(sim.state.is_damaged(&"scrubber"))
	sim.state.stack.assign([&"plate", &"plate", &"plate"])
	watch_signals(sim)
	_run(1.0, pad.position)
	assert_false(sim.state.is_damaged(&"scrubber"))
	assert_signal_emitted_with_parameters(sim, "machine_repaired", [&"scrubber"])
	assert_eq(sim.state.stack.size(), 1, "the spare plate stays on the back")


func test_haulers_never_repair() -> void:
	_start(KESSIK)
	_build([&"scrubber", &"bay"])
	sim.state.drones = 1
	sim = GameSim.new(defs, sim.state)
	sim.state.damaged[&"scrubber"] = true
	sim.state.outputs[&"smelter"] = 20
	_run(30.0)
	assert_true(sim.state.is_damaged(&"scrubber"))


# --- Bonuses -----------------------------------------------------------------------------

func test_offer_is_three_untaken_bonuses_and_stable() -> void:
	_start(0)
	var offer := Bonuses.offer(defs, sim.state)
	assert_eq(offer.size(), 3)
	assert_eq(Bonuses.offer(defs, sim.state), offer, "same three after a reload")
	assert_true(Bonuses.pick(defs, sim.state, offer[1].id))
	assert_false(Bonuses.pick(defs, sim.state, offer[0].id), "one pick per planet")
	assert_eq(sim.state.bonuses, [offer[1].id] as Array[StringName])
	var next := GameSim.carry_state(defs, sim.state, 1)
	assert_eq(next.bonuses, sim.state.bonuses, "bonuses carry over")
	assert_false(next.bonus_picked)
	assert_false(Bonuses.offer(defs, next).has(offer[1]), "never offered again")


func test_bonus_effects() -> void:
	_start(0)
	var base_pack := sim.pack_capacity()
	var base_drone := sim.drone_speed()
	var plate := defs.item(&"plate")
	_start(0, [&"deep_pockets", &"swift_haulers", &"trade_charter", &"overclock"])
	assert_eq(sim.pack_capacity(), base_pack + 4)
	assert_almost_eq(sim.drone_speed(), base_drone * 1.25, 0.0001)
	assert_almost_eq(Economy.deliver(sim.state, plate, sim.planet, 0.0, sim.pay_factor()), plate.sell_value * 1.25, 0.0001)
	assert_almost_eq(sim.machine_speed(sim.machine_def(&"smelter")), 1.15, 0.0001)


func test_head_start_gives_a_bay_and_a_hauler() -> void:
	_start(1, [&"head_start"])
	assert_true(sim.state.is_built(&"bay"))
	assert_eq(sim.drones.size(), 1)


func test_weather_shield_shortens_hazards() -> void:
	_start(ORRIN, [&"weather_shield"])
	assert_almost_eq(HazardDirector.duration(sim), sim.planet.hazard.duration * 0.7, 0.001)


func test_big_lander_brings_more_and_habitats_grow() -> void:
	_start(0, [&"big_lander"])
	assert_eq(Colony.colonists_per_lander(sim), 4)
	assert_eq(Colony.habitat_capacity(sim), 8)
	sim.state.terraform = 10.0
	_run(defs.colony.lander_descent_time + 0.5)
	assert_eq(sim.colonists.size(), 4)
	assert_eq(sim.state.colonists_waiting, 0)


func test_rich_veins_fill_nodes_and_speed_respawn() -> void:
	_start(0)
	var stock: int = sim.nodes[0].max_stock
	var respawn := sim.node_respawn_time()
	_start(0, [&"rich_veins"])
	assert_eq(sim.nodes[0].max_stock, roundi(stock * 1.5))
	assert_almost_eq(sim.node_respawn_time(), respawn * 0.7, 0.001)


# --- Upgrades (SPEC 4.4) -----------------------------------------------------------------

func test_upgraded_machines_take_more_colonists() -> void:
	_start(0)
	var smelter := sim.machine_def(&"smelter")
	assert_eq(Colony.workers_for(sim, smelter), defs.colony.max_per_machine)
	sim.state.machine_levels[&"smelter"] = 1
	assert_eq(Colony.workers_for(sim, smelter), defs.colony.max_per_machine + defs.colony.upgraded_extra_workers)


func test_upgrade_pads_open_without_heat_towers_and_hide_while_damaged() -> void:
	_start(ORRIN)
	_build([&"electrolyser", &"greenhouse", &"refinery"])
	assert_true(sim.upgrades_open(), "Heat Towers aren't part of the chain")
	assert_null(sim.pad(&"upgrade_heat_tower_1"), "towers have no upgrades")
	_start(KESSIK)
	_build([&"scrubber", &"electrolyser", &"ice_melter", &"algae_pond"])
	assert_true(sim.pad_visible(sim.pad(&"upgrade_scrubber")))
	sim.state.damaged[&"scrubber"] = true
	assert_false(sim.pad_visible(sim.pad(&"upgrade_scrubber")))
	assert_true(sim.pad_visible(sim.pad(&"repair_scrubber")))


func test_dig_upgrade_carries_over() -> void:
	_start(0)
	var interval := sim.mine_interval()
	sim.state.credits = 1000.0
	_run(3.0, sim.pad(&"dig").position)
	assert_gt(sim.state.dig_level, 0)
	assert_almost_eq(sim.mine_interval(), interval / (1.0 + sim.state.dig_level * defs.dig_upgrade.amount_per_level), 0.0001)
	sim.state.hauler_level = 2
	var next := GameSim.carry_state(defs, sim.state, 1)
	assert_eq(next.dig_level, sim.state.dig_level, "dig speed carries over")
	assert_eq(next.hauler_level, 0, "hauler upgrades belong to this planet's bay")


# --- Saves -------------------------------------------------------------------------------

func test_version_two_save_migrates_and_keeps_its_terraform() -> void:
	var world := GameSim.new_planet_state(defs, KESSIK).to_dict()
	world["terraform"] = 40.0
	for key in ["growth", "toxicity", "bonuses", "bonus_picked", "dig_level", "damaged", "repairs", "impacts"]:
		world.erase(key)
	var state := SaveManager.state_from_save_dict({"version": 2, "world": world})
	assert_not_null(state)
	var s := GameSim.new(defs, state)
	assert_eq(s.state.terraform, 40.0, "an old Kessik save never drops")
	assert_eq(s.state.toxicity, 60.0)
	assert_eq(s.state.growth, 40.0)


func test_m5_state_round_trips() -> void:
	_start(KESSIK, [&"overclock"])
	sim.state.machine_levels[&"scrubber"] = 2
	sim.state.damaged[&"ice_melter"] = true
	sim.state.repairs[&"ice_melter"] = 3
	sim.state.impacts.assign([Vector2(3.5, -12.25)])
	sim.state.growth = 12.5
	sim.state.toxicity = 64.0
	sim.state.bonus_picked = true
	var back := SaveManager.import_text(SaveManager.export_text(sim.state))
	assert_eq(back.to_dict(), sim.state.to_dict())


# --- Bot ---------------------------------------------------------------------------------

func test_bot_repairs_a_damaged_machine() -> void:
	_start(KESSIK)
	_build([&"scrubber"])
	sim.state.damaged[&"scrubber"] = true
	var bot := BotPlayer.new(sim)
	for i in roundi(120.0 / DT):
		bot.step(DT)
		if not sim.state.is_damaged(&"scrubber"):
			break
	assert_false(sim.state.is_damaged(&"scrubber"))


func test_swap_pad_is_planet_one_only() -> void:
	for planet in [ORRIN, KESSIK]:
		_start(planet)
		for p in sim.pads:
			assert_ne(p.kind, PadInfo.Kind.SWAP, "%s has no SWAP pad" % sim.planet.display_name)
