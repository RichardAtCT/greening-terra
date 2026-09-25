class_name PadView
extends Node3D
## A floor pad: dark base, bordered top in the pad's colour, and a flat title + subtitle.

const PAD_SHADER := preload("res://shaders/pad.gdshader")
const TITLE_FONT := preload("res://assets/fonts/oxanium_700.tres")
const SUB_FONT := preload("res://assets/fonts/IBMPlexMono-SemiBold.ttf")
## Metres per pixel of the prototype's 256 px pad canvas drawn over 2.1 m.
const PX := 2.1 / 256.0
const LIFT := 0.03

static var _base_mesh: BoxMesh
static var _base_mat: StandardMaterial3D

var info: PadInfo
var _top_mat: ShaderMaterial
var _title: Label3D
var _sub: Label3D
var _near := false


func setup(p_info: PadInfo) -> void:
	info = p_info
	name = "Pad_" + info.key
	position = Vector3(info.position.x, 0, info.position.y)
	if _base_mesh == null:
		_base_mesh = BoxMesh.new()
		_base_mesh.size = Vector3(2.2, 0.08, 2.2)
		_base_mat = ItemVisuals.lambert(Color("2a1c1f"))
	var base := MeshInstance3D.new()
	base.mesh = _base_mesh
	base.material_override = _base_mat
	base.position.y = 0.04
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)

	_top_mat = ShaderMaterial.new()
	_top_mat.shader = PAD_SHADER
	_top_mat.set_shader_parameter("border_color", info.color)
	var top := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.1, 2.1)
	top.mesh = q
	top.material_override = _top_mat
	top.rotation.x = -PI / 2
	top.position.y = 0.085
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)

	var has_sub := info.label != ""
	_title = _flat_label(TITLE_FONT, 62, info.title, 0.0 if not has_sub else 22.0)
	if has_sub:
		_sub = _flat_label(SUB_FONT, 25, info.label, -40.0)


func _flat_label(font: Font, size: int, text: String, offset_px: float) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.font_size = size
	l.pixel_size = PX
	l.text = text
	l.modulate = info.color
	l.shaded = false
	l.double_sided = false
	l.outline_size = 0
	l.render_priority = 1
	l.rotation.x = -PI / 2
	l.position = Vector3(0, 0.09, -offset_px * PX)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	return l


func set_near(near: bool) -> void:
	if near == _near:
		return
	_near = near
	_top_mat.set_shader_parameter("opacity", 1.0 if near else 0.78)
	position.y = LIFT if near else 0.0
