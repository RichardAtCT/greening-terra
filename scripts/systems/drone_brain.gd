class_name DroneBrain
extends RefCounted
## One hauler's flight: take a job from the Dispatcher, fly to its source, load, fly to its
## target, unload, repeat. With nothing to do it waits by the Drone Bay and asks again each step.

enum State { PICK, TO_SOURCE, LOAD, TO_DEST, UNLOAD }


class Drone:
	var index: int
	var position: Vector2
	var heading: float = 0.0
	var cargo: Array[StringName] = []
	var state: State = State.PICK
	var t: float = 0.0
	var wait: float = 0.0
	var job: Dispatcher.Job
	## Items still to pick up at the job's source (held back from other haulers).
	var reserved: int = 0


static func step(sim: GameSim, d: Drone, dt: float) -> void:
	var tuning := sim.defs.tuning
	d.t += dt
	if d.state == State.PICK and not _pick(sim, d):
		_move(d, idle_point(sim, d), sim.drone_speed(), tuning.drone_arrive_radius, dt)
		return

	var job := d.job
	match d.state:
		State.TO_SOURCE:
			if job.kind == Dispatcher.Kind.FIELD and sim.state.node_stock[job.node] <= 0:
				# Someone else emptied it: try another node of the same item, else give up.
				var other := Dispatcher.best_node(sim, d, job.item, job.target_point(sim))
				if other < 0:
					_drop_job(d)
					return
				job.node = other
			if _move(d, job.source_point(sim), sim.drone_speed(), tuning.drone_arrive_radius, dt):
				d.state = State.LOAD
				d.t = 0.0
				d.wait = 0.0
		State.LOAD:
			if job.kind == Dispatcher.Kind.FIELD:
				if sim.state.node_stock[job.node] <= 0 or d.reserved <= 0:
					_leave_source(d)
				elif d.t > tuning.drone_dig_interval:
					d.t = 0.0
					sim.dig_node(job.node)
					d.cargo.append(job.item)
					d.reserved -= 1
			else:
				var id := job.source.id
				var free: int = sim.state.outputs.get(id, 0) - Dispatcher.reserved_output(sim, id, d)
				if free > 0 and d.t > tuning.drone_transfer_interval:
					d.t = 0.0
					sim.state.outputs[id] -= 1
					d.cargo.append(job.item)
					d.reserved = maxi(0, d.reserved - 1)
					d.wait = 0.0
				elif free <= 0:
					# Wait a moment for the machine to finish more, then go with what we have.
					d.wait += dt
					if d.wait > tuning.drone_output_wait:
						_leave_source(d)
			if d.cargo.size() >= sim.drone_capacity():
				_leave_source(d)
		State.TO_DEST:
			if _move(d, job.target_point(sim), sim.drone_speed(), tuning.drone_arrive_radius, dt):
				d.state = State.UNLOAD
				d.t = 0.0
				d.wait = 0.0
		State.UNLOAD:
			if d.t > tuning.drone_transfer_interval and not d.cargo.is_empty():
				d.t = 0.0
				var item: StringName = d.cargo[d.cargo.size() - 1]
				if job.target == null:
					d.cargo.pop_back()
					sim.deliver_item(item, Vector3(d.position.x, tuning.drone_hover_height, d.position.y))
				elif Economy.accepts(sim.state, job.target, item):
					d.cargo.pop_back()
					Economy.add_to_queue(sim.state, job.target, item)
				else:
					# The queue is full (the player fed it too): sell sellable goods instead.
					d.wait += tuning.drone_transfer_interval
					var def := sim.defs.item(item)
					if d.wait > tuning.drone_unload_wait and def and def.is_sellable():
						job.target = null
						job.kind = Dispatcher.Kind.SELL
						d.state = State.TO_DEST
			if d.cargo.is_empty():
				# Done: take the next job straight away, so no hauler sits idle for a step.
				_drop_job(d)
				_pick(sim, d)


## Where a hauler with nothing to do hovers: a small ring beside the Drone Bay.
static func idle_point(sim: GameSim, d: Drone) -> Vector2:
	var a := d.index * 2.4
	return sim.planet.bay_position + Vector2(cos(a), sin(a)) * sim.defs.tuning.drone_idle_radius


## Takes the best job going. Returns false if there's nothing to do.
static func _pick(sim: GameSim, d: Drone) -> bool:
	d.job = Dispatcher.best_job(sim, d)
	if d.job == null:
		d.reserved = 0
		return false
	d.reserved = d.job.amount
	d.state = State.TO_SOURCE
	d.wait = 0.0
	return true


static func _leave_source(d: Drone) -> void:
	d.reserved = 0
	if d.cargo.is_empty():
		_drop_job(d)
	else:
		d.state = State.TO_DEST


static func _drop_job(d: Drone) -> void:
	d.job = null
	d.reserved = 0
	d.state = State.PICK


## Moves towards target at speed; returns true on arrival.
static func _move(d: Drone, target: Vector2, speed: float, arrive_radius: float, dt: float) -> bool:
	var delta := target - d.position
	var dist := delta.length()
	if dist < arrive_radius:
		return true
	var s := minf(dist, speed * dt)
	d.position += delta / dist * s
	d.heading = atan2(delta.x, delta.y)
	return false
