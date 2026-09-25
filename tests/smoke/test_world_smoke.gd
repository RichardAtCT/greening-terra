extends GutTest
## Loads the planet scene and runs it for a while without errors.


func before_each() -> void:
	# Never touch a real profile from tests.
	SaveManager.active_profile = 99
	GameState.sim = null
	GameState.start(GameSim.new_planet_state(GameState.defs, 0))


func after_each() -> void:
	Audio.stop_all()
	DirAccess.remove_absolute(SaveManager.profile_path(99))


func test_planet_runs_and_player_walks_with_joystick() -> void:
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	var player: PlayerController = world.get_node("Player")
	var joystick: TouchJoystick = world.get_node("UI/Joystick")
	var start := player.global_position
	joystick.value = Vector2(1, 0)
	await wait_physics_frames(30)
	assert_gt(player.global_position.x, start.x + 1.0, "player moved right")
	joystick.release()


func test_planet_with_haulers_runs_60_seconds() -> void:
	var s := GameSim.new_planet_state(GameState.defs, 0)
	for id in [&"electrolyser", &"greenhouse", &"bay"]:
		s.built[id] = true
	s.drones = 4
	GameState.start(s)
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	await wait_frames(2)
	# Step the sim fast-forward through the scene's own update path.
	for i in 600:
		world._process(0.1)
	assert_gt(GameState.sim.state.stat(&"produced_plate"), 0)
	assert_eq(world.get_node("Player").get_class(), "CharacterBody3D")


func test_colony_lander_and_storm_run_through_the_scene() -> void:
	var s := GameSim.new_planet_state(GameState.defs, 0)
	for id in [&"electrolyser", &"greenhouse", &"bay"]:
		s.built[id] = true
	s.drones = 3
	# Two landers due at once, and a storm about to start.
	s.terraform = 26.0
	s.hazard_phase = HazardDirector.Phase.WARNING
	s.hazard_t = 3.0
	GameState.start(s)
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	await wait_frames(2)
	# The scene caps each step at 0.05 s: this is 40 s of play.
	for i in 800:
		world._process(0.1)
	var sim := GameState.sim
	assert_eq(sim.state.landers, 2)
	assert_eq(sim.colonists.size(), 4)
	assert_eq(sim.state.hazard_count, 1, "the storm came and went")
	assert_true(sim.state.is_built(&"habitat_1"))
	var colony: ColonyView = world.get_node("Colony")
	var shown := 0
	for c in colony.get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("Look"):
			shown += (c as MultiMeshInstance3D).multimesh.visible_instance_count
	assert_eq(shown, 4, "every colonist is drawn")


func test_debug_overlay_toggles_and_describes_jobs() -> void:
	var s := GameSim.new_planet_state(GameState.defs, 0)
	s.built[&"bay"] = true
	s.drones = 2
	GameState.start(s)
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	await wait_frames(2)
	var overlay: DebugOverlay = world.get_node("Debug")
	var was: bool = SaveManager.settings.get("debug_overlay", false)
	overlay.set_shown(false)
	SaveManager.settings["debug_overlay"] = false
	overlay.toggle()
	assert_true(overlay.visible)
	for i in 5:
		world._process(0.1)
	var text := DebugOverlay.describe(GameState.sim)
	assert_string_contains(text, "haulers: 2 field")
	assert_string_contains(text, "#1 field regolith")
	overlay.toggle()
	assert_false(overlay.visible)
	SaveManager.set_setting("debug_overlay", was)


func test_title_screen_loads_and_lists_three_profiles() -> void:
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child_autofree(title)
	await wait_frames(2)
	var names := 0
	for l in title.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Explorer") or (l as Label).text == SaveManager.profile_name(1):
			names += 1
	assert_gte(names, 3)


func test_orrin_and_kessik_run_through_their_hazards() -> void:
	for index in [1, 2]:
		var defs := GameState.defs
		var s := GameSim.new_planet_state(defs, index)
		for m in defs.planet(index).machines:
			s.built[m.id] = true
		s.built[&"bay"] = true
		s.drones = 4
		s.terraform = 30.0
		s.toxicity = 20.0
		s.hazard_phase = HazardDirector.Phase.WARNING
		s.hazard_t = 2.0
		GameState.start(s)
		var sim := GameState.sim
		if sim.planet.hazard.kind == HazardDef.Kind.METEORS:
			s.impacts = HazardDirector.impact_points(sim)
		var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
		add_child(world)
		await wait_frames(2)
		# 60 s of play (the scene caps each step at 0.05 s).
		for i in 1200:
			world._process(0.1)
		assert_eq(sim.state.hazard_count, 1, "%s: the hazard came and went" % sim.planet.display_name)
		assert_gt(sim.state.stat(&"produced_plate"), 0)
		if sim.planet.hazard.kind == HazardDef.Kind.METEORS:
			assert_eq(sim.state.damaged.size(), 1, "a meteor hit a machine")
		else:
			assert_gt(sim.state.stat(&"heat"), 0, "haulers fed the heat towers")
		world.free()
		await wait_frames(1)


func test_win_screen_offers_bonuses_then_the_star_map() -> void:
	var s := GameSim.new_planet_state(GameState.defs, 0)
	s.growth = 99.999
	s.terraform = 99.999
	GameState.start(s)
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	await wait_frames(2)
	GameState.sim.deliver_item(&"seedpod", Vector3.ZERO)
	world._process(0.05)
	assert_true(GameState.sim.state.won)
	var offer := Bonuses.offer(GameState.defs, GameState.sim.state)
	assert_eq(offer.size(), 3)
	var hud: Hud = world.get_node("UI/Hud")
	hud.bonus_picked.emit(offer[2].id)
	assert_true(GameState.sim.state.bonus_picked)
	assert_eq(GameState.sim.state.bonuses, [offer[2].id] as Array[StringName])


func test_star_map_waits_for_the_bonus_then_launches() -> void:
	var s := GameSim.new_planet_state(GameState.defs, 0)
	s.terraform = 100.0
	s.won = true
	GameState.start(s)
	var map: StarMap = load(StarMap.SCENE).instantiate()
	add_child_autofree(map)
	await wait_frames(2)
	assert_false(map._launch.visible, "pick a bonus first")
	s.bonus_picked = true
	map._refresh()
	assert_true(map._launch.visible)
	map._on_launch()
	for i in 10:
		map._process(0.1)
	assert_between(map._flight, 0.3, 0.6, "the rocket is on its way")
