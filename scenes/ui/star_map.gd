class_name StarMap
extends Control
## The star map between planets (SPEC 3): the three worlds on a line, finished ones in green, the
## rocket parked at the current one. Once the current planet is terraformed, "Launch" flies the
## rocket along the line to the next world and lands there. The last world launches on to the
## start of the next round ("Tessera-4 II"), as before.

const SCENE := "res://scenes/ui/star_map.tscn"
const PLANET_SCENE := "res://scenes/world/planet.tscn"
const STAR_COUNT := 90

var defs: GameDefs
var state: WorldState

var _map: Control
var _launch: Button
var _back: Button
var _status: Label
var _stars: PackedVector3Array = []
var _time := 0.0
## -1 while parked; 0..1 while flying to the next world.
var _flight := -1.0


func _ready() -> void:
	GameState.ensure_started()
	defs = GameState.defs
	state = GameState.sim.state
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0e0a14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	add_child(_map)

	var insets := SafeArea.insets(get_window())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20 + insets.w
	col.offset_right = -20 - insets.y
	col.offset_top = 24 + insets.x
	col.offset_bottom = -20 - insets.z
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(UiStyle.label("STAR MAP", UiStyle.DISPLAY_WIDE, 11, UiStyle.MUTE))
	col.add_child(UiStyle.label("The Greening route", UiStyle.DISPLAY_BOLD, 26, UiStyle.INK))
	_status = UiStyle.label("", UiStyle.MONO, 13, UiStyle.MUTE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	if not state.bonuses.is_empty():
		col.add_child(UiStyle.label("BONUSES", UiStyle.DISPLAY_WIDE, 11, UiStyle.AMBER))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 6)
		chips.add_theme_constant_override("v_separation", 6)
		col.add_child(chips)
		for id in state.bonuses:
			var b := defs.bonus(id)
			if b == null:
				continue
			var chip := PanelContainer.new()
			var st := UiStyle.panel(999, 10, 4, Color(b.color, 0.16))
			st.border_color = Color(b.color, 0.6)
			chip.add_theme_stylebox_override("panel", st)
			chip.add_child(UiStyle.label(b.display_name, UiStyle.DISPLAY, 12, b.color.lerp(UiStyle.INK, 0.3)))
			chips.add_child(chip)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	col.add_child(row)
	_launch = UiStyle.button("Launch", true)
	_launch.pressed.connect(_on_launch)
	row.add_child(_launch)
	_back = UiStyle.button("Back to %s" % GameSim.planet_display_name(defs, state.planet_index))
	_back.pressed.connect(func(): get_tree().change_scene_to_file(PLANET_SCENE))
	row.add_child(_back)
	_refresh()


func _refresh() -> void:
	var here := GameSim.planet_display_name(defs, state.planet_index)
	var next := GameSim.planet_display_name(defs, state.planet_index + 1)
	_launch.visible = state.won
	_launch.text = "Launch to %s" % next
	if state.won:
		_status.text = "%s is breathing. Your pack, boots, dig speed and bonuses come with you; credits stay behind." % here
		_launch.grab_focus.call_deferred()
	else:
		_status.text = "Terraform %s to 100%% to launch to %s. (%.0f%% so far.)" % [here, next, state.terraform]
		_back.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if _flight >= 0.0:
		_flight += delta / defs.tuning.star_map_flight_time
		if _flight >= 1.0:
			_flight = 1.0
			set_process(false)
			GameState.next_planet()
			get_tree().change_scene_to_file(PLANET_SCENE)
	_map.queue_redraw()


func _on_launch() -> void:
	if _flight >= 0.0 or not state.won:
		return
	_flight = 0.0
	_launch.disabled = true
	_back.disabled = true
	Audio.play(&"lander")


## Where each of the three worlds sits: across the middle of the screen.
func _node_pos(i: int) -> Vector2:
	var s := _map.size
	var n := defs.planets.size()
	return Vector2(s.x * (0.18 + 0.64 * i / maxf(1.0, n - 1.0)), s.y * 0.5)


func _draw_map() -> void:
	var s := _map.size
	for st in _stars:
		var tw := 0.5 + 0.5 * sin(_time * (1.0 + st.z * 2.0) + st.z * 30.0)
		_map.draw_circle(Vector2(st.x * s.x, st.y * s.y), 0.6 + st.z * 1.1, Color(1, 1, 1, 0.25 + 0.5 * tw * st.z))
	var n := defs.planets.size()
	var cur := state.planet_index % n
	var cycle := state.planet_index / n
	for i in n - 1:
		_map.draw_dashed_line(_node_pos(i), _node_pos(i + 1), Color(UiStyle.INK, 0.35), 2.0, 8.0, true, true)
	for i in n:
		var p := defs.planets[i]
		var at := _node_pos(i)
		var done := i < cur or (i == cur and state.won)
		var r := 26.0 if i == cur else 20.0
		# Finished worlds show their green end colour; the rest their barren start.
		var body := p.sky_end.lerp(Color("5fae4a"), 0.55) if done else p.sky_mid.lerp(p.ground_start, 0.25)
		_map.draw_circle(at, r, body)
		_map.draw_arc(at, r * 0.72, -0.4, 1.2, 12, Color(1, 1, 1, 0.18), 3.0, true)
		if done:
			_map.draw_arc(at, r + 5.0, 0.0, TAU, 40, UiStyle.GREEN, 2.5, true)
		elif i == cur:
			_map.draw_arc(at, r + 5.0, 0.0, TAU, 40, Color(UiStyle.AMBER, 0.6 + 0.4 * sin(_time * 3.0)), 2.0, true)
		var name := GameSim.planet_display_name(defs, i + cycle * n)
		var font := UiStyle.DISPLAY
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_map.draw_string(font, at + Vector2(-w * 0.5, r + 24.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.INK)
		var tag := "TERRAFORMED" if done else ("HERE · %d%%" % floori(state.terraform) if i == cur else "AHEAD")
		var tw2 := UiStyle.MONO.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_map.draw_string(UiStyle.MONO, at + Vector2(-tw2 * 0.5, r + 40.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UiStyle.GREEN if done else (UiStyle.AMBER if i == cur else UiStyle.MUTE))
	_draw_rocket(cur, n)


## The rocket: parked just above the current world, or on its way to the next one.
func _draw_rocket(cur: int, n: int) -> void:
	var from := _node_pos(cur) + Vector2(0, -44)
	var to := _node_pos((cur + 1) % n) + Vector2(0, -44)
	var pos := from
	var ang := 0.0
	if _flight >= 0.0:
		var k := _flight * _flight * (3.0 - 2.0 * _flight)
		# An arc over the line (a loop back to the start after the last world).
		var mid := (from + to) * 0.5 + Vector2(0, -90 if cur + 1 < n else -160)
		pos = from.lerp(mid, k).lerp(mid.lerp(to, k), k)
		var ahead := from.lerp(mid, minf(1.0, k + 0.02)).lerp(mid.lerp(to, minf(1.0, k + 0.02)), minf(1.0, k + 0.02))
		ang = (ahead - pos).angle() + PI / 2
		for t in 6:
			var kk := maxf(0.0, k - t * 0.025)
			var trail := from.lerp(mid, kk).lerp(mid.lerp(to, kk), kk)
			_map.draw_circle(trail, 4.0 - t * 0.5, Color(Color("ffb04a"), 0.5 - t * 0.08))
	else:
		pos.y += sin(_time * 2.0) * 3.0
	_map.draw_set_transform(pos, ang)
	var body := PackedVector2Array([Vector2(0, -16), Vector2(6, -6), Vector2(6, 9), Vector2(-6, 9), Vector2(-6, -6)])
	_map.draw_colored_polygon(body, Color("e8e4dc"))
	_map.draw_colored_polygon(PackedVector2Array([Vector2(6, 3), Vector2(11, 12), Vector2(6, 9)]), Color("d9794a"))
	_map.draw_colored_polygon(PackedVector2Array([Vector2(-6, 3), Vector2(-11, 12), Vector2(-6, 9)]), Color("d9794a"))
	_map.draw_circle(Vector2(0, -4), 2.5, Color("8fe3ff"))
	if _flight >= 0.0:
		_map.draw_colored_polygon(PackedVector2Array([Vector2(-4, 9), Vector2(4, 9), Vector2(0, 18 + sin(_time * 40.0) * 3.0)]), Color("ffb04a"))
	_map.draw_set_transform_matrix(Transform2D.IDENTITY)
