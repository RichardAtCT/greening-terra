extends GutTest
## M3 art pass: baked models, building node contracts, pad icons, audio data and the draw-call budget.

const MESHES := "res://assets/meshes/"
## SPEC 7.1 budget. The estimate below counts every visible surface, before frustum culling.
const DRAW_CALL_BUDGET := 150
## Building labels are drawn in 2D by LabelLayer: panels, titles and subtitles, one pass each.
const LABEL_LAYER_CALLS := 3


func before_each() -> void:
	SaveManager.active_profile = 99
	GameState.sim = null


func after_each() -> void:
	Audio.stop_all()
	DirAccess.remove_absolute(SaveManager.profile_path(99))


func test_baked_meshes_are_one_or_two_surfaces() -> void:
	var files := DirAccess.get_files_at(MESHES)
	assert_gt(files.size(), 10)
	for f in files:
		if not f.ends_with(".res"):
			continue
		var m: Mesh = load(MESHES + f)
		assert_between(m.get_surface_count(), 1, 2, f)


func test_buildings_keep_their_glow_nodes() -> void:
	for scene in ["smelter", "electrolyser", "greenhouse", "drone_bay"]:
		var n: Node = load("res://scenes/buildings/%s.tscn" % scene).instantiate()
		assert_not_null(n.get_node_or_null("Glow"), scene)
		var glow: MeshInstance3D = n.get_node("Glow")
		assert_true(glow.mesh.surface_get_material(0) is StandardMaterial3D, scene)
		n.free()
	var hub: Node = load("res://scenes/buildings/hub.tscn").instantiate()
	assert_not_null(hub.get_node_or_null("Blink"))
	hub.free()


func test_player_keeps_stack_and_leg_contract() -> void:
	var p: PlayerController = load("res://scenes/actors/player.tscn").instantiate()
	assert_true(p.get_node("Model/Stack") is ItemStackView)
	assert_not_null(p.body)
	assert_not_null(p.leg_left)
	assert_not_null(p.leg_right)
	p.free()


func test_pads_carry_item_icons() -> void:
	var sim := GameSim.new(GameState.defs, GameSim.new_planet_state(GameState.defs, 0))
	assert_eq(sim.pad(&"in_smelter").icons, [&"regolith"] as Array[StringName])
	assert_eq(sim.pad(&"out_smelter").icons, [&"plate"] as Array[StringName])
	assert_eq(sim.pad(&"in_greenhouse").icons.size(), 2)
	assert_eq(sim.pad(&"depot").icons.size(), 3)


func test_every_sound_loads() -> void:
	var def: AudioDef = load("res://data/audio.tres")
	for id in [&"pickup", &"drop", &"coin", &"build", &"lander"]:
		var s := def.sound(id)
		assert_not_null(s, String(id))
		assert_gt(s.streams.size(), 0, String(id))


func test_wind_loop_is_seamless_and_not_silent() -> void:
	var wav := ProceduralAudio.wind_loop(1.0, 11025, 0.05)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	var data := wav.data
	# Wrapping from the last sample to the first is no bigger a jump than any step inside the loop.
	var wrap := absi(data.decode_s16(0) - data.decode_s16(data.size() - 2))
	var biggest := 0
	var peak := 0
	for i in range(2, data.size(), 2):
		biggest = maxi(biggest, absi(data.decode_s16(i) - data.decode_s16(i - 2)))
		peak = maxi(peak, absi(data.decode_s16(i)))
	assert_lte(wrap, biggest, "loop ends meet")
	assert_gt(peak, 1000)


func test_moss_front_grows_with_terraform() -> void:
	var tf := GameState.defs.terraform
	assert_eq(TerraformView.moss_reach(tf, 0.0), 0.0)
	assert_gt(TerraformView.moss_reach(tf, 60.0), TerraformView.moss_reach(tf, 40.0))
	assert_gt(TerraformView.moss_reach(tf, 100.0), 33.0, "covers the play area at 100%")


func test_late_game_fits_draw_call_budget_on_every_planet() -> void:
	for index in GameState.defs.planets.size():
		var calls := await _late_game_calls(index)
		gut.p("%s late-game drawables (before culling): %d" % [GameState.defs.planet(index).display_name, calls])
		assert_lt(calls, DRAW_CALL_BUDGET, GameState.defs.planet(index).display_name)


## Everything built and levelled, max haulers with mixed cargo, the whole colony with two waiting,
## a lander coming down with the last one's food piled on the SUPPLY pad, and the planet's hazard
## at full strength (with a meteor-damaged machine on Kessik), which never all happen at once in play.
func _late_game_calls(index: int) -> int:
	var defs := GameState.defs
	var planet := defs.planet(index)
	var s := GameSim.new_planet_state(defs, index)
	for m in planet.machines:
		s.built[m.id] = true
		# Half upgraded, so UPGRADE pads still show on the rest.
		if not m.upgrade_costs.is_empty() and planet.machines.find(m) % 2 == 0:
			s.machine_levels[m.id] = 1
	s.built[&"bay"] = true
	s.drones = planet.max_drones
	s.terraform = 100.0
	s.toxicity = 0.0
	var items := []
	for m in planet.machines:
		if m.recipe.makes_item():
			items.append(m.recipe.output)
	for i in 20:
		s.stack.append(items[i % items.size()])
	for i in planet.habitat_positions.size():
		s.built[Colony.habitat_key(i)] = true
	s.landers = planet.lander_costs.size() - 2
	s.lander_t = 2.0
	s.food = planet.lander_costs[-1] - 1
	s.housed = (planet.lander_costs.size() - 1) * planet.colonists_per_lander
	s.colonists_waiting = planet.colonists_per_lander
	if planet.hazard:
		s.hazard_phase = HazardDirector.Phase.ACTIVE
		s.hazard_t = minf(20.0, planet.hazard.duration * 0.5)
		if planet.hazard.kind == HazardDef.Kind.METEORS:
			s.impacts.assign([Vector2(5, 14), Vector2(-12, 3), Vector2(14, -2)])
			for m in planet.machines:
				if m.takes_workers and m.recipe.output != planet.hazard.repair_item:
					s.damaged[m.id] = true
					break
	GameState.start(s)
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child(world)
	await wait_process_frames(3)
	for i in 50:
		world._process(0.05)
	# Give every hauler cargo, so each cargo MultiMesh is in use.
	for d in GameState.sim.drones:
		var cargo: Array[StringName] = []
		for k in 1 + d.index % 4:
			cargo.append(items[(d.index + k) % items.size()])
		d.cargo.assign(cargo)
	world._process(0.05)
	var calls := _count_surfaces(world) + LABEL_LAYER_CALLS
	world.queue_free()
	await wait_process_frames(2)
	return calls


func _count_surfaces_one(g: Node) -> int:
	var gi := g as GeometryInstance3D
	var n := 1
	if gi is MultiMeshInstance3D:
		var mm := (gi as MultiMeshInstance3D).multimesh
		n = mm.mesh.get_surface_count() if mm and mm.mesh and mm.visible_instance_count != 0 else 0
	elif gi is MeshInstance3D:
		n = (gi as MeshInstance3D).mesh.get_surface_count() if (gi as MeshInstance3D).mesh else 0
	# A material overlay (frost, soot) draws the mesh a second time.
	return n * (2 if gi.material_overlay else 1)


func _count_surfaces(root: Node) -> int:
	var n := 0
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		if (g as GeometryInstance3D).is_visible_in_tree():
			n += _count_surfaces_one(g)
	return n
