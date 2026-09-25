class_name AudioDef
extends Resource
## Sound effects and the procedural ambience (wind and birdsong), with their levels.

@export var sounds: Array[SoundDef] = []
## Players shared by all sound effects.
@export var pool_size: int = 8

@export_group("Wind")
## Wind loop volume and pitch at 0% and 100% terraform (it calms as the air thickens).
@export var wind_volume_db_start: float = -9.0
@export var wind_volume_db_end: float = -24.0
@export var wind_pitch_start: float = 1.0
@export var wind_pitch_end: float = 0.62
## Slow gusts: volume swings by up to this many dB.
@export var wind_gust_db: float = 5.0
@export var wind_gust_rate: float = 0.13
## Seconds of generated noise in the loop, and its sample rate.
@export var wind_loop_seconds: float = 4.0
@export var wind_mix_rate: int = 22050
## Low-pass smoothing of the noise (0..1, lower is darker).
@export var wind_smoothing: float = 0.045

@export_group("Birdsong")
## Birds start singing at this terraform %, and are at full volume by birds_full_at.
@export var birds_from: float = 70.0
@export var birds_full_at: float = 95.0
@export var birds_volume_db: float = -13.0
## Seconds between songs (random in this range).
@export var birds_gap_min: float = 2.5
@export var birds_gap_max: float = 7.0
@export var birds_variations: int = 5


func sound(id: StringName) -> SoundDef:
	for s in sounds:
		if s.id == id:
			return s
	return null
