class_name TerraformView
extends Node3D
## Turns the displayed terraform % into the planet's look: sky, fog, light, ground tint, moss and
## frost (ground_terraform shader), lakes (water shader), dust, and moss, grass, flowers and trees
## that spread outward from the hub (each planet shifts when its plants come: tundra on Orrin b).
## The planet's hazard adds its own look on top: a dust storm's orange fog, a cold snap's snow and
## frost, a meteor shower's darkening sky.

const DUST_COUNT := 260
const GROUND_SHADER := preload("res://shaders/ground_terraform.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const ROCK_MESH := preload("res://assets/meshes/decor_rock.res")
const CRATER_MESH := preload("res://assets/meshes/decor_crater.res")
const PINE_MESH := preload("res://assets/meshes/tree_pine.res")
const ROUND_TREE_MESH := preload("res://assets/meshes/tree_round.res")
const GRASS_MESH := preload("res://assets/meshes/grass_tuft.res")
const FLOWER_MESH := preload("res://assets/meshes/flowers.res")

var defs: GameDefs
var planet: PlanetDef
var environment: Environment
var sun: DirectionalLight3D

var ground_mat: ShaderMaterial
var rock_mat: StandardMaterial3D
var crater_mat: StandardMaterial3D
var _lakes: Array[MeshInstance3D] = []
var _lake_radius: Array[float] = []
var _dust_mat: ShaderMaterial
var _drift := Vector2.ZERO
var _fall := 0.0
var _frost := 0.0
var _layers: Array[Dictionary] = []


func build(p_defs: GameDefs, p_planet: PlanetDef, rng: RandomNumberGenerator) -> void:
	defs = p_defs
	planet = p_planet
	var tf := defs.terraform

	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("moss_color", planet.moss_color)
	ground_mat.set_shader_parameter("hub", planet.hub_position)
	ground_mat.set_shader_parameter("moss_edge", tf.ground_moss_edge)
	ground_mat.set_shader_parameter("moss_strength", tf.ground_moss_strength)
	ground_mat.set_shader_parameter("frost_color", planet.frost_color)
	set_warm_spots([])
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = TerrainBuilder.ground_mesh(rng)
	ground.material_override = ground_mat
	_no_shadow(ground)
	add_child(ground)

	crater_mat = _tinted(planet.ground_start * tf.rock_darken)
	var craters := MultiMeshInstance3D.new()
	craters.name = "Craters"
	craters.multimesh = TerrainBuilder.craters_multimesh(planet, rng, CRATER_MESH)
	craters.material_override = crater_mat
	_no_shadow(craters)
	add_child(craters)

	rock_mat = _tinted(planet.ground_start * tf.rock_darken)
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "Rocks"
	rocks.multimesh = TerrainBuilder.rocks_multimesh(planet, rng, ROCK_MESH)
	rocks.material_override = rock_mat
	_no_shadow(rocks)
	add_child(rocks)

	var lake_mat := ShaderMaterial.new()
	lake_mat.shader = WATER_SHADER
	lake_mat.set_shader_parameter("deep_color", planet.water_deep)
	lake_mat.set_shader_parameter("shallow_color", planet.water_shallow)
	var lake_mesh := MeshUtil.water_disc(4, 28)
	for lake in planet.lakes:
		var mi := MeshInstance3D.new()
		mi.mesh = lake_mesh
		mi.material_override = lake_mat
		mi.position = Vector3(lake.x, 0.05, lake.y)
		mi.scale = Vector3.ONE * 0.001
		_no_shadow(mi)
		add_child(mi)
		_lakes.append(mi)
		_lake_radius.append(lake.z)

	var pines := int(round(tf.tree_count * (planet.pine_share if planet.pine_share >= 0.0 else tf.tree_pine_share)))
	_layers.append(_build_layer("Moss", MeshUtil.disc(1.0, 7), tf.moss_count, rng, _place_moss))
	_layers.append(_build_layer("Grass", GRASS_MESH, tf.grass_count, rng, _place_grass))
	_layers.append(_build_layer("Flowers", FLOWER_MESH, tf.flower_count, rng, _place_flower))
	_layers.append(_build_layer("Pines", PINE_MESH, pines, rng, _place_tree))
	_layers.append(_build_layer("Trees", ROUND_TREE_MESH, tf.tree_count - pines, rng, _place_tree))
	_build_dust(rng)


## Applies the look for terraform % t. snap = jump straight there (on load) instead of growing.
## storm (0..1, HazardDirector.intensity) darkens the sky during a hazard's warning, then brings in
## the hazard's thick coloured fog and driving dust while it's on.
func apply(t: float, delta: float, snap: bool, player_pos: Vector3, storm := 0.0) -> void:
	var tf := defs.terraform
	var k := t / 100.0
	var h := planet.hazard
	var dark := storm if h else 0.0
	# 0 during the warning, rising to 1 as the hazard itself arrives.
	var thick := clampf(inverse_lerp(h.warning_darken, 1.0, storm), 0.0, 1.0) if h and storm > 0.0 else 0.0
	var fog := thick if h and h.fog_enabled else 0.0
	var sky := TerraformMath.sky_color(tf, planet, t)
	if h:
		sky = sky.lerp(h.dark_color, dark * 0.6)
	environment.background_color = sky.lerp(h.fog_color * 0.8, fog * 0.7) if h else sky
	environment.fog_light_color = sky.lerp(h.fog_color, fog) if h else sky
	environment.fog_depth_begin = lerpf(tf.fog_near + tf.fog_near_gain * k, h.fog_near if h else 0.0, fog)
	environment.fog_depth_end = lerpf(tf.fog_far + tf.fog_far_gain * k, h.fog_far if h else 0.0, fog)
	var hemi := sky.lerp(Color.WHITE, 0.5) * (tf.ambient_energy + tf.ambient_energy_gain * k)
	environment.ambient_light_color = Color(hemi.r + 0.18, hemi.g + 0.18, hemi.b + 0.18)
	sun.light_energy = (tf.sun_energy + tf.sun_energy_gain * k) * (1.0 - 0.45 * dark)
	var ground := planet.ground_start.lerp(planet.ground_end, k)
	ground_mat.set_shader_parameter("ground_tint", ground)
	ground_mat.set_shader_parameter("moss_reach", moss_reach(tf, t))
	var cover := clampf((t - tf.ground_moss_cover_start) / (tf.ground_moss_cover_full - tf.ground_moss_cover_start), 0.0, 1.0)
	ground_mat.set_shader_parameter("moss_cover", lerpf(tf.ground_moss_cover_min, tf.ground_moss_cover_max, cover))
	rock_mat.albedo_color = planet.ground_start * tf.rock_darken
	crater_mat.albedo_color = ground * tf.rock_darken
	var dust := tf.dust_opacity * maxf(0.0, 1.0 - t / tf.dust_gone_at)
	var gust := thick if h and h.dust_opacity > 0.0 else 0.0
	_dust_mat.set_shader_parameter("opacity", lerpf(dust, h.dust_opacity, gust) if h else dust)
	var wind := tf.dust_wind.lerp(h.dust_wind, gust) if h else tf.dust_wind
	_drift = (_drift + wind * delta).posmod(40.0)
	_dust_mat.set_shader_parameter("drift", _drift)
	var mote := planet.ground_start.lerp(Color.WHITE, 0.45)
	if h and h.dust_color.a > 0.0:
		mote = mote.lerp(Color(h.dust_color, 1.0), gust)
	_dust_mat.set_shader_parameter("color", mote)
	# Snow falls; dust only drifts.
	_fall = fposmod(_fall + (h.dust_fall * gust if h else 0.0) * delta, 60.0)
	_dust_mat.set_shader_parameter("fall", _fall)
	# Frost (Orrin b) melts off as the planet warms, from the hub outwards; a cold snap brings it back.
	var melt := clampf(1.0 - t / maxf(planet.frost_gone_at, 0.01), 0.0, 1.0)
	_frost = maxf(planet.frost * melt, (h.frost if h else 0.0) * thick)
	ground_mat.set_shader_parameter("frost", _frost)
	ground_mat.set_shader_parameter("frost_reach", moss_reach(tf, t) * 1.3)
	_dust_mat.set_shader_parameter("center", player_pos)
	var ls := TerraformMath.lake_scale(tf, t)
	for i in _lakes.size():
		var mi := _lakes[i]
		var goal := ls * _lake_radius[i]
		var cur := goal if snap else mi.scale.x + (goal - mi.scale.x) * minf(1.0, delta * tf.lake_grow_rate)
		mi.scale = Vector3.ONE * maxf(0.001, cur)
	for layer in _layers:
		_step_layer(layer, t, delta, snap)


## How much frost is on the ground right now (0..1), for frosting machines to match.
func frost_amount() -> float:
	return _frost


## Burning Heat Towers melt the frost round them: up to four (x, z, radius) spots.
func set_warm_spots(spots: Array) -> void:
	var packed := PackedVector4Array()
	for i in 4:
		var w: Vector3 = spots[i] if i < spots.size() else Vector3(0, 0, 0)
		packed.append(Vector4(w.x, w.y, w.z, 1.0 if i < spots.size() else 0.0))
	ground_mat.set_shader_parameter("warm", packed)


## How far (metres from the hub) the ground moss has spread at terraform % t. It tracks the middle
## of the moss patches' thresholds, so the patches and the ground turn green together.
static func moss_reach(tf: TerraformDef, t: float) -> float:
	var k := (t - tf.moss_threshold_base - tf.moss_threshold_jitter * 0.5) / tf.moss_threshold_spread
	return maxf(0.0, k * tf.moss_radius)


func _build_layer(layer_name: String, mesh: Mesh, count: int, rng: RandomNumberGenerator, placer: Callable) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var data: Array[Dictionary] = []
	for i in count:
		var d: Dictionary = placer.call(i, rng)
		d.cur = 0.0
		data.append(d)
		mm.set_instance_color(i, d.color)
		mm.set_instance_transform(i, _layer_xform(d, 0.0001))
	var mat := _tinted(Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.multimesh = mm
	mmi.material_override = mat
	_no_shadow(mmi)
	add_child(mmi)
	return {"mm": mm, "data": data}


func _layer_xform(d: Dictionary, s: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, d.rot).scaled(Vector3.ONE * s), Vector3(d.x, d.y, d.z))


func _step_layer(layer: Dictionary, t: float, delta: float, snap: bool) -> void:
	var mm: MultiMesh = layer.mm
	var rate := defs.terraform.plant_grow_rate
	var data: Array[Dictionary] = layer.data
	for i in data.size():
		var d := data[i]
		var target := 1.0 if t >= d.th else 0.0
		if snap:
			d.cur = target
		elif absf(d.cur - target) > 0.002:
			d.cur += (target - d.cur) * minf(1.0, delta * rate)
		elif d.cur != target:
			d.cur = target
		else:
			continue
		mm.set_instance_transform(i, _layer_xform(d, maxf(0.0001, d.cur * d.s)))


func _place_moss(i: int, rng: RandomNumberGenerator) -> Dictionary:
	var tf := defs.terraform
	var x := 0.0
	var z := 0.0
	for attempt in 200:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * tf.moss_radius
		x = cos(a) * r
		z = sin(a) * r
		if TerrainBuilder.is_clear(planet, x, z, -1.6) and TerrainBuilder.is_dry(planet, x, z, -0.5):
			break
	var dist := Vector2(x, z).length()
	return {
		"x": x, "z": z, "y": 0.03 + i * 0.00004, "rot": rng.randf() * TAU, "s": 0.55 + rng.randf() * 1.1,
		"th": tf.moss_threshold_base + dist / tf.moss_radius * tf.moss_threshold_spread + rng.randf() * tf.moss_threshold_jitter,
		"color": hsl(0.24 + rng.randf() * 0.08, 0.3 + rng.randf() * 0.18, 0.26 + rng.randf() * 0.12),
	}


func _place_grass(_i: int, rng: RandomNumberGenerator) -> Dictionary:
	var tf := defs.terraform
	var p := _open_spot(rng, 2.0, tf.grass_radius, -1.0, -0.2)
	return {
		"x": p.x, "z": p.y, "y": 0.0, "rot": rng.randf() * TAU, "s": 0.7 + rng.randf() * 0.7,
		"th": planet.grass_shift + tf.grass_threshold_base + p.length() / tf.grass_radius * tf.grass_threshold_spread + rng.randf() * tf.grass_threshold_jitter,
		"color": hsl(0.25 + planet.plant_hue_shift + rng.randf() * 0.08, (0.4 + rng.randf() * 0.2) * planet.plant_saturation, 0.42 + rng.randf() * 0.14),
	}


func _place_flower(_i: int, rng: RandomNumberGenerator) -> Dictionary:
	var tf := defs.terraform
	var p := _open_spot(rng, 3.0, tf.flower_radius, -0.8, 0.0)
	return {
		"x": p.x, "z": p.y, "y": 0.0, "rot": rng.randf() * TAU, "s": 0.8 + rng.randf() * 0.5,
		"th": planet.flower_shift + tf.flower_threshold_base + p.length() / tf.flower_radius * tf.flower_threshold_spread + rng.randf() * tf.flower_threshold_jitter,
		"color": Color.WHITE.lerp(hsl(rng.randf(), 0.7, 0.75), 0.35),
	}


## A random spot between the radii that avoids clear zones and lakes (margins as in is_clear/is_dry).
func _open_spot(rng: RandomNumberGenerator, min_r: float, max_r: float, clear_margin: float, dry_margin: float) -> Vector2:
	var x := 0.0
	var z := 0.0
	for attempt in 200:
		var a := rng.randf() * TAU
		var r := min_r + sqrt(rng.randf()) * (max_r - min_r)
		x = cos(a) * r
		z = sin(a) * r
		if TerrainBuilder.is_clear(planet, x, z, clear_margin) and TerrainBuilder.is_dry(planet, x, z, dry_margin):
			break
	return Vector2(x, z)


func _place_tree(_i: int, rng: RandomNumberGenerator) -> Dictionary:
	var tf := defs.terraform
	var x := 0.0
	var z := 0.0
	for attempt in 200:
		var a := rng.randf() * TAU
		var r := tf.tree_min_radius + rng.randf() * (tf.tree_max_radius - tf.tree_min_radius)
		x = cos(a) * r
		z = sin(a) * r
		if TerrainBuilder.is_clear(planet, x, z, 1.0) and TerrainBuilder.is_dry(planet, x, z, 1.0):
			break
	var dist := Vector2(x, z).length()
	return {
		"x": x, "z": z, "y": 0.0, "rot": rng.randf() * TAU, "s": 0.7 + rng.randf() * 0.8,
		"th": planet.tree_shift + tf.tree_threshold_base + dist / tf.tree_max_radius * tf.tree_threshold_spread + rng.randf() * tf.tree_threshold_jitter,
		"color": hsl(0.28 + planet.plant_hue_shift + rng.randf() * 0.07, 0.45 * planet.plant_saturation, 0.28 + rng.randf() * 0.1),
	}


func _build_dust(rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = DUST_COUNT
	for i in DUST_COUNT:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color((rng.randf() - 0.5) * 40.0, rng.randf() * 6.0, (rng.randf() - 0.5) * 40.0, 0.0))
	_dust_mat = ShaderMaterial.new()
	_dust_mat.shader = preload("res://shaders/dust.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Dust"
	mmi.multimesh = mm
	mmi.material_override = _dust_mat
	mmi.custom_aabb = AABB(Vector3(-200, -10, -200), Vector3(400, 40, 400))
	_no_shadow(mmi)
	add_child(mmi)


## Material for a baked mesh tinted by one colour (vertex colour × albedo).
func _tinted(color: Color) -> StandardMaterial3D:
	var m := ItemVisuals.lambert(color)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


func _no_shadow(g: GeometryInstance3D) -> void:
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## HSL to RGB, matching THREE.Color.setHSL.
static func hsl(h: float, s: float, l: float) -> Color:
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	return Color(_hue(p, q, h + 1.0 / 3.0), _hue(p, q, h), _hue(p, q, h - 1.0 / 3.0))


static func _hue(p: float, q: float, t: float) -> float:
	t = fposmod(t, 1.0)
	if t < 1.0 / 6.0:
		return p + (q - p) * 6.0 * t
	if t < 0.5:
		return q
	if t < 2.0 / 3.0:
		return p + (q - p) * 6.0 * (2.0 / 3.0 - t)
	return p
