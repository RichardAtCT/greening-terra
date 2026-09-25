extends SceneTree
## Renders the planet in a given state and saves a PNG, for checking visuals without a phone.
## Needs a display (e.g. xvfb-run). Example:
##   xvfb-run -a -s "-screen 0 1280x1024x24" tools/godot/godot --resolution 390x844 \
##     -s tools/dev/screenshot.gd -- --tf=60 --drones=6 --built=all --out=/tmp/shot.png
## --scene=res://scenes/ui/title.tscn renders another scene instead of the planet.
## Uses throwaway profile 97, so real saves are untouched.

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	await process_frame
	var gs = root.get_node("GameState")
	root.get_node("SaveManager").active_profile = 97
	var defs: GameDefs = gs.defs
	var s := GameSim.new_planet_state(defs, int(args.get("planet", "0")))
	s.terraform = float(args.get("tf", "0"))
	s.credits = float(args.get("credits", "0"))
	if args.get("built", "") == "all":
		for m in defs.planet(s.planet_index).machines:
			s.built[m.id] = true
		s.built[&"bay"] = true
	s.drones = int(args.get("drones", "0"))
	if args.has("x"):
		s.player_position = Vector2(float(args.x), float(args.get("z", "7")))
	for i in int(args.get("carry", "0")):
		s.stack.append([&"regolith", &"plate", &"o2", &"seedpod"][i % 4] if args.get("mixed", "") != "" else &"regolith")
	s.tutorial_step = int(args.get("step", "0"))
	gs.start(s)
	var planet: Node = load(args.get("scene", "res://scenes/world/planet.tscn")).instantiate()
	root.add_child(planet)
	for i in int(args.get("frames", "90")):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(args.get("out", "user://shot.png"))
	print("saved ", args.get("out", "user://shot.png"))
	DirAccess.remove_absolute("user://profile_97.json")
	quit()
