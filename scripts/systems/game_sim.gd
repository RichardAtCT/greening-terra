class_name GameSim
extends RefCounted
## The whole game rules for one planet, with no scene access.
## The planet scene feeds it the player's position each frame and draws what it reports;
## tools/balance_sim.gd drives it with a scripted player instead.

## An item moved from one world point to another (for the flying-item animation).
signal item_flew(item: StringName, from: Vector3, to: Vector3)
## Something was added to or taken from the player's back.
signal stack_changed
signal node_dug(index: int)
signal delivered(item: StringName, credits: float)
signal purchased(key: StringName)
signal toast(text: String)
signal drone_added(drone: DroneBrain.Drone)
signal planet_won
## A lander has appeared in the sky; it touches down lander_descent_time later.
signal lander_coming
signal lander_landed(colonists: int)
signal colonist_added(colonist: Colony.Colonist)
## A delivery went into the hub's food store instead of being sold.
signal food_stored(item: StringName)
signal hazard_changed(phase: HazardDirector.Phase)
## A meteor shower landed: where, and which machines it damaged.
signal meteors_landed(points: Array[Vector2], hit: Array[StringName])
signal machine_repaired(id: StringName)

const PLAYER_STACK_HEIGHT := 1.6
const PAD_DROP_HEIGHT := 0.4
const HUB_DROP_HEIGHT := 2.4

var defs: GameDefs
var planet: PlanetDef
var state: WorldState
var pads: Array[PadInfo] = []
## Flattened resource nodes: { "item", "position", "max_stock" }.
var nodes: Array[Dictionary] = []
var drones: Array[DroneBrain.Drone] = []
var colonists: Array[Colony.Colonist] = []

var _timers: Dictionary = {}
## Pay pad key -> seconds it still rests after a purchase (not saved: a reload never double-buys).
var _resting: Dictionary = {}
var _machines: Dictionary = {}


func _init(p_defs: GameDefs, p_state: WorldState) -> void:
	defs = p_defs
	state = p_state
	planet = defs.planet(state.planet_index)
	for m in planet.machines:
		_machines[m.id] = m
		if m.starts_built:
			state.built[m.id] = true
	# Terraform set directly (tests, tools) counts as grown.
	state.growth = maxf(state.growth, state.terraform)
	if state.toxicity < 0.0:
		# A save from before toxicity existed: never let the % shown drop.
		state.toxicity = minf(planet.start_toxicity, 100.0 - state.growth)
	Economy.refresh_terraform(state)
	_build_nodes()
	_build_pads()
	for i in state.drones:
		_spawn_drone()
	_restore_colonists()


## Fresh state for a planet, carrying over the player's kit and bonuses.
static func new_planet_state(defs: GameDefs, planet_index: int, pack_level := 0, boots_level := 0,
		dig_level := 0, bonuses: Array[StringName] = []) -> WorldState:
	var s := WorldState.new()
	var p := defs.planet(planet_index)
	s.planet_index = planet_index
	s.pack_level = pack_level
	s.boots_level = boots_level
	s.dig_level = dig_level
	s.bonuses = bonuses.duplicate()
	s.toxicity = p.start_toxicity
	s.player_position = p.depot_position + Vector2(0, 3.4)
	if Bonuses.has(defs, s, BonusDef.Kind.HEAD_START):
		s.built[&"bay"] = true
		s.drones = 1
	return s


## The next planet's fresh state for a player leaving `from` (credits reset; kit and bonuses carry).
static func carry_state(defs: GameDefs, from: WorldState, planet_index: int) -> WorldState:
	return new_planet_state(defs, planet_index, from.pack_level, from.boots_level, from.dig_level, from.bonuses)


func machine_def(id: StringName) -> MachineDef:
	return _machines.get(id)


func pad(key: StringName) -> PadInfo:
	for p in pads:
		if p.key == key:
			return p
	return null


func tutorial_steps() -> Array[TutorialStep]:
	if planet.tutorial:
		return planet.tutorial.steps
	return []


func pack_capacity() -> int:
	return Economy.pack_capacity(defs, state)


func pack_full() -> bool:
	return state.stack.size() >= pack_capacity()


func move_speed() -> float:
	return Economy.move_speed(defs, state) * HazardDirector.player_factor(self)


func drone_speed() -> float:
	return defs.tuning.drone_speed * Economy.hauler_speed_factor(defs, state.hauler_level) \
		* (1.0 + Bonuses.total(defs, state, BonusDef.Kind.DRONE_SPEED)) * HazardDirector.drone_factor(self)


func drone_capacity() -> int:
	return Economy.hauler_capacity(defs, state.hauler_level)


## Seconds per item dug (SPEC 4.4 dig speed upgrade).
func mine_interval() -> float:
	return defs.tuning.mine_interval / (1.0 + state.dig_level * defs.dig_upgrade.amount_per_level)


func node_respawn_time() -> float:
	return defs.tuning.node_respawn_time * maxf(0.1, 1.0 - Bonuses.total_2(defs, state, BonusDef.Kind.NODES))


## Multiplies hub payouts (Trade Charter).
func pay_factor() -> float:
	return 1.0 + Bonuses.total(defs, state, BonusDef.Kind.PAY)


## How fast a machine runs right now: its upgrades, the colonists working it, Overclock, a vent
## under it and the hazard (a cold snap away from heat). 0 while meteor-damaged. Heat Towers
## always burn at 1.
func machine_speed(m: MachineDef) -> float:
	if state.is_damaged(m.id):
		return 0.0
	if m.is_heat_tower():
		return 1.0
	var speed := Economy.machine_upgrade_speed(state, m) * Colony.machine_speed(self, m.id)
	speed *= 1.0 + Bonuses.total(defs, state, BonusDef.Kind.MACHINE_SPEED)
	if on_vent(m):
		speed *= 1.0 + planet.vent_boost
	return speed * HazardDirector.machine_factor(self, m)


## A Heat Tower that is built and burning.
func is_warm(m: MachineDef) -> bool:
	return m.is_heat_tower() and state.is_built(m.id) and not state.is_damaged(m.id) and state.busy.get(m.id, 0.0) > 0.0


## Is this spot inside a burning Heat Tower's radius?
func warmed(pos: Vector2) -> bool:
	for m in planet.machines:
		if is_warm(m) and pos.distance_to(m.position) <= m.heat_radius:
			return true
	return false


func on_vent(m: MachineDef) -> bool:
	for v in planet.vents:
		if m.position.distance_to(v) <= planet.vent_radius:
			return true
	return false


## The item colonists eat on this planet (seedpods, or biomass on Kessik), or &"" if none is made.
func food_item() -> StringName:
	for m in planet.machines:
		if m.recipe.makes_item():
			var it := defs.item(m.recipe.output)
			if it and it.food_value > 0.0:
				return it.id
	return &""


func planet_name() -> String:
	return planet_display_name(defs, state.planet_index)


## "Tessera-4", or "Tessera-4 II" on the second time round the planet list.
static func planet_display_name(p_defs: GameDefs, index: int) -> String:
	var cycle := index / p_defs.planets.size()
	return p_defs.planet(index).display_name + (" " + "I".repeat(cycle + 1) if cycle > 0 else "")


func has_nodes_for(item: StringName) -> bool:
	for n in nodes:
		if n.item == item:
			return true
	return false


func idle_point_for(item: StringName) -> Vector2:
	for rn in planet.resource_nodes:
		if rn.item == item:
			return rn.idle_point
	return planet.hub_position


func nearest_node(item: StringName, from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in nodes.size():
		if nodes[i].item != item or state.node_stock[i] <= 0:
			continue
		var d := from.distance_to(nodes[i].position)
		if d < best_d:
			best_d = d
			best = i
	return best


func dig_node(index: int) -> void:
	state.node_stock[index] -= 1
	node_dug.emit(index)


func deliver_item(item: StringName, from: Vector3) -> void:
	var def := defs.item(item)
	var credits := Economy.deliver(state, def, planet, Colony.food_target(self), pay_factor())
	if credits < 0.0:
		return
	var hub := planet.hub_position
	item_flew.emit(item, from, Vector3(hub.x, HUB_DROP_HEIGHT, hub.y))
	if credits > 0.0:
		delivered.emit(item, credits)
	else:
		food_stored.emit(item)


## Is the pad in play right now (e.g. BUILD pads vanish once built)?
func pad_visible(p: PadInfo) -> bool:
	match p.kind:
		PadInfo.Kind.IN, PadInfo.Kind.OUT:
			return state.is_built(p.machine.id)
		PadInfo.Kind.REPAIR:
			return state.is_damaged(p.machine.id)
		PadInfo.Kind.SWAP:
			return state.is_built(p.machine.id) and state.machine_level(p.machine.id) < p.machine.swap_until_level \
				and not state.is_damaged(p.machine.id)
		PadInfo.Kind.PAY:
			match p.pay:
				PadInfo.Pay.BUILD_MACHINE:
					return not state.is_built(p.machine.id)
				PadInfo.Pay.BUILD_BAY:
					return not state.is_built(&"bay")
				PadInfo.Pay.BUY_DRONE:
					return state.is_built(&"bay") and state.drones < planet.max_drones
				PadInfo.Pay.UPGRADE_HAULERS:
					return state.is_built(&"bay") and upgrades_open() and pad_cost(p) > 0
				PadInfo.Pay.UPGRADE_MACHINE:
					return upgrades_open() and Economy.machine_upgrade_cost(state, p.machine) > 0 and not state.is_damaged(p.machine.id)
				PadInfo.Pay.BUILD_HABITAT:
					# Offered one at a time, once colonists have a first home.
					return not state.is_built(Colony.habitat_key(p.index)) and state.is_built(Colony.habitat_key(p.index - 1))
	return true


## Credits a pay pad still asks for in total, or -1 if there's nothing to buy.
func pad_cost(p: PadInfo) -> int:
	match p.pay:
		PadInfo.Pay.BUILD_MACHINE:
			return p.machine.build_cost
		PadInfo.Pay.BUILD_BAY:
			return planet.bay_cost
		PadInfo.Pay.BUY_DRONE:
			return Economy.drone_cost(defs, state.drones, planet.max_drones)
		PadInfo.Pay.PACK:
			return Economy.upgrade_cost(defs.pack_upgrade, state.pack_level)
		PadInfo.Pay.BOOTS:
			return Economy.upgrade_cost(defs.boots_upgrade, state.boots_level)
		PadInfo.Pay.BUILD_HABITAT:
			return planet.habitat_costs[p.index]
		PadInfo.Pay.UPGRADE_MACHINE:
			return Economy.machine_upgrade_cost(state, p.machine)
		PadInfo.Pay.UPGRADE_HAULERS:
			return Economy.upgrade_cost(defs.hauler_upgrade, state.hauler_level)
		PadInfo.Pay.DIG:
			return Economy.upgrade_cost(defs.dig_upgrade, state.dig_level)
	return -1


## UPGRADE pads appear once the whole chain stands, so early credits go on the chain and haulers.
## Heat Towers don't count: they're placement, not chain.
func upgrades_open() -> bool:
	for m in planet.machines:
		if not m.is_heat_tower() and not state.is_built(m.id):
			return false
	return true


## "Smelter", then "Smelter Mk II" and so on once upgraded.
func machine_title(m: MachineDef) -> String:
	var level := state.machine_level(m.id)
	return m.display_name + (" Mk " + mark(level + 1) if level > 0 else "")


static func mark(n: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"][clampi(n, 1, 8) - 1]


## Advances the whole planet by dt with the player standing at player_pos.
func step(dt: float, player_pos: Vector2) -> void:
	state.player_position = player_pos
	_step_mining(dt, player_pos)
	_step_nodes(dt)
	_step_pads(dt, player_pos)
	HazardDirector.step(self, dt)
	Colony.step(self, dt)
	for m in planet.machines:
		if state.is_built(m.id):
			if Economy.step_machine(state, m, dt, machine_speed(m)) > 0 and not m.recipe.makes_item():
				# Heat warms the planet directly: nothing to haul.
				Economy.add_growth(state, m.recipe.terraform / planet.terraform_divisor)
	for d in drones:
		DroneBrain.step(self, d, dt)
	Tutorial.advance(tutorial_steps(), state)
	if state.terraform >= 100.0 and not state.won:
		state.won = true
		planet_won.emit()


func _tick(key: StringName, dt: float, interval: float) -> bool:
	var t: float = _timers.get(key, 0.0) + dt
	if t >= interval:
		_timers[key] = t - interval
		return true
	_timers[key] = t
	return false


func _player_top(player_pos: Vector2) -> Vector3:
	return Vector3(player_pos.x, PLAYER_STACK_HEIGHT, player_pos.y)


func _step_mining(dt: float, player_pos: Vector2) -> void:
	for i in nodes.size():
		if state.node_stock[i] <= 0:
			continue
		if player_pos.distance_to(nodes[i].position) < defs.tuning.mine_radius:
			if not pack_full() and _tick(&"mine", dt, mine_interval()):
				dig_node(i)
				state.stack.append(nodes[i].item)
				stack_changed.emit()
			break


func _step_nodes(dt: float) -> void:
	for i in nodes.size():
		if state.node_stock[i] <= 0:
			state.node_respawn[i] += dt
			if state.node_respawn[i] > node_respawn_time():
				state.node_stock[i] = nodes[i].max_stock
				state.node_respawn[i] = 0.0


func _step_pads(dt: float, player_pos: Vector2) -> void:
	for key in _resting.keys():
		_resting[key] -= dt
		if _resting[key] <= 0.0:
			_resting.erase(key)
	var interval := defs.tuning.transfer_interval
	for p in pads:
		if not pad_visible(p):
			continue
		if player_pos.distance_to(p.position) >= defs.tuning.pad_radius:
			_timers[p.key] = 0.0
			continue
		match p.kind:
			PadInfo.Kind.IN:
				if _tick(p.key, dt, interval):
					var item := Economy.feed_one(state, p.machine)
					if item != &"":
						item_flew.emit(item, _player_top(player_pos), Vector3(p.position.x, PAD_DROP_HEIGHT, p.position.y))
						stack_changed.emit()
			PadInfo.Kind.OUT:
				if state.outputs.get(p.machine.id, 0) > 0 and not pack_full() and _tick(p.key, dt, interval):
					if Economy.take_output(state, p.machine, pack_capacity()):
						stack_changed.emit()
			PadInfo.Kind.DEPOT:
				if _tick(p.key, dt, interval):
					var i := Economy.sellable_index(defs, state.stack)
					if i >= 0:
						var item: StringName = state.stack[i]
						state.stack.remove_at(i)
						deliver_item(item, _player_top(player_pos))
						stack_changed.emit()
			PadInfo.Kind.PAY:
				_step_pay(p, dt)
			PadInfo.Kind.REPAIR:
				if _tick(p.key, dt, interval):
					_step_repair(p, player_pos)
			PadInfo.Kind.SWAP:
				# Each trade moves swap_ratio items off the back, so it takes that many transfer ticks.
				if _tick(p.key, dt, interval * p.machine.swap_ratio):
					_step_swap(p, player_pos)


## Is this pay pad resting after a purchase?
func pad_resting(p: PadInfo) -> bool:
	return _resting.has(p.key)


func _step_pay(p: PadInfo, dt: float) -> void:
	if pad_resting(p):
		_timers[p.key] = 0.0
		return
	var cost := pad_cost(p)
	if cost < 0 or not _tick(p.key, dt, defs.tuning.pay_interval):
		return
	var paid: int = state.paid.get(p.key, 0)
	var amount := Economy.pay_chunk(cost, paid, state.credits, defs.tuning.pay_chunks)
	if amount > 0:
		state.credits -= amount
		paid += amount
		state.paid[p.key] = paid
	if paid >= cost:
		state.paid[p.key] = 0
		_resting[p.key] = defs.tuning.pay_rest
		_buy(p)


## One repair item from the player's back onto a damaged machine; fixed once the cost is paid.
func _step_repair(p: PadInfo, player_pos: Vector2) -> void:
	var h := planet.hazard
	var id := p.machine.id
	var i := state.stack.rfind(h.repair_item)
	if i < 0:
		return
	state.stack.remove_at(i)
	stack_changed.emit()
	item_flew.emit(h.repair_item, _player_top(player_pos), Vector3(p.position.x, PAD_DROP_HEIGHT, p.position.y))
	state.repairs[id] = state.repairs.get(id, 0) + 1
	if state.repairs[id] >= h.repair_cost:
		state.damaged.erase(id)
		state.repairs.erase(id)
		state.add_stat(&"repaired")
		toast.emit(p.machine.display_name + " repaired")
		machine_repaired.emit(id)


## One SWAP trade: the surplus input flies off the player's back onto the pad, and the input the
## machine is short of flies back.
func _step_swap(p: PadInfo, player_pos: Vector2) -> void:
	var trade := Economy.swap_trade(state, p.machine)
	if trade.is_empty():
		return
	Economy.swap_one(state, p.machine, trade[0], trade[1])
	var at := Vector3(p.position.x, PAD_DROP_HEIGHT, p.position.y)
	for n in p.machine.swap_ratio:
		item_flew.emit(trade[0], _player_top(player_pos), at)
	item_flew.emit(trade[1], at, _player_top(player_pos))
	stack_changed.emit()


## The objective bar's nudge towards a SWAP pad, while its machine sits idle for want of an input
## the player could swap for. Empty otherwise.
func swap_hint() -> String:
	for p in pads:
		if p.kind != PadInfo.Kind.SWAP or not pad_visible(p):
			continue
		var m := p.machine
		var trade := Economy.swap_trade(state, m)
		if trade.is_empty() or state.queued(m.id, trade[1]) > 0 or state.busy.get(m.id, 0.0) > 0.0:
			continue
		return m.swap_hint.format({"need": defs.item(trade[1]).display_name,
			"give": _plural(defs.item(trade[0]).display_name), "ratio": m.swap_ratio})
	return ""


## "Plate" → "plates"; a symbol like "O₂" stays as it is.
static func _plural(name: String) -> String:
	var last := name.right(1)
	if last != last.to_lower() or last == last.to_upper():
		return name
	return name.to_lower() + "s"


func _buy(p: PadInfo) -> void:
	match p.pay:
		PadInfo.Pay.BUILD_MACHINE:
			state.built[p.machine.id] = true
			toast.emit(p.machine.display_name + " online")
		PadInfo.Pay.BUILD_BAY:
			state.built[&"bay"] = true
			state.drones = 1
			_spawn_drone()
			toast.emit("Drone Bay online · first hauler free")
		PadInfo.Pay.BUY_DRONE:
			state.drones += 1
			_spawn_drone()
			toast.emit("Hauler #%d launched" % state.drones)
		PadInfo.Pay.PACK:
			state.pack_level += 1
			toast.emit("Pack holds %d" % pack_capacity())
		PadInfo.Pay.BOOTS:
			state.boots_level += 1
			toast.emit("Boots +%d%%" % roundi(state.boots_level * defs.boots_upgrade.amount_per_level * 100.0))
		PadInfo.Pay.BUILD_HABITAT:
			state.built[Colony.habitat_key(p.index)] = true
			toast.emit("Habitat %d built · room for %d more" % [p.index + 1, Colony.habitat_capacity(self)])
			Colony.house(self)
		PadInfo.Pay.UPGRADE_HAULERS:
			var cargo := Economy.hauler_next_is_cargo(state.hauler_level)
			state.hauler_level += 1
			toast.emit("Haulers carry %d" % drone_capacity() if cargo \
				else "Haulers +%d%% speed" % roundi((Economy.hauler_speed_factor(defs, state.hauler_level) - 1.0) * 100.0))
		PadInfo.Pay.UPGRADE_MACHINE:
			state.machine_levels[p.machine.id] = state.machine_level(p.machine.id) + 1
			state.add_stat(&"machine_upgrades")
			toast.emit("%s · +%d%% speed" % [machine_title(p.machine), roundi(p.machine.upgrade_speed * 100.0)])
		PadInfo.Pay.DIG:
			state.dig_level += 1
			toast.emit("Dig speed +%d%%" % roundi(state.dig_level * defs.dig_upgrade.amount_per_level * 100.0))

	purchased.emit(p.key)


func _spawn_drone() -> void:
	var d := DroneBrain.Drone.new()
	d.index = drones.size()
	d.position = planet.bay_position
	drones.append(d)
	drone_added.emit(d)


## Colonists loaded from a save start at their posts (or at home when off duty).
func _restore_colonists() -> void:
	for i in state.meals.size():
		Colony.spawn(self, i, Colony.home(self, i))
	Colony._assign(self)
	for c in colonists:
		if c.machine:
			c.position = Colony.work_spot(self, c.machine, c.slot)
			c.target = c.position
	Colony._step_food(self, 0.0)


func _build_nodes() -> void:
	var rich := 1.0 + Bonuses.total(defs, state, BonusDef.Kind.NODES)
	for rn in planet.resource_nodes:
		for pos in rn.positions:
			nodes.append({"item": rn.item, "position": pos, "max_stock": roundi(rn.max_stock * rich)})
	if state.node_stock.size() != nodes.size():
		state.node_stock.resize(nodes.size())
		state.node_respawn.resize(nodes.size())
		for i in nodes.size():
			state.node_stock[i] = nodes[i].max_stock
			state.node_respawn[i] = 0.0


func _build_pads() -> void:
	var meteors := planet.hazard != null and planet.hazard.kind == HazardDef.Kind.METEORS
	for m in planet.machines:
		var p_in := PadInfo.new(StringName("in_" + m.id), PadInfo.Kind.IN, m.position + m.in_pad_offset)
		p_in.machine = m
		p_in.title = "IN"
		p_in.label = m.in_pad_label
		p_in.color = m.in_pad_color
		p_in.icons.assign(m.recipe.inputs.keys())
		pads.append(p_in)
		if m.recipe.makes_item():
			var out_item := defs.item(m.recipe.output)
			var p_out := PadInfo.new(StringName("out_" + m.id), PadInfo.Kind.OUT, m.position + m.out_pad_offset)
			p_out.machine = m
			p_out.title = "OUT"
			p_out.label = out_item.short_label()
			p_out.color = out_item.color
			p_out.icons.append(out_item.id)
			pads.append(p_out)
		var p_build := _pay_pad(StringName("build_" + m.id), PadInfo.Pay.BUILD_MACHINE, m.position + m.build_pad_offset, "BUILD", "₵%d" % m.build_cost)
		p_build.machine = m
		if not m.upgrade_costs.is_empty():
			var p_up := _pay_pad(StringName("upgrade_" + m.id), PadInfo.Pay.UPGRADE_MACHINE, m.position + m.upgrade_pad_offset, "UPGRADE", "")
			p_up.machine = m
			p_up.label = upgrade_pad_label(p_up)
		# A meteor-damaged machine's REPAIR pad, in front of its IN and OUT pads.
		if meteors and m.takes_workers:
			var h := planet.hazard
			var p_fix := PadInfo.new(StringName("repair_" + m.id), PadInfo.Kind.REPAIR, m.position + m.repair_pad_offset)
			p_fix.machine = m
			p_fix.title = "REPAIR"
			p_fix.label = "%d %s" % [h.repair_cost, defs.item(h.repair_item).short_label()]
			p_fix.color = Color("ff6a4a")
			p_fix.icons.append(h.repair_item)
			pads.append(p_fix)
		# The early-game SWAP pad: surplus of one input traded for the one the machine is short of.
		if m.swap_ratio > 0 and m.recipe.inputs.size() > 1:
			var p_swap := PadInfo.new(StringName("swap_" + m.id), PadInfo.Kind.SWAP, m.position + m.swap_pad_offset)
			p_swap.machine = m
			p_swap.title = "SWAP"
			p_swap.color = Color("b58cff")
			p_swap.icons.assign(m.recipe.inputs.keys())
			# Fixed text (a changed subtitle re-uploads the pad atlas); the objective bar says which way.
			p_swap.label = "%d FOR 1" % m.swap_ratio
			pads.append(p_swap)
	var depot := PadInfo.new(&"depot", PadInfo.Kind.DEPOT, planet.depot_position)
	depot.title = "DELIVER"
	depot.label = " ".join(_sellable_names())
	depot.color = Color("86e07c")
	depot.icons.assign(_sellable_ids())
	pads.append(depot)
	var bay_pad := planet.bay_position + planet.bay_pad_offset
	_pay_pad(&"build_bay", PadInfo.Pay.BUILD_BAY, bay_pad, "BUILD", "₵%d" % planet.bay_cost)
	_pay_pad(&"buy_drone", PadInfo.Pay.BUY_DRONE, bay_pad, defs.drone_upgrade.pad_title, defs.drone_upgrade.pad_label)
	if defs.hauler_upgrade:
		var hp := _pay_pad(&"upgrade_haulers", PadInfo.Pay.UPGRADE_HAULERS, planet.bay_position + planet.hauler_pad_offset, defs.hauler_upgrade.pad_title, "")
		hp.label = upgrade_pad_label(hp)
	_pay_pad(&"pack", PadInfo.Pay.PACK, planet.outfitter_position + planet.pack_pad_offset, defs.pack_upgrade.pad_title, defs.pack_upgrade.pad_label)
	_pay_pad(&"boots", PadInfo.Pay.BOOTS, planet.outfitter_position + planet.boots_pad_offset, defs.boots_upgrade.pad_title, defs.boots_upgrade.pad_label)
	_pay_pad(&"dig", PadInfo.Pay.DIG, planet.outfitter_position + planet.dig_pad_offset, defs.dig_upgrade.pad_title, defs.dig_upgrade.pad_label)
	for i in planet.habitat_positions.size():
		if i < planet.habitat_costs.size() and planet.habitat_costs[i] > 0:
			var h := _pay_pad(StringName("build_" + Colony.habitat_key(i)), PadInfo.Pay.BUILD_HABITAT,
				planet.habitat_positions[i] + planet.habitat_pad_offset, "BUILD", "₵%d" % planet.habitat_costs[i])
			h.index = i


## An upgrade pad's subtitle: what the next level gives and its cost ("MK II ₵150", "+1 CARGO ₵150").
func upgrade_pad_label(p: PadInfo) -> String:
	var cost := pad_cost(p)
	if cost < 0:
		return "MAX"
	if p.pay == PadInfo.Pay.UPGRADE_HAULERS:
		var what := "+%d CARGO" % defs.tuning.hauler_upgrade_cargo if Economy.hauler_next_is_cargo(state.hauler_level) \
			else "+%d%% SPEED" % roundi(defs.tuning.hauler_upgrade_speed * 100.0)
		return "%s ₵%d" % [what, cost]
	return "MK %s ₵%d" % [mark(state.machine_level(p.machine.id) + 2), cost]


func _pay_pad(key: StringName, pay: PadInfo.Pay, pos: Vector2, title: String, label: String) -> PadInfo:
	var p := PadInfo.new(key, PadInfo.Kind.PAY, pos)
	p.pay = pay
	p.title = title
	p.label = label
	p.color = Color("f2b35b")
	pads.append(p)
	return p


func _sellable_names() -> PackedStringArray:
	var names := PackedStringArray()
	for id in _sellable_ids():
		names.append(defs.item(id).short_label())
	return names


func _sellable_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for m in planet.machines:
		var it := defs.item(m.recipe.output)
		if it and it.is_sellable() and not ids.has(it.id):
			ids.append(it.id)
	return ids
