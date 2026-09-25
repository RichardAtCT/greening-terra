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

var _timers: Dictionary = {}
var _machines: Dictionary = {}


func _init(p_defs: GameDefs, p_state: WorldState) -> void:
	defs = p_defs
	state = p_state
	planet = defs.planet(state.planet_index)
	for m in planet.machines:
		_machines[m.id] = m
		if m.starts_built:
			state.built[m.id] = true
	_build_nodes()
	_build_pads()
	for i in state.drones:
		_spawn_drone()


## Fresh state for a planet, carrying over the player's kit.
static func new_planet_state(defs: GameDefs, planet_index: int, pack_level := 0, boots_level := 0) -> WorldState:
	var s := WorldState.new()
	s.planet_index = planet_index
	s.pack_level = pack_level
	s.boots_level = boots_level
	s.player_position = defs.planet(planet_index).depot_position + Vector2(0, 3.4)
	return s


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
	return Economy.move_speed(defs, state)


func planet_name() -> String:
	var cycle := state.planet_index / defs.planets.size()
	return planet.display_name + (" " + "I".repeat(cycle + 1) if cycle > 0 else "")


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
	if Economy.deliver(state, def, planet):
		var hub := planet.hub_position
		item_flew.emit(item, from, Vector3(hub.x, HUB_DROP_HEIGHT, hub.y))
		delivered.emit(item, Economy.payout(def, planet))


## Is the pad in play right now (e.g. BUILD pads vanish once built)?
func pad_visible(p: PadInfo) -> bool:
	match p.kind:
		PadInfo.Kind.IN, PadInfo.Kind.OUT:
			return state.is_built(p.machine.id)
		PadInfo.Kind.PAY:
			match p.pay:
				PadInfo.Pay.BUILD_MACHINE:
					return not state.is_built(p.machine.id)
				PadInfo.Pay.BUILD_BAY:
					return not state.is_built(&"bay")
				PadInfo.Pay.BUY_DRONE:
					return state.is_built(&"bay")
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
	return -1


## Advances the whole planet by dt with the player standing at player_pos.
func step(dt: float, player_pos: Vector2) -> void:
	state.player_position = player_pos
	_step_mining(dt, player_pos)
	_step_nodes(dt)
	_step_pads(dt, player_pos)
	for m in planet.machines:
		if state.is_built(m.id):
			Economy.step_machine(state, m, dt)
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
			if not pack_full() and _tick(&"mine", dt, defs.tuning.mine_interval):
				dig_node(i)
				state.stack.append(nodes[i].item)
				stack_changed.emit()
			break


func _step_nodes(dt: float) -> void:
	for i in nodes.size():
		if state.node_stock[i] <= 0:
			state.node_respawn[i] += dt
			if state.node_respawn[i] > defs.tuning.node_respawn_time:
				state.node_stock[i] = nodes[i].max_stock
				state.node_respawn[i] = 0.0


func _step_pads(dt: float, player_pos: Vector2) -> void:
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


func _step_pay(p: PadInfo, dt: float) -> void:
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
		_buy(p)


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
	purchased.emit(p.key)


func _spawn_drone() -> void:
	var d := DroneBrain.Drone.new()
	d.index = drones.size()
	d.position = planet.bay_position
	drones.append(d)
	drone_added.emit(d)


func _build_nodes() -> void:
	for rn in planet.resource_nodes:
		for pos in rn.positions:
			nodes.append({"item": rn.item, "position": pos, "max_stock": rn.max_stock})
	if state.node_stock.size() != nodes.size():
		state.node_stock.resize(nodes.size())
		state.node_respawn.resize(nodes.size())
		for i in nodes.size():
			state.node_stock[i] = nodes[i].max_stock
			state.node_respawn[i] = 0.0


func _build_pads() -> void:
	for m in planet.machines:
		var out_item := defs.item(m.recipe.output)
		var p_in := PadInfo.new(StringName("in_" + m.id), PadInfo.Kind.IN, m.position + m.in_pad_offset)
		p_in.machine = m
		p_in.title = "IN"
		p_in.label = m.in_pad_label
		p_in.color = m.in_pad_color
		pads.append(p_in)
		var p_out := PadInfo.new(StringName("out_" + m.id), PadInfo.Kind.OUT, m.position + m.out_pad_offset)
		p_out.machine = m
		p_out.title = "OUT"
		p_out.label = out_item.short_label()
		p_out.color = out_item.color
		pads.append(p_out)
		var p_build := _pay_pad(StringName("build_" + m.id), PadInfo.Pay.BUILD_MACHINE, m.position + m.build_pad_offset, "BUILD", "₵%d" % m.build_cost)
		p_build.machine = m
	var depot := PadInfo.new(&"depot", PadInfo.Kind.DEPOT, planet.depot_position)
	depot.title = "DELIVER"
	depot.label = " ".join(_sellable_names())
	depot.color = Color("86e07c")
	pads.append(depot)
	var bay_pad := planet.bay_position + planet.bay_pad_offset
	_pay_pad(&"build_bay", PadInfo.Pay.BUILD_BAY, bay_pad, "BUILD", "₵%d" % planet.bay_cost)
	_pay_pad(&"buy_drone", PadInfo.Pay.BUY_DRONE, bay_pad, defs.drone_upgrade.pad_title, defs.drone_upgrade.pad_label)
	_pay_pad(&"pack", PadInfo.Pay.PACK, planet.outfitter_position + planet.pack_pad_offset, defs.pack_upgrade.pad_title, defs.pack_upgrade.pad_label)
	_pay_pad(&"boots", PadInfo.Pay.BOOTS, planet.outfitter_position + planet.boots_pad_offset, defs.boots_upgrade.pad_title, defs.boots_upgrade.pad_label)


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
	for m in planet.machines:
		var it := defs.item(m.recipe.output)
		if it.is_sellable():
			names.append(it.short_label())
	return names
