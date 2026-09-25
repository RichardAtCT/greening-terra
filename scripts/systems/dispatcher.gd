class_name Dispatcher
extends RefCounted
## SPEC 4.5: an idle hauler takes the highest-scoring job. The score is urgency (the target's input
## queue running low, the source's output filling up) minus the distance flown. Items a hauler has
## promised to pick up or drop off are reserved, so two haulers never chase the same pile.
## Reservations are read from the haulers themselves, so there is no bookkeeping to go stale.

enum Kind {
	## Dig a raw resource and carry it to a machine's IN pad.
	FIELD,
	## Carry a machine's output to another machine's IN pad (plates and O₂ to the greenhouse).
	FEED,
	## Carry a machine's output to the hub.
	SELL,
}


class Job:
	var kind: Kind
	var item: StringName
	## FIELD: the resource node dug (-1 otherwise).
	var node: int = -1
	## FEED and SELL: the machine whose OUT pad is emptied.
	var source: MachineDef
	## FIELD and FEED: the machine whose IN pad is filled. Null means the hub.
	var target: MachineDef
	## Items reserved when the job was taken.
	var amount: int = 0
	var score: float = 0.0

	func source_point(sim: GameSim) -> Vector2:
		if kind == Kind.FIELD:
			return sim.nodes[node].position
		return source.position + source.out_pad_offset

	func target_point(sim: GameSim) -> Vector2:
		if target == null:
			return sim.planet.depot_position
		return target.position + target.in_pad_offset

	func describe() -> String:
		var to := "hub" if target == null else String(target.id)
		var from := "node %d" % node if kind == Kind.FIELD else String(source.id)
		return "%s %s: %s → %s" % [Kind.keys()[kind].to_lower(), item, from, to]


## The best job for this hauler right now, or null if there is nothing to do.
static func best_job(sim: GameSim, d: DroneBrain.Drone) -> Job:
	var best: Job = null
	for j in jobs(sim, d):
		if best == null or j.score > best.score:
			best = j
	return best


## Every job the hauler could take now, scored from where it is.
static func jobs(sim: GameSim, d: DroneBrain.Drone) -> Array[Job]:
	var out: Array[Job] = []
	var s := sim.state
	var t := sim.defs.tuning
	var cap := sim.drone_capacity()
	for m in sim.planet.machines:
		if not s.is_built(m.id):
			continue
		# Raw resources from the field into machines that take them.
		for raw in m.recipe.inputs:
			if not sim.has_nodes_for(raw):
				continue
			var room := m.queue_cap - s.queued(m.id, raw) - incoming(sim, m.id, raw, d)
			if room <= 0:
				continue
			var node := best_node(sim, d, raw, m.position + m.in_pad_offset)
			if node < 0:
				continue
			var j := Job.new()
			j.kind = Kind.FIELD
			j.item = raw
			j.node = node
			j.target = m
			j.amount = mini(cap, mini(room, sim.state.node_stock[node] - reserved_node(sim, node, d)))
			_score(sim, d, j, 1.0 - float(m.queue_cap - room) / m.queue_cap, 0.0, 0.0)
			out.append(j)
		# Finished goods on this machine's OUT pad (a Heat Tower makes none).
		if not m.recipe.makes_item():
			continue
		var avail: int = s.outputs.get(m.id, 0) - reserved_output(sim, m.id, d)
		if avail <= 0:
			continue
		var item := m.recipe.output
		var full := float(s.outputs.get(m.id, 0)) / Economy.output_cap(s, m)
		for other in sim.planet.machines:
			if other == m or not s.is_built(other.id) or not other.recipe.inputs.has(item):
				continue
			var room := other.queue_cap - t.drone_queue_margin - s.queued(other.id, item) - incoming(sim, other.id, item, d)
			if room <= 0:
				continue
			var j := Job.new()
			j.kind = Kind.FEED
			j.item = item
			j.source = m
			j.target = other
			j.amount = mini(cap, mini(avail, room))
			_score(sim, d, j, 1.0 - float(other.queue_cap - room) / other.queue_cap, full, t.dispatch_feed_bonus)
			out.append(j)
		var def := sim.defs.item(item)
		if def and def.is_sellable():
			var j := Job.new()
			j.kind = Kind.SELL
			j.item = item
			j.source = m
			j.amount = mini(cap, avail)
			_score(sim, d, j, 0.0, full, t.dispatch_sell_bonus)
			out.append(j)
	return out


static func _score(sim: GameSim, d: DroneBrain.Drone, j: Job, need: float, full: float, bonus: float) -> void:
	var t := sim.defs.tuning
	var src := j.source_point(sim)
	var travel := d.position.distance_to(src) + src.distance_to(j.target_point(sim))
	j.score = need * t.dispatch_need_weight + full * t.dispatch_full_weight + bonus \
		+ float(j.amount) / sim.drone_capacity() * t.dispatch_load_weight - travel * t.dispatch_distance_weight


## The node of this item with unreserved stock that makes the shortest trip (hauler → node → dest).
static func best_node(sim: GameSim, d: DroneBrain.Drone, item: StringName, dest: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in sim.nodes.size():
		if sim.nodes[i].item != item or sim.state.node_stock[i] - reserved_node(sim, i, d) <= 0:
			continue
		var p: Vector2 = sim.nodes[i].position
		var dist := d.position.distance_to(p) + p.distance_to(dest)
		if dist < best_d:
			best_d = dist
			best = i
	return best


## Items at a machine's OUT pad still promised to haulers (other than `except`).
static func reserved_output(sim: GameSim, machine_id: StringName, except: DroneBrain.Drone = null) -> int:
	var n := 0
	for o in sim.drones:
		if o != except and o.job and o.job.source and o.job.source.id == machine_id:
			n += o.reserved
	return n


## Stock in a resource node still promised to haulers (other than `except`).
static func reserved_node(sim: GameSim, node: int, except: DroneBrain.Drone = null) -> int:
	var n := 0
	for o in sim.drones:
		if o != except and o.job and o.job.node == node:
			n += o.reserved
	return n


## Items on their way to a machine's IN queue: carried, or still to be picked up.
static func incoming(sim: GameSim, machine_id: StringName, item: StringName, except: DroneBrain.Drone = null) -> int:
	var n := 0
	for o in sim.drones:
		if o != except and o.job and o.job.target and o.job.target.id == machine_id and o.job.item == item:
			n += o.cargo.size() + o.reserved
	return n
