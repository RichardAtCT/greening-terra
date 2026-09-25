class_name HazardDirector
extends RefCounted
## Schedules, telegraphs and applies the planet's hazard (SPEC 4.2), with no scene access.
## Between the hazard's start and end terraform %, it waits a random gap, warns for telegraph_time,
## then runs for duration. Gaps grow as terraform rises. The random gap is seeded from the planet
## and the number of hazards so far, so a saved game and the balance sim both repeat exactly.

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
				_enter(sim, Phase.WARNING, h.telegraph_time)
		Phase.WARNING:
			s.hazard_t -= dt
			if s.hazard_t <= 0.0:
				_enter(sim, Phase.ACTIVE, h.duration)
		Phase.ACTIVE:
			s.hazard_t -= dt
			if s.hazard_t <= 0.0:
				s.hazard_count += 1
				s.hazard_wait = -1.0
				_enter(sim, Phase.NONE, 0.0)


## Seconds to wait before hazard number `count`, at terraform % tf.
static func gap(h: HazardDef, planet_seed: int, count: int, tf: float) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([planet_seed, count])
	var k := clampf(inverse_lerp(h.start_percent, h.end_percent, tf), 0.0, 1.0)
	return rng.randf_range(h.interval_min, h.interval_max) * lerpf(1.0, h.interval_growth, k)


static func is_active(sim: GameSim) -> bool:
	return sim.planet.hazard != null and sim.state.hazard_phase == Phase.ACTIVE


static func player_factor(sim: GameSim) -> float:
	return sim.planet.hazard.player_speed if is_active(sim) else 1.0


static func drone_factor(sim: GameSim) -> float:
	return sim.planet.hazard.drone_speed if is_active(sim) else 1.0


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
			var into := h.duration - s.hazard_t
			return lerpf(h.warning_darken, 1.0, clampf(into / fade, 0.0, 1.0)) * clampf(s.hazard_t / fade, 0.0, 1.0) \
				if s.hazard_t < fade else lerpf(h.warning_darken, 1.0, clampf(into / fade, 0.0, 1.0))
	return 0.0


static func _enter(sim: GameSim, phase: Phase, t: float) -> void:
	sim.state.hazard_phase = phase
	sim.state.hazard_t = t
	sim.hazard_changed.emit(phase)
