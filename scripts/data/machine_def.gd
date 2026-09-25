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
