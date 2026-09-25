class_name ItemStackView
extends Node3D
## Draws a list of items as a stack, one MultiMesh per item type (cheap on draw calls).

enum Layout {
	## Columns on the astronaut's back (or a drone's cargo), bottom first.
	BACK,
	## 2x2 layers on a pad.
	PAD,
	## A hanging column under a drone, top first.
	HANGING,
}

@export var layout: Layout = Layout.PAD
var defs: GameDefs
var column_size: int = 14
var max_shown: int = 18

var _multis: Dictionary = {}
var _signature: String = ""
## The top item [MultiMesh, instance index, rest transform], and the pop animation on it.
var _top: Array = []
var _pop: Array = []
var _pop_t := -1.0


func show_items(items: Array[StringName]) -> void:
	var shown := items.slice(0, max_shown) if layout == Layout.PAD else items
	var sig := ",".join(shown)
	if sig == _signature:
		return
	_signature = sig
	var per_type: Dictionary = {}
	var top_id: StringName = &""
	var top_xf := Transform3D()
	var col_heights := [0.0, 0.0]
	for i in shown.size():
		var id: StringName = shown[i]
		var def := defs.item(id)
		var xf := Transform3D()
		match layout:
			Layout.BACK:
				var col := 0 if i < column_size else 1
				xf = Transform3D(Basis(Vector3.UP, i * 0.4), Vector3(0, col_heights[col] + def.stack_height * 0.5, -0.46 * col))
				col_heights[col] += def.stack_height
			Layout.PAD:
				var layer := i / 4
				var k := i % 4
				xf = Transform3D(Basis(Vector3.UP, float(i)), Vector3((k % 2 - 0.5) * 0.5, 0.1 + layer * 0.32, (k / 2 - 0.5) * 0.5))
			Layout.HANGING:
				xf = Transform3D(Basis(), Vector3(0, -i * 0.3, 0))
		if not per_type.has(id):
			per_type[id] = []
		per_type[id].append(xf)
		top_id = id
		top_xf = xf
	for id in _multis:
		if not per_type.has(id):
			_multis[id].multimesh.visible_instance_count = 0
	for id in per_type:
		var mmi: MultiMeshInstance3D = _multis.get(id)
		var list: Array = per_type[id]
		if mmi == null or mmi.multimesh.instance_count < list.size():
			mmi = _make(id, maxi(list.size(), 8), mmi)
		mmi.multimesh.visible_instance_count = list.size()
		for j in list.size():
			mmi.multimesh.set_instance_transform(j, list[j])
	_top = []
	if top_id != &"":
		_top = [_multis[top_id].multimesh, per_type[top_id].size() - 1, top_xf]
	_pop_t = -1.0


## Bounces the top item (it just landed). Skipped with "Fewer effects" on.
func pop() -> void:
	if _top.is_empty() or SaveManager.settings.get("reduced_effects", false):
		return
	_pop = _top
	_pop_t = 0.0


func _process(delta: float) -> void:
	if _pop_t < 0.0:
		return
	_pop_t += delta
	var mm: MultiMesh = _pop[0]
	var xf: Transform3D = _pop[2]
	var j := defs.juice
	var k := _pop_t / j.stack_pop_time
	if k >= 1.0:
		_pop_t = -1.0
		mm.set_instance_transform(_pop[1], xf)
		return
	var s := 1.0 + j.stack_pop_scale * sin(PI * k) * (1.0 - k)
	mm.set_instance_transform(_pop[1], Transform3D(xf.basis.scaled(Vector3.ONE * s), xf.origin))


func _make(id: StringName, count: int, old: MultiMeshInstance3D) -> MultiMeshInstance3D:
	if old:
		old.queue_free()
	var def := defs.item(id)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ItemVisuals.mesh(def.shape)
	mm.instance_count = ceili(count * 1.5)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ItemVisuals.material(def)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_multis[id] = mmi
	return mmi
