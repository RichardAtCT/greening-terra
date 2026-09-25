class_name HazardDef
extends Resource
## A planet's hazard (SPEC 4.2): when it happens, how it's telegraphed, what it slows down and how
## it looks. Hazards only ever slow things down; they never take items or credits.

@export var id: StringName = &"dust_storm"
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

@export_group("Look")
## Seconds to blend in and out at the start and end.
@export var fade_time: float = 2.5
## How far the sky darkens towards dark_color during the warning (0..1).
@export var warning_darken: float = 0.35
@export var dark_color: Color = Color("3a1c14")
## Fog colour and distances at full strength.
@export var fog_color: Color = Color("c0673a")
@export var fog_near: float = 4.0
@export var fog_far: float = 22.0
## Dust motes: opacity and wind (x, z metres per second) at full strength.
@export var dust_opacity: float = 0.85
@export var dust_wind: Vector2 = Vector2(9.0, 2.5)
## Wind loop boost at full strength.
@export var wind_boost_db: float = 9.0
@export var wind_pitch_boost: float = 0.25
