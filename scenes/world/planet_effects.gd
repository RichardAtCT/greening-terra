class_name PlanetEffects
extends Node3D
## M5's planet-specific effects, each a single MultiMesh (one draw call) whatever the count:
## - glowing rings on the ground: every burning Heat Tower's warm radius (brighter in a cold snap)
##   and every marked meteor impact point during a shower's warning;
## - the meteors themselves falling on those points, with their fiery trails, then a dust burst;
## - steam and heat haze rising from Kessik's geothermal vents, over dark vent craters.

const RING_SHADER := preload("res://shaders/ground_ring.gdshader")
const STEAM_SHADER := preload("res://shaders/steam.gdshader")
const METEOR_MESH := preload("res://assets/meshes/meteor.res")
const CRATER_MESH := preload("res://assets/meshes/decor_crater.res")
const HEAT_COLOR := Color("ff8a3a")
const IMPACT_COLOR := Color("ff4a3a")
## Puffs per vent in the steam MultiMesh.
const STEAM_PUFFS := 7
## Where meteors come from, relative to where they land.
const METEOR_FROM := Vector3(9.0, 34.0, -14.0)

var sim: GameSim
var reduced := false

var _rings: MultiMesh
var _meteors: MultiMesh
var _trails: MultiMesh
var _puffs: Array[CPUParticles3D] = []
var _time := 0.0


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	reduced = SaveManager.settings.get("reduced_effects", false)
	var planet := sim.planet
	var towers := 0
	for m in planet.machines:
		if m.is_heat_tower():
			towers += 1
	var h := planet.hazard
	var meteors := h.meteor_count if h and h.kind == HazardDef.Kind.METEORS else 0
	if towers + meteors > 0:
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 2)
		quad.orientation = PlaneMesh.FACE_Y
		var mat := ShaderMaterial.new()
		mat.shader = RING_SHADER
		_rings = _multimesh("Rings", quad, mat, towers + meteors, true)
	if meteors > 0:
		var rock := StandardMaterial3D.new()
		rock.albedo_color = Color("5a4a40")
		rock.vertex_color_use_as_albedo = true
		rock.emission_enabled = true
		rock.emission = Color("ff6a2a") * 0.6
		_meteors = _multimesh("Meteors", METEOR_MESH, rock, meteors)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.55
		cone.height = 1.0
		cone.radial_segments = 8
		cone.rings = 0
		var fire := ItemVisuals.unshaded(Color(Color("ffb04a"), 0.7))
		fire.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trails = _multimesh("Trails", cone, fire, meteors)
	if not planet.vents.is_empty():
		_build_vents(planet)
	update_view(0.0)


## A meteor shower landed: a burst of dust at each point (skipped with "Fewer effects").
func impact(points: Array[Vector2]) -> void:
	if reduced:
		return
	for i in points.size():
		if i >= _puffs.size():
			var p := BuildingView.make_puff(GameState.defs.juice.puff_amount, 1.0)
			p.name = "Impact%d" % i
			add_child(p)
			_puffs.append(p)
		_puffs[i].position = Vector3(points[i].x, 0.2, points[i].y)
		_puffs[i].restart()


func update_view(delta: float) -> void:
	_time += delta
	var s := sim.state
	var h := sim.planet.hazard
	if _rings:
		var n := 0
		var snap := h != null and h.kind == HazardDef.Kind.COLD_SNAP and s.hazard_phase != HazardDirector.Phase.NONE
		for m in sim.planet.machines:
			if not sim.is_warm(m):
				continue
			var r := m.heat_radius
			_rings.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(r, 1, r)), Vector3(m.position.x, 0.07, m.position.y)))
			var glow := (0.32 if snap else 0.12) * (0.85 + 0.15 * sin(_time * 3.0 + n))
			_rings.set_instance_color(n, Color(HEAT_COLOR, glow))
			_rings.set_instance_custom_data(n, Color(0.25 if snap else 0.1, 0, 0, 0))
			n += 1
		var marked := h != null and h.kind == HazardDef.Kind.METEORS and s.hazard_phase != HazardDirector.Phase.NONE
		if marked:
			var r := h.impact_radius
			for p in s.impacts:
				var pulse := 0.6 + 0.4 * sin(_time * 10.0)
				_rings.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(r, 1, r)), Vector3(p.x, 0.08, p.y)))
				_rings.set_instance_color(n, Color(IMPACT_COLOR, pulse))
				_rings.set_instance_custom_data(n, Color(0.3, 1, 0, 0))
				n += 1
		_rings.visible_instance_count = n
	if _meteors:
		var n := 0
		if s.hazard_phase == HazardDirector.Phase.ACTIVE:
			# Falling from high to the side, landing as the shower ends.
			var k := clampf(1.0 - s.hazard_t / maxf(HazardDirector.duration(sim), 0.01), 0.0, 1.0)
			for p in s.impacts:
				var land := Vector3(p.x, 0.3, p.y)
				var at := land + METEOR_FROM * (1.0 - k)
				var dir := -METEOR_FROM.normalized()
				var spin := Basis(Vector3(1, 0.3, 0.2).normalized(), _time * 6.0 + n)
				_meteors.set_instance_transform(n, Transform3D(spin, at))
				# The trail streams back up the path, pointing from the meteor to where it came from.
				var up := -dir
				var side := up.cross(Vector3.FORWARD).normalized()
				var trail := Basis(side, up, side.cross(up)).scaled(Vector3(1, 4.5, 1))
				_trails.set_instance_transform(n, Transform3D(trail, at + up * 2.4))
				n += 1
		_meteors.visible_instance_count = n
		_trails.visible_instance_count = n


func _build_vents(planet: PlanetDef) -> void:
	var craters := MultiMesh.new()
	craters.transform_format = MultiMesh.TRANSFORM_3D
	craters.mesh = CRATER_MESH
	craters.instance_count = planet.vents.size()
	for i in planet.vents.size():
		var v := planet.vents[i]
		# A wide, shallow dark crater round each vent, under the building on it.
		craters.set_instance_transform(i, Transform3D(Basis(Vector3.UP, i * 1.3).scaled(Vector3(1.3, 0.5, 1.3)), Vector3(v.x, -0.03, v.y)))
	var crater_mat := ItemVisuals.lambert(Color("2a2422"))
	crater_mat.vertex_color_use_as_albedo = true
	var cmi := MultiMeshInstance3D.new()
	cmi.name = "VentCraters"
	cmi.multimesh = craters
	cmi.material_override = crater_mat
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cmi)

	var steam := MultiMesh.new()
	steam.transform_format = MultiMesh.TRANSFORM_3D
	steam.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	steam.mesh = q
	var puffs := STEAM_PUFFS if not reduced else 3
	steam.instance_count = planet.vents.size() * puffs
	var rng := RandomNumberGenerator.new()
	rng.seed = planet.seed
	for i in planet.vents.size():
		# Steam rises beside the building on the vent, on its far side.
		var v := planet.vents[i] + Vector2(rng.randf_range(-0.8, 0.8), -1.6)
		for k in puffs:
			var n := i * puffs + k
			steam.set_instance_transform(n, Transform3D.IDENTITY)
			steam.set_instance_custom_data(n, Color(v.x, v.y, float(k) / puffs + rng.randf() * 0.1, rng.randf() * TAU))
	var mat := ShaderMaterial.new()
	mat.shader = STEAM_SHADER
	mat.set_shader_parameter("color", planet.steam_color)
	var smi := MultiMeshInstance3D.new()
	smi.name = "Steam"
	smi.multimesh = steam
	smi.material_override = mat
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 12, 120))
	add_child(smi)


func _multimesh(node_name: String, mesh: Mesh, material: Material, count: int, per_instance := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = per_instance
	mm.use_custom_data = per_instance
	mm.mesh = mesh
	mm.instance_count = maxi(count, 1)
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 50, 120))
	add_child(mmi)
	return mm
