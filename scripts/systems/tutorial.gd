class_name Tutorial
extends RefCounted
## Pure tutorial progression and objective text.


static func is_done(step: TutorialStep, state: WorldState) -> bool:
	for c in step.done_when:
		match c.kind:
			TutorialCondition.Kind.CARRYING:
				if state.count_carried(c.key) >= c.amount:
					return true
			TutorialCondition.Kind.STAT:
				if state.stat(c.key) >= c.amount:
					return true
			TutorialCondition.Kind.BUILT:
				if state.is_built(c.key):
					return true
	return false


## Advances past every completed step (never past the last one).
static func advance(steps: Array[TutorialStep], state: WorldState) -> void:
	while state.tutorial_step < steps.size() - 1 and is_done(steps[state.tutorial_step], state):
		state.tutorial_step += 1


static func current(steps: Array[TutorialStep], state: WorldState) -> TutorialStep:
	if steps.is_empty():
		return null
	return steps[clampi(state.tutorial_step, 0, steps.size() - 1)]


## Objective text, swapped for the "keep saving" line while the next purchase is unaffordable.
static func hint_text(sim: GameSim) -> String:
	var steps := sim.tutorial_steps()
	var step := current(steps, sim.state)
	if step == null:
		return ""
	var text := step.text
	if step.saving_for_pad != &"":
		var pad := sim.pad(step.saving_for_pad)
		var cost := sim.pad_cost(pad) if pad else -1
		if cost > 0 and sim.state.credits + sim.state.paid.get(step.saving_for_pad, 0) < cost:
			text = step.saving_text
	var last := sim.state.tutorial_step >= steps.size() - 1
	# Once the tutorial is done, the bar also says how more colonists come (SPEC 4.1).
	if last:
		var colony := Colony.outlook(sim)
		if colony != "":
			text = colony + " " + text
	if sim.pack_full() and not last and sim.state.tutorial_step != 0:
		text = "Pack full. " + text
	# A machine idle for want of an input the player could swap for says so instead.
	var swap := sim.swap_hint()
	if swap != "":
		text = swap
	return text


## "3/9" while the tutorial runs, then the stage name.
static func step_label(sim: GameSim) -> String:
	var steps := sim.tutorial_steps()
	if sim.state.tutorial_step < steps.size() - 1:
		return "%d/%d" % [sim.state.tutorial_step + 1, steps.size()]
	return TerraformMath.stage_name(sim.defs.terraform, sim.state.terraform).to_upper()
