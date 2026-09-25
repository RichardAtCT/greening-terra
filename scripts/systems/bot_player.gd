class_name BotPlayer
extends RefCounted
## A scripted player for the balance sim: walks at the real walk speed and greedily does the most
## valuable thing it can (buy, feed, collect, deliver, dig). Pure logic on top of GameSim.

enum Plan { NONE, BUY, FEED, DELIVER, COLLECT, DIG, WAIT }

## Relative value per credit of each purchase, used to pick between affordable options.
const BUY_VALUE := {
	PadInfo.Pay.BUILD_MACHINE: 3.0,
	PadInfo.Pay.BUILD_BAY: 3.0,
	PadInfo.Pay.BUY_DRONE: 2.0,
	PadInfo.Pay.PACK: 1.2,
	PadInfo.Pay.BOOTS: 1.0,
}

var sim: GameSim
var position: Vector2
var plan: Plan = Plan.NONE
var target: Vector2
var pad: PadInfo
var machine: MachineDef
var dig_item: StringName
var node_index := -1
var _plan_time := 0.0


func _init(p_sim: GameSim) -> void:
	sim = p_sim
	position = sim.state.player_position


## Advances the bot and the sim by dt.
func step(dt: float) -> void:
	if plan == Plan.NONE or _plan_finished():
		_decide()
	_plan_time += dt
	var to := target - position
	var reach := sim.defs.tuning.pad_radius * 0.5 if plan != Plan.DIG else sim.defs.tuning.mine_radius * 0.5
	if to.length() > reach:
		position += to.limit_length(sim.move_speed() * dt)
	sim.step(dt, position)


func _arrived() -> bool:
	var reach := sim.defs.tuning.pad_radius * 0.5 if plan != Plan.DIG else sim.defs.tuning.mine_radius * 0.5
	return position.distance_to(target) <= reach + 0.01


func _plan_finished() -> bool:
	var s := sim.state
	match plan:
		Plan.BUY:
			var cost := sim.pad_cost(pad)
			return not sim.pad_visible(pad) or cost < 0 or s.paid.get(pad.key, 0) == 0 and _plan_time > 0.5 and _arrived() \
					or (_arrived() and s.credits < 1.0)
		Plan.FEED:
			return _arrived() and Economy.feedable_index(s, machine) < 0
		Plan.DELIVER:
			return _arrived() and Economy.sellable_index(sim.defs, s.stack) < 0
		Plan.COLLECT:
			return _arrived() and (s.outputs.get(machine.id, 0) <= 0 or sim.pack_full())
		Plan.DIG:
			return sim.pack_full() or node_index < 0 or s.node_stock[node_index] <= 0
		Plan.WAIT:
			return _plan_time > 1.0
	return true


func _start_plan(p: Plan, where: Vector2) -> void:
	plan = p
	target = where
	_plan_time = 0.0


func _decide() -> void:
	var s := sim.state
	# 1. Buy the most valuable thing we can afford.
	var best: PadInfo = null
	var best_value := 0.0
	var saving_for := _next_building_cost()
	for p in sim.pads:
		if p.kind != PadInfo.Kind.PAY or not sim.pad_visible(p):
			continue
		var cost := sim.pad_cost(p)
		if cost <= 0:
			continue
		var remaining: float = cost - s.paid.get(p.key, 0)
		if remaining > s.credits:
			continue
		var is_building := p.pay == PadInfo.Pay.BUILD_MACHINE or p.pay == PadInfo.Pay.BUILD_BAY
		# Don't fritter credits on kit when a building is nearly affordable.
		if not is_building and saving_for > 0 and s.credits * 2.0 >= saving_for:
			continue
		var value: float = BUY_VALUE[p.pay] / cost
		if value > best_value:
			best_value = value
			best = p
	if best:
		pad = best
		_start_plan(Plan.BUY, best.position)
		return

	# 2. Feed carried items into a machine that takes them (intermediates to multi-input machines).
	for m in sim.planet.machines:
		if s.is_built(m.id) and Economy.feedable_index(s, m) >= 0:
			machine = m
			_start_plan(Plan.FEED, m.position + m.in_pad_offset)
			return

	# 3. Sell what we carry.
	if Economy.sellable_index(sim.defs, s.stack) >= 0:
		_start_plan(Plan.DELIVER, sim.planet.depot_position)
		return

	# 4. Collect finished goods if a machine has a worthwhile pile.
	var best_out := 0
	for m in sim.planet.machines:
		var outs: int = s.outputs.get(m.id, 0)
		if s.is_built(m.id) and outs > best_out and outs >= mini(3, sim.pack_capacity() - s.stack.size()):
			best_out = outs
			machine = m
	if best_out > 0 and not sim.pack_full():
		_start_plan(Plan.COLLECT, machine.position + machine.out_pad_offset)
		return

	# 5. Dig whatever raw resource is most needed.
	dig_item = _most_needed_raw()
	if dig_item != &"" and not sim.pack_full():
		node_index = sim.nearest_node(dig_item, position)
		if node_index >= 0:
			_start_plan(Plan.DIG, sim.nodes[node_index].position)
			return
	_start_plan(Plan.WAIT, sim.planet.depot_position)


func _next_building_cost() -> int:
	var cheapest := 0
	for p in sim.pads:
		if (p.pay == PadInfo.Pay.BUILD_MACHINE or p.pay == PadInfo.Pay.BUILD_BAY) and sim.pad_visible(p):
			var c := sim.pad_cost(p)
			if c > 0 and (cheapest == 0 or c < cheapest):
				cheapest = c
	return cheapest


## Raw item whose machine chain is shortest of input (balancing multi-input recipes).
func _most_needed_raw() -> StringName:
	var s := sim.state
	var best := &""
	var best_have := INF
	for m in sim.planet.machines:
		if not s.is_built(m.id) or m.recipe.inputs.size() != 1:
			continue
		var raw: StringName = m.recipe.inputs.keys()[0]
		if not sim.has_nodes_for(raw) or s.queued(m.id, raw) >= m.queue_cap:
			continue
		# Everything already in this chain: queued raw, finished output, output queued downstream.
		var have: float = s.queued(m.id, raw) + s.outputs.get(m.id, 0)
		for other in sim.planet.machines:
			if other.recipe.inputs.size() > 1:
				have += s.queued(other.id, m.recipe.output)
		if have < best_have:
			best_have = have
			best = raw
	return best
