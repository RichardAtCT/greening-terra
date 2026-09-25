class_name ColonyView
extends Node3D
## Draws the colony: every colonist in one MultiMesh per look (Mini Characters, baked), a food
## icon over hungry heads, colonists waiting for a habitat by the landing pad, and the lander
## coming down, waiting, and lifting off again. Mirrors the sim's Colony state.

const LOOKS := [
	preload("res://assets/meshes/colonist_female-b.res"),
	preload("res://assets/meshes/colonist_male-a.res"),
	preload("res://assets/meshes/colonist_female-e.res"),
	preload("res://assets/meshes/colonist_male-b.res"),
]
const LANDER_MESH := preload("res://assets/meshes/lander.res")
## Waiting colonists stand in a loose arc this far in front of the landing pad.
const WAIT_RADIUS := 2.4

var sim: GameSim
var defs: GameDefs

var _looks: Array[MultiMesh] = []
var _hungry: MultiMesh
var _phase: Dictionary = {}
var _time := 0.0
var _lander: Node3D
var _flame: MeshInstance3D
var _puff: CPUParticles3D
## View-only lander timeline after touchdown: seconds since it landed (-1: not on the pad).
var _landed_t := -1.0


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	defs = sim.defs
	var cap := 0
	for i in sim.planet.lander_milestones.size():
		cap += sim.planet.colonists_per_lander
	for i in LOOKS.size():
		_looks.append(_multimesh("Look%d" % i, LOOKS[i], cap, null))
	var pod := defs.item(&"seedpod")
	_hungry = _multimesh("Hungry", ItemVisuals.mesh(pod.shape) if pod else MeshUtil.disc(0.2, 8), cap,
		ItemVisuals.material(pod) if pod else null)

	_lander = Node3D.new()
	_lander.name = "Lander"
	var body := MeshInstance3D.new()
	body.mesh = LANDER_MESH
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lander.add_child(body)
	_flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.05
	cone.height = 1.6
	cone.radial_segments = 8
	cone.rings = 0
	_flame.mesh = cone
	_flame.material_override = ItemVisuals.unshaded(Color(Color("ffb04a"), 0.85))
	_flame.position.y = -0.7
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lander.add_child(_flame)
	_lander.visible = false
	add_child(_lander)
	var lp := sim.planet.lander_position
	_lander.position = Vector3(lp.x, 0, lp.y)
	if sim.state.lander_t >= 0.0:
		_lander.visible = true
	update_view(0.0)


## The lander touched down: kick up dust and start its stay on the pad.
func landed() -> void:
	_landed_t = 0.0
	if SaveManager.settings.get("reduced_effects", false):
		return
	if _puff == null:
		_puff = BuildingView.make_puff(defs.juice.lander_puff_amount, 1.6)
		_puff.position = _lander.position + Vector3(0, 0.1, 0)
		add_child(_puff)
	_puff.restart()


func update_view(delta: float) -> void:
	_time += delta
	_update_lander(delta)
	var j := defs.juice
	var counts: Array[int] = []
	counts.resize(_looks.size())
	counts.fill(0)
	var hungry := 0
	for c in sim.colonists:
		var ph: float = _phase.get(c.index, float(c.index) * 1.7)
		var pos := Vector3(c.position.x, 0.0, c.position.y)
		var pitch := 0.0
		var roll := 0.0
		if c.moving:
			ph += delta * j.colonist_step_rate
			pos.y = absf(sin(ph)) * j.colonist_bob
			roll = sin(ph) * j.colonist_sway
		elif c.working:
			ph += delta * j.colonist_work_rate
			pitch = maxf(0.0, sin(ph)) * j.colonist_work_lean
		_phase[c.index] = ph
		var basis := Basis(Vector3.UP, c.heading) * Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, pitch)
		var look := c.index % _looks.size()
		_place(_looks[look], counts[look], Transform3D(basis, pos))
		counts[look] += 1
		if c.hungry:
			var s := j.hungry_icon_scale * (1.0 + 0.12 * sin(_time * 6.0 + c.index))
			var icon := Transform3D(Basis(Vector3.UP, _time * 2.0).scaled(Vector3.ONE * s),
				pos + Vector3(0, j.hungry_icon_height + sin(_time * 3.0 + c.index) * 0.06, 0))
			_place(_hungry, hungry, icon)
			hungry += 1
	# Colonists with nowhere to live wait by the landing pad, facing the hub.
	var lp := sim.planet.lander_position
	var face := sim.planet.hub_position - lp
	var waiting := sim.state.colonists_waiting
	for k in waiting:
		var a := atan2(face.x, face.y) + (k - (waiting - 1) * 0.5) * 0.45
		var p := lp + Vector2(sin(a), cos(a)) * WAIT_RADIUS
		var look := (sim.colonists.size() + k) % _looks.size()
		var bob := absf(sin(_time * 2.0 + k)) * 0.02
		_place(_looks[look], counts[look], Transform3D(Basis(Vector3.UP, atan2(face.x, face.y)), Vector3(p.x, bob, p.y)))
		counts[look] += 1
	for i in _looks.size():
		_looks[i].visible_instance_count = mini(counts[i], _looks[i].instance_count)
	_hungry.visible_instance_count = mini(hungry, _hungry.instance_count)


func _update_lander(delta: float) -> void:
	var c := defs.colony
	var j := defs.juice
	var lt := sim.state.lander_t
	if lt >= 0.0:
		# Coming down: fast at first, easing onto the pad.
		var k := clampf(lt / maxf(c.lander_descent_time, 0.01), 0.0, 1.0)
		_lander.visible = true
		_lander.position.y = j.lander_drop_height * k * k
		_flame.visible = true
		_flame.scale = Vector3.ONE * (0.8 + 0.25 * sin(_time * 40.0))
		_landed_t = -1.0
		return
	if _landed_t < 0.0:
		_lander.visible = false
		return
	_landed_t += delta
	var up := _landed_t - c.lander_stay_time
	if up <= 0.0:
		_lander.position.y = 0.0
		_flame.visible = false
		return
	var k := up / maxf(j.lander_liftoff_time, 0.01)
	if k >= 1.0:
		_landed_t = -1.0
		_lander.visible = false
		return
	_lander.position.y = j.lander_drop_height * k * k
	_flame.visible = true
	_flame.scale = Vector3.ONE * (0.8 + 0.25 * sin(_time * 40.0))


## Sized for every colonist a planet brings, so the buffers never need to grow mid-frame.
func _place(mm: MultiMesh, i: int, xf: Transform3D) -> void:
	if i < mm.instance_count:
		mm.set_instance_transform(i, xf)


func _multimesh(node_name: String, mesh: Mesh, count: int, material: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = maxi(count, 4)
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	if material:
		mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 10, 120))
	add_child(mmi)
	return mm
