class_name HazardDef
extends Resource
## A planet's hazard (SPEC 4.2): when it happens, how it's telegraphed, what it slows down and how
## it looks. Hazards only ever slow things down; they never take items or credits.

enum Kind {
	## Slows the player and haulers (Tessera-4's dust storm).
	STORM,
	## Slows machines outside any warm Heat Tower's radius (Orrin b).
	COLD_SNAP,
	## Meteors land on marked points and damage machines until repaired (Kessik).
	METEORS,
}

@export var id: StringName = &"dust_storm"
@export var kind: Kind = Kind.STORM
@export var display_name: String = "Dust storm"
## HUD banner text while it's coming and while it's on.
@export var warning_text: String = "Dust storm coming"
@export var active_text: String = "Dust storm"

@export_group("Timing")
## Hazards happen only between these terraform %.
@export var start_percent: float = 15.0
@export var end_percent: float = 60.0
## Seconds from one hazard's end (or from reaching start_percent) to the next warning, random in
## this range. The gap is multiplied by up to interval_growth as terraform nears end_percent.
@export var interval_min: float = 240.0
@export var interval_max: float = 360.0
@export var interval_growth: float = 1.5
## Seconds of warning before it starts, and how long it lasts.
@export var telegraph_time: float = 10.0
@export var duration: float = 30.0

@export_group("Effects")
## Speed multipliers while it's on.
@export var player_speed: float = 0.7
@export var drone_speed: float = 0.6
## COLD_SNAP: machine speed outside any warm Heat Tower's radius.
@export var machine_speed: float = 1.0
## METEORS: how many fall, how many of them aim at a machine, how close a hit must be, and what
## a repair costs (items the player carries onto the damaged machine's REPAIR pad).
@export var meteor_count: int = 3
@export var meteor_hits: int = 1
@export var impact_radius: float = 2.0
@export var repair_item: StringName = &"plate"
@export var repair_cost: int = 5

@export_group("Look")
## Seconds to blend in and out at the start and end.
@export var fade_time: float = 2.5
## How far the sky darkens towards dark_color during the warning (0..1).
@export var warning_darken: float = 0.35
@export var dark_color: Color = Color("3a1c14")
## Thick fog at full strength (off: the planet's own fog stays).
@export var fog_enabled: bool = true
## Fog colour and distances (from the camera, which sits about 17 m from the player) at full strength.
@export var fog_color: Color = Color("c0673a")
@export var fog_near: float = 13.0
@export var fog_far: float = 32.0
## Dust motes: opacity and wind (x, z metres per second) at full strength.
@export var dust_opacity: float = 0.85
@export var dust_wind: Vector2 = Vector2(9.0, 2.5)
## Mote colour at full strength (alpha 0: the planet's usual dust colour), e.g. snow in a cold snap.
@export var dust_color: Color = Color(0, 0, 0, 0)
## Motes fall at this many metres per second (snow), wrapping round.
@export var dust_fall: float = 0.0
## Extra frost on the ground and on cold machines at full strength (0..1).
@export var frost: float = 0.0
