class_name RecipeDef
extends Resource
## What a machine consumes and makes per cycle.

## Item id -> count consumed per cycle.
@export var inputs: Dictionary[StringName, int] = {}
@export var output: StringName
## Seconds per cycle.
@export var time: float = 1.0
