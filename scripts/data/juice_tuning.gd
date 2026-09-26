class_name JuiceTuning
extends Resource
## Feedback animation numbers (SPEC 6). All of it is skipped with the "Fewer effects" setting,
## except the pad icons turning.

@export_group("Back stack")
## An item landing on the back stack bounces up to 1 + stack_pop_scale for stack_pop_time seconds.
@export var stack_pop_time: float = 0.22
@export var stack_pop_scale: float = 0.6
## Each item already on the stack raises the pick-up sound's pitch by this much (up to the cap).
@export var pickup_pitch_step: float = 0.018
@export var pickup_pitch_max: float = 1.35
## Digging is only heard within this distance of the player (drones dig far away).
@export var dig_hearing_radius: float = 6.0

@export_group("Building complete")
## The model springs up from this scale, wobbling at frequency (rad/s) and settling at decay.
@export var building_pop_from: float = 0.55
@export var building_pop_time: float = 0.9
@export var building_pop_frequency: float = 13.0
@export var building_pop_decay: float = 6.0
@export var puff_amount: int = 28

@export_group("Pad icons")
@export var icon_scale: float = 2.0
@export var icon_height: float = 0.55
## Radians per second.
@export var icon_spin: float = 1.2
@export var icon_bob: float = 0.05

@export_group("Colonists")
## Walking: a bouncy waddle (bob height in metres, steps per second in radians, sway in radians).
@export var colonist_bob: float = 0.07
@export var colonist_step_rate: float = 11.0
@export var colonist_sway: float = 0.14
## Working: a nod towards the machine.
@export var colonist_work_rate: float = 5.0
@export var colonist_work_lean: float = 0.16

@export_group("Lander")
## It starts this high and eases down over ColonyTuning.lander_descent_time.
@export var lander_drop_height: float = 24.0
## Seconds to climb away again after its stay.
@export var lander_liftoff_time: float = 3.0
@export var lander_puff_amount: int = 36

@export_group("Win")
@export var confetti_amount: int = 160
@export var confetti_lifetime: float = 3.2
