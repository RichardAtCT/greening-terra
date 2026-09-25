class_name Economy
extends RefCounted
## Pure economy rules: costs, payouts, capacities and machine throughput.
## No scene access, so tests and tools/balance_sim.gd call these directly.


static func pack_capacity(defs: GameDefs, state: WorldState) -> int:
	return defs.tuning.pack_base + roundi(state.pack_level * defs.pack_upgrade.amount_per_level)


static func move_speed(defs: GameDefs, state: WorldState) -> float:
	return defs.player.move_speed * (1.0 + defs.boots_upgrade.amount_per_level * state.boots_level)


## Cost of the next level, or -1 when maxed.
static func upgrade_cost(upgrade: UpgradeDef, level: int) -> int:
	if level >= upgrade.max_level:
		return -1
	return upgrade.cost(level)


## Cost of the next hauler, or -1 at the planet's cap. The first hauler comes free with the bay.
static func drone_cost(defs: GameDefs, drones: int, max_drones: int) -> int:
	if drones >= max_drones:
		return -1
	return defs.drone_upgrade.cost(maxi(0, drones - 1))


## Credits the hub pays for one item on this planet (0 for raw resources).
static func payout(item: ItemDef, planet: PlanetDef) -> float:
	return item.sell_value * planet.pay_multiplier


## Terraform % one delivered item adds on this planet.
static func terraform_gain(item: ItemDef, planet: PlanetDef) -> float:
	return item.terraform_value / planet.terraform_divisor


## Sells one item at the hub. Returns false if it can't be sold.
static func deliver(state: WorldState, item: ItemDef, planet: PlanetDef) -> bool:
	if item == null or not item.is_sellable():
		return false
	state.credits += payout(item, planet)
	state.terraform = minf(100.0, state.terraform + terraform_gain(item, planet))
	state.add_stat(&"delivered")
	return true


static func accepts(state: WorldState, machine: MachineDef, item: StringName) -> bool:
	return machine.recipe.inputs.has(item) and state.queued(machine.id, item) < machine.queue_cap


## Index of the top-most carried item the machine will take, or -1.
static func feedable_index(state: WorldState, machine: MachineDef) -> int:
	for i in range(state.stack.size() - 1, -1, -1):
		if accepts(state, machine, state.stack[i]):
			return i
	return -1


## Moves one item from the player's stack into the machine's queue. Returns the item or &"".
static func feed_one(state: WorldState, machine: MachineDef) -> StringName:
	var i := feedable_index(state, machine)
	if i < 0:
		return &""
	var item: StringName = state.stack[i]
	state.stack.remove_at(i)
	add_to_queue(state, machine, item)
	state.add_stat(&"fed")
	return item


static func add_to_queue(state: WorldState, machine: MachineDef, item: StringName) -> void:
	if not state.queues.has(machine.id):
		state.queues[machine.id] = {}
	state.queues[machine.id][item] = state.queued(machine.id, item) + 1


## Index of the top-most sellable carried item, or -1.
static func sellable_index(defs: GameDefs, stack: Array[StringName]) -> int:
	for i in range(stack.size() - 1, -1, -1):
		var it := defs.item(stack[i])
		if it and it.is_sellable():
			return i
	return -1


## Takes one finished item from a machine's OUT pad onto the player's stack.
static func take_output(state: WorldState, machine: MachineDef, capacity: int) -> bool:
	if state.outputs.get(machine.id, 0) <= 0 or state.stack.size() >= capacity:
		return false
	state.outputs[machine.id] -= 1
	state.stack.append(machine.recipe.output)
	return true


static func has_inputs(state: WorldState, machine: MachineDef) -> bool:
	for item in machine.recipe.inputs:
		if state.queued(machine.id, item) < machine.recipe.inputs[item]:
			return false
	return true


## Advances one machine by dt. Returns how many items finished this step (0 or 1).
static func step_machine(state: WorldState, machine: MachineDef, dt: float) -> int:
	var produced := 0
	var left: float = state.busy.get(machine.id, 0.0)
	if left > 0.0:
		left -= dt
		if left <= 0.0:
			left = 0.0
			state.outputs[machine.id] = state.outputs.get(machine.id, 0) + 1
			state.add_stat(StringName("produced_" + machine.recipe.output))
			produced = 1
	if left <= 0.0 and state.outputs.get(machine.id, 0) < machine.output_cap and has_inputs(state, machine):
		for item in machine.recipe.inputs:
			state.queues[machine.id][item] -= machine.recipe.inputs[item]
		left = machine.recipe.time
	state.busy[machine.id] = left
	return produced


## Credits to move into a pay pad on one tick.
static func pay_chunk(cost: int, paid: int, credits: float, chunks: int) -> int:
	var chunk := maxi(1, ceili(float(cost) / chunks))
	return maxi(0, mini(chunk, mini(cost - paid, floori(credits))))
