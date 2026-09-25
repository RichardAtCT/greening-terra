extends Node3D
## The playable planet: builds the world from the planet's data, steps the GameSim with the
## player's position every frame, and mirrors the sim's state into visuals and the HUD.

@onready var _env: WorldEnvironment = $Environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _player: PlayerController = $Player
@onready var _camera: FollowCamera = $Camera
@onready var _hud: Hud = $UI/Hud
@onready var _joystick: TouchJoystick = $UI/Joystick

var defs: GameDefs
var sim: GameSim

var _terraform: TerraformView
var _flyers: FlyerLayer
var _guide: GuideMarker
var _pads: Array[PadView] = []
var _nodes: Array[ResourceNodeView] = []
var _machines: Dictionary = {}
var _hub: BuildingView
var _bay: BuildingView
var _outfitter: BuildingView
var _drones: Array[DroneView] = []
var _player_stack: ItemStackView
var _shown_tf := 0.0
var _paused := false
var _time := 0.0
var _save_t := 0.0
var _visibility_cb: JavaScriptObject


func _ready() -> void:
	GameState.ensure_started()
	defs = GameState.defs
	sim = GameState.sim
	var rng := RandomNumberGenerator.new()
	rng.seed = sim.planet.seed

	_env.environment = _env.environment.duplicate()
	_terraform = TerraformView.new()
	_terraform.name = "Terrain"
	_terraform.environment = _env.environment
	_terraform.sun = _sun
	add_child(_terraform)
	_terraform.build(defs, sim.planet, rng)

	_build_buildings()
	_build_nodes(rng)
	for p in sim.pads:
		var pv := PadView.new()
		add_child(pv)
		pv.setup(p)
		_pads.append(pv)

	_flyers = FlyerLayer.new()
	_flyers.defs = defs
	_flyers.fly_time = defs.tuning.fly_time
	_flyers.arc_height = defs.tuning.fly_arc
	add_child(_flyers)
	_guide = GuideMarker.new()
	add_child(_guide)

	_player.joystick = _joystick
	_player.global_position = Vector3(sim.state.player_position.x, 0, sim.state.player_position.y)
	_player.reset_physics_interpolation()
	_camera.snap_to_target()
	_player_stack = _player.get_node("Model/Stack")
	_player_stack.defs = defs
	_player_stack.column_size = defs.tuning.stack_column_size
	_player_stack.show_items(sim.state.stack)

	for d in sim.drones:
		_add_drone_view(d)

	sim.item_flew.connect(_on_item_flew)
	sim.stack_changed.connect(func(): _player_stack.show_items(sim.state.stack))
	sim.node_dug.connect(func(i): _nodes[i].dug())
	sim.drone_added.connect(_add_drone_view)
	EventBus.planet_won.connect(_on_won)

	_joystick.blocker = _hud.blocks_touch
	_hud.menu_opened.connect(func(): _set_paused(true))
	_hud.menu_closed.connect(func(): _set_paused(false))
	_hud.restart_requested.connect(func(): _travel(GameState.restart_planet))
	_hud.launch_requested.connect(func(): _travel(GameState.next_planet))
	_hud.stay_requested.connect(func(): _set_paused(false))

	_shown_tf = sim.state.terraform
	_terraform.apply(_shown_tf, 0.0, true, _player.global_position)
	_setup_web_visibility_save()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += dt
	if not _paused:
		sim.step(dt, _player.ground_position())
	_player.move_speed = sim.move_speed()

	var p := _player.global_position
	for i in _nodes.size():
		_nodes[i].update_view(sim.state.node_stock[i], sim.nodes[i].max_stock, dt)
	for pv in _pads:
		var vis := sim.pad_visible(pv.info)
		pv.visible = vis
		pv.set_near(vis and Vector2(p.x, p.z).distance_to(pv.info.position) < defs.tuning.pad_radius)
	_update_buildings()
	for dv in _drones:
		dv.update_view(dt)

	_shown_tf += (sim.state.terraform - _shown_tf) * minf(1.0, dt * defs.terraform.display_rate)
	_terraform.apply(_shown_tf, dt, false, p)

	var step := Tutorial.current(sim.tutorial_steps(), sim.state)
	_guide.update_guide(step != null and step.has_target, step.target if step else Vector2.ZERO, Vector2(p.x, p.z), dt)
	_hud.update_hud(sim, _shown_tf, dt)

	_save_t += dt
	if _save_t >= defs.tuning.autosave_interval:
		_save_t = 0.0
		GameState.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if sim:
			GameState.save()


func _set_paused(paused: bool) -> void:
	_paused = paused
	_player.controls_enabled = not paused
	if paused:
		_joystick.release()


func _travel(action: Callable) -> void:
	_hud.hide_win()
	action.call()
	get_tree().reload_current_scene()


func _on_won() -> void:
	_set_paused(true)
	var next_name := GameSim.planet_display_name(defs, sim.state.planet_index + 1)
	_hud.show_win(sim.planet_name(), next_name, sim.planet.win_text)


func _on_item_flew(item: StringName, from: Vector3, to: Vector3) -> void:
	# Items leaving the player start from the real top of the back stack.
	if from.y == GameSim.PLAYER_STACK_HEIGHT and Vector2(from.x, from.z).distance_to(_player.ground_position()) < 0.01:
		from = _player.stack_top()
	_flyers.launch(item, from, to)


func _add_drone_view(d: DroneBrain.Drone) -> void:
	var dv := DroneView.new()
	add_child(dv)
	dv.setup(d, defs)
	_drones.append(dv)


func _build_nodes(rng: RandomNumberGenerator) -> void:
	for rn in sim.planet.resource_nodes:
		for pos in rn.positions:
			var nv := ResourceNodeView.new()
			add_child(nv)
			nv.setup(rn, pos, rng)
			_nodes.append(nv)


func _build_buildings() -> void:
	var planet := sim.planet
	_hub = BuildingView.new()
	add_child(_hub)
	_hub.setup(preload("res://scenes/buildings/hub.tscn"), planet.hub_position, planet.hub_collide_radius, 4.6, 3.6)
	for m in planet.machines:
		var bv := BuildingView.new()
		add_child(bv)
		bv.setup(m.scene, m.position, m.collide_radius, m.label_height, 3.9)
		bv.add_ghost(m.footprint)
		bv.add_pad_stacks(defs, m.in_pad_offset, m.out_pad_offset)
		_machines[m.id] = bv
	_bay = BuildingView.new()
	add_child(_bay)
	_bay.setup(preload("res://scenes/buildings/drone_bay.tscn"), planet.bay_position, planet.bay_collide_radius, 3.4, 3.9)
	_bay.add_ghost(Vector3(3.2, 2.2, 3.0))
	_outfitter = BuildingView.new()
	add_child(_outfitter)
	_outfitter.setup(preload("res://scenes/buildings/outfitter.tscn"), planet.outfitter_position, planet.outfitter_collide_radius, 3.2, 4.2)


func _update_buildings() -> void:
	var s := sim.state
	var muted := Color("bca99b")
	for m in sim.planet.machines:
		var bv: BuildingView = _machines[m.id]
		var built := s.is_built(m.id)
		bv.set_built(built)
		if not built:
			bv.label.set_text(m.display_name, "₵ %d / %d" % [s.paid.get(StringName("build_" + m.id), 0), m.build_cost])
			continue
		var busy: bool = s.busy.get(m.id, 0.0) > 0.0
		bv.set_glow(0.65 + 0.3 * sin(_time * 10.0) if busy else 0.22)
		var outs: int = s.outputs.get(m.id, 0)
		var queue_text := ""
		if m.recipe.inputs.size() > 1:
			var parts := PackedStringArray()
			for item in m.recipe.inputs:
				parts.append("%d %s" % [s.queued(m.id, item), defs.item(item).display_name])
			queue_text = " · ".join(parts)
		else:
			var total := 0
			for item in m.recipe.inputs:
				total += s.queued(m.id, item)
			queue_text = "%d in" % total
		bv.label.set_text(m.display_name, "%s · %d out" % [queue_text, outs], Color("86e07c") if busy else muted)
		var in_items: Array[StringName] = []
		for item in m.recipe.inputs:
			for k in s.queued(m.id, item):
				in_items.append(item)
		bv.in_stack.show_items(in_items)
		var out_items: Array[StringName] = []
		for k in mini(outs, defs.tuning.pad_stack_max):
			out_items.append(m.recipe.output)
		bv.out_stack.show_items(out_items)

	var bay_built := s.is_built(&"bay")
	_bay.set_built(bay_built)
	if not bay_built:
		_bay.label.set_text("Drone Bay", "₵ %d / %d" % [s.paid.get(&"build_bay", 0), sim.planet.bay_cost])
	elif s.drones >= sim.planet.max_drones:
		_bay.label.set_text("Drone Bay", "%d haulers · max" % s.drones)
	else:
		var paid: int = s.paid.get(&"buy_drone", 0)
		var next_cost := Economy.drone_cost(defs, s.drones, sim.planet.max_drones)
		var txt := "%d hauler%s · next ₵%d" % [s.drones, "s" if s.drones > 1 else "", next_cost]
		if paid > 0:
			txt += " (%d paid)" % paid
		_bay.label.set_text("Drone Bay", txt)
	var pack_cost := Economy.upgrade_cost(defs.pack_upgrade, s.pack_level)
	var boots_cost := Economy.upgrade_cost(defs.boots_upgrade, s.boots_level)
	_outfitter.label.set_text("Outfitter", "Pack %s · Boots %s" % [
		"max" if pack_cost < 0 else "₵%d" % pack_cost, "max" if boots_cost < 0 else "₵%d" % boots_cost])
	var pay := sim.planet.pay_multiplier
	_hub.label.set_text("Colony Hub", "×%.1f pay" % pay if s.planet_index > 0 else "sells plates, O₂, pods", Color("86e07c"))
	_hub.set_glow(0.4 + 0.6 * (1.0 if sin(_time * 3.0) > 0.0 else 0.0))


func _setup_web_visibility_save() -> void:
	if not OS.has_feature("web"):
		return
	# Save when the tab is hidden (switching apps on iPhone), as the page may be killed afterwards.
	_visibility_cb = JavaScriptBridge.create_callback(func(_args):
		if JavaScriptBridge.eval("document.hidden", true):
			GameState.save())
	var doc := JavaScriptBridge.get_interface("document")
	doc.addEventListener("visibilitychange", _visibility_cb)

