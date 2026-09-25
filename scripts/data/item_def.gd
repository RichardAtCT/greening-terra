class_name ItemDef
extends Resource
## One kind of item: a raw resource or a processed good.

enum Shape { ROCK, CRYSTAL, PLATE, CANISTER, POD }

@export var id: StringName
@export var display_name: String
## Short upper-case name for pad labels; empty means display_name in capitals.
@export var short_name: String
@export var color: Color = Color.WHITE
@export var emissive: Color = Color.BLACK
@export var shape: Shape = Shape.ROCK
## Height one item adds to a stack.
@export var stack_height: float = 0.3
## Credits paid by the hub. Zero means it can't be sold (raw resources).
@export var sell_value: float = 0.0
## Terraform % added on delivery, before the planet's divisor.
@export var terraform_value: float = 0.0
## Food value for colonists (M4).
@export var food_value: float = 0.0


func is_sellable() -> bool:
	return sell_value > 0.0


func short_label() -> String:
	return short_name if short_name != "" else display_name.to_upper()
