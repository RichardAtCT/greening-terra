class_name GameTuning
extends Resource
## Shared gameplay timings, radii and caps. Defaults are the prototype's values.

@export_group("Player")
@export var pack_base: int = 8
@export var mine_radius: float = 1.6
@export var mine_interval: float = 0.2
@export var pad_radius: float = 1.2
## Seconds between single-item transfers on IN, OUT and DELIVER pads.
@export var transfer_interval: float = 0.07

@export_group("Paying")
@export var pay_interval: float = 0.045
## A cost is paid in about this many chunks.
@export var pay_chunks: int = 35

@export_group("Nodes")
@export var node_respawn_time: float = 5.0

@export_group("Drones")
@export var drone_speed: float = 5.5
@export var drone_capacity: int = 4
@export var drone_arrive_radius: float = 0.25
@export var drone_dig_interval: float = 0.35
@export var drone_transfer_interval: float = 0.12
## Leave a machine OUT pad with a partial load after waiting this long.
@export var drone_output_wait: float = 1.0
## Give up on a full IN queue and sell instead after this long.
@export var drone_unload_wait: float = 3.0
## Send goods to the greenhouse only while its queue has this much room.
@export var drone_queue_margin: int = 3
@export var drone_hover_height: float = 2.4

@export_group("Presentation")
@export var fly_time: float = 0.3
@export var fly_arc: float = 1.2
@export var stack_column_size: int = 14
@export var pad_stack_max: int = 18
@export var toast_time: float = 2.4
@export var autosave_interval: float = 10.0
