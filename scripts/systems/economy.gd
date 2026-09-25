class_name Economy
extends RefCounted
## Pure economy rules: costs, payouts, capacities and machine throughput.
## No scene access, so tests and tools/balance_sim.gd call these directly.


static func pack_capacity(defs: GameDefs, state: WorldState) -> int:
	return defs.tuning.pack_base + roundi(state.pack_level * defs.pack_upgrade.amount_per_level) \
		+ roundi(Bonuses.total(defs, state, BonusDef.Kind.PACK))


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


## Items each hauler carries: the base plus every cargo upgrade (levels 1, 3, 5...).
static func hauler_capacity(defs: GameDefs, level: int) -> int:
	return defs.tuning.drone_capacity + defs.tuning.hauler_upgrade_cargo * ((level + 1) / 2)


## How much faster hauler upgrades make every hauler (levels 2, 4, 6...).
static func hauler_speed_factor(defs: GameDefs, level: int) -> float:
	return 1.0 + defs.tuning.hauler_upgrade_speed * (level / 2)


## Does the next hauler upgrade add cargo (rather than speed)?
static func hauler_next_is_cargo(level: int) -> bool:
	return level % 2 == 0


## Credits the hub pays for one item on this planet (0 for raw resources), times any bonus.
static func payout(item: ItemDef, planet: PlanetDef, factor := 1.0) -> float:
	return item.sell_value * planet.pay_multiplier * factor


## Terraform % one delivered item adds on this planet.
static func terraform_gain(item: ItemDef, planet: PlanetDef) -> float:
	return item.terraform_value / planet.terraform_divisor


## Delivers one item to the hub. Food goes into the hub's store while it holds less than
## food_target meals (SPEC 4.1); everything else sellable is sold. Either way the item's terraform
## value counts, and a filter clears its toxins. Returns the credits paid, or -1 if the item can't
## be delivered.
static func deliver(state: WorldState, item: ItemDef, planet: PlanetDef, food_target := 0.0, pay_factor := 1.0) -> float:
	if item == null or not item.is_sellable():
		return -1.0
	var credits := 0.0
	if item.food_value > 0.0 and state.food < food_target:
		state.food += item.food_value
		state.add_stat(&"food_stored")
	else:
		credits = payout(item, planet, pay_factor)
		state.credits += credits
	if item.detox_value > 0.0:
		state.toxicity = tidy(maxf(0.0, state.toxicity - item.detox_value))
	add_growth(state, terraform_gain(item, planet))
	state.add_stat(&"delivered")
	state.add_stat(StringName("delivered_" + item.id))
	return credits


## Cost of a machine's next upgrade, or -1 when it has none left.
static func machine_upgrade_cost(state: WorldState, machine: MachineDef) -> int:
	var level := state.machine_level(machine.id)
	if level >= machine.upgrade_costs.size():
		return -1
	return machine.upgrade_costs[level]


## How much faster a machine's upgrades make it run (1.0 at Mk I).
static func machine_upgrade_speed(state: WorldState, machine: MachineDef) -> float:
	return 1.0 + machine.upgrade_speed * state.machine_level(machine.id)


## Finished items the machine's OUT pad holds before it stops, with its upgrades.
static func output_cap(state: WorldState, machine: MachineDef) -> int:
	return machine.output_cap + machine.upgrade_output_cap * state.machine_level(machine.id)


## Adds terraform % to the planet's growth. Terraform itself is growth capped by toxicity
## (SPEC 3, Kessik): growth over the cap is kept and shows once the toxins clear.
static func add_growth(state: WorldState, gain: float) -> void:
	state.growth = tidy(minf(100.0, state.growth + gain))
	refresh_terraform(state)


## Rounds to 9 decimals, so a value survives a JSON save exactly (Godot writes 16 digits).
static func tidy(x: float) -> float:
	return roundf(x * 1e9) / 1e9


static func refresh_terraform(state: WorldState) -> void:
	state.terraform = minf(state.growth, 100.0 - maxf(0.0, state.toxicity))


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


## Advances one machine by dt, running `speed` times as fast (colonists, upgrades, hazards).
## Returns how many cycles finished this step (0 or 1). A machine with no output item (a Heat
## Tower) just burns its input. At speed 0 (meteor damage) it starts nothing new.
static func step_machine(state: WorldState, machine: MachineDef, dt: float, speed := 1.0) -> int:
	var produced := 0
	var left: float = state.busy.get(machine.id, 0.0)
	if left > 0.0:
		left -= dt * speed
		if left <= 0.0:
			left = 0.0
			if machine.recipe.makes_item():
				state.outputs[machine.id] = state.outputs.get(machine.id, 0) + 1
				state.add_stat(StringName("produced_" + machine.recipe.output))
			else:
				state.add_stat(&"heat")
			produced = 1
	if speed > 0.0 and left <= 0.0 and state.outputs.get(machine.id, 0) < output_cap(state, machine) and has_inputs(state, machine):
		for item in machine.recipe.inputs:
			state.queues[machine.id][item] -= machine.recipe.inputs[item]
		left = machine.recipe.time
	state.busy[machine.id] = left
	return produced


## Credits to move into a pay pad on one tick.
static func pay_chunk(cost: int, paid: int, credits: float, chunks: int) -> int:
	var chunk := maxi(1, ceili(float(cost) / chunks))
	return maxi(0, mini(chunk, mini(cost - paid, floori(credits))))
