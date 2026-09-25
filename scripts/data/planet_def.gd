class_name PlanetDef
extends Resource
## Everything that makes one planet: look, layout, machines and tutorial.

@export var id: StringName
@export var display_name: String
@export var seed: int = 11

@export_group("Palette")
@export var sky_start: Color
@export var sky_mid: Color
@export var sky_end: Color
@export var ground_start: Color
@export var ground_end: Color
## Moss blended into the ground as it spreads from the hub.
@export var moss_color: Color = Color("4f7a3a")
@export var water_deep: Color = Color("2f6f8f")
@export var water_shallow: Color = Color("5aa7b5")

@export_group("Economy")
## Multiplies hub payouts.
@export var pay_multiplier: float = 1.0
## Divides terraform gains.
@export var terraform_divisor: float = 1.0

@export_group("Layout")
@export var hub_position: Vector2 = Vector2.ZERO
@export var hub_collide_radius: float = 2.5
@export var depot_position: Vector2 = Vector2(0, 3.6)
@export var machines: Array[MachineDef] = []
@export var resource_nodes: Array[ResourceNodeDef] = []
@export var bay_position: Vector2 = Vector2(-15, -9)
@export var bay_pad_offset: Vector2 = Vector2(0, 2.9)
@export var bay_collide_radius: float = 1.9
@export var bay_cost: int = 60
@export var max_drones: int = 12
## The HAULERS upgrade pad, relative to the Drone Bay (beside its BUY pad).
@export var hauler_pad_offset: Vector2 = Vector2(-2.8, 2.9)
@export var outfitter_position: Vector2 = Vector2(15, -9)
@export var outfitter_collide_radius: float = 1.5
@export var pack_pad_offset: Vector2 = Vector2(-2.4, 2.9)
@export var boots_pad_offset: Vector2 = Vector2(0.0, 2.9)
@export var dig_pad_offset: Vector2 = Vector2(2.4, 2.9)
## Habitats (SPEC 4.1): positions, build costs (the first is free and built by the first lander)
## and where each one's BUILD pad sits.
@export var habitat_positions: Array[Vector2] = [Vector2(-6, 10.5), Vector2(6, 10.5), Vector2(-3, 15)]
@export var habitat_costs: PackedInt32Array = [0, 120, 240]
@export var habitat_pad_offset: Vector2 = Vector2(0, 2.7)
@export var habitat_collide_radius: float = 1.5
## Where landers touch down.
@export var lander_position: Vector2 = Vector2(6.5, 4.5)
## Lakes as (x, z, radius).
@export var lakes: Array[Vector3] = []
## Areas kept clear of decoration, as (x, z, radius).
@export var clear_zones: Array[Vector3] = []

@export_group("Colony")
## A lander arrives as terraform passes each of these %.
@export var lander_milestones: PackedFloat32Array = [10, 25, 40, 55, 70, 85]
@export var colonists_per_lander: int = 2
## Null for no hazard.
@export var hazard: HazardDef

@export_group("Surface")
## Geothermal vents (Kessik): a machine built within vent_radius of one runs vent_boost faster.
@export var vents: PackedVector2Array = []
@export var vent_radius: float = 1.5
@export var vent_boost: float = 0.5
## Toxicity % at the start (Kessik). Terraform can't rise above 100 - toxicity; delivered items
## still count, and show once filters clear the air.
@export var start_toxicity: float = 0.0
## Frost on the ground (Orrin b), 0..1 at 0% terraform, melting away by frost_gone_at %.
@export var frost: float = 0.0
@export var frost_gone_at: float = 60.0
@export var frost_color: Color = Color("e4eef7")
## Heat shimmer and steam colour over the vents.
@export var steam_color: Color = Color("e8e4dc")

@export_group("Vegetation")
## Terraform % added to each plant layer's thresholds (tundra: grass sooner, trees later).
@export var grass_shift: float = 0.0
@export var flower_shift: float = 0.0
@export var tree_shift: float = 0.0
## Hue added to grass and trees (-0.08 is yellower tundra, +0.1 bluer), and their saturation scale.
@export var plant_hue_shift: float = 0.0
@export var plant_saturation: float = 1.0
## Share of trees that are pines (-1: TerraformDef's default).
@export var pine_share: float = -1.0

@export_group("Balance")
## Target minutes to reach 100% (min, max), checked by tools/balance_sim.gd.
@export var target_minutes: Vector2 = Vector2(25, 35)
## False while the planet is a placeholder; the balance sim reports it but doesn't fail on it.
@export var balance_enforced: bool = true

@export_group("Guide")
@export var tutorial: TutorialDef
@export_multiline var win_text: String
