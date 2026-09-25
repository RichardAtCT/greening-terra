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
## After a purchase the pad rests this long before taking credits again, so a player still standing
## on it doesn't buy the next level by accident.
@export var pay_rest: float = 2.0

@export_group("Bonuses")
## Bonuses offered at 100%.
@export var bonus_offer_count: int = 3

@export_group("Nodes")
@export var node_respawn_time: float = 5.0

@export_group("Drones")
@export var drone_speed: float = 5.5
@export var drone_capacity: int = 4
## Hauler upgrades alternate: the 1st, 3rd, 5th... add this much cargo to every hauler,
## the 2nd, 4th, 6th... make every hauler this much faster (0.15 = +15%, added up).
@export var hauler_upgrade_cargo: int = 1
@export var hauler_upgrade_speed: float = 0.15
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
## Haulers with nothing to do hover in a ring this wide beside the Drone Bay.
@export var drone_idle_radius: float = 1.6

@export_group("Dispatcher")
## Job score (SPEC 4.5): how empty the target's queue is (0..1) times need_weight, plus how full the
## source's OUT pad is (0..1) times full_weight, plus the load's share of a full hold times
## load_weight, plus a bonus by kind, minus metres flown (hauler → source → target) times distance_weight.
@export var dispatch_need_weight: float = 10.0
@export var dispatch_full_weight: float = 12.0
@export var dispatch_load_weight: float = 4.0
## Carrying goods on to another machine beats selling them.
@export var dispatch_feed_bonus: float = 3.0
@export var dispatch_sell_bonus: float = 0.0
@export var dispatch_distance_weight: float = 0.12

@export_group("Presentation")
@export var fly_time: float = 0.3
@export var fly_arc: float = 1.2
@export var stack_column_size: int = 14
@export var pad_stack_max: int = 18
@export var toast_time: float = 2.4
@export var autosave_interval: float = 10.0
## Seconds the rocket takes between worlds on the star map.
@export var star_map_flight_time: float = 2.2
