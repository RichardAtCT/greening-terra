class_name TutorialCondition
extends Resource
## One way a tutorial step can be completed.

enum Kind {
	## At least `amount` of item `key` on the player's back.
	CARRYING,
	## Stat `key` (fed, delivered, produced_<item>) at least `amount`.
	STAT,
	## Building `key` is built.
	BUILT,
	## Never completes (the last, open-ended step).
	NEVER,
}

@export var kind: Kind = Kind.STAT
@export var key: StringName
@export var amount: int = 1
