extends Node
## Game-wide signals, so UI and world nodes don't need references to each other.

signal toast(text: String)
signal credits_earned(amount: float)
signal purchased(key: StringName)
signal planet_won
## A new GameSim was started (new game, load, next planet, restart).
signal sim_started
