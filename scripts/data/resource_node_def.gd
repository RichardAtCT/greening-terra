class_name ResourceNodeDef
extends Resource
## A group of diggable resource nodes of one item type.

@export var item: StringName
@export var max_stock: int = 6
## Node positions (x, z).
@export var positions: PackedVector2Array
## Where drones wait when every node of this type is empty.
@export var idle_point: Vector2
@export var color: Color = Color.WHITE
@export var emissive: Color = Color.BLACK
@export var translucent: bool = false
