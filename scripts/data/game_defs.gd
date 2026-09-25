class_name GameDefs
extends Resource
## Root of all game data: load res://data/game.tres to get everything.

@export var items: Array[ItemDef] = []
@export var planets: Array[PlanetDef] = []
@export var tuning: GameTuning
@export var terraform: TerraformDef
@export var player: PlayerTuning
@export var pack_upgrade: UpgradeDef
@export var boots_upgrade: UpgradeDef
@export var drone_upgrade: UpgradeDef
@export var juice: JuiceTuning


func item(id: StringName) -> ItemDef:
	for it in items:
		if it.id == id:
			return it
	return null


func planet(index: int) -> PlanetDef:
	return planets[index % planets.size()]
