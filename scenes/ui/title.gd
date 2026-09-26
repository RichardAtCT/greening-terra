extends Control
## Title screen: three family profiles, each with a name and colour, plus settings.

const PLANET_SCENE := "res://scenes/world/planet.tscn"

var _cards: VBoxContainer
var _settings: Control
var _armed_delete := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1c1016")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = minf(400.0, get_viewport_rect().size.x - 32.0)
	center.add_child(col)
	var insets := SafeArea.insets(get_window())
	var top_gap := Control.new()
	top_gap.custom_minimum_size.y = insets.x + 24.0
	col.add_child(top_gap)
	col.add_child(UiStyle.label("AN AD-FREE TERRAFORMING GAME", UiStyle.DISPLAY_WIDE, 11, UiStyle.MUTE))
	col.add_child(UiStyle.label("Greening Tessera", UiStyle.DISPLAY_BOLD, 34, UiStyle.INK))
	col.add_child(_paragraph("Pick your explorer. Each one has their own planets and progress."))
	if not SaveManager.storage_persists():
		var warn := _paragraph("This browser isn't keeping saves, so progress goes when the page closes. Open the game in its own tab, or use Back up save in the game menu.")
		warn.add_theme_color_override("font_color", UiStyle.RUST)
		col.add_child(warn)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	col.add_child(_cards)
	var settings_btn := UiStyle.button("Settings")
	settings_btn.pressed.connect(func(): _settings.visible = true)
	col.add_child(settings_btn)
	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size.y = insets.z + 24.0
	col.add_child(bottom_gap)
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.visible = false
	SaveManager.profiles_changed.connect(_rebuild)
	_rebuild()


func _paragraph(text: String) -> Label:
	var p := UiStyle.label(text, UiStyle.MONO, 13, UiStyle.MUTE)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return p


func _rebuild() -> void:
	for c in _cards.get_children():
		c.queue_free()
	for i in range(1, SaveManager.PROFILE_COUNT + 1):
		_cards.add_child(_card(i))


func _card(profile: int) -> Control:
	var color := SaveManager.profile_color(profile)
	var panel := PanelContainer.new()
	var style := UiStyle.panel(10, 14, 12)
	style.border_color = color
	style.border_width_left = 6
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UiStyle.label(SaveManager.profile_name(profile), UiStyle.DISPLAY_BOLD, 20, color))
	col.add_child(UiStyle.label(_summary(profile), UiStyle.MONO, 12, UiStyle.MUTE))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	col.add_child(row)
	var play := UiStyle.button("Continue" if SaveManager.has_save(profile) else "Start", true)
	play.pressed.connect(func(): _play(profile))
	row.add_child(play)
	var rename := UiStyle.button("Name")
	rename.pressed.connect(func():
		TextPrompt.ask(self, "Explorer name", SaveManager.profile_name(profile), func(text):
			if text != null and String(text).strip_edges() != "":
				SaveManager.set_profile(profile, text, SaveManager.profile_color(profile).to_html(false))))
	row.add_child(rename)
	var recolor := UiStyle.button("Colour")
	recolor.pressed.connect(func():
		var hexes: Array = SaveManager.COLORS
		var cur := hexes.find(SaveManager.profile_color(profile).to_html(false))
		SaveManager.set_profile(profile, SaveManager.profile_name(profile), hexes[(cur + 1) % hexes.size()]))
	row.add_child(recolor)
	if SaveManager.has_save(profile):
		var del := UiStyle.button("Tap again to erase" if _armed_delete == profile else "Erase", false, true)
		del.pressed.connect(func():
			if _armed_delete == profile:
				_armed_delete = 0
				SaveManager.delete_save(profile)
			else:
				_armed_delete = profile
				_rebuild())
		row.add_child(del)
	return panel


func _summary(profile: int) -> String:
	var state := SaveManager.load_state(profile)
	if state == null:
		return "New game"
	return "%s · %.0f%% · ₵%d" % [GameSim.planet_display_name(GameState.defs, state.planet_index), state.terraform, floori(state.credits)]


func _play(profile: int) -> void:
	SaveManager.active_profile = profile
	GameState.sim = null
	GameState.ensure_started()
	get_tree().change_scene_to_file(PLANET_SCENE)
