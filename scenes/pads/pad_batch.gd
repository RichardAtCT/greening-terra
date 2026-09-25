class_name PadBatch
extends Node3D
## Draws every pad in shared MultiMeshes: one for the dark base slabs, one for the bordered tops
## with their titles and subtitles, one per item type for the floating icons and one for the pay
## pads' coins. That's a few draw calls for every pad (M3 used three per pad plus one per icon).
## The pads' text is rendered once into an atlas (a SubViewport of Labels) that the top shader
## reads. Icons float above each pad's far edge, turning and bobbing (JuiceTuning), and everything
## follows each PadView (hidden with it, lifted with it).

const COIN := &"coin"
const ICON_Z := -0.55
const ICON_SPACING := 0.72
const PAD_SHADER := preload("res://shaders/pad.gdshader")
const TITLE_FONT := preload("res://assets/fonts/oxanium_700.tres")
const SUB_FONT := preload("res://assets/fonts/IBMPlexMono-SemiBold.ttf")
## The prototype's pad canvas is 256 px across 2.1 m; the atlas keeps rows 70..198 of it per pad,
## drawn at ATLAS_SCALE times that size (then mipmapped) so it stays crisp at an angle.
const CELL := Vector2i(256, 128)
const CELL_TOP := 70.0
const ATLAS_SCALE := 2
const ATLAS_COLS := 4
## Opacity of a pad's top when the player isn't on it.
const IDLE_OPACITY := 0.78

var pads: Array[PadView] = []
var _juice: JuiceTuning
var _bases: MultiMesh
var _tops: MultiMesh
var _atlas: SubViewport
var _top_mat: ShaderMaterial
var _icons: Dictionary = {}
var _time := 0.0


func setup(p_pads: Array[PadView], defs: GameDefs) -> void:
	pads = p_pads
	_juice = defs.juice
	var slab := BoxMesh.new()
	slab.size = Vector3(2.2, 0.08, 2.2)
	_bases = _multimesh("Bases", slab, ItemVisuals.lambert(Color("2a1c1f")), pads.size())
	_build_atlas()
	var top := QuadMesh.new()
	top.size = Vector2(2.1, 2.1)
	top.orientation = PlaneMesh.FACE_Y
	_top_mat = ShaderMaterial.new()
	_top_mat.shader = PAD_SHADER
	_top_mat.set_shader_parameter("atlas", _atlas.get_texture())
	_top_mat.set_shader_parameter("atlas_cells", Vector2(ATLAS_COLS, _atlas.size.y / (CELL.y * ATLAS_SCALE)))
	_top_mat.set_shader_parameter("text_rows", Vector2(CELL_TOP, CELL_TOP + CELL.y) / 256.0)
	_tops = _multimesh("Tops", top, _top_mat, pads.size(), true)
	_bake_atlas.call_deferred()
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
		_tops.set_instance_transform(n, at * Transform3D(Basis(), Vector3(0, 0.085, 0)))
		_tops.set_instance_color(n, pv.info.color)
		_tops.set_instance_custom_data(n, Color(pv.atlas_cell, 1.0 if pv.near else IDLE_OPACITY, 0, 0))
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
	_tops.visible_instance_count = n
	for id in _icons:
		_icons[id].visible_instance_count = counts.get(id, 0)


## Renders every pad's title and subtitle (white on black; the shader reads the red channel as
## coverage and tints it) into one texture.
func _build_atlas() -> void:
	var k := ATLAS_SCALE
	var rows := maxi(1, ceili(float(pads.size()) / ATLAS_COLS))
	_atlas = SubViewport.new()
	_atlas.name = "TextAtlas"
	_atlas.size = Vector2i(CELL.x * ATLAS_COLS, CELL.y * rows) * k
	_atlas.disable_3d = true
	_atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_atlas)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = _atlas.size
	_atlas.add_child(black)
	for i in pads.size():
		var pv := pads[i]
		pv.atlas_cell = i
		var cell := Control.new()
		cell.position = Vector2((i % ATLAS_COLS) * CELL.x, (i / ATLAS_COLS) * CELL.y) * k
		cell.size = CELL * k
		_atlas.add_child(cell)
		# Centres match the old Label3Ds: title 22 px towards the far edge, subtitle 40 px nearer.
		var has_sub := pv.info.label != ""
		cell.add_child(_text(pv.info.title, TITLE_FONT, 62 * k, ((128.0 - 22.0 if has_sub else 128.0) - CELL_TOP) * k, 76 * k))
		if has_sub:
			cell.add_child(_text(pv.info.label, SUB_FONT, 25 * k, (128.0 + 40.0 - CELL_TOP) * k, 34 * k))


func _text(text: String, font: Font, size: int, center_y: float, height: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, center_y - height * 0.5)
	l.size = Vector2(CELL.x * ATLAS_SCALE, height)
	return l


## Once the atlas has been drawn, keeps it as a mipmapped one-channel texture (a quarter of the
## memory, and no shimmer at a distance) and frees the viewport. Headless, the viewport stays.
func _bake_atlas() -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(_atlas):
		return
	var img := _atlas.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_R8)
	img.generate_mipmaps()
	_top_mat.set_shader_parameter("atlas", ImageTexture.create_from_image(img))
	_atlas.queue_free()
	_atlas = null


func _multimesh(node_name: String, mesh: Mesh, material: Material, count: int, per_instance := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = per_instance
	mm.use_custom_data = per_instance
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
