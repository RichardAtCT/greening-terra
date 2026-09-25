class_name WorldState
extends RefCounted
## Everything that changes during play on one planet, plus what carries over between planets.
## Plain data only, so it can be saved, loaded and simulated headless.

var planet_index: int = 0
var credits: float = 0.0
var terraform: float = 0.0
var pack_level: int = 0
var boots_level: int = 0
## Items on the player's back, bottom first.
var stack: Array[StringName] = []
## Building id -> true once built (machine ids and &"bay").
var built: Dictionary = {}
var drones: int = 0
var tutorial_step: int = 0
## &"fed", &"delivered", &"produced_<item>" -> count.
var stats: Dictionary = {}
## Machine id -> { item id -> queued count }.
var queues: Dictionary = {}
## Machine id -> finished items waiting on the OUT pad.
var outputs: Dictionary = {}
## Machine id -> seconds left on the current cycle (0 = idle).
var busy: Dictionary = {}
## Pay pad key -> credits paid so far towards it.
var paid: Dictionary = {}
var won: bool = false
var node_stock: PackedInt32Array = []
var node_respawn: PackedFloat32Array = []
var player_position: Vector2 = Vector2(0, 7)


func stat(key: StringName) -> int:
	return stats.get(key, 0)


func add_stat(key: StringName, amount: int = 1) -> void:
	stats[key] = stat(key) + amount


func is_built(id: StringName) -> bool:
	return built.get(id, false)


func queued(machine_id: StringName, item: StringName) -> int:
	return queues.get(machine_id, {}).get(item, 0)


func count_carried(item: StringName) -> int:
	return stack.count(item)


func to_dict() -> Dictionary:
	return {
		"planet_index": planet_index,
		"credits": credits,
		"terraform": terraform,
		"pack_level": pack_level,
		"boots_level": boots_level,
		"stack": stack.map(func(s): return String(s)),
		"built": _keys_to_str(built),
		"drones": drones,
		"tutorial_step": tutorial_step,
		"stats": _keys_to_str(stats),
		"queues": _nested_to_str(queues),
		"outputs": _keys_to_str(outputs),
		"busy": _keys_to_str(busy),
		"paid": _keys_to_str(paid),
		"won": won,
		"node_stock": Array(node_stock),
		"node_respawn": Array(node_respawn),
		"player_position": [player_position.x, player_position.y],
	}


static func from_dict(d: Dictionary) -> WorldState:
	var s := WorldState.new()
	s.planet_index = int(d.get("planet_index", 0))
	s.credits = float(d.get("credits", 0.0))
	s.terraform = float(d.get("terraform", 0.0))
	s.pack_level = int(d.get("pack_level", 0))
	s.boots_level = int(d.get("boots_level", 0))
	for item in d.get("stack", []):
		s.stack.append(StringName(item))
	s.built = _keys_to_name(d.get("built", {}), TYPE_BOOL)
	s.drones = int(d.get("drones", 0))
	s.tutorial_step = int(d.get("tutorial_step", 0))
	s.stats = _keys_to_name(d.get("stats", {}), TYPE_INT)
	for m in d.get("queues", {}):
		s.queues[StringName(m)] = _keys_to_name(d["queues"][m], TYPE_INT)
	s.outputs = _keys_to_name(d.get("outputs", {}), TYPE_INT)
	s.busy = _keys_to_name(d.get("busy", {}), TYPE_FLOAT)
	s.paid = _keys_to_name(d.get("paid", {}), TYPE_INT)
	s.won = bool(d.get("won", false))
	s.node_stock = PackedInt32Array(d.get("node_stock", []))
	s.node_respawn = PackedFloat32Array(d.get("node_respawn", []))
	var pp: Array = d.get("player_position", [0, 7])
	s.player_position = Vector2(float(pp[0]), float(pp[1]))
	return s


static func _keys_to_str(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[String(k)] = src[k]
	return out


static func _nested_to_str(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[String(k)] = _keys_to_str(src[k])
	return out


static func _keys_to_name(src: Dictionary, type: int) -> Dictionary:
	var out := {}
	for k in src:
		out[StringName(k)] = type_convert(src[k], type)
	return out
