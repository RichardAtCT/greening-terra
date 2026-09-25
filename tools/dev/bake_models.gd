extends SceneTree
## Bakes the Kenney models in assets/models/ into single-draw-call meshes (assets/meshes/*.res)
## and writes the building scenes in scenes/buildings/.
## Run after changing anything below:
##   tools/godot/godot --headless --import && tools/godot/godot --headless --script tools/dev/bake_models.gd
##
## Every Kenney material is a flat colour, so all of a model's surfaces merge into one surface
## with the colours moved into vertex colours (assets/materials/kit.tres). Glass surfaces go into
## a second, transparent surface. Each source model is first recentred on its bounding box in X/Z
## with its base at y = 0 (the GLBs are offset from the origin), then scaled, turned and placed.
##
## Part keys: src (path under assets/models, no extension), scale (float or Vector3), pos, rot (deg, Y),
## nodes (only these mesh nodes), colors ({material name: Color}), glass ({material name: Color with alpha}),
## mesh + color (a procedural mesh instead of a GLB), stack (true: sit on top of the parts so far).
## Textured materials (Mini Characters' colour atlas) are sampled at each vertex's UV, so they bake
## into vertex colours like everything else.

const MODELS := "res://assets/models/"
const MESHES := "res://assets/meshes/"
const BUILDINGS := "res://scenes/buildings/"
const KIT := preload("res://assets/materials/kit.tres")
const KIT_GLASS := preload("res://assets/materials/kit_glass.tres")

## Grey levels used for meshes that are tinted at runtime (material albedo × vertex colour).
const TINT := Color.WHITE
const TINT_SHADE := Color(0.82, 0.82, 0.82)
const LEAF := Color(0.93, 0.93, 0.93)
## Space Kit's cool greys and orange, warmed and darkened towards the prototype's palette so the
## buildings don't blow out under the planet's light. Applied before each part's own colours.
const PALETTE := {
	"metal": Color("d6cfc4"),
	"metalDark": Color("8c847e"),
	"dark": Color("4d4547"),
	"metalRed": Color("e39a4a"),
}

## Mini Characters used for colonists, one MultiMesh (draw call) each.
const COLONISTS := ["female-b", "female-e", "male-a", "male-b"]
## About two thirds of the astronaut's height.
const COLONIST_SCALE := 1.5

var _count := 0


func _init() -> void:
	_bake_actors()
	_bake_nature()
	_bake_buildings()
	_bake_colony()
	print("baked %d meshes" % _count)
	quit()


# --- Actors and resources ---------------------------------------------------------------

func _bake_actors() -> void:
	# astronautA is bare-headed: hair becomes a white helmet and the face an orange visor, as in the prototype.
	var suit := {"rock": Color("e8e4dc"), "skin": Color("ffb04a"), "rockDark": Color("d98a2e")}
	var astro := {"src": "space/astronautA", "scale": 2.0, "colors": suit}
	var pack := BoxMesh.new()
	pack.size = Vector3(0.5, 0.5, 0.2)
	_save_mesh("astronaut_body", [_with(astro, {"nodes": ["body", "head", "armLeft", "armRight"]}),
		{"mesh": pack, "color": Color("d9794a"), "xform": Transform3D(Basis(), Vector3(0, 0.98, -0.3))}])
	_save_mesh("astronaut_leg_left", [_with(astro, {"nodes": ["legLeft"]})])
	_save_mesh("astronaut_leg_right", [_with(astro, {"nodes": ["legRight"]})])

	# Faces +Z (the sim's heading convention); the cargo hangs below it.
	_save_mesh("drone", [{"src": "space/craft_cargoA", "scale": 0.5}])

	# Resource nodes are tinted by their ResourceNodeDef colour at runtime.
	var rock_tint := {"rock": TINT, "rockTrack": TINT_SHADE, "rockDark": Color(0.7, 0.7, 0.7)}
	_save_mesh("node_regolith", [
		{"src": "space/rock_largeA", "scale": 1.35, "pos": Vector3(0.25, 0, -0.2), "rot": 20, "colors": rock_tint},
		{"src": "space/rock_largeB", "scale": 1.05, "pos": Vector3(-0.5, 0, 0.3), "rot": 75, "colors": rock_tint},
		{"src": "space/meteor_half", "scale": 0.75, "pos": Vector3(0.35, 0, 0.6), "rot": 140, "colors": rock_tint},
	])
	var ice_tint := {"rock": Color(0.42, 0.45, 0.5), "rockTrack": Color(0.36, 0.39, 0.44), "crystal": TINT}
	var shards := []
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.4
		var h := 1.0 + 0.35 * (i % 3)
		var basis := Basis(Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)), 0.35).scaled(Vector3(0.55, h, 0.55))
		shards.append({"mesh": MeshUtil.octahedron(0.5), "color": TINT, "xform": Transform3D(basis, Vector3(cos(a) * 0.38, 0.35 * h, sin(a) * 0.38))})
	_save_mesh("node_ice", [{"src": "space/rock_crystalsLargeA", "scale": 1.4, "rot": 30, "colors": ice_tint}] + shards)

	# Decor, tinted by the ground colour.
	_save_mesh("decor_rock", [{"src": "space/rock_largeB", "scale": 1.0, "colors": rock_tint}])
	_save_mesh("decor_crater", [{"src": "space/crater", "scale": Vector3(4.0, 1.6, 4.0),
		"colors": {"rock": TINT, "rockDark": Color(0.72, 0.72, 0.72)}}])


func _bake_nature() -> void:
	# Leaves are near-white so each MultiMesh instance's colour tints them; trunks keep their colour.
	_save_mesh("tree_pine", [{"src": "nature/tree_pineRoundA", "scale": 1.85, "colors": {"leafsDark": LEAF}}])
	_save_mesh("tree_round", [{"src": "nature/tree_default", "scale": 1.45, "colors": {"leafsGreen": LEAF}}])
	_save_mesh("grass_tuft", [
		{"src": "nature/grass_large", "scale": 2.2, "colors": {"grass": LEAF}},
		{"src": "nature/grass_leafs", "scale": 2.4, "pos": Vector3(0.45, 0, 0.2), "rot": 60, "colors": {"grass": LEAF}},
		{"src": "nature/plant_bushSmall", "scale": 1.8, "pos": Vector3(-0.35, 0, 0.35), "rot": 20, "colors": {"grass": TINT_SHADE}},
	])
	var stem := {"grass": Color("5e9a4a")}
	_save_mesh("flowers", [
		{"src": "nature/flower_yellowA", "scale": 2.4, "pos": Vector3(0.0, 0, 0.0), "colors": stem},
		{"src": "nature/flower_redA", "scale": 2.2, "pos": Vector3(0.35, 0, 0.25), "rot": 90, "colors": stem},
		{"src": "nature/flower_purpleA", "scale": 2.3, "pos": Vector3(-0.3, 0, 0.3), "rot": 200, "colors": stem},
	])
	_save_mesh("lily", [{"src": "nature/lily_large", "scale": 3.0}])


# --- Buildings ---------------------------------------------------------------------------

func _bake_buildings() -> void:
	var antenna := CylinderMesh.new()
	antenna.top_radius = 0.05
	antenna.bottom_radius = 0.07
	antenna.height = 1.2
	antenna.radial_segments = 6
	antenna.rings = 0
	var hub := _save_mesh("hub", [
		{"src": "space/hangar_roundB", "scale": 1.5},
		{"mesh": antenna, "color": Color("9a948c"), "xform": Transform3D(Basis(), Vector3(0.7, 3.1, -0.5))},
		{"src": "space/satelliteDish_large", "scale": 0.9, "pos": Vector3(-1.1, 2.1, -0.6), "rot": 150},
	])
	var hub_scene := _root("Hub", hub)
	_glow(hub_scene, "Blink", _sphere(0.13), Color("ff6a4a"), 1.0, Vector3(0.7, 3.78, -0.5))
	_save_scene(hub_scene, "hub")

	var smelter := _save_mesh("smelter", [
		{"src": "space/machine_generatorLarge", "scale": 2.2, "rot": 90},
		{"src": "space/chimney_detailed", "scale": Vector3(1.4, 1.35, 1.4), "pos": Vector3(-0.85, 0, -0.75)},
	])
	var sm := _root("Smelter", smelter)
	_glow(sm, "Glow", _quad(1.1, 0.5), Color("ff7a2a"), 0.4, Vector3(0, 0.65, 1.15))
	_save_scene(sm, "smelter")

	var electrolyser := _save_mesh("electrolyser", [
		{"src": "space/machine_barrelLarge", "scale": 2.6, "pos": Vector3(0, 0, 0.15)},
		{"src": "space/machine_barrel", "scale": 1.6, "pos": Vector3(-0.95, 0, -0.75), "rot": 90},
		{"src": "space/machine_barrel", "scale": 1.6, "pos": Vector3(0.95, 0, -0.75), "rot": 90},
	])
	var el := _root("Electrolyser", electrolyser)
	_glow(el, "Glow", _ring(1.02, 0.06), Color("8fe3ff"), 0.4, Vector3(0, 0.35, 0.15))
	_save_scene(el, "electrolyser")

	var plants := []
	for i in 7:
		var a := float(i) / 7.0 * TAU + 0.3
		var r := 1.25 if i > 0 else 0.0
		var src := "nature/tree_cone" if i % 2 == 0 else "nature/plant_bushSmall"
		plants.append({"src": src, "scale": 1.3 if i % 2 == 0 else 2.6, "pos": Vector3(cos(a) * r, 0.2, sin(a) * r), "rot": i * 47})
	var greenhouse := _save_mesh("greenhouse", [
		{"src": "space/hangar_roundGlass", "scale": 1.55, "glass": {"dark": Color(Color("b6f0b0"), 0.35)}},
	] + plants)
	var gh := _root("Greenhouse", greenhouse)
	_glow(gh, "Glow", _ring(2.62, 0.07), Color("86e07c"), 0.4, Vector3(0, 0.12, 0))
	_save_scene(gh, "greenhouse")

	var bay := _save_mesh("drone_bay", [
		{"src": "space/platform_large", "scale": Vector3(1.6, 2.2, 1.5)},
		{"src": "space/satelliteDish_large", "scale": 1.5, "pos": Vector3(-1.2, 0, -1.1), "rot": 35},
		{"src": "space/pipe_straight", "scale": 0.8, "pos": Vector3(1.25, 0, -1.05), "rot": 90},
	])
	var by := _root("DroneBay", bay)
	_glow(by, "Glow", _ring(0.9, 0.06), Color("f2b35b"), 0.5, Vector3(0, 0.26, 0.1))
	_save_scene(by, "drone_bay")

	var outfitter := _save_mesh("outfitter", [{"src": "space/hangar_smallA", "scale": Vector3(1.35, 1.5, 1.2)}])
	var of := _root("Outfitter", outfitter)
	_glow(of, "Sign", _quad(1.6, 0.35), Color("f2b35b"), 0.65, Vector3(0, 1.75, 0.0), Vector3(-90, 0, 0))
	_save_scene(of, "outfitter")


# --- Colony (M4) --------------------------------------------------------------------------

func _bake_colony() -> void:
	# Rigged characters, posed from their idle animation's first frame (arms down).
	for c in COLONISTS:
		_save_mesh("colonist_" + c, [{"src": "characters/character-" + c, "scale": COLONIST_SCALE, "pose": "idle"}])

	# A small rocket on landing legs; faces +Z like everything else.
	_save_mesh("lander", [
		{"src": "space/rocket_baseA", "scale": 1.5},
		# The fuel tank sits down inside the base's landing legs.
		{"src": "space/rocket_fuelA", "scale": 1.5, "pos": Vector3(0, 1.3, 0)},
		{"src": "space/rocket_topA", "scale": 1.5, "pos": Vector3(0, 1.3 + 0.72, 0)},
	])

	var habitat := _save_mesh("habitat", [
		{"src": "space/hangar_smallB", "scale": Vector3(1.2, 1.3, 1.2)},
		{"src": "space/satelliteDish_large", "scale": 0.55, "pos": Vector3(0.35, 1.22, -0.45), "rot": 200},
	])
	var hab := _root("Habitat", habitat)
	_glow(hab, "Glow", _quad(0.5, 0.3), Color("ffd98a"), 0.6, Vector3(0, 1.15, 1.2))
	_save_scene(hab, "habitat")


# --- Merging -----------------------------------------------------------------------------

func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var d := base.duplicate()
	d.merge(extra, true)
	return d


## Merges the parts into one mesh (plus a glass surface if any part has glass) and saves it.
func _save_mesh(mesh_name: String, parts: Array) -> ArrayMesh:
	var solid := _Bucket.new()
	var glass := _Bucket.new()
	for part in parts:
		if part.get("stack", false):
			var top := 0.0
			for v in solid.verts:
				top = maxf(top, v.y)
			part = _with(part, {"pos": part.get("pos", Vector3.ZERO) + Vector3(0, top, 0)})
		if part.has("mesh"):
			_add_arrays(solid, part.mesh.surface_get_arrays(0), part.get("xform", Transform3D.IDENTITY), part.color)
			continue
		var src: Node3D = load(MODELS + part.src + ".glb").instantiate()
		if part.has("pose"):
			# Rigged models (Mini Characters) are bound in a T-pose: pose the skeleton first.
			root.add_child(src)
			var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
			ap.play(part.pose)
			ap.seek(0.0, true)
		var meshes := _mesh_nodes(src)
		var box := _bounds(meshes)
		var recentre := Transform3D(Basis(), -Vector3(box.get_center().x, box.position.y, box.get_center().z))
		var s = part.get("scale", 1.0)
		var sv: Vector3 = s if s is Vector3 else Vector3.ONE * s
		var place := Transform3D(Basis(Vector3.UP, deg_to_rad(part.get("rot", 0.0))).scaled(sv), part.get("pos", Vector3.ZERO))
		var only: Array = part.get("nodes", [])
		var colors: Dictionary = part.get("colors", {})
		var glass_map: Dictionary = part.get("glass", {})
		for entry in meshes:
			var mi: MeshInstance3D = entry[0]
			if not only.is_empty() and not only.has(String(mi.name)):
				continue
			var xf: Transform3D = place * recentre * entry[1]
			var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin else null
			if skel and part.has("pose"):
				xf = place * recentre * _relative(src, skel)
			for si in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(si) as BaseMaterial3D
				var mat_name := mat.resource_name if mat else ""
				var arrays := mi.mesh.surface_get_arrays(si)
				if skel and part.has("pose"):
					arrays = _posed(arrays, mi.skin, skel)
				if glass_map.has(mat_name):
					_add_arrays(glass, arrays, xf, glass_map[mat_name])
				elif mat and mat.albedo_texture:
					_add_arrays(solid, arrays, xf, mat.albedo_color, _atlas(mat.albedo_texture))
				else:
					var c: Color = colors.get(mat_name, PALETTE.get(mat_name, mat.albedo_color if mat else Color.WHITE))
					_add_arrays(solid, arrays, xf, c)
		if src.is_inside_tree():
			root.remove_child(src)
		src.free()
	var mesh := ArrayMesh.new()
	mesh.resource_name = mesh_name
	solid.commit(mesh, KIT)
	glass.commit(mesh, KIT_GLASS)
	var path := MESHES + mesh_name + ".res"
	var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	print("%s: %d surface(s), %d tris -> %s" % [path, mesh.get_surface_count(), solid.tris() + glass.tris(), error_string(err)])
	_count += 1
	return load(path)


class _Bucket:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func tris() -> int:
		return indices.size() / 3

	func commit(mesh: ArrayMesh, mat: Material) -> void:
		if verts.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## Surface arrays skinned into the skeleton's current pose (in skeleton space).
func _posed(arrays: Array, skin: Skin, skel: Skeleton3D) -> Array:
	var binds: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(i))
		binds.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(i))
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / v.size()
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	for i in v.size():
		var pv := Vector3.ZERO
		var pn := Vector3.ZERO
		for k in per:
			var w := weights[i * per + k]
			if w <= 0.0:
				continue
			var t := binds[bones[i * per + k]]
			pv += (t * v[i]) * w
			pn += (t.basis * n[i]) * w
		out_v.append(pv)
		out_n.append(pn.normalized())
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = out_v
	out[Mesh.ARRAY_NORMAL] = out_n
	return out


func _relative(root_node: Node, node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root_node:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## A texture as a readable image for sampling colours.
func _atlas(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _add_arrays(b: _Bucket, arrays: Array, xf: Transform3D, color: Color, atlas: Image = null) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n = arrays[Mesh.ARRAY_NORMAL]
	var idx = arrays[Mesh.ARRAY_INDEX]
	var uv = arrays[Mesh.ARRAY_TEX_UV] if atlas else null
	var nb := xf.basis.inverse().transposed()
	var mirrored := xf.basis.determinant() < 0.0
	var base := b.verts.size()
	for i in v.size():
		b.verts.append(xf * v[i])
		b.normals.append((nb * n[i]).normalized() if n != null else Vector3.UP)
		if uv != null:
			var px := Vector2i(clampi(int(fposmod(uv[i].x, 1.0) * atlas.get_width()), 0, atlas.get_width() - 1),
				clampi(int(fposmod(uv[i].y, 1.0) * atlas.get_height()), 0, atlas.get_height() - 1))
			b.colors.append(atlas.get_pixelv(px) * color)
		else:
			b.colors.append(color)
	var list := PackedInt32Array()
	if idx == null or (idx as PackedInt32Array).is_empty():
		for i in v.size():
			list.append(i)
	else:
		list = idx
	for i in range(0, list.size(), 3):
		if mirrored:
			b.indices.append_array([base + list[i], base + list[i + 2], base + list[i + 1]])
		else:
			b.indices.append_array([base + list[i], base + list[i + 1], base + list[i + 2]])


## [MeshInstance3D, transform relative to the scene root] for every mesh node.
func _mesh_nodes(root_node: Node3D) -> Array:
	var out := []
	for mi in root_node.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = mi.transform
		var p := mi.get_parent()
		while p != null and p != root_node:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		out.append([mi, xf])
	return out


func _bounds(meshes: Array) -> AABB:
	var box := AABB()
	var first := true
	for entry in meshes:
		var b: AABB = entry[1] * (entry[0] as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- Scenes ------------------------------------------------------------------------------

func _root(root_name: String, mesh: ArrayMesh) -> Node3D:
	var r := Node3D.new()
	r.name = root_name
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = mesh
	r.add_child(mi)
	return r


## A pulsing light for BuildingView (it animates surface 0's albedo alpha).
func _glow(parent: Node3D, node_name: String, mesh: PrimitiveMesh, color: Color, opacity: float, pos: Vector3, rot := Vector3.ZERO) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, opacity)
	mesh.material = m
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)


func _save_scene(r: Node3D, file: String) -> void:
	for c in r.get_children():
		c.owner = r
	var packed := PackedScene.new()
	packed.pack(r)
	var path := BUILDINGS + file + ".tscn"
	print("%s -> %s" % [path, error_string(ResourceSaver.save(packed, path))])
	r.free()


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 6
	return s


func _quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q


func _ring(r: float, tube: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = 32
	t.ring_segments = 4
	return t
