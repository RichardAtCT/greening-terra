class_name Bonuses
extends RefCounted
## Planet bonuses (SPEC 4.3): what the ones taken add up to, and which three to offer at 100%.
## Pure rules; the bonus pool and amounts are in data (GameDefs.bonuses).


## Sum of `amount` over every taken bonus of this kind (0 if none).
static func total(defs: GameDefs, state: WorldState, kind: BonusDef.Kind) -> float:
	var sum := 0.0
	for id in state.bonuses:
		var b := defs.bonus(id)
		if b and b.kind == kind:
			sum += b.amount
	return sum


## Sum of `amount_2` over every taken bonus of this kind.
static func total_2(defs: GameDefs, state: WorldState, kind: BonusDef.Kind) -> float:
	var sum := 0.0
	for id in state.bonuses:
		var b := defs.bonus(id)
		if b and b.kind == kind:
			sum += b.amount_2
	return sum


static func has(defs: GameDefs, state: WorldState, kind: BonusDef.Kind) -> bool:
	for id in state.bonuses:
		var b := defs.bonus(id)
		if b and b.kind == kind:
			return true
	return false


## The bonuses offered on this planet: up to bonus_offer_count not yet taken, picked at random
## but seeded from the planet and the bonuses so far, so a reload shows the same three.
static func offer(defs: GameDefs, state: WorldState) -> Array[BonusDef]:
	var pool: Array[BonusDef] = []
	for b in defs.bonuses:
		if not state.bonuses.has(b.id):
			pool.append(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([defs.planet(state.planet_index).seed, state.planet_index, state.bonuses.size()])
	var out: Array[BonusDef] = []
	while not pool.is_empty() and out.size() < defs.tuning.bonus_offer_count:
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## Takes a bonus for good. Returns false if it can't be taken (already picked, or not on offer).
static func pick(defs: GameDefs, state: WorldState, id: StringName) -> bool:
	if state.bonus_picked or state.bonuses.has(id):
		return false
	for b in offer(defs, state):
		if b.id == id:
			state.bonuses.append(id)
			state.bonus_picked = true
			return true
	return false
