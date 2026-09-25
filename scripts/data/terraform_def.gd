class_name TerraformDef
extends Resource
## How terraform % maps to stage names, atmosphere readouts and the planet's look.

@export_group("Stages")
## Upper bound (exclusive) of each stage, paired with stage_names.
@export var stage_limits: PackedFloat32Array = [8, 25, 45, 65, 90, 100]
@export var stage_names: PackedStringArray = ["Barren regolith", "Thin atmosphere", "First rain", "Lichen bloom", "Grasslands", "Young forests"]
@export var complete_name: String = "Terraformed"

@export_group("Atmosphere")
## kPa = pressure_base + pressure_gain * k ^ pressure_power, with k = terraform / 100.
@export var pressure_base: float = 0.6
@export var pressure_gain: float = 100.4
@export var pressure_power: float = 1.5
## °C = temperature_base + temperature_gain * k.
@export var temperature_base: float = -63.0
@export var temperature_gain: float = 77.0

@export_group("Look")
## Terraform % where the sky reaches its mid colour.
@export var sky_mid_at: float = 45.0
@export var fog_near: float = 14.0
@export var fog_near_gain: float = 18.0
@export var fog_far: float = 48.0
@export var fog_far_gain: float = 50.0
@export var ambient_energy: float = 0.55
@export var ambient_energy_gain: float = 0.35
@export var sun_energy: float = 0.7
@export var sun_energy_gain: float = 0.45
@export var rock_darken: float = 0.75
@export var dust_opacity: float = 0.6
## Dust fades out completely at this terraform %.
@export var dust_gone_at: float = 40.0
## Calm-weather drift of the dust motes (x, z metres per second).
@export var dust_wind: Vector2 = Vector2(1.4, 0.4)
@export var lake_start: float = 25.0
@export var lake_span: float = 40.0
## How fast the displayed terraform % catches up with the real one.
@export var display_rate: float = 3.0
@export var lake_grow_rate: float = 1.5
@export var plant_grow_rate: float = 2.2

@export_group("Moss")
@export var moss_count: int = 460
@export var moss_radius: float = 42.0
## Threshold = base + (r / radius) * spread + random * jitter.
@export var moss_threshold_base: float = 14.0
@export var moss_threshold_spread: float = 55.0
@export var moss_threshold_jitter: float = 22.0

@export_group("Ground moss")
## The moss front on the ground shader follows the moss patches' thresholds (see Moss above).
## Width of its ragged edge, in metres.
@export var ground_moss_edge: float = 7.0
## Share of the ground inside the front that is mossy, from cover_min at cover_start % to cover_max at cover_full %.
@export var ground_moss_cover_min: float = 0.35
@export var ground_moss_cover_max: float = 0.95
@export var ground_moss_cover_start: float = 15.0
@export var ground_moss_cover_full: float = 85.0
@export var ground_moss_strength: float = 0.85

@export_group("Grass and flowers")
@export var grass_count: int = 220
@export var grass_radius: float = 40.0
@export var grass_threshold_base: float = 40.0
@export var grass_threshold_spread: float = 40.0
@export var grass_threshold_jitter: float = 15.0
@export var flower_count: int = 90
@export var flower_radius: float = 34.0
## Flowers open from this terraform % (the same point birdsong starts).
@export var flower_threshold_base: float = 70.0
@export var flower_threshold_spread: float = 22.0
@export var flower_threshold_jitter: float = 8.0

@export_group("Trees")
@export var tree_count: int = 150
@export var tree_min_radius: float = 8.0
@export var tree_max_radius: float = 44.0
@export var tree_threshold_base: float = 55.0
@export var tree_threshold_spread: float = 30.0
@export var tree_threshold_jitter: float = 14.0
## Share of trees that are pines; the rest are round-crowned.
@export var tree_pine_share: float = 0.6
