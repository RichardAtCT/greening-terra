extends SceneTree
## Balance simulator (SPEC 7.5). Plays every planet with a greedy scripted player and the real
## GameSim in accelerated time, prints time to each milestone, and fails (exit 1) if an enforced
## planet finishes outside its target minutes by more than 20%.
##   godot --headless --script tools/balance_sim.gd [-- --planets=0,1,2 --dt=0.0333 --max-minutes=150]
## For quick experiments, --scale-tf=0.5 and --scale-machine-time=1.2 scale the loaded data in
## memory (nothing is saved); put the numbers you settle on into data/.

const TOLERANCE := 0.2


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var defs: GameDefs = load("res://data/game.tres")
	if args.has("scale-tf"):
		for item in defs.items:
			item.terraform_value *= float(args["scale-tf"])
	if args.has("scale-machine-time"):
		for m in defs.planet(0).machines:
			m.recipe.time *= float(args["scale-machine-time"])
	var dt := float(args.get("dt", str(1.0 / 30.0)))
	var max_minutes := float(args.get("max-minutes", "150"))
	var planets: Array = []
	for p in String(args.get("planets", "0,1,2")).split(","):
		planets.append(int(p))

	var failures := 0
	var pack := 0
	var boots := 0
	print("")
	print("%-12s %8s %8s %8s %8s %8s %8s %8s  %-10s %s" % ["planet", "1st bld", "bay", "green", "25%", "50%", "75%", "100%", "target", "result"])
	for index in planets:
		var planet := defs.planet(index)
		var res := run_planet(defs, index, pack, boots, dt, max_minutes)
		pack = res.pack_level
		boots = res.boots_level
		var total: float = res.times.get("100", -1.0)
		var lo := planet.target_minutes.x * (1.0 - TOLERANCE)
		var hi := planet.target_minutes.y * (1.0 + TOLERANCE)
		var ok := total > 0 and total / 60.0 >= lo and total / 60.0 <= hi
		var verdict := "ok" if ok else ("FAIL" if planet.balance_enforced else "off (placeholder)")
		if not ok and planet.balance_enforced:
			failures += 1
		print("%-12s %8s %8s %8s %8s %8s %8s %8s  %-10s %s" % [planet.display_name,
			_fmt(res.times.get("first_build")), _fmt(res.times.get("bay")), _fmt(res.times.get("greenhouse")),
			_fmt(res.times.get("25")), _fmt(res.times.get("50")), _fmt(res.times.get("75")), _fmt(res.times.get("100")),
			"%d-%d min" % [planet.target_minutes.x, planet.target_minutes.y], verdict])
		print("    end: %d drones, pack lvl %d, boots lvl %d, %d delivered, ₵%d left" % [
			res.drones, res.pack_level, res.boots_level, res.delivered, res.credits])
	print("")
	quit(1 if failures > 0 else 0)


static func run_planet(defs: GameDefs, index: int, pack: int, boots: int, dt: float, max_minutes: float) -> Dictionary:
	var state := GameSim.new_planet_state(defs, index, pack, boots)
	var sim := GameSim.new(defs, state)
	var bot := BotPlayer.new(sim)
	var times := {}
	var t := 0.0
	while t < max_minutes * 60.0 and state.terraform < 100.0:
		bot.step(dt)
		t += dt
		for id in [&"bay", &"greenhouse"]:
			if state.is_built(id) and not times.has(String(id)):
				times[String(id)] = t
		if not times.has("first_build"):
			for m in sim.planet.machines:
				if not m.starts_built and state.is_built(m.id):
					times["first_build"] = t
		for pct in [25, 50, 75, 100]:
			if state.terraform >= pct and not times.has(str(pct)):
				times[str(pct)] = t
	return {
		"times": times, "pack_level": state.pack_level, "boots_level": state.boots_level,
		"drones": state.drones, "delivered": state.stat(&"delivered"), "credits": int(state.credits),
	}


static func _fmt(seconds) -> String:
	if seconds == null:
		return "-"
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
