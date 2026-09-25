class_name LabelLayer
extends Control
## Draws every WorldLabel on screen, over the 3D world and under the HUD, in three passes: all the
## panels, then all the titles, then all the subtitles. Each pass is one canvas item using one
## texture (none, the title font, the subtitle font), so the whole set batches into a few draw
## calls. Labels keep their world size (they shrink with distance, like the Label3Ds they replace)
## and always draw on top, as before.

var camera: Camera3D

var _panels: Control
var _titles: Control
var _subs: Control
var _panel_box: StyleBoxFlat
## Per label this frame: [label, canvas position, scale (canvas px per label px)].
var _shown: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_box = StyleBoxFlat.new()
	_panel_box.bg_color = WorldLabel.PANEL_COLOR
	_panel_box.set_corner_radius_all(20)
	_panel_box.anti_aliasing = true
	_panels = _pass("Panels", _draw_panels)
	_titles = _pass("Titles", _draw_titles)
	_subs = _pass("Subs", _draw_subs)


func _pass(pass_name: String, draw: Callable) -> Control:
	var c := Control.new()
	c.name = pass_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(draw)
	add_child(c)
	return c


func _process(_delta: float) -> void:
	_collect()
	_panels.queue_redraw()
	_titles.queue_redraw()
	_subs.queue_redraw()


## Labels on screen, furthest first (so nearer ones draw over them), with where and how big.
func _collect() -> void:
	_shown.clear()
	if camera == null or not camera.is_inside_tree():
		return
	var right := camera.global_basis.x
	var depths := []
	for node in get_tree().get_nodes_in_group(WorldLabel.GROUP):
		var l := node as WorldLabel
		if l == null or not l.is_visible_in_tree() or l.title == "":
			continue
		var p := l.global_position
		if camera.is_position_behind(p):
			continue
		# unproject_position is already in canvas units (the visible rect, after content scale).
		var at := camera.unproject_position(p)
		var edge := camera.unproject_position(p + right * l.scale_m)
		var s := at.distance_to(edge) / WorldLabel.CANVAS_W
		_shown.append([l, at, s])
		depths.append(camera.global_position.distance_squared_to(p))
	var order := range(_shown.size())
	order.sort_custom(func(a, b): return depths[a] > depths[b])
	var sorted := []
	for i in order:
		sorted.append(_shown[i])
	_shown = sorted


func _draw_panels() -> void:
	for e in _shown:
		var l: WorldLabel = e[0]
		_panels.draw_set_transform(e[1], 0.0, Vector2.ONE * e[2])
		_panel_box.draw(_panels.get_canvas_item(), Rect2(-l.panel_size * 0.5, l.panel_size))
	_panels.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_titles() -> void:
	var font := WorldLabel.TITLE_FONT
	for e in _shown:
		var l: WorldLabel = e[0]
		# The title sits above centre when there's a subtitle.
		var y := -26.0 if l.sub != "" else 0.0
		_titles.draw_set_transform(e[1], 0.0, Vector2.ONE * e[2])
		_titles.draw_string(font, Vector2(-l.title_width * 0.5, y + _baseline(font, WorldLabel.TITLE_PX)), l.title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, WorldLabel.TITLE_PX, WorldLabel.TITLE_COLOR)
	_titles.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_subs() -> void:
	var font := WorldLabel.SUB_FONT
	for e in _shown:
		var l: WorldLabel = e[0]
		if l.sub == "":
			continue
		_subs.draw_set_transform(e[1], 0.0, Vector2.ONE * e[2])
		_subs.draw_string(font, Vector2(-l.sub_width * 0.5, 30.0 + _baseline(font, WorldLabel.SUB_PX)), l.sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, WorldLabel.SUB_PX, l.accent)
	_subs.draw_set_transform_matrix(Transform2D.IDENTITY)


## Offset from a line's vertical centre to its baseline.
static func _baseline(font: Font, size: int) -> float:
	return (font.get_ascent(size) - font.get_descent(size)) * 0.5


## Labels drawn last frame (for tests and the debug overlay).
func shown_count() -> int:
	return _shown.size()
