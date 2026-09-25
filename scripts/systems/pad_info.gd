class_name PadInfo
extends RefCounted
## A standing pad in the world. Built by GameSim from the planet layout.

enum Kind { IN, OUT, DEPOT, PAY }
enum Pay { NONE, BUILD_MACHINE, BUILD_BAY, BUY_DRONE, PACK, BOOTS }

var key: StringName
var kind: Kind
var pay: Pay = Pay.NONE
var position: Vector2
var machine: MachineDef
var title: String
var label: String
var color: Color


func _init(p_key: StringName, p_kind: Kind, p_position: Vector2) -> void:
	key = p_key
	kind = p_kind
	position = p_position
