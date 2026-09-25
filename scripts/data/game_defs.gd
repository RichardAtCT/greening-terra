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
## Hauler upgrades at the Drone Bay: odd levels add cargo, even levels add speed (GameTuning).
@export var hauler_upgrade: UpgradeDef
## SPEC 4.4: dig speed at the Outfitter (carries over from planet to planet).
@export var dig_upgrade: UpgradeDef
@export var juice: JuiceTuning
@export var colony: ColonyTuning
## SPEC 4.3's pool; three are offered when a planet reaches 100%.
@export var bonuses: Array[BonusDef] = []


func bonus(id: StringName) -> BonusDef:
	for b in bonuses:
		if b.id == id:
			return b
	return null


func item(id: StringName) -> ItemDef:
	for it in items:
		if it.id == id:
			return it
	return null


func planet(index: int) -> PlanetDef:
	return planets[index % planets.size()]
