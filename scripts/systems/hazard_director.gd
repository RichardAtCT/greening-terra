class_name HazardDirector
extends RefCounted
## Schedules, telegraphs and applies the planet's hazard (SPEC 4.2), with no scene access.
## Between the hazard's start and end terraform %, it waits a random gap, warns for telegraph_time,
## then runs for duration. Gaps grow as terraform rises. The random gap is seeded from the planet
## and the number of hazards so far, so a saved game and the balance sim both repeat exactly.
## Three kinds (HazardDef.Kind): a storm slows the player and haulers; a cold snap slows machines
## outside a burning Heat Tower's radius; a meteor shower marks its impact points when the warning
## starts and damages the machines it lands on when it ends (never the hub, never the machine that
## makes the repair item, so a repair is always possible).

enum Phase { NONE, WARNING, ACTIVE }


static func step(sim: GameSim, dt: float) -> void:
	var h := sim.planet.hazard
	if h == null:
		return
	var s := sim.state
	match s.hazard_phase:
		Phase.NONE:
			if s.terraform < h.start_percent or s.terraform >= h.end_percent:
				s.hazard_wait = -1.0
				return
			if s.hazard_wait < 0.0:
				s.hazard_wait = gap(h, sim.planet.seed, s.hazard_count, s.terraform)
			s.hazard_wait -= dt
			if s.hazard_wait <= 0.0:
				if h.kind == HazardDef.Kind.METEORS:
					s.impacts = impact_points(sim)
				_enter(sim, Phase.WARNING, h.telegraph_time)
		Phase.WARNING:
			s.hazard_t -= dt
			if s.hazard_t <= 0.0:
				_enter(sim, Phase.ACTIVE, duration(sim))
		Phase.ACTIVE:
			s.hazard_t -= dt
			if s.hazard_t <= 0.0:
				if h.kind == HazardDef.Kind.METEORS:
					_land_meteors(sim)
				s.hazard_count += 1
				s.hazard_wait = -1.0
				_enter(sim, Phase.NONE, 0.0)


## Seconds to wait before hazard number `count`, at terraform % tf.
static func gap(h: HazardDef, planet_seed: int, count: int, tf: float) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([planet_seed, count])
	var k := clampf(inverse_lerp(h.start_percent, h.end_percent, tf), 0.0, 1.0)
	return rng.randf_range(h.interval_min, h.interval_max) * lerpf(1.0, h.interval_growth, k)


## How long the hazard lasts, shortened by Weather Shield.
static func duration(sim: GameSim) -> float:
	var shield := Bonuses.total(sim.defs, sim.state, BonusDef.Kind.HAZARD_DURATION)
	return sim.planet.hazard.duration * maxf(0.2, 1.0 - shield)


## Machines a meteor may damage: built, working machines, except any that makes the repair item.
static func hittable(sim: GameSim, m: MachineDef) -> bool:
	var h := sim.planet.hazard
	return sim.state.is_built(m.id) and m.takes_workers and m.recipe.output != h.repair_item


## Where the next shower lands: meteor_hits of them on machines (chosen at random among those
## that can be hit and aren't already damaged), the rest on open ground round the colony.
static func impact_points(sim: GameSim) -> Array[Vector2]:
	var h := sim.planet.hazard
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.planet.seed, sim.state.hazard_count, &"impacts"])
	var targets: Array[MachineDef] = []
	for m in sim.planet.machines:
		if hittable(sim, m) and not sim.state.is_damaged(m.id):
			targets.append(m)
	var out: Array[Vector2] = []
	for i in mini(h.meteor_hits, targets.size()):
		out.append(targets.pop_at(rng.randi() % targets.size()).position)
	var tries := 0
	while out.size() < h.meteor_count and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var p := sim.planet.hub_position + Vector2(cos(a), sin(a)) * rng.randf_range(9.0, 24.0)
		if _clear_of_buildings(sim, p, h.impact_radius + 2.0):
			out.append(p)
	return out


static func _clear_of_buildings(sim: GameSim, p: Vector2, margin: float) -> bool:
	var planet := sim.planet
	if p.distance_to(planet.hub_position) < planet.hub_collide_radius + margin:
		return false
	for m in planet.machines:
		if p.distance_to(m.position) < m.collide_radius + margin:
			return false
	for c in [planet.bay_position, planet.outfitter_position, planet.lander_position] + Array(planet.habitat_positions):
		if p.distance_to(c) < 2.0 + margin:
			return false
	return true


static func _land_meteors(sim: GameSim) -> void:
	var h := sim.planet.hazard
	var s := sim.state
	var hit: Array[StringName] = []
	for m in sim.planet.machines:
		if not hittable(sim, m) or s.is_damaged(m.id):
			continue
		for p in s.impacts:
			if p.distance_to(m.position) <= h.impact_radius:
				s.damaged[m.id] = true
				hit.append(m.id)
				break
	var points := s.impacts.duplicate()
	s.impacts.clear()
	sim.meteors_landed.emit(points, hit)
	for id in hit:
		sim.toast.emit("Meteor hit the %s · repair with %d %s" % [sim.machine_def(id).display_name,
			h.repair_cost, sim.defs.item(h.repair_item).display_name.to_lower() + "s"])


static func is_active(sim: GameSim) -> bool:
	return sim.planet.hazard != null and sim.state.hazard_phase == Phase.ACTIVE


static func player_factor(sim: GameSim) -> float:
	return sim.planet.hazard.player_speed if is_active(sim) else 1.0


static func drone_factor(sim: GameSim) -> float:
	return sim.planet.hazard.drone_speed if is_active(sim) else 1.0


## A machine's speed factor from the hazard: a cold snap slows it unless a Heat Tower warms it.
static func machine_factor(sim: GameSim, m: MachineDef) -> float:
	if not is_active(sim) or sim.planet.hazard.kind != HazardDef.Kind.COLD_SNAP:
		return 1.0
	return 1.0 if sim.warmed(m.position) else sim.planet.hazard.machine_speed


## Is this machine frozen right now (a cold snap, outside any warm radius)? For the frost look.
static func is_frozen(sim: GameSim, m: MachineDef) -> bool:
	return m.takes_workers and machine_factor(sim, m) < 1.0


## How strong the hazard looks right now, 0..1: a slow build during the warning (up to
## warning_darken), then full strength while active, fading in and out over fade_time.
static func intensity(sim: GameSim) -> float:
	var h := sim.planet.hazard
	if h == null:
		return 0.0
	var s := sim.state
	match s.hazard_phase:
		Phase.WARNING:
			return h.warning_darken * clampf(1.0 - s.hazard_t / maxf(h.telegraph_time, 0.01), 0.0, 1.0)
		Phase.ACTIVE:
			var fade := maxf(h.fade_time, 0.01)
			var into := duration(sim) - s.hazard_t
			return lerpf(h.warning_darken, 1.0, clampf(into / fade, 0.0, 1.0)) * clampf(s.hazard_t / fade, 0.0, 1.0) \
				if s.hazard_t < fade else lerpf(h.warning_darken, 1.0, clampf(into / fade, 0.0, 1.0))
	return 0.0


static func _enter(sim: GameSim, phase: Phase, t: float) -> void:
	sim.state.hazard_phase = phase
	sim.state.hazard_t = t
	sim.hazard_changed.emit(phase)
