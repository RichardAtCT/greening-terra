class_name ColonyTuning
extends Resource
## Colonists, landers, food and habitats (SPEC 4.1). Where they land and live is in each PlanetDef.

@export_group("Landers")
## Seconds from the lander appearing in the sky to touching down (the colonists step out then).
@export var lander_descent_time: float = 5.0
## Seconds it waits on the pad before lifting off again (view only).
@export var lander_stay_time: float = 3.0

@export_group("Work")
## Each colonist working a machine makes it this much faster (0.25 = +25%).
@export var machine_boost: float = 0.25
@export var max_per_machine: int = 2
## A machine at Mk II or above takes this many more.
@export var upgraded_extra_workers: int = 2
## Colonist walking speed, in metres per second.
@export var walk_speed: float = 2.2
## Where the two work spots are: this far out from the machine's collision radius, either side,
## and this far towards its pads.
@export var work_side_gap: float = 0.55
@export var work_forward: float = 0.9
## An upgraded machine's extra workers stand this far behind the first two.
@export var work_row_gap: float = 1.3
## Off-duty colonists wander within this radius of their habitat and pause between strolls.
@export var wander_radius: float = 2.6
@export var wander_pause_min: float = 2.0
@export var wander_pause_max: float = 6.0

@export_group("Food")
## Each colonist eats one food every this many seconds.
@export var meal_interval: float = 90.0
## The hub keeps this many seconds of food for everyone housed and sells the rest.
@export var food_reserve_seconds: float = 300.0

@export_group("Habitats")
## Colonists one habitat houses.
@export var habitat_capacity: int = 4
