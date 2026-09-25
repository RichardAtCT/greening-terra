class_name RecipeDef
extends Resource
## What a machine consumes and makes per cycle.

## Item id -> count consumed per cycle.
@export var inputs: Dictionary[StringName, int] = {}
## Empty for a Heat Tower, whose cycles make heat rather than an item.
@export var output: StringName
## Seconds per cycle.
@export var time: float = 1.0
## Terraform % (before the planet's divisor) each cycle adds when there's no output item (heat).
@export var terraform: float = 0.0


func makes_item() -> bool:
	return output != &""
