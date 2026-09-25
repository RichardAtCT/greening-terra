class_name PadBatch
extends Node3D
## Draws every pad's dark base slab and its floating icons in shared MultiMeshes: one for the
## slabs, one per item type and one for the pay pads' coins. That's a few draw calls instead of
## one per slab and per icon. Icons float above each pad's far edge, turning and bobbing
## (JuiceTuning), and follow each PadView (hidden with it, lifted with it).

const COIN := &"coin"
const ICON_Z := -0.55
const ICON_SPACING := 0.72

var pads: Array[PadView] = []
var _juice: JuiceTuning
var _bases: MultiMesh
var _icons: Dictionary = {}
var _time := 0.0


func setup(p_pads: Array[PadView], defs: GameDefs) -> void:
	pads = p_pads
	_juice = defs.juice
	var slab := BoxMesh.new()
	slab.size = Vector3(2.2, 0.08, 2.2)
	_bases = _multimesh("Bases", slab, ItemVisuals.lambert(Color("2a1c1f")), pads.size())
	var counts := {}
	for pv in pads:
		for id in pv.icon_ids():
			counts[id] = counts.get(id, 0) + 1
	for id in counts:
		if id == COIN:
			var coin := ItemVisuals.coin()
			_icons[id] = _multimesh("Icons_coin", coin.mesh, null, counts[id])
			coin.free()
		else:
			var def := defs.item(id)
			_icons[id] = _multimesh("Icons_" + id, ItemVisuals.mesh(def.shape), ItemVisuals.material(def), counts[id])
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


func _update() -> void:
	var n := 0
	var counts := {}
	for pv in pads:
		if not pv.visible:
			continue
		var at := pv.transform
		_bases.set_instance_transform(n, at * Transform3D(Basis(), Vector3(0, 0.04, 0)))
		n += 1
		var ids := pv.icon_ids()
		for i in ids.size():
			var id := ids[i]
			var mm: MultiMesh = _icons[id]
			var k: int = counts.get(id, 0)
			var pos := Vector3((i - (ids.size() - 1) * 0.5) * ICON_SPACING,
				_juice.icon_height + sin(_time * 2.0 + i * 1.3) * _juice.icon_bob, ICON_Z)
			var basis := Basis(Vector3.UP, i * 0.9 + _time * _juice.icon_spin).scaled(Vector3.ONE * _juice.icon_scale)
			if id == COIN:
				# Coins stand on their edge.
				basis = basis * Basis(Vector3.RIGHT, PI / 2)
			mm.set_instance_transform(k, at * Transform3D(basis, pos))
			counts[id] = k + 1
	_bases.visible_instance_count = n
	for id in _icons:
		_icons[id].visible_instance_count = counts.get(id, 0)


func _multimesh(node_name: String, mesh: Mesh, material: Material, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = maxi(count, 1)
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	if material:
		mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm
