class_name Hud
extends Control
## The in-game HUD: terraform panel (with Kessik's toxicity), credits and pack, objective bar,
## toasts, hazard banner, menu and the win screen with its bonus picker. Laid out to match the
## prototype's HTML HUD.

signal menu_opened
signal menu_closed
signal restart_requested
## The player wants the star map (to launch onwards once this planet is done).
signal star_map_requested
signal bonus_picked(id: StringName)
signal stay_requested
signal title_requested
signal restore_requested(state: WorldState)

const TOXIC := Color("e8c23a")

var _safe := Vector4.ZERO
var _root: MarginContainer
var _planet: Label
var _pct: Label
var _bar_fill: ColorRect
var _bar_back: Panel
var _bar_cap: ColorRect
var _tox_row: HBoxContainer
var _tox: Label
var _tox_back: Panel
var _tox_fill: ColorRect
var _stage: Label
var _atmo: Label
var _credits: Label
var _credits_panel: PanelContainer
var _pack: Label
var _pack_count: Label
var _colony_panel: PanelContainer
var _food: Label
var _food_row: HBoxContainer
var _lander: Label
var _people: Label
var _banner: PanelContainer
var _banner_icon: HazardIcon
var _banner_text: Label
var _menu_button: Button
var _hint_panel: PanelContainer
var _hint_step: Label
var _hint_text: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_t := 0.0
var _pulse_t := 0.0
var _menu: Control
var _menu_stats: Dictionary = {}
var _reset_button: Button
var _reset_armed := false
var _win: Control
var _win_title: Label
var _win_body: Label
var _launch_button: Button
var _bonus_title: Label
var _bonus_cards: VBoxContainer
var _star_map_button: Button
var _settings: SettingsPanel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_hint()
	_build_toast()
	_build_banner()
	_menu = _build_menu()
	_win = _build_win()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	EventBus.toast.connect(show_toast)
	EventBus.credits_earned.connect(func(_c): pulse_credits())


## True while a touch at pos should not move the player (buttons, open overlays).
func blocks_touch(pos: Vector2) -> bool:
	if _menu.visible or _win.visible or _settings.visible:
		return true
	return _menu_button.get_global_rect().grow(6).has_point(pos)


func is_overlay_open() -> bool:
	return _menu.visible or _win.visible or _settings.visible


func update_hud(sim: GameSim, shown_tf: float, delta: float) -> void:
	var tf := sim.defs.terraform
	_planet.text = sim.planet_name().to_upper()
	_pct.text = "%.1f%%" % shown_tf
	_bar_fill.size = Vector2(_bar_back.size.x * clampf(shown_tf / 100.0, 0.0, 1.0), _bar_back.size.y)
	_update_toxicity(sim)
	_stage.text = TerraformMath.stage_name(tf, sim.state.terraform)
	_atmo.text = TerraformMath.atmosphere_text(tf, shown_tf)
	_credits.text = str(floori(sim.state.credits))
	var cap := sim.pack_capacity()
	_pack_count.text = "%d/%d" % [sim.state.stack.size(), cap]
	_pack_count.add_theme_color_override("font_color", UiStyle.RUST if sim.state.stack.size() >= cap else UiStyle.INK)
	_update_colony(sim)
	_update_banner(sim)
	_hint_step.text = Tutorial.step_label(sim)
	_hint_text.text = Tutorial.hint_text(sim)
	if _pulse_t > 0.0:
		_pulse_t -= delta
		_credits.scale = Vector2.ONE * (1.0 + 0.18 * maxf(0.0, _pulse_t / 0.35))
	else:
		_credits.scale = Vector2.ONE
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(minf(_toast_t / 0.25, (sim.defs.tuning.toast_time - _toast_t) / 0.25 + 0.001), 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.visible = false
	if _menu.visible:
		_menu_stats.drones.text = str(sim.state.drones)
		_menu_stats.delivered.text = str(sim.state.stat(&"delivered"))
		_menu_stats.pack.text = str(cap)
		_menu_stats.boots.text = "+%d%%" % roundi(sim.state.boots_level * sim.defs.boots_upgrade.amount_per_level * 100.0)
		_menu_stats.colonists.text = str(sim.state.meals.size() + sim.state.colonists_waiting)
		_menu_stats.food.text = str(floori(sim.state.food))
		_star_map_button.visible = sim.state.won


## Kessik: the toxicity readout and bar, and the part of the terraform bar it still holds back.
func _update_toxicity(sim: GameSim) -> void:
	var on := sim.planet.start_toxicity > 0.0
	_tox_row.visible = on
	_tox_back.visible = on
	_bar_cap.visible = on and sim.state.toxicity > 0.0
	if not on:
		return
	var tox := clampf(sim.state.toxicity, 0.0, 100.0)
	_tox.text = "Toxins %d%%" % ceili(tox) if tox > 0.0 else "Air clear"
	_tox.add_theme_color_override("font_color", TOXIC if tox > 0.0 else UiStyle.GREEN)
	_tox_fill.size = Vector2(_tox_back.size.x * tox / 100.0, _tox_back.size.y)
	var w := _bar_back.size.x
	_bar_cap.position = Vector2(w * (1.0 - tox / 100.0), 0)
	_bar_cap.size = Vector2(w * tox / 100.0, _bar_back.size.y)


## Food store and colonists (top right), once the first lander has come.
func _update_colony(sim: GameSim) -> void:
	var s := sim.state
	var people := s.meals.size() + s.colonists_waiting
	var next := Colony.next_lander_at(sim.planet, s.terraform)
	if s.lander_t >= 0.0:
		_lander.text = "lander landing"
	elif next >= 0.0:
		_lander.text = "lander at %d%%" % roundi(next)
	_lander.visible = s.lander_t >= 0.0 or next >= 0.0
	_colony_panel.visible = people > 0 or _lander.visible
	_food_row.visible = people > 0
	_people.visible = people > 0
	if people == 0:
		return
	var hungry := Colony.hungry_count(sim)
	_food.text = str(floori(s.food))
	_food.add_theme_color_override("font_color", UiStyle.RUST if hungry > 0 else (UiStyle.GREEN if s.food >= Colony.food_target(sim) else UiStyle.INK))
	if hungry > 0:
		_people.text = "%d hungry" % hungry
		_people.add_theme_color_override("font_color", UiStyle.RUST)
	elif s.colonists_waiting > 0:
		_people.text = "%d · %d wait" % [s.meals.size(), s.colonists_waiting]
		_people.add_theme_color_override("font_color", UiStyle.AMBER)
	else:
		_people.text = "%d colonists" % people
		_people.add_theme_color_override("font_color", UiStyle.MUTE)


## The hazard banner: a warning with a countdown, then how long is left.
func _update_banner(sim: GameSim) -> void:
	var h := sim.planet.hazard
	var s := sim.state
	var phase := s.hazard_phase if h else HazardDirector.Phase.NONE
	_banner.visible = phase != HazardDirector.Phase.NONE
	if not _banner.visible:
		return
	var warn := phase == HazardDirector.Phase.WARNING
	var color := UiStyle.AMBER if warn else UiStyle.RUST
	_banner_text.text = "%s · %d" % [h.warning_text if warn else h.active_text, ceili(s.hazard_t)]
	_banner_text.add_theme_color_override("font_color", color)
	_banner_icon.color = color
	_banner_icon.kind = h.kind
	_banner_icon.spin = 0.0 if warn else 1.0


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast_t = GameState.defs.tuning.toast_time if GameState.defs else 2.4
	_toast.modulate.a = 0.0


func pulse_credits() -> void:
	if _pulse_t <= 0.0:
		_pulse_t = 0.35


func open_menu() -> void:
	_reset_armed = false
	_reset_button.text = "Restart planet"
	_menu.visible = true
	menu_opened.emit()


func close_menu() -> void:
	_menu.visible = false
	menu_closed.emit()


## The win screen: pick one of three bonuses (SPEC 4.3), then on to the star map.
func show_win(sim: GameSim, confetti := true) -> void:
	_win_title.text = "%s is breathing" % sim.planet_name()
	_win_body.text = sim.planet.win_text
	_launch_button.text = "To the star map"
	_fill_bonuses(sim)
	_win.visible = true
	if confetti:
		_confetti()


func _fill_bonuses(sim: GameSim) -> void:
	for c in _bonus_cards.get_children():
		c.queue_free()
	var offer := Bonuses.offer(sim.defs, sim.state)
	var picking := not sim.state.bonus_picked and not offer.is_empty()
	_bonus_title.text = "PICK A BONUS FOR THE REST OF YOUR JOURNEY" if picking else "YOUR BONUSES"
	_bonus_title.visible = picking or not sim.state.bonuses.is_empty()
	if picking:
		for b in offer:
			_bonus_cards.add_child(_bonus_card(b, true))
	else:
		for id in sim.state.bonuses:
			var b := sim.defs.bonus(id)
			if b:
				_bonus_cards.add_child(_bonus_card(b, false))
	_launch_button.disabled = picking
	if picking:
		(_bonus_cards.get_child(0) as Control).grab_focus.call_deferred()
	else:
		_launch_button.grab_focus.call_deferred()


func _bonus_card(b: BonusDef, pickable: bool) -> Control:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL if pickable else Control.FOCUS_NONE
	btn.disabled = not pickable
	btn.custom_minimum_size.y = 66 if pickable else 44
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := UiStyle.panel(8, 12, 8, Color(b.color, 0.12 if state != "pressed" else 0.22))
		st.border_color = b.color if state == "focus" or state == "hover" else Color(b.color, 0.45)
		st.border_width_left = 4
		if state == "focus":
			st.set_border_width_all(2)
			st.border_width_left = 4
		btn.add_theme_stylebox_override(state, st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_top = 6
	col.offset_right = -10
	col.offset_bottom = -6
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(col)
	col.add_child(UiStyle.label(b.display_name, UiStyle.DISPLAY_BOLD, 15, b.color.lerp(UiStyle.INK, 0.3)))
	var d := UiStyle.label(b.description, UiStyle.MONO, 11, UiStyle.MUTE)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	if pickable:
		btn.pressed.connect(func():
			Audio.play(&"bonus")
			bonus_picked.emit(b.id))
	return btn


## A burst of confetti from the top of the screen. Skipped with "Fewer effects" on.
func _confetti() -> void:
	if SaveManager.settings.get("reduced_effects", false):
		return
	var j := GameState.defs.juice
	var p := CPUParticles2D.new()
	p.name = "Confetti"
	p.one_shot = true
	p.explosiveness = 0.35
	p.amount = j.confetti_amount
	p.lifetime = j.confetti_lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.5, 10.0)
	p.position = Vector2(size.x * 0.5, -20.0)
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 130.0)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 10.0
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	ramp.colors = PackedColorArray([UiStyle.GREEN, UiStyle.AMBER, Color("8fe3ff"), Color("ff6a4a"), Color("f4efe6")])
	p.color_initial_ramp = ramp
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func hide_win() -> void:
	_win.visible = false


func _apply_safe_area() -> void:
	_safe = SafeArea.insets(get_window())
	_root.add_theme_constant_override("margin_top", int(_safe.x) + 12)
	_root.add_theme_constant_override("margin_right", int(_safe.y) + 16)
	_root.add_theme_constant_override("margin_left", int(_safe.w) + 16)
	_hint_panel.offset_bottom = -(_safe.z + 16.0)
	_toast.offset_top = _safe.x + 240.0
	_banner.offset_top = _safe.x + 192.0
	var w := get_viewport_rect().size.x
	(_planet.get_parent().get_parent() as Control).custom_minimum_size.x = minf(270.0, w * 0.52)
	_hint_panel.offset_left = maxf(16.0, (w - 440.0) * 0.5)
	_hint_panel.offset_right = -maxf(16.0, (w - 440.0) * 0.5)


func _build_top() -> void:
	_root = MarginContainer.new()
	_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_root.add_child(row)

	var tf_panel := PanelContainer.new()
	tf_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	tf_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tf_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tf_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tf_panel.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_planet = UiStyle.label("TESSERA-4", UiStyle.DISPLAY_WIDE, 11, UiStyle.MUTE)
	_planet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_planet)
	_pct = UiStyle.label("0.0%", UiStyle.MONO_SEMI, 15, UiStyle.INK)
	head.add_child(_pct)
	_bar_back = Panel.new()
	_bar_back.custom_minimum_size.y = 8
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.clip_contents = true
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(UiStyle.INK, 0.1)
	back_style.set_corner_radius_all(4)
	_bar_back.add_theme_stylebox_override("panel", back_style)
	col.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.material = _gradient_material()
	_bar_back.add_child(_bar_fill)
	# Kessik: the share of the bar toxins still hold back.
	_bar_cap = ColorRect.new()
	_bar_cap.color = Color(TOXIC, 0.35)
	_bar_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_cap.visible = false
	_bar_back.add_child(_bar_cap)
	_tox_row = HBoxContainer.new()
	_tox_row.add_theme_constant_override("separation", 8)
	_tox_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tox_row.visible = false
	col.add_child(_tox_row)
	_tox = UiStyle.label("Toxins 100%", UiStyle.MONO_SEMI, 11, TOXIC)
	_tox_row.add_child(_tox)
	_tox_back = Panel.new()
	_tox_back.custom_minimum_size.y = 5
	_tox_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tox_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tox_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tox_back.clip_contents = true
	_tox_back.visible = false
	var tox_style := StyleBoxFlat.new()
	tox_style.bg_color = Color(UiStyle.INK, 0.1)
	tox_style.set_corner_radius_all(3)
	_tox_back.add_theme_stylebox_override("panel", tox_style)
	_tox_row.add_child(_tox_back)
	_tox_fill = ColorRect.new()
	_tox_fill.color = TOXIC
	_tox_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tox_back.add_child(_tox_fill)
	_stage = UiStyle.label("Barren regolith", UiStyle.DISPLAY, 15, UiStyle.GREEN)
	col.add_child(_stage)
	_atmo = UiStyle.label("0.6 kPa · −63 °C", UiStyle.MONO, 11, UiStyle.MUTE)
	col.add_child(_atmo)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(right)
	_credits_panel = PanelContainer.new()
	_credits_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_credits_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(_credits_panel)
	var cr_row := HBoxContainer.new()
	cr_row.add_theme_constant_override("separation", 6)
	cr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_panel.add_child(cr_row)
	cr_row.add_child(UiStyle.label("₵", UiStyle.DISPLAY, 16, UiStyle.AMBER))
	_credits = UiStyle.label("0", UiStyle.MONO_SEMI, 20, UiStyle.AMBER)
	_credits.resized.connect(func(): _credits.pivot_offset = _credits.size * 0.5)
	cr_row.add_child(_credits)
	var pack_panel := PanelContainer.new()
	pack_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	pack_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(pack_panel)
	var pack_row := HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 6)
	pack_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_panel.add_child(pack_row)
	_pack = UiStyle.label("Pack", UiStyle.MONO, 12, UiStyle.MUTE)
	pack_row.add_child(_pack)
	_pack_count = UiStyle.label("0/8", UiStyle.MONO_SEMI, 12, UiStyle.INK)
	pack_row.add_child(_pack_count)
	_colony_panel = PanelContainer.new()
	_colony_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_colony_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colony_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_colony_panel.visible = false
	right.add_child(_colony_panel)
	var colony_col := VBoxContainer.new()
	colony_col.add_theme_constant_override("separation", 2)
	colony_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colony_panel.add_child(colony_col)
	var food_row := HBoxContainer.new()
	_food_row = food_row
	food_row.add_theme_constant_override("separation", 6)
	food_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_row.alignment = BoxContainer.ALIGNMENT_END
	colony_col.add_child(food_row)
	food_row.add_child(UiStyle.label("Food", UiStyle.MONO, 12, UiStyle.MUTE))
	_food = UiStyle.label("0", UiStyle.MONO_SEMI, 12, UiStyle.INK)
	food_row.add_child(_food)
	_people = UiStyle.label("", UiStyle.MONO, 11, UiStyle.MUTE)
	_people.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	colony_col.add_child(_people)
	# When the next colonists come: landers are called by terraform % (SPEC 4.1).
	_lander = UiStyle.label("", UiStyle.MONO, 11, UiStyle.MUTE)
	_lander.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	colony_col.add_child(_lander)
	_menu_button = UiStyle.button("MENU")
	_menu_button.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := UiStyle.panel(8, 10, 6)
		if state == "focus":
			s.border_color = UiStyle.AMBER
			s.set_border_width_all(2)
		_menu_button.add_theme_stylebox_override(state, s)
	_menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_menu_button.pressed.connect(open_menu)
	right.add_child(_menu_button)


func _gradient_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 a : source_color = vec4(0.788, 0.439, 0.247, 1.0);
uniform vec4 b : source_color = vec4(0.843, 0.702, 0.353, 1.0);
uniform vec4 c : source_color = vec4(0.525, 0.878, 0.486, 1.0);
void fragment() {
	// Rust to gold to green across the filled part, like the prototype's CSS gradient.
	float t = UV.x;
	COLOR = t < 0.45 ? mix(a, b, t / 0.45) : mix(b, c, (t - 0.45) / 0.55);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_hint() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.anchor_left = 0.0
	_hint_panel.anchor_right = 1.0
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_left = 16
	_hint_panel.offset_right = -16
	_hint_panel.offset_bottom = -16
	add_child(_hint_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(row)
	_hint_step = UiStyle.label("1/9", UiStyle.DISPLAY_WIDE, 11, UiStyle.AMBER)
	_hint_step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_hint_step)
	_hint_text = UiStyle.label("", UiStyle.MONO, 13, UiStyle.INK)
	_hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hint_text)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UiStyle.panel(999, 14, 7))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 136
	_banner.visible = false
	add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	_banner_icon = HazardIcon.new()
	_banner_icon.custom_minimum_size = Vector2(20, 20)
	row.add_child(_banner_icon)
	_banner_text = UiStyle.label("", UiStyle.DISPLAY, 15, UiStyle.AMBER)
	row.add_child(_banner_text)


## The hazard's own icon, so the banner reads without reading: three gusting wind lines (storm),
## a turning snowflake (cold snap) or a falling meteor (shower).
class HazardIcon:
	extends Control
	var color := UiStyle.AMBER
	var kind: HazardDef.Kind = HazardDef.Kind.STORM
	## 0: still (warning), 1: blowing.
	var spin := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta * (1.0 + 3.0 * spin)
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		match kind:
			HazardDef.Kind.COLD_SNAP:
				var c := size * 0.5
				var r := minf(w, h) * 0.48
				for i in 3:
					var a := _t * 0.6 + i * PI / 3.0
					var d := Vector2(cos(a), sin(a)) * r
					draw_line(c - d, c + d, color, 2.0, true)
					for e: float in [-1.0, 1.0]:
						var tip: Vector2 = c + d * e * 0.62
						var back := -d.normalized() * e * r * 0.28
						draw_line(tip, tip + back.rotated(0.8), color, 1.5, true)
						draw_line(tip, tip + back.rotated(-0.8), color, 1.5, true)
			HazardDef.Kind.METEORS:
				var k := fmod(_t * 0.8, 1.0)
				var at := Vector2(w * (0.75 - 0.35 * k), h * (0.25 + 0.4 * k))
				for i in 3:
					var off := Vector2(1, -1).normalized() * (5.0 + i * 3.0)
					draw_line(at + off.rotated((i - 1) * 0.35) * 0.5, at + off.rotated((i - 1) * 0.35) * 1.5, Color(color, 0.8 - i * 0.2), 1.5, true)
				draw_circle(at, minf(w, h) * 0.2, color)
				draw_line(Vector2(w * 0.1, h * 0.95), Vector2(w * 0.9, h * 0.95), Color(color, 0.6), 1.5, true)
			_:
				for i in 3:
					var y := h * (0.25 + 0.25 * i)
					var pts := PackedVector2Array()
					var len := w * (0.95 - 0.2 * absf(i - 1.0))
					for k in 9:
						var x := len * k / 8.0
						pts.append(Vector2(x, y + sin(x * 0.45 + _t * 4.0 + i) * 1.6))
					draw_polyline(pts, color, 2.0, true)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiStyle.panel(999, 14, 8))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 120
	_toast.visible = false
	add_child(_toast)
	_toast_label = UiStyle.label("", UiStyle.DISPLAY, 15, UiStyle.GREEN)
	_toast.add_child(_toast_label)


func _overlay() -> Array:
	var o := ColorRect.new()
	o.color = Color(12.0 / 255.0, 6.0 / 255.0, 9.0 / 255.0, 0.55)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	add_child(o)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel(10, 22, 22))
	card.custom_minimum_size.x = minf(400.0, get_viewport_rect().size.x - 32.0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	return [o, col]


func _paragraph(text: String) -> Label:
	var p := UiStyle.label(text, UiStyle.MONO, 13, UiStyle.MUTE)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size.x = 300
	return p


func _build_menu() -> Control:
	var parts := _overlay()
	var col: VBoxContainer = parts[1]
	col.add_child(UiStyle.label("Colony log", UiStyle.DISPLAY_BOLD, 26, UiStyle.INK))
	col.add_child(_paragraph("Drag anywhere to walk, or use WASD / arrow keys. Stand on a pad to use it. Progress saves automatically."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for key in ["drones", "delivered", "pack", "boots", "colonists", "food"]:
		var cell := PanelContainer.new()
		var st := UiStyle.panel(8, 8, 8, Color(0, 0, 0, 0))
		cell.add_theme_stylebox_override("panel", st)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		cell.add_child(v)
		var names := {"drones": "Drones", "delivered": "Delivered", "pack": "Pack size", "boots": "Boots", "colonists": "Colonists", "food": "Food store"}
		v.add_child(UiStyle.label(names[key], UiStyle.MONO, 12, UiStyle.MUTE))
		var val := UiStyle.label("0", UiStyle.MONO_SEMI, 17, UiStyle.INK)
		v.add_child(val)
		_menu_stats[key] = val
		grid.add_child(cell)
	var btns := HFlowContainer.new()
	btns.add_theme_constant_override("h_separation", 8)
	btns.add_theme_constant_override("v_separation", 8)
	col.add_child(btns)
	var back := UiStyle.button("Back to the colony", true)
	back.pressed.connect(close_menu)
	btns.add_child(back)
	_reset_button = UiStyle.button("Restart planet", false, true)
	_reset_button.pressed.connect(_on_reset)
	btns.add_child(_reset_button)
	var more := HFlowContainer.new()
	more.add_theme_constant_override("h_separation", 8)
	more.add_theme_constant_override("v_separation", 8)
	col.add_child(more)
	var settings := UiStyle.button("Settings")
	settings.pressed.connect(func(): _settings.visible = true)
	more.add_child(settings)
	var backup := UiStyle.button("Back up save")
	backup.pressed.connect(_on_backup)
	more.add_child(backup)
	var restore := UiStyle.button("Restore save")
	restore.pressed.connect(_on_restore)
	more.add_child(restore)
	_star_map_button = UiStyle.button("Star map")
	_star_map_button.visible = false
	_star_map_button.pressed.connect(func(): star_map_requested.emit())
	more.add_child(_star_map_button)
	var switch := UiStyle.button("Switch explorer")
	switch.pressed.connect(func(): title_requested.emit())
	more.add_child(switch)
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.visible = false
	return parts[0]


func _on_backup() -> void:
	GameState.save()
	TextPrompt.show_copyable(self, "Copy this text and keep it somewhere safe:", SaveManager.export_text(GameState.sim.state))


func _on_restore() -> void:
	TextPrompt.ask(self, "Paste a backed-up save (this replaces the current game):", "", func(text):
		if text == null or String(text).strip_edges() == "":
			return
		var state := SaveManager.import_text(text)
		if state == null:
			show_toast("That doesn't look like a save")
			return
		_menu.visible = false
		restore_requested.emit(state))


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Tap again to wipe this planet"
		return
	_menu.visible = false
	restart_requested.emit()


func _build_win() -> Control:
	var parts := _overlay()
	var col: VBoxContainer = parts[1]
	col.add_child(UiStyle.label("TERRAFORMING COMPLETE", UiStyle.DISPLAY_WIDE, 11, UiStyle.MUTE))
	_win_title = UiStyle.label("", UiStyle.DISPLAY_BOLD, 26, UiStyle.INK)
	_win_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_win_title)
	_win_body = _paragraph("")
	col.add_child(_win_body)
	_bonus_title = UiStyle.label("PICK A BONUS", UiStyle.DISPLAY_WIDE, 11, UiStyle.AMBER)
	col.add_child(_bonus_title)
	_bonus_cards = VBoxContainer.new()
	_bonus_cards.add_theme_constant_override("separation", 8)
	col.add_child(_bonus_cards)
	var btns := HFlowContainer.new()
	btns.add_theme_constant_override("h_separation", 8)
	btns.add_theme_constant_override("v_separation", 8)
	col.add_child(btns)
	_launch_button = UiStyle.button("To the star map", true)
	_launch_button.pressed.connect(func(): star_map_requested.emit())
	btns.add_child(_launch_button)
	var stay := UiStyle.button("Stay here")
	stay.pressed.connect(func():
		_win.visible = false
		stay_requested.emit())
	btns.add_child(stay)
	return parts[0]
