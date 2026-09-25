extends Node
## Single source of truth: the loaded game data and the running GameSim for the active profile.

const DEFS_PATH := "res://data/game.tres"

var defs: GameDefs
var sim: GameSim


func _ready() -> void:
	defs = load(DEFS_PATH)


## Loads the active profile's save, or starts a new game if there is none.
func ensure_started() -> void:
	if sim:
		return
	var state := SaveManager.load_state(SaveManager.active_profile)
	if state:
		start(state)
	else:
		start(GameSim.new_planet_state(defs, 0))
		save()


func start(state: WorldState) -> void:
	sim = GameSim.new(defs, state)
	sim.toast.connect(EventBus.toast.emit)
	sim.delivered.connect(func(_item, credits): EventBus.credits_earned.emit(credits))
	sim.purchased.connect(func(key):
		EventBus.purchased.emit(key)
		save())
	sim.planet_won.connect(func():
		EventBus.planet_won.emit()
		save())
	EventBus.sim_started.emit()


## Travels to the next planet. Credits reset; pack, boots, dig speed and bonuses carry over.
func next_planet() -> void:
	start(GameSim.carry_state(defs, sim.state, sim.state.planet_index + 1))
	save()


## Starts this planet again. Kit and bonuses stay (including one picked here, and whether it was).
func restart_planet() -> void:
	var s := sim.state
	var fresh := GameSim.carry_state(defs, s, s.planet_index)
	fresh.bonus_picked = s.bonus_picked
	start(fresh)
	save()


func save() -> void:
	if sim:
		SaveManager.save_state(SaveManager.active_profile, sim.state)
