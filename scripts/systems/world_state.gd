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
## Machine id -> upgrades bought (0 = Mk I).
var machine_levels: Dictionary = {}
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

## Colony (SPEC 4.1). Landers that have come down, and seconds left on the one descending (-1: none).
var landers: int = 0
var lander_t: float = -1.0
## Colonists who arrived with no habitat space, waiting at the hub.
var colonists_waiting: int = 0
## One entry per housed colonist: seconds until their next meal (0 = hungry).
var meals: PackedFloat32Array = []
## Meals in the hub's food store.
var food: float = 0.0

## Hazard (SPEC 4.2): HazardDirector.Phase, seconds left in it, seconds until the next warning
## (-1: not scheduled), and how many have passed.
var hazard_phase: int = 0
var hazard_t: float = 0.0
var hazard_wait: float = -1.0
var hazard_count: int = 0


func stat(key: StringName) -> int:
	return stats.get(key, 0)


func add_stat(key: StringName, amount: int = 1) -> void:
	stats[key] = stat(key) + amount


func is_built(id: StringName) -> bool:
	return built.get(id, false)


func machine_level(machine_id: StringName) -> int:
	return machine_levels.get(machine_id, 0)


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
		"machine_levels": _keys_to_str(machine_levels),
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
		"landers": landers,
		"lander_t": lander_t,
		"colonists_waiting": colonists_waiting,
		"meals": Array(meals),
		"food": food,
		"hazard_phase": hazard_phase,
		"hazard_t": hazard_t,
		"hazard_wait": hazard_wait,
		"hazard_count": hazard_count,
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
	s.machine_levels = _keys_to_name(d.get("machine_levels", {}), TYPE_INT)
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
	s.landers = int(d.get("landers", 0))
	s.lander_t = float(d.get("lander_t", -1.0))
	s.colonists_waiting = int(d.get("colonists_waiting", 0))
	s.meals = PackedFloat32Array(d.get("meals", []))
	s.food = float(d.get("food", 0.0))
	s.hazard_phase = int(d.get("hazard_phase", 0))
	s.hazard_t = float(d.get("hazard_t", 0.0))
	s.hazard_wait = float(d.get("hazard_wait", -1.0))
	s.hazard_count = int(d.get("hazard_count", 0))
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
