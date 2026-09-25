class_name PadBatch
extends Node3D
## Draws every pad in shared MultiMeshes: one for the dark base slabs, one for the bordered tops
## with their titles and subtitles, one per item type for the floating icons and one for the pay
## pads' coins. That's a few draw calls for every pad (M3 used three per pad plus one per icon).
## The pads' text is written once into an atlas texture that the top shader reads. Icons float above each pad's far edge, turning and bobbing (JuiceTuning), and everything
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
var _top_mat: ShaderMaterial
var _icons: Dictionary = {}
var _time := 0.0


func setup(p_pads: Array[PadView], defs: GameDefs) -> void:
	pads = p_pads
	_juice = defs.juice
	var slab := BoxMesh.new()
	slab.size = Vector3(2.2, 0.08, 2.2)
	_bases = _multimesh("Bases", slab, ItemVisuals.lambert(Color("2a1c1f")), pads.size())
	var atlas := _build_atlas()
	var top := QuadMesh.new()
	top.size = Vector2(2.1, 2.1)
	top.orientation = PlaneMesh.FACE_Y
	_top_mat = ShaderMaterial.new()
	_top_mat.shader = PAD_SHADER
	_top_mat.set_shader_parameter("atlas", atlas)
	_top_mat.set_shader_parameter("atlas_cells", Vector2(ATLAS_COLS, atlas.get_height() / (CELL.y * ATLAS_SCALE)))
	_top_mat.set_shader_parameter("text_rows", Vector2(CELL_TOP, CELL_TOP + CELL.y) / 256.0)
	_tops = _multimesh("Tops", top, _top_mat, pads.size(), true)
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


## Writes every pad's title and subtitle into one texture, on the CPU: each string is shaped by the
## TextServer and its glyphs copied from the font's own glyph cache (white on black; the shader
## reads red as coverage and tints it). Then mipmapped, so it stays crisp at an angle. Drawing
## Labels into a SubViewport and reading that back came out garbled on WebGL; this can't.
func _build_atlas() -> Texture2D:
	var k := ATLAS_SCALE
	var title_font := _plain(TITLE_FONT)
	var sub_font := _plain(SUB_FONT)
	var rows := maxi(1, ceili(float(pads.size()) / ATLAS_COLS))
	var img := Image.create_empty(CELL.x * ATLAS_COLS * k, CELL.y * rows * k, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for i in pads.size():
		var pv := pads[i]
		pv.atlas_cell = i
		var cell := Vector2((i % ATLAS_COLS) * CELL.x, (i / ATLAS_COLS) * CELL.y) * k
		# Centres match the old Label3Ds: title 22 px towards the far edge, subtitle 40 px nearer.
		var has_sub := pv.info.label != ""
		var fit := CELL.x * k * 0.9
		_write(img, pv.info.title, title_font, 62 * k, cell + Vector2(CELL.x * k * 0.5, ((128.0 - 22.0 if has_sub else 128.0) - CELL_TOP) * k), fit)
		if has_sub:
			_write(img, pv.info.label, sub_font, 25 * k, cell + Vector2(CELL.x * k * 0.5, (128.0 + 40.0 - CELL_TOP) * k), fit)
	img.convert(Image.FORMAT_R8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A copy of a font that rasterises plain coverage glyphs (the game's fonts are MSDF, whose glyph
## cache holds distance fields, not something to copy into a texture).
static func _plain(font: Font) -> Font:
	if font is FontVariation:
		var v := (font as FontVariation).duplicate() as FontVariation
		v.base_font = _plain(v.base_font)
		v.fallbacks = []
		return v
	var src := font as FontFile
	var f := FontFile.new()
	f.data = src.data
	f.multichannel_signed_distance_field = false
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f


## Draws text centred on `center` into img, glyph by glyph from the font's cache, shrunk to fit
## within max_width.
static func _write(img: Image, text: String, font: Font, size: int, center: Vector2, max_width: float) -> void:
	var ts := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string(text, font, size)
	var width := line.get_size().x
	if width > max_width:
		line = TextLine.new()
		line.add_string(text, font, floori(size * max_width / width))
		width = line.get_size().x
	var baseline := center.y + (line.get_line_ascent() - line.get_line_descent()) * 0.5
	var pen := Vector2(center.x - width * 0.5, baseline)
	var pages := {}
	for g in ts.shaped_text_get_glyphs(line.get_rid()):
		var rid: RID = g.font_rid
		var at: Vector2 = pen + g.offset
		pen.x += g.advance * g.repeat
		if not rid.is_valid() or g.index == 0:
			continue
		var fs := Vector2i(g.font_size, 0)
		ts.font_render_glyph(rid, fs, g.index)
		var page: int = ts.font_get_glyph_texture_idx(rid, fs, g.index)
		if page < 0:
			continue
		var key := [rid, fs, page]
		if not pages.has(key):
			var tex_img := ts.font_get_texture_image(rid, fs, page)
			tex_img.convert(Image.FORMAT_RGBA8)
			pages[key] = tex_img
		var src: Image = pages[key]
		var uv: Rect2 = ts.font_get_glyph_uv_rect(rid, fs, g.index)
		var dst: Vector2 = at + ts.font_get_glyph_offset(rid, fs, g.index)
		var glyph := src.get_region(Rect2i(uv.position, uv.size))
		# The cache is white with coverage in alpha: blending over black leaves coverage in red.
		img.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), Vector2i(dst.round()))


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
