class_name FlyerLayer
extends Node3D
## Items flying in an arc between two points: the genre's satisfying "drain" feedback.

var defs: GameDefs
var fly_time: float = 0.3
var arc_height: float = 1.2

var _active: Array[Dictionary] = []
var _pool: Array[MeshInstance3D] = []


func launch(item: StringName, from: Vector3, to: Vector3) -> void:
	var def := defs.item(item)
	if def == null:
		return
	var mi: MeshInstance3D = _pool.pop_back() if not _pool.is_empty() else null
	if mi == null:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	mi.mesh = ItemVisuals.mesh(def.shape)
	mi.material_override = ItemVisuals.material(def)
	mi.position = from
	mi.visible = true
	_active.append({"node": mi, "from": from, "to": to, "t": 0.0})


func _process(delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var f: Dictionary = _active[i]
		f.t += delta / fly_time
		var k := minf(1.0, f.t)
		var mi: MeshInstance3D = f.node
		mi.position = (f.from as Vector3).lerp(f.to, k) + Vector3(0, sin(PI * k) * arc_height, 0)
		mi.rotation.y += delta * 8.0
		if k >= 1.0:
			mi.visible = false
			_pool.append(mi)
			_active.remove_at(i)
