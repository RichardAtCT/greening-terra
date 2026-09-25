class_name WorldLabel
extends Node3D
## A floating label over a building: a title and an optional coloured subtitle on a rounded dark
## panel. It holds only the text; LabelLayer draws every label on screen in three batched passes
## (panels, titles, subtitles), so they cost a few 2D draw calls in all instead of three 3D ones
## each. Sizes follow the prototype's 512x150 canvas sprites: scale_m is the world width of 512 px.

const GROUP := &"world_labels"
const CANVAS_W := 512.0
const TITLE_PX := 48
const SUB_PX := 34
const PAD_PX := 54.0
const MAX_W_PX := 504.0
const TITLE_COLOR := Color("f3e6dc")
const PANEL_COLOR := Color(0.078, 0.043, 0.063, 0.82)

const TITLE_FONT := preload("res://assets/fonts/oxanium_600.tres")
const SUB_FONT := preload("res://assets/fonts/IBMPlexMono-Medium.ttf")

## World width of the full 512 px canvas.
@export var scale_m: float = 3.6

var title := ""
var sub := ""
var accent := Color("f2b35b")
## Panel size in canvas pixels.
var panel_size := Vector2(100, 78)
var title_width := 0.0
var sub_width := 0.0

var _last: String = ""


func _enter_tree() -> void:
	add_to_group(GROUP)


func set_text(p_title: String, p_sub: String = "", p_accent: Color = Color("f2b35b")) -> void:
	var key := "%s|%s|%s" % [p_title, p_sub, p_accent.to_html()]
	if key == _last:
		return
	_last = key
	title = p_title
	sub = p_sub
	accent = p_accent
	title_width = TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX).x
	sub_width = SUB_FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_PX).x if sub != "" else 0.0
	panel_size = Vector2(minf(MAX_W_PX, maxf(title_width, sub_width) + PAD_PX), 132.0 if sub != "" else 78.0)
