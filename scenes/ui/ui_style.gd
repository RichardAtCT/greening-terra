class_name UiStyle
extends RefCounted
## The prototype's HUD palette, fonts and panel styles.

const INK := Color("f3e6dc")
const MUTE := Color("bca99b")
const PANEL := Color(22.0 / 255.0, 12.0 / 255.0, 17.0 / 255.0, 0.76)
const LINE := Color(243.0 / 255.0, 230.0 / 255.0, 220.0 / 255.0, 0.16)
const AMBER := Color("f2b35b")
const GREEN := Color("86e07c")
const RUST := Color("d9794a")

const DISPLAY := preload("res://assets/fonts/oxanium_600.tres")
const DISPLAY_BOLD := preload("res://assets/fonts/oxanium_700.tres")
## Letter-spaced, for small upper-case eyebrow labels.
const DISPLAY_WIDE := preload("res://assets/fonts/oxanium_600_wide.tres")
const MONO := preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const MONO_SEMI := preload("res://assets/fonts/IBMPlexMono-SemiBold.ttf")


static func panel(radius := 10, pad_x := 12, pad_y := 10, bg := PANEL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = LINE
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, primary := false, danger := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): Audio.play(&"click"))
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", DISPLAY)
	b.add_theme_font_size_override("font_size", 14)
	var fg := INK
	var bg := Color(0, 0, 0, 0)
	var border := LINE
	if primary:
		fg = Color("132012")
		bg = GREEN
		border = Color(0, 0, 0, 0)
	elif danger:
		fg = RUST
		border = Color(RUST, 0.6)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := panel(8, 14, 10, bg if state != "pressed" else bg.darkened(0.15))
		s.border_color = border if state != "focus" else AMBER
		if state == "focus":
			s.set_border_width_all(2)
		b.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	return b
