extends GutTest
## M3 art pass: baked models, building node contracts, pad icons, audio data and the draw-call budget.

const MESHES := "res://assets/meshes/"
## SPEC 7.1 budget. The estimate below counts every visible surface, before frustum culling.
const DRAW_CALL_BUDGET := 150


func before_each() -> void:
	SaveManager.active_profile = 99
	GameState.sim = null


func after_each() -> void:
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


func test_late_game_fits_draw_call_budget() -> void:
	var s := GameSim.new_planet_state(GameState.defs, 0)
	for m in GameState.defs.planet(0).machines:
		s.built[m.id] = true
	s.built[&"bay"] = true
	s.drones = GameState.defs.planet(0).max_drones
	s.terraform = 100.0
	for i in 20:
		s.stack.append([&"regolith", &"plate", &"o2", &"seedpod"][i % 4])
	# M4: the whole colony (every habitat, every colonist, a few hungry), a lander on its way down
	# and a dust storm blowing, which never all happen at once in play.
	var planet := GameState.defs.planet(0)
	for i in planet.habitat_positions.size():
		s.built[Colony.habitat_key(i)] = true
	s.landers = planet.lander_milestones.size() - 1
	s.lander_t = 2.0
	for i in (planet.lander_milestones.size() - 1) * planet.colonists_per_lander:
		s.meals.append(0.0 if i % 4 == 0 else 60.0)
	s.colonists_waiting = planet.colonists_per_lander
	s.hazard_phase = HazardDirector.Phase.ACTIVE
	s.hazard_t = 20.0
	GameState.start(s)
	var world: Node3D = load("res://scenes/world/planet.tscn").instantiate()
	add_child_autofree(world)
	await wait_process_frames(3)
	for i in 50:
		world._process(0.1)
	# Give every hauler cargo, so each cargo MultiMesh is in use.
	for d in GameState.sim.drones:
		d.cargo.assign([&"plate", &"o2", &"seedpod", &"regolith"].slice(0, 1 + d.index % 4))
	world._process(0.1)
	var calls := _count_surfaces(world)
	gut.p("late-game drawables (before culling): %d" % calls)
	assert_lt(calls, DRAW_CALL_BUDGET)


func _count_surfaces(root: Node) -> int:
	var n := 0
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		if gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm and mm.mesh and (mm.visible_instance_count != 0):
				n += mm.mesh.get_surface_count()
		elif gi is MeshInstance3D:
			if (gi as MeshInstance3D).mesh:
				n += (gi as MeshInstance3D).mesh.get_surface_count()
		else:
			n += 1
	return n
