class_name WorldLabel
extends Node3D
## Floating billboard label with a rounded dark panel: a title and an optional coloured subtitle.
## Sizes follow the prototype's 512x150 canvas sprites.

const CANVAS_W := 512.0
const TITLE_PX := 48
const SUB_PX := 34
const PAD_PX := 54.0
const MAX_W_PX := 504.0

const TITLE_FONT := preload("res://assets/fonts/oxanium_600.tres")
const SUB_FONT := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const BG_SHADER := preload("res://shaders/label_bg.gdshader")

## World width of the full 512 px canvas.
@export var scale_m: float = 3.6

var _title: Label3D
var _sub: Label3D
var _bg: MeshInstance3D
var _bg_mat: ShaderMaterial
var _last: String = ""


func _ready() -> void:
	var px := scale_m / CANVAS_W
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BG_SHADER
	_bg_mat.render_priority = -2
	_bg_mat.set_shader_parameter("radius", 20.0 * px)
	_bg = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_bg.mesh = q
	_bg.material_override = _bg_mat
	_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bg)
	_title = _make_label(TITLE_FONT, TITLE_PX, px)
	_sub = _make_label(SUB_FONT, SUB_PX, px)


func _make_label(font: Font, size: int, px: float) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.font_size = size
	l.pixel_size = px
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.double_sided = true
	l.outline_size = 0
	l.render_priority = 1
	l.modulate = Color("f3e6dc")
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	return l


func set_text(title: String, sub: String = "", accent: Color = Color("f2b35b")) -> void:
	var key := "%s|%s|%s" % [title, sub, accent.to_html()]
	if key == _last:
		return
	_last = key
	var px := scale_m / CANVAS_W
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	_sub.modulate = accent
	var w1 := TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX).x
	var w2 := SUB_FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_PX).x if sub != "" else 0.0
	var bw := minf(MAX_W_PX, maxf(w1, w2) + PAD_PX)
	var bh := 132.0 if sub != "" else 78.0
	_bg_mat.set_shader_parameter("size", Vector2(bw, bh) * px)
	# Offsets are in pixels, in the label's own (camera-facing) plane.
	_title.offset = Vector2(0, 26 if sub != "" else 0)
	_sub.offset = Vector2(0, -30)
