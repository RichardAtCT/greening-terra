extends GutTest
## Dispatcher (SPEC 4.5 and 7.6): scoring, reservations and no idle haulers while there's work.

const DT := 1.0 / 30.0

var defs: GameDefs
var sim: GameSim


func before_each() -> void:
	defs = load("res://data/game.tres")
	var s := GameSim.new_planet_state(defs, 0)
	for id in [&"electrolyser", &"greenhouse", &"bay"]:
		s.built[id] = true
	sim = GameSim.new(defs, s)


## Every machine mid-cycle, so none takes from its queue during the test's first step.
func _hold_machines() -> void:
	for m in sim.planet.machines:
		sim.state.busy[m.id] = 1000.0


func _add_drones(n: int) -> void:
	for i in n:
		sim.state.drones += 1
		sim._spawn_drone()


func test_empty_queues_send_haulers_to_the_field() -> void:
	_add_drones(1)
	var job := Dispatcher.best_job(sim, sim.drones[0])
	assert_not_null(job)
	assert_eq(job.kind, Dispatcher.Kind.FIELD)
	assert_true(job.target.id == &"smelter" or job.target.id == &"electrolyser")


func test_full_output_beats_the_field() -> void:
	_add_drones(1)
	sim.state.outputs[&"greenhouse"] = 40
	var job := Dispatcher.best_job(sim, sim.drones[0])
	assert_eq(job.kind, Dispatcher.Kind.SELL)
	assert_eq(job.source.id, &"greenhouse")


func test_plates_go_to_the_greenhouse_before_the_hub() -> void:
	_add_drones(1)
	sim.state.outputs[&"smelter"] = 30
	for m in [&"smelter", &"electrolyser"]:
		sim.state.queues[m] = {(&"regolith" if m == &"smelter" else &"ice"): 20}
	var job := Dispatcher.best_job(sim, sim.drones[0])
	assert_eq(job.kind, Dispatcher.Kind.FEED)
	assert_eq(job.target.id, &"greenhouse")
	sim.state.queues[&"greenhouse"] = {&"plate": 20}
	job = Dispatcher.best_job(sim, sim.drones[0])
	assert_eq(job.kind, Dispatcher.Kind.SELL, "greenhouse full: sell instead")


func test_two_haulers_never_reserve_the_same_items() -> void:
	# Only one job in the world: three plates waiting, every queue full.
	_add_drones(3)
	for m in [&"smelter", &"electrolyser"]:
		sim.state.queues[m] = {(&"regolith" if m == &"smelter" else &"ice"): 20}
	sim.state.queues[&"greenhouse"] = {&"plate": 20, &"o2": 20}
	sim.state.outputs[&"smelter"] = 3
	_hold_machines()
	sim.step(DT, Vector2(0, 30))
	var taken := 0
	var with_job := 0
	for d in sim.drones:
		if d.job:
			with_job += 1
			taken += d.reserved
	assert_eq(with_job, 1, "one hauler takes the pile, the others stay idle")
	assert_eq(taken, 3)
	assert_eq(Dispatcher.reserved_output(sim, &"smelter"), 3)


func test_field_reservations_split_a_node_between_haulers() -> void:
	_add_drones(4)
	sim.step(DT, Vector2(0, 30))
	for i in sim.nodes.size():
		assert_lte(Dispatcher.reserved_node(sim, i), sim.state.node_stock[i], "node %d over-reserved" % i)


func test_incoming_items_count_against_queue_room() -> void:
	_add_drones(12)
	sim.state.queues[&"smelter"] = {&"regolith": 18}
	_hold_machines()
	sim.step(DT, Vector2(0, 30))
	var room := 20 - 18
	assert_lte(Dispatcher.incoming(sim, &"smelter", &"regolith"), room)


func test_no_idle_hauler_while_a_job_exists() -> void:
	_add_drones(8)
	for i in roundi(120.0 / DT):
		sim.step(DT, Vector2(0, 30))
		if i % 30 != 0:
			continue
		for d in sim.drones:
			assert_true(d.job != null or Dispatcher.jobs(sim, d).is_empty(), "hauler %d idle with work to do" % d.index)


func test_hauler_sells_when_the_target_fills_up() -> void:
	_add_drones(1)
	var d := sim.drones[0]
	sim.state.outputs[&"smelter"] = 4
	for m in [&"smelter", &"electrolyser"]:
		sim.state.queues[m] = {(&"regolith" if m == &"smelter" else &"ice"): 20}
	sim.state.queues[&"greenhouse"] = {&"plate": 10, &"o2": 20}
	sim.step(DT, Vector2(0, 30))
	assert_eq(d.job.kind, Dispatcher.Kind.FEED)
	# The player fills the greenhouse while the hauler is on its way.
	sim.state.queues[&"greenhouse"][&"plate"] = 20
	sim.state.busy[&"greenhouse"] = 0.0
	sim.state.queues[&"greenhouse"][&"o2"] = 0
	var credits := sim.state.credits
	for i in roundi(30.0 / DT):
		sim.step(DT, Vector2(0, 30))
	assert_gt(sim.state.credits, credits, "plates were sold at the hub")


func test_storm_slows_haulers() -> void:
	var normal := sim.drone_speed()
	sim.state.terraform = 30.0
	sim.state.hazard_phase = HazardDirector.Phase.ACTIVE
	sim.state.hazard_t = 10.0
	assert_almost_eq(sim.drone_speed(), normal * sim.planet.hazard.drone_speed, 0.0001)


func test_upgraded_haulers_carry_more() -> void:
	_add_drones(1)
	sim.state.hauler_level = 1
	var cap := defs.tuning.drone_capacity + defs.tuning.hauler_upgrade_cargo
	var job := Dispatcher.best_job(sim, sim.drones[0])
	assert_eq(job.amount, cap, "a node holds more than a hold")
	for i in roundi(20.0 / DT):
		sim.step(DT, Vector2(0, 30))
		if sim.drones[0].cargo.size() >= cap:
			break
	assert_eq(sim.drones[0].cargo.size(), cap, "fills the bigger hold before leaving")
