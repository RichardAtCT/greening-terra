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
var _node_batch: NodeBatch
var _labels: LabelLayer
var _effects: PlanetEffects
var _frost_mat: ShaderMaterial
var _soot_mat: StandardMaterial3D
var _machines: Dictionary = {}
var _hub: BuildingView
var _bay: BuildingView
var _outfitter: BuildingView
var _drones: DroneSwarm
var _colony: ColonyView
var _habitats: Array[BuildingView] = []
var _debug: DebugOverlay
var _player_stack: ItemStackView
var _shown_tf := 0.0
var _paused := false
var _time := 0.0
var _save_t := 0.0
var _stack_count := 0
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

	_labels = LabelLayer.new()
	_labels.name = "Labels"
	_labels.camera = _camera
	$UI.add_child(_labels)
	$UI.move_child(_labels, 0)
	_build_buildings()
	_build_nodes(rng)
	for p in sim.pads:
		var pv := PadView.new()
		add_child(pv)
		pv.setup(p)
		_pads.append(pv)
	var batch := PadBatch.new()
	batch.name = "PadBatch"
	add_child(batch)
	batch.setup(_pads, defs)

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
	_stack_count = sim.state.stack.size()

	_drones = DroneSwarm.new()
	_drones.name = "Drones"
	add_child(_drones)
	_drones.setup(defs, sim.planet.max_drones)
	for d in sim.drones:
		_drones.add(d)
	_colony = ColonyView.new()
	_colony.name = "Colony"
	add_child(_colony)
	_colony.setup(sim)
	_effects = PlanetEffects.new()
	_effects.name = "Effects"
	add_child(_effects)
	_effects.setup(sim)
	_frost_mat = ShaderMaterial.new()
	_frost_mat.shader = preload("res://shaders/frost_overlay.gdshader")
	_frost_mat.set_shader_parameter("frost_color", sim.planet.frost_color)
	_soot_mat = ItemVisuals.unshaded(Color(Color("1c1412"), 0.5))
	_debug = DebugOverlay.new()
	_debug.name = "Debug"
	add_child(_debug)
	_debug.setup(sim, _hud)

	sim.item_flew.connect(_on_item_flew)
	sim.stack_changed.connect(_on_stack_changed)
	sim.node_dug.connect(_on_node_dug)
	sim.drone_added.connect(_drones.add)
	sim.lander_coming.connect(func(): Audio.play(&"lander"))
	sim.lander_landed.connect(func(_n):
		_colony.landed()
		Audio.play(&"land"))
	sim.food_stored.connect(func(_item): Audio.play(&"food"))
	sim.hazard_changed.connect(_on_hazard_changed)
	sim.meteors_landed.connect(_on_meteors_landed)
	sim.machine_repaired.connect(func(_id): Audio.play(&"repair"))
	EventBus.planet_won.connect(_on_won)
	EventBus.credits_earned.connect(_on_credits)
	EventBus.purchased.connect(_on_purchased)

	_joystick.blocker = _hud.blocks_touch
	_hud.menu_opened.connect(func(): _set_paused(true))
	_hud.menu_closed.connect(func(): _set_paused(false))
	_hud.restart_requested.connect(func(): _travel(GameState.restart_planet))
	_hud.star_map_requested.connect(_open_star_map)
	_hud.bonus_picked.connect(func(id: StringName):
		if Bonuses.pick(defs, sim.state, id):
			GameState.save()
			_hud.show_win(sim, false))
	_hud.stay_requested.connect(func(): _set_paused(false))
	_hud.title_requested.connect(func():
		Audio.stop_ambience()
		GameState.save()
		GameState.sim = null
		get_tree().change_scene_to_file("res://scenes/ui/title.tscn"))
	_hud.restore_requested.connect(func(state: WorldState):
		_travel(func():
			GameState.start(state)
			GameState.save()))

	_shown_tf = sim.state.terraform
	_terraform.apply(_shown_tf, 0.0, true, _player.global_position)
	_setup_web_visibility_save()
	# Scenes load after the title's Start tap, so iOS already allows audio here.
	Audio.set_terraform(_shown_tf)
	Audio.start_ambience()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += dt
	if not _paused:
		sim.step(dt, _player.ground_position())
	_player.move_speed = sim.move_speed()

	var p := _player.global_position
	for i in _nodes.size():
		_nodes[i].update_view(sim.state.node_stock[i], sim.nodes[i].max_stock, dt)
	_node_batch.update_view()
	for pv in _pads:
		var vis := sim.pad_visible(pv.info)
		pv.visible = vis
		if vis and sim.shows_cost(pv.info):
			pv.set_label(sim.upgrade_pad_label(pv.info))
		# A pay pad dims while it rests after a purchase, so the player sees it's done.
		pv.set_near(vis and not sim.pad_resting(pv.info) and Vector2(p.x, p.z).distance_to(pv.info.position) < defs.tuning.pad_radius)
	_update_buildings()
	_drones.hauler_level = sim.state.hauler_level
	_drones.update_view(dt)
	_colony.update_view(dt)
	_effects.update_view(dt)

	_shown_tf += (sim.state.terraform - _shown_tf) * minf(1.0, dt * defs.terraform.display_rate)
	var storm := HazardDirector.intensity(sim)
	_terraform.apply(_shown_tf, dt, false, p, storm)
	Audio.set_terraform(_shown_tf)
	Audio.set_storm(storm)

	var step := Tutorial.current(sim.tutorial_steps(), sim.state)
	_guide.update_guide(step != null and step.has_target, step.target if step else Vector2.ZERO, Vector2(p.x, p.z), dt)
	_hud.update_hud(sim, _shown_tf, dt)

	# Real time, not the capped sim step, so slow devices still autosave on schedule.
	_save_t += delta
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
	Audio.play(&"win")
	_hud.show_win(sim)


## The star map (SPEC 3) replaces the old direct "Launch to …": the rocket flies from there.
## A finished planet's bonus is picked first (the win screen offers it again if it was skipped).
func _open_star_map() -> void:
	if sim.state.won and not sim.state.bonus_picked and not Bonuses.offer(defs, sim.state).is_empty():
		_hud.close_menu()
		_set_paused(true)
		_hud.show_win(sim, false)
		return
	_hud.hide_win()
	GameState.save()
	Audio.stop_ambience()
	get_tree().change_scene_to_file(StarMap.SCENE)


func _on_stack_changed() -> void:
	var n := sim.state.stack.size()
	_player_stack.show_items(sim.state.stack)
	if n > _stack_count:
		_player_stack.pop()
		# The pick-up climbs in pitch as the stack grows.
		var j := defs.juice
		Audio.play(&"pickup", minf(1.0 + j.pickup_pitch_step * n, j.pickup_pitch_max))
	elif n < _stack_count:
		Audio.play(&"drop")
	_stack_count = n


func _on_node_dug(i: int) -> void:
	_nodes[i].dug()
	if _nodes[i].global_position.distance_to(_player.global_position) < defs.juice.dig_hearing_radius:
		Audio.play(&"dig")


func _on_credits(_amount: float) -> void:
	Audio.play(&"coin")


func _on_purchased(key: StringName) -> void:
	if String(key).begins_with("build_"):
		Audio.play(&"build")
		_camera.nudge()
	else:
		Audio.play(&"upgrade")


func _on_item_flew(item: StringName, from: Vector3, to: Vector3) -> void:
	# Items leaving the player start from the real top of the back stack.
	if from.y == GameSim.PLAYER_STACK_HEIGHT and Vector2(from.x, from.z).distance_to(_player.ground_position()) < 0.01:
		from = _player.stack_top()
	_flyers.launch(item, from, to)


func _on_hazard_changed(phase: HazardDirector.Phase) -> void:
	if phase == HazardDirector.Phase.WARNING:
		Audio.play(sim.planet.hazard.warning_sound)


func _on_meteors_landed(points: Array[Vector2], _hit: Array[StringName]) -> void:
	Audio.play(sim.planet.hazard.impact_sound)
	_effects.impact(points)
	_camera.nudge()


func _build_nodes(rng: RandomNumberGenerator) -> void:
	for rn in sim.planet.resource_nodes:
		for pos in rn.positions:
			var nv := ResourceNodeView.new()
			add_child(nv)
			nv.setup(rn, pos, rng)
			_nodes.append(nv)
	_node_batch = NodeBatch.new()
	_node_batch.name = "NodeBatch"
	add_child(_node_batch)
	_node_batch.setup(_nodes)


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
	for pos in planet.habitat_positions:
		var hv := BuildingView.new()
		add_child(hv)
		hv.setup(preload("res://scenes/buildings/habitat.tscn"), pos, planet.habitat_collide_radius, 2.9, 3.4)
		hv.add_ghost(Vector3(2.8, 1.4, 2.4))
		_habitats.append(hv)


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
		var busy: bool = s.busy.get(m.id, 0.0) > 0.0 and not s.is_damaged(m.id)
		bv.set_glow(0.65 + 0.3 * sin(_time * 10.0) if busy else 0.22)
		var outs: int = s.outputs.get(m.id, 0)
		var title := sim.machine_title(m)
		var frozen := HazardDirector.is_frozen(sim, m)
		if s.is_damaged(m.id):
			var h := sim.planet.hazard
			bv.label.set_text(title, "damaged · repair %d/%d" % [s.repairs.get(m.id, 0), h.repair_cost], Color("ff6a4a"))
			bv.set_overlay(_soot_mat)
			bv.set_smoking(true)
		elif m.is_heat_tower():
			var fuel := s.queued(m.id, m.recipe.inputs.keys()[0])
			bv.label.set_text(title, ("warm · %d polymer" % fuel) if busy else "cold · needs polymer",
				PlanetEffects.HEAT_COLOR if busy else muted)
			bv.set_glow(0.75 + 0.25 * sin(_time * 4.0) if busy else 0.1)
		else:
			var queue_text := ""
			if m.recipe.inputs.size() > 2:
				var counts := PackedStringArray()
				for item in m.recipe.inputs:
					counts.append(str(s.queued(m.id, item)))
				queue_text = "/".join(counts) + " in"
			elif m.recipe.inputs.size() > 1:
				var parts := PackedStringArray()
				for item in m.recipe.inputs:
					parts.append("%d %s" % [s.queued(m.id, item), defs.item(item).display_name])
				queue_text = " · ".join(parts)
			else:
				var total := 0
				for item in m.recipe.inputs:
					total += s.queued(m.id, item)
				queue_text = "%d in" % total
			if frozen:
				bv.label.set_text(title, "frozen · %s · %d out" % [queue_text, outs], sim.planet.frost_color)
			else:
				bv.label.set_text(title, "%s · %d out" % [queue_text, outs], Color("86e07c") if busy else muted)
		if not s.is_damaged(m.id):
			bv.set_smoking(false)
			bv.set_overlay(_frost_mat if frozen else null)
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
		# At the cap, the next hauler upgrade is what's left to buy here.
		var up := sim.pad(&"upgrade_haulers")
		var up_cost := sim.pad_cost(up) if up else -1
		if up_cost > 0 and sim.pad_visible(up):
			_bay.label.set_text("Drone Bay", "%d haulers · upgrade ₵%d" % [s.drones, up_cost])
		else:
			_bay.label.set_text("Drone Bay", "%d haulers · carry %d" % [s.drones, sim.drone_capacity()])
	else:
		var paid: int = s.paid.get(&"buy_drone", 0)
		var next_cost := Economy.drone_cost(defs, s.drones, sim.planet.max_drones)
		var txt := "%d hauler%s · next ₵%d" % [s.drones, "s" if s.drones > 1 else "", next_cost]
		if paid > 0:
			txt += " (%d paid)" % paid
		_bay.label.set_text("Drone Bay", txt)
	# Each pad shows its own next cost; the label just says the kit comes with you.
	_outfitter.label.set_text("Outfitter", "kit that travels with you")
	_update_habitats()
	# Burning towers melt the frost round them; frozen machines frost over with the snap.
	var warm := []
	for m in sim.planet.machines:
		if sim.is_warm(m):
			warm.append(Vector3(m.position.x, m.position.y, m.heat_radius))
	_terraform.set_warm_spots(warm)
	_frost_mat.set_shader_parameter("amount", clampf(HazardDirector.intensity(sim), 0.0, 1.0))
	var pay := sim.planet.pay_multiplier
	var pay_text := "×%.1f pay" % (pay * sim.pay_factor()) if pay * sim.pay_factor() != 1.0 else "sells plates, O₂, pods"
	_hub.label.set_text("Colony Hub", pay_text, Color("86e07c"))
	_hub.set_glow(0.4 + 0.6 * (1.0 if sin(_time * 3.0) > 0.0 else 0.0))


func _update_habitats() -> void:
	var s := sim.state
	var planet := sim.planet
	var cap := Colony.habitat_capacity(sim)
	for i in _habitats.size():
		var hv := _habitats[i]
		var key := Colony.habitat_key(i)
		var built := s.is_built(key)
		# A habitat shows up (as a ghost) once it can be built: the first one waits for the first lander.
		var offered := built or i == 0 or s.is_built(Colony.habitat_key(i - 1))
		hv.visible = offered
		if not offered:
			continue
		hv.set_built(built)
		if built:
			# Only the built ones' residents count here, in build order.
			var k := 0
			for h in i:
				if s.is_built(Colony.habitat_key(h)):
					k += 1
			var living := clampi(s.meals.size() - k * cap, 0, cap)
			hv.label.set_text("Habitat", "%d/%d home" % [living, cap], Color("86e07c"))
			hv.set_glow(0.35 + 0.4 * float(living) / cap)
		elif i == 0:
			hv.label.set_text("Habitat", "first lander at %d%%" % roundi(planet.lander_milestones[0]) if not planet.lander_milestones.is_empty() else "")
		else:
			hv.label.set_text("Habitat", "₵ %d / %d" % [s.paid.get(StringName("build_" + key), 0), planet.habitat_costs[i]])


func _setup_web_visibility_save() -> void:
	if not OS.has_feature("web"):
		return
	# Save when the tab is hidden (switching apps on iPhone), as the page may be killed afterwards.
	_visibility_cb = JavaScriptBridge.create_callback(func(_args):
		if JavaScriptBridge.eval("document.hidden", true):
			GameState.save())
	var doc := JavaScriptBridge.get_interface("document")
	doc.addEventListener("visibilitychange", _visibility_cb)

