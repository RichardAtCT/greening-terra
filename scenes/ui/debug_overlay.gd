class_name DebugOverlay
extends Node3D
## SPEC 4.5 debug overlay: a line for each hauler's current job (hauler → source → target,
## coloured by kind), a faint line from each colonist to where they're going, and a text panel
## with frame rate, draw calls, jobs, colony and hazard state. Toggle with F3 or the ` key, or
## with "Debug overlay" in Settings (saved as a setting, so it survives a reload).

const COLORS := {
	Dispatcher.Kind.FIELD: Color("f2b35b"),
	Dispatcher.Kind.FEED: Color("8fe3ff"),
	Dispatcher.Kind.SELL: Color("86e07c"),
}
const LINE_Y := 0.25

var sim: GameSim

var _mesh: ImmediateMesh
var _lines: MeshInstance3D
var _layer: CanvasLayer
var _text: Label
var _t := 0.0


func setup(p_sim: GameSim, _hud: Control = null) -> void:
	sim = p_sim
	_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 2
	_lines.material_override = mat
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(8, 10, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 12
	panel.offset_top = -40
	_layer.add_child(panel)
	_text = UiStyle.label("", UiStyle.MONO, 11, UiStyle.INK)
	panel.add_child(_text)
	set_shown(SaveManager.settings.get("debug_overlay", false))


func set_shown(on: bool) -> void:
	visible = on
	_layer.visible = on
	if not on:
		_mesh.clear_surfaces()


func toggle() -> void:
	var on := not visible
	SaveManager.set_setting("debug_overlay", on)
	set_shown(on)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_F3 or k.keycode == KEY_QUOTELEFT):
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		# Settings may have switched it on.
		if SaveManager.settings.get("debug_overlay", false):
			set_shown(true)
		return
	if not SaveManager.settings.get("debug_overlay", false):
		set_shown(false)
		return
	_draw_lines()
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		_text.text = describe(sim)


func _draw_lines() -> void:
	_mesh.clear_surfaces()
	var segs: Array = []
	for d in sim.drones:
		if d.job == null:
			continue
		var c: Color = COLORS[d.job.kind]
		var src := d.job.source_point(sim)
		var dst := d.job.target_point(sim)
		if d.state == DroneBrain.State.TO_SOURCE or d.state == DroneBrain.State.LOAD:
			segs.append([d.position, src, c.darkened(0.35)])
			segs.append([src, dst, c])
		else:
			segs.append([d.position, dst, c])
	for col in sim.colonists:
		if col.position.distance_to(col.target) > 0.1:
			segs.append([col.position, col.target, Color(1, 1, 1, 0.6)])
	# Meteor impact points: a cross at each.
	for p in sim.state.impacts:
		segs.append([p + Vector2(-1, -1), p + Vector2(1, 1), Color("ff4a3a")])
		segs.append([p + Vector2(-1, 1), p + Vector2(1, -1), Color("ff4a3a")])
	if segs.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for seg in segs:
		_line(seg[0], seg[1], seg[2])
	_mesh.surface_end()


func _line(a: Vector2, b: Vector2, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(Vector3(a.x, LINE_Y, a.y))
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(Vector3(b.x, LINE_Y, b.y))


## The panel text (also handy from tests and tools).
static func describe(s: GameSim) -> String:
	var lines := PackedStringArray()
	lines.append("%d fps · %d draw calls" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var kinds := {}
	var idle := 0
	for d in s.drones:
		if d.job:
			var k: String = Dispatcher.Kind.keys()[d.job.kind].to_lower()
			kinds[k] = kinds.get(k, 0) + 1
		else:
			idle += 1
	var parts := PackedStringArray()
	for k in kinds:
		parts.append("%d %s" % [kinds[k], k])
	if idle > 0:
		parts.append("%d idle" % idle)
	lines.append("haulers: " + (", ".join(parts) if not parts.is_empty() else "none"))
	for d in s.drones:
		if d.job:
			lines.append("  #%d %s (%d)" % [d.index + 1, d.job.describe(), d.cargo.size() + d.reserved])
	var st := s.state
	lines.append("colony: %d housed, %d waiting, %d landers, food %.0f/%d" % [
		st.housed, st.colonists_waiting, st.landers, st.food, Colony.lander_cost(s)])
	if s.planet.start_toxicity > 0.0:
		lines.append("toxicity %.1f%%, growth %.1f%% (shown %.1f%%)" % [st.toxicity, st.growth, st.terraform])
	var warm := PackedStringArray()
	for m in s.planet.machines:
		if m.is_heat_tower() and st.is_built(m.id):
			warm.append("%s %s" % [m.id.trim_prefix("heat_tower_"), "warm" if s.is_warm(m) else "cold"])
	if not warm.is_empty():
		lines.append("heat towers: " + ", ".join(warm))
	if not st.damaged.is_empty():
		lines.append("damaged: " + ", ".join(st.damaged.keys()))
	var h := s.planet.hazard
	if h:
		var phase: String = HazardDirector.Phase.keys()[st.hazard_phase].to_lower()
		var when := "%.0fs left" % st.hazard_t if st.hazard_phase != HazardDirector.Phase.NONE \
			else ("next in %.0fs" % st.hazard_wait if st.hazard_wait >= 0.0 else "off")
		lines.append("%s: %s, %s (%d so far)" % [h.display_name.to_lower(), phase, when, st.hazard_count])
	return "\n".join(lines)
