class_name SettingsPanel
extends ColorRect
## Settings overlay: music and sound volume, haptics, reduced effects. Saved separately from profiles.

signal closed


func _ready() -> void:
	color = Color(12.0 / 255.0, 6.0 / 255.0, 9.0 / 255.0, 0.55)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel(10, 22, 22))
	card.custom_minimum_size.x = minf(400.0, get_viewport_rect().size.x - 32.0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	col.add_child(UiStyle.label("Settings", UiStyle.DISPLAY_BOLD, 26, UiStyle.INK))
	col.add_child(_slider("Music", "music_volume"))
	col.add_child(_slider("Sounds", "sfx_volume"))
	col.add_child(_toggle("Vibration", "haptics"))
	col.add_child(_toggle("Fewer effects", "reduced_effects"))
	var close := UiStyle.button("Done", true)
	close.pressed.connect(func():
		visible = false
		closed.emit())
	col.add_child(close)
	apply_audio()


## Pushes the saved volumes to the audio buses.
static func apply_audio() -> void:
	for pair in [["Music", "music_volume"], ["SFX", "sfx_volume"]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			var v: float = SaveManager.settings[pair[1]]
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(bus, v <= 0.001)


func _slider(text: String, key: String) -> Control:
	var row := VBoxContainer.new()
	row.add_child(UiStyle.label(text, UiStyle.MONO, 13, UiStyle.MUTE))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = SaveManager.settings[key]
	s.custom_minimum_size.y = 28
	s.value_changed.connect(func(v):
		SaveManager.set_setting(key, v)
		apply_audio())
	row.add_child(s)
	return row


func _toggle(text: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = SaveManager.settings[key]
	c.add_theme_font_override("font", UiStyle.MONO)
	c.add_theme_font_size_override("font_size", 13)
	c.add_theme_color_override("font_color", UiStyle.INK)
	c.add_theme_color_override("font_pressed_color", UiStyle.INK)
	c.add_theme_color_override("font_hover_color", UiStyle.INK)
	c.toggled.connect(func(on): SaveManager.set_setting(key, on))
	return c
