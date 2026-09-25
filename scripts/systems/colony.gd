class_name Colony
extends RefCounted
## Colonists, landers, food and habitats (SPEC 4.1), with no scene access.
## A lander comes down as terraform passes each of the planet's milestones. Its colonists move into
## a habitat if there's room (the first habitat is built free by the first lander) and otherwise
## wait at the hub. Housed colonists work beside built machines, up to two each, making them faster.
## Everyone eats from the hub's food store; a hungry colonist stops working until fed, but never
## leaves. Walking is straight lines that slide around buildings (the ground is flat and open).


class Colonist:
	var index: int
	var position: Vector2
	var heading: float = 0.0
	## The machine this colonist works, or null when off duty.
	var machine: MachineDef
	## Which side of the machine (0 or 1).
	var slot: int = 0
	var target: Vector2
	var moving: bool = false
	## Off duty: seconds until the next stroll, and how many strolls so far.
	var pause: float = 0.0
	var strolls: int = 0
	## At the machine, fed, and making it faster.
	var working: bool = false
	var hungry: bool = false


static func step(sim: GameSim, dt: float) -> void:
	_step_landers(sim, dt)
	_step_food(sim, dt)
	_assign(sim)
	for c in sim.colonists:
		_step_colonist(sim, c, dt)


## Number of landers due at the current terraform %.
static func landers_due(planet: PlanetDef, terraform: float) -> int:
	var n := 0
	for m in planet.lander_milestones:
		if terraform >= m:
			n += 1
	return n


## Terraform % that calls the next lander, or -1 once they've all been called.
static func next_lander_at(planet: PlanetDef, terraform: float) -> float:
	for m in planet.lander_milestones:
		if terraform < m:
			return m
	return -1.0


## Where the colony stands, for the objective bar: who's waiting for a home, or when the next
## colonists come. Empty once every lander has landed and everyone is housed.
static func outlook(sim: GameSim) -> String:
	var s := sim.state
	if s.colonists_waiting > 0:
		return "%d colonist%s need a Habitat." % [s.colonists_waiting, "s" if s.colonists_waiting > 1 else ""]
	if s.lander_t >= 0.0:
		return "A lander is coming down."
	var next := next_lander_at(sim.planet, s.terraform)
	if next < 0.0:
		return ""
	return "At %d%% a lander brings %d colonists." % [roundi(next), sim.planet.colonists_per_lander]


static func habitat_key(index: int) -> StringName:
	return StringName("habitat_%d" % (index + 1))


static func habitats_built(sim: GameSim) -> int:
	var n := 0
	for i in sim.planet.habitat_positions.size():
		if sim.state.is_built(habitat_key(i)):
			n += 1
	return n


## Colonists per lander: the planet's, plus Big Lander.
static func colonists_per_lander(sim: GameSim) -> int:
	return sim.planet.colonists_per_lander + roundi(Bonuses.total(sim.defs, sim.state, BonusDef.Kind.LANDER))


## Colonists one habitat houses. Habitats grow with Big Lander, so everyone still fits.
static func habitat_capacity(sim: GameSim) -> int:
	var base := sim.defs.colony.habitat_capacity
	return ceili(float(base) * colonists_per_lander(sim) / maxi(1, sim.planet.colonists_per_lander))


## Most colonists a planet brings (for sizing buffers).
static func max_colonists(sim: GameSim) -> int:
	return sim.planet.lander_milestones.size() * colonists_per_lander(sim)


## Colonists a machine takes: none at a Heat Tower, more once upgraded.
static func workers_for(sim: GameSim, m: MachineDef) -> int:
	if not m.takes_workers:
		return 0
	var n := sim.defs.colony.max_per_machine
	if sim.state.machine_level(m.id) > 0:
		n += sim.defs.colony.upgraded_extra_workers
	return n


static func housing(sim: GameSim) -> int:
	return habitats_built(sim) * habitat_capacity(sim)


static func housed(sim: GameSim) -> int:
	return sim.state.meals.size()


## Food the hub keeps back for the colonists before selling the rest (SPEC 4.1: five minutes' worth).
static func food_target(sim: GameSim) -> float:
	var c := sim.defs.colony
	return ceilf(housed(sim) * c.food_reserve_seconds / c.meal_interval)


static func hungry_count(sim: GameSim) -> int:
	var n := 0
	for m in sim.state.meals:
		if m <= 0.0:
			n += 1
	return n


## How much faster colonists make a machine run (1.0 = no one working it).
static func machine_speed(sim: GameSim, machine_id: StringName) -> float:
	var n := 0
	for c in sim.colonists:
		if c.working and c.machine.id == machine_id:
			n += 1
	return 1.0 + n * sim.defs.colony.machine_boost


## Moves waiting colonists into free habitat space. Called on arrival and when a habitat is built.
static func house(sim: GameSim) -> void:
	var s := sim.state
	while s.colonists_waiting > 0 and s.meals.size() < housing(sim):
		s.colonists_waiting -= 1
		s.meals.append(sim.defs.colony.meal_interval)
		var c := spawn(sim, s.meals.size() - 1, sim.planet.lander_position)
		sim.colonist_added.emit(c)


## Creates the runtime colonist for housed colonist `index` (on arrival, or at load time).
static func spawn(sim: GameSim, index: int, at: Vector2) -> Colonist:
	var c := Colonist.new()
	c.index = index
	c.position = at
	c.target = at
	sim.colonists.append(c)
	return c


static func _step_landers(sim: GameSim, dt: float) -> void:
	var s := sim.state
	if s.lander_t < 0.0:
		if s.landers < landers_due(sim.planet, s.terraform):
			s.lander_t = sim.defs.colony.lander_descent_time
			sim.lander_coming.emit()
		return
	s.lander_t -= dt
	if s.lander_t > 0.0:
		return
	s.lander_t = -1.0
	s.landers += 1
	var n := colonists_per_lander(sim)
	s.colonists_waiting += n
	if habitats_built(sim) == 0 and not sim.planet.habitat_positions.is_empty():
		s.built[habitat_key(0)] = true
	house(sim)
	sim.lander_landed.emit(n)
	var text := "Lander arrived · %d waiting for a habitat" % s.colonists_waiting if s.colonists_waiting > 0 \
		else "Lander arrived: %d colonists" % n
	var next := next_lander_at(sim.planet, s.terraform)
	if next >= 0.0:
		text += " · next at %d%%" % roundi(next)
	sim.toast.emit(text)


static func _step_food(sim: GameSim, dt: float) -> void:
	var s := sim.state
	var interval := sim.defs.colony.meal_interval
	for i in s.meals.size():
		var m := s.meals[i] - dt
		if m <= 0.0:
			if s.food >= 1.0:
				s.food -= 1.0
				m = maxf(m + interval, interval * 0.5)
			else:
				m = 0.0
		s.meals[i] = m
	for c in sim.colonists:
		c.hungry = c.index < s.meals.size() and s.meals[c.index] <= 0.0


## Keeps each colonist on the machine they already work, and gives the rest a free spot, spreading
## them one per machine before doubling up. Built machines never unbuild, so a job is for good.
static func _assign(sim: GameSim) -> void:
	var taken := {}
	for c in sim.colonists:
		if c.machine:
			taken[c.machine.id] = taken.get(c.machine.id, 0) + 1
	for c in sim.colonists:
		if c.machine:
			continue
		var best: MachineDef = null
		for m in sim.planet.machines:
			if sim.state.is_built(m.id) and taken.get(m.id, 0) < workers_for(sim, m) \
					and (best == null or taken.get(m.id, 0) < taken.get(best.id, 0)):
				best = m
		if best == null:
			break
		c.machine = best
		c.slot = taken.get(best.id, 0)
		taken[best.id] = c.slot + 1


## Where a colonist stands to work a machine: either side of it, a little towards its pads.
## Slots 2 and 3 (an upgraded machine) stand behind the first two.
static func work_spot(sim: GameSim, m: MachineDef, slot: int) -> Vector2:
	var c := sim.defs.colony
	var side := -1.0 if slot % 2 == 0 else 1.0
	var row := slot / 2
	return m.position + Vector2(side * (m.collide_radius + c.work_side_gap), c.work_forward - row * c.work_row_gap)


## The habitat a colonist lives in: the (index / capacity)-th one built.
static func home(sim: GameSim, index: int) -> Vector2:
	var k := index / habitat_capacity(sim)
	for i in sim.planet.habitat_positions.size():
		if sim.state.is_built(habitat_key(i)):
			if k == 0:
				return sim.planet.habitat_positions[i]
			k -= 1
	return sim.planet.hub_position


static func _step_colonist(sim: GameSim, c: Colonist, dt: float) -> void:
	var tuning := sim.defs.colony
	if c.machine:
		c.target = work_spot(sim, c.machine, c.slot)
	elif not c.moving:
		c.pause -= dt
		if c.pause <= 0.0:
			# Off duty: stroll somewhere round home. Deterministic, so the balance sim repeats.
			c.strolls += 1
			var a := fposmod(c.index * 2.39996 + c.strolls * 1.9, TAU)
			var near := sim.planet.habitat_collide_radius + 0.5
			var r := lerpf(near, maxf(near, tuning.wander_radius), fposmod(c.index * 0.37 + c.strolls * 0.61, 1.0))
			c.target = _slide(sim, home(sim, c.index) + Vector2(cos(a), sin(a)) * r)
			c.pause = lerpf(tuning.wander_pause_min, tuning.wander_pause_max, fposmod(c.strolls * 0.43 + c.index * 0.29, 1.0))
	var to := c.target - c.position
	var dist := to.length()
	c.moving = dist > 0.08
	if c.moving:
		var stepv := to / dist * minf(dist, tuning.walk_speed * dt)
		var next := _slide(sim, c.position + stepv)
		if next.distance_to(c.position) < stepv.length() * 0.1:
			# Walking straight at a building: step off to the side to go round it.
			next = _slide(sim, c.position + stepv.rotated(1.2))
		c.position = next
		c.heading = atan2(stepv.x, stepv.y)
	elif c.machine:
		# Face the machine while working.
		var face := c.machine.position - c.position
		c.heading = atan2(face.x, face.y)
	c.working = c.machine != null and not c.moving and not c.hungry


## Pushes a point out of any building it walked into, so colonists slide round them.
static func _slide(sim: GameSim, p: Vector2) -> Vector2:
	var planet := sim.planet
	p = _push_out(p, planet.hub_position, planet.hub_collide_radius + 0.3)
	for m in planet.machines:
		if sim.state.is_built(m.id):
			p = _push_out(p, m.position, m.collide_radius + 0.2)
	p = _push_out(p, planet.bay_position, planet.bay_collide_radius + 0.2)
	p = _push_out(p, planet.outfitter_position, planet.outfitter_collide_radius + 0.2)
	for i in planet.habitat_positions.size():
		if sim.state.is_built(habitat_key(i)):
			p = _push_out(p, planet.habitat_positions[i], planet.habitat_collide_radius + 0.2)
	return p


static func _push_out(p: Vector2, center: Vector2, radius: float) -> Vector2:
	var d := p - center
	var len := d.length()
	if len >= radius:
		return p
	if len < 0.001:
		return center + Vector2(radius, 0)
	return center + d / len * radius
