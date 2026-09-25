class_name UpgradeDef
extends Resource
## A purchasable upgrade. cost(level) = round((base_cost + cost_step * level) * cost_growth ^ level).

@export var id: StringName
@export var display_name: String
@export var pad_title: String
@export var pad_label: String
@export var base_cost: float = 10.0
@export var cost_step: float = 0.0
@export var cost_growth: float = 1.0
## Levels that can be bought; buying stops at this level.
@export var max_level: int = 10
## Effect per level (meaning depends on the upgrade: slots, speed fraction...).
@export var amount_per_level: float = 1.0


func cost(level: int) -> int:
	return roundi((base_cost + cost_step * level) * pow(cost_growth, level))
