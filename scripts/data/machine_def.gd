class_name MachineDef
extends Resource
## A processing building with IN, OUT and BUILD pads.

@export var id: StringName
@export var display_name: String
@export var recipe: RecipeDef
@export var build_cost: int = 0
@export var starts_built: bool = false
## Ground position (x, z).
@export var position: Vector2
@export var scene: PackedScene
## Size of the wireframe ghost shown before it's built.
@export var footprint: Vector3 = Vector3(2.5, 2.0, 2.5)
@export var collide_radius: float = 1.8
@export var label_height: float = 3.6
## Pad positions relative to the machine.
@export var in_pad_offset: Vector2 = Vector2(-1.4, 2.9)
@export var out_pad_offset: Vector2 = Vector2(1.4, 2.9)
@export var build_pad_offset: Vector2 = Vector2(0.0, 2.9)
## IN pad colour and subtitle (the OUT pad uses the output item's colour and name).
@export var in_pad_color: Color = Color.WHITE
@export var in_pad_label: String
@export var queue_cap: int = 20
@export var output_cap: int = 40

@export_group("Upgrades")
## Cost of each upgrade after Mk I (SPEC 4.4): one entry per level. Empty means no UPGRADE pad.
@export var upgrade_costs: PackedInt32Array = []
## Each upgrade makes the machine this much faster (0.5 = +50% per level, added up).
@export var upgrade_speed: float = 0.5
## Each upgrade holds this many more finished items on the OUT pad.
@export var upgrade_output_cap: int = 10
## Where the UPGRADE pad sits, relative to the machine (beside it, clear of the IN and OUT pads).
@export var upgrade_pad_offset: Vector2 = Vector2(4.0, 0.9)
