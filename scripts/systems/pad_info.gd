class_name PadInfo
extends RefCounted
## A standing pad in the world. Built by GameSim from the planet layout.

enum Kind { IN, OUT, DEPOT, PAY, REPAIR, SWAP }
enum Pay { NONE, BUILD_MACHINE, BUILD_BAY, BUY_DRONE, PACK, BOOTS, BUILD_HABITAT, UPGRADE_MACHINE, UPGRADE_HAULERS, DIG }

var key: StringName
var kind: Kind
var pay: Pay = Pay.NONE
var position: Vector2
var machine: MachineDef
## BUILD_HABITAT: which of the planet's habitats.
var index: int = -1
var title: String
var label: String
var color: Color
## Items drawn above the pad so it can be read without reading (SPEC 6). Pay pads show a coin instead.
var icons: Array[StringName] = []


func _init(p_key: StringName, p_kind: Kind, p_position: Vector2) -> void:
	key = p_key
	kind = p_kind
	position = p_position
