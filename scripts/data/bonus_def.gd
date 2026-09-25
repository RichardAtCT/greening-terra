class_name BonusDef
extends Resource
## A planet bonus (SPEC 4.3): picked 1 of 3 when a planet reaches 100%, and kept for the whole save.

enum Kind {
	## Haulers fly amount faster (0.25 = +25%).
	DRONE_SPEED,
	## The pack holds amount more.
	PACK,
	## Each new planet starts with the Drone Bay and one hauler built.
	HEAD_START,
	## Machines run amount faster.
	MACHINE_SPEED,
	## The hub pays amount more.
	PAY,
	## Hazards last amount less (0.3 = -30%).
	HAZARD_DURATION,
	## Each lander brings amount more colonists (habitats grow to fit).
	LANDER,
	## Resource nodes hold amount more, and respawn amount_2 faster.
	NODES,
}

@export var id: StringName
@export var display_name: String
## One short line for the picker card.
@export var description: String
@export var kind: Kind = Kind.DRONE_SPEED
@export var amount: float = 0.25
@export var amount_2: float = 0.0
## Card colour and icon item (drawn like a pad icon); empty icon means a coin.
@export var color: Color = Color("f2b35b")
@export var icon: StringName
