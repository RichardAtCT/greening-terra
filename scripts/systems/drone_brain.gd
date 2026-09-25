class_name DroneBrain
extends RefCounted
## The prototype's hauler logic: each drone takes a fixed route by index (index % routes).
## M4 replaces this with the scoring dispatcher from SPEC 4.5.

enum State { PICK, TO_SOURCE, LOAD, TO_DEST, UNLOAD }


class Drone:
	var index: int
	var position: Vector2
	var heading: float = 0.0
	var cargo: Array[StringName] = []
	var state: State = State.PICK
	var t: float = 0.0
	var wait: float = 0.0
	## Route: { "src": "field"/"out", "src_id": item or machine id, "dst": "machine:<id>"/"auto"/"depot" }
	var route: Dictionary = {}
	var node: int = -1
	var dest: String = ""


static func routes(sim: GameSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var feeders: Array[MachineDef] = []
	for m in sim.planet.machines:
		if m.recipe.inputs.size() == 1:
			feeders.append(m)
	# Single-input machines fed from the field, then their output routed onward.
	for m in feeders:
		if not sim.state.is_built(m.id):
			continue
		var raw: StringName = m.recipe.inputs.keys()[0]
		if sim.has_nodes_for(raw):
			out.append({"src": "field", "src_id": raw, "dst": "machine:" + m.id})
		out.append({"src": "out", "src_id": m.id, "dst": "auto"})
	# Multi-input machines (the greenhouse) sell straight to the hub.
	for m in sim.planet.machines:
		if m.recipe.inputs.size() > 1 and sim.state.is_built(m.id):
			out.append({"src": "out", "src_id": m.id, "dst": "depot"})
	return out


static func step(sim: GameSim, d: Drone, dt: float) -> void:
	var tuning := sim.defs.tuning
	d.t += dt
	if d.state == State.PICK:
		var rs := routes(sim)
		if rs.is_empty():
			return
		d.route = rs[d.index % rs.size()]
		d.state = State.TO_SOURCE
		d.node = -1
		d.dest = ""
		d.wait = 0.0

	var from_field: bool = d.route.src == "field"
	var src_id := StringName(d.route.src_id)

	match d.state:
		State.TO_SOURCE:
			var target: Vector2
			if from_field:
				if d.node < 0 or sim.state.node_stock[d.node] <= 0:
					d.node = sim.nearest_node(src_id, d.position)
				if d.node < 0:
					_move(d, sim.idle_point_for(src_id), tuning, dt)
					return
				target = sim.nodes[d.node].position
			else:
				target = sim.machine_def(src_id).position + sim.machine_def(src_id).out_pad_offset
			if _move(d, target, tuning, dt):
				d.state = State.LOAD
				d.t = 0.0
				d.wait = 0.0
		State.LOAD:
			if from_field:
				if d.node < 0 or sim.state.node_stock[d.node] <= 0:
					d.state = State.TO_DEST if not d.cargo.is_empty() else State.TO_SOURCE
				elif d.t > tuning.drone_dig_interval:
					d.t = 0.0
					sim.dig_node(d.node)
					d.cargo.append(src_id)
			else:
				var waiting: int = sim.state.outputs.get(src_id, 0)
				if waiting > 0 and d.t > tuning.drone_transfer_interval:
					d.t = 0.0
					sim.state.outputs[src_id] = waiting - 1
					d.cargo.append(sim.machine_def(src_id).recipe.output)
					d.wait = 0.0
				elif waiting == 0:
					d.wait += dt
					if not d.cargo.is_empty() and d.wait > tuning.drone_output_wait:
						d.state = State.TO_DEST
			if d.cargo.size() >= tuning.drone_capacity:
				d.state = State.TO_DEST
		State.TO_DEST:
			if d.dest == "":
				d.dest = _choose_dest(sim, d)
			if _move(d, _dest_point(sim, d.dest), tuning, dt):
				d.state = State.UNLOAD
				d.t = 0.0
				d.wait = 0.0
		State.UNLOAD:
			if d.t > tuning.drone_transfer_interval and not d.cargo.is_empty():
				d.t = 0.0
				var item: StringName = d.cargo[d.cargo.size() - 1]
				if d.dest == "depot":
					d.cargo.pop_back()
					sim.deliver_item(item, Vector3(d.position.x, tuning.drone_hover_height, d.position.y))
				else:
					var m := sim.machine_def(StringName(d.dest.trim_prefix("machine:")))
					if Economy.accepts(sim.state, m, item):
						d.cargo.pop_back()
						Economy.add_to_queue(sim.state, m, item)
					else:
						d.wait += tuning.drone_transfer_interval
						var def := sim.defs.item(item)
						if d.wait > tuning.drone_unload_wait and def and def.is_sellable():
							d.dest = "depot"
							d.state = State.TO_DEST
			if d.cargo.is_empty():
				d.state = State.PICK


static func _choose_dest(sim: GameSim, d: Drone) -> String:
	var dst: String = d.route.dst
	if dst != "auto":
		return dst
	# Auto: feed a built multi-input machine that takes this item while its queue has room, else sell.
	var item: StringName = d.cargo[0] if not d.cargo.is_empty() else &""
	for m in sim.planet.machines:
		if m.recipe.inputs.size() > 1 and sim.state.is_built(m.id) and m.recipe.inputs.has(item) \
				and sim.state.queued(m.id, item) < m.queue_cap - sim.defs.tuning.drone_queue_margin:
			return "machine:" + m.id
	return "depot"


static func _dest_point(sim: GameSim, dest: String) -> Vector2:
	if dest == "depot":
		return sim.planet.depot_position
	var m := sim.machine_def(StringName(dest.trim_prefix("machine:")))
	return m.position + m.in_pad_offset


## Moves towards target; returns true on arrival.
static func _move(d: Drone, target: Vector2, tuning: GameTuning, dt: float) -> bool:
	var delta := target - d.position
	var dist := delta.length()
	if dist < tuning.drone_arrive_radius:
		return true
	var s := minf(dist, tuning.drone_speed * dt)
	d.position += delta / dist * s
	d.heading = atan2(delta.x, delta.y)
	return false
