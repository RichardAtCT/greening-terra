extends SceneTree
## Regenerates the placeholder building/actor scenes that mirror the prototype's primitive models.
## Run: godot --headless --script tools/dev/gen_placeholder_models.gd
## M3 replaces these with real models; after that this script is only a reference.

const OUT := "res://scenes/buildings/"


func _init() -> void:
	_save(_hub(), OUT + "hub.tscn")
	_save(_smelter(), OUT + "smelter.tscn")
	_save(_electrolyser(), OUT + "electrolyser.tscn")
	_save(_greenhouse(), OUT + "greenhouse.tscn")
	_save(_drone_bay(), OUT + "drone_bay.tscn")
	_save(_outfitter(), OUT + "outfitter.tscn")
	quit()


func _save(root: Node3D, path: String) -> void:
	_own(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, path)
	print("%s -> %s" % [path, error_string(err)])
	root.free()


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)


func lam(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func glow(c: Color, opacity := 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, opacity)
	return m


func add(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	if mesh is ArrayMesh:
		(mesh as ArrayMesh).surface_set_material(0, mat)
	else:
		mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func dome(r: float, seg := 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r
	s.is_hemisphere = true
	s.radial_segments = seg
	s.rings = seg / 2
	return s


func ring(r: float, tube: float, seg := 32) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = seg
	t.ring_segments = 6
	return t


func quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q


func root(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	return r


func _hub() -> Node3D:
	var g := root("Hub")
	add(g, "Base", cyl(2.4, 2.6, 0.35, 24), lam(Color("5d5552")), Vector3(0, 0.17, 0))
	add(g, "Dome", dome(2.05), lam(Color("e9e3d8")), Vector3(0, 0.35, 0))
	add(g, "Band", ring(2.08, 0.09), lam(Color("f2b35b")), Vector3(0, 0.8, 0))
	add(g, "Antenna", cyl(0.05, 0.05, 1.6, 6), lam(Color("9a948c")), Vector3(0.7, 2.9, -0.4))
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	s.radial_segments = 8
	s.rings = 6
	add(g, "Blink", s, glow(Color("ff6a4a"), 1.0), Vector3(0.7, 3.75, -0.4))
	return g


func _smelter() -> Node3D:
	var g := root("Smelter")
	add(g, "Body", box(2.6, 1.7, 2.2), lam(Color("7b5a48")), Vector3(0, 0.85, 0))
	add(g, "Roof", box(2.8, 0.2, 2.4), lam(Color("4d3a33")), Vector3(0, 1.8, 0))
	add(g, "Chimney", cyl(0.24, 0.3, 1.6, 8), lam(Color("3d302c")), Vector3(-0.7, 2.5, -0.4))
	add(g, "Glow", quad(1.2, 0.6), glow(Color("ff7a2a")), Vector3(0, 0.7, 1.11))
	return g


func _electrolyser() -> Node3D:
	var g := root("Electrolyser")
	add(g, "Body", box(2.4, 1.2, 2.0), lam(Color("4d6c80")), Vector3(0, 0.6, 0))
	for sx in [-0.6, 0.6]:
		var side := "L" if sx < 0 else "R"
		add(g, "Tank" + side, cyl(0.45, 0.45, 2.2, 12), lam(Color("d8dde0")), Vector3(sx, 1.7, -0.3))
		add(g, "Cap" + side, dome(0.45, 12), lam(Color("d8dde0")), Vector3(sx, 2.8, -0.3))
	add(g, "Glow", quad(1.8, 0.25), glow(Color("8fe3ff")), Vector3(0, 0.75, 1.01))
	return g


func _greenhouse() -> Node3D:
	var g := root("Greenhouse")
	add(g, "Base", cyl(2.6, 2.7, 0.3, 24), lam(Color("5a534e")), Vector3(0, 0.15, 0))
	# Nine seedling cones merged into one mesh (one draw call).
	var parts := []
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var r := 1.3 if i % 3 != 0 else 0.4
		parts.append([cyl(0.0, 0.3, 0.9, 5), Transform3D(Basis(), Vector3(cos(a) * r, 0.75, sin(a) * r)), Color.WHITE])
	add(g, "Plants", MeshUtil.merge(parts), lam(Color("4f9a44")), Vector3.ZERO)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(Color("b6f0b0"), 0.32)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	add(g, "Dome", dome(2.4, 20), glass, Vector3(0, 0.3, 0))
	add(g, "Glow", ring(2.45, 0.07), glow(Color("86e07c")), Vector3(0, 0.35, 0))
	return g


func _drone_bay() -> Node3D:
	var g := root("DroneBay")
	add(g, "Platform", box(3.2, 0.3, 3.0), lam(Color("5a5256")), Vector3(0, 0.15, 0))
	add(g, "Ring", ring(1.0, 0.07, 28), lam(Color("f2b35b")), Vector3(0, 0.33, 0))
	add(g, "Tower", box(0.5, 2.2, 0.5), lam(Color("6b6468")), Vector3(-1.3, 1.1, -1.1))
	return g


func _outfitter() -> Node3D:
	var g := root("Outfitter")
	add(g, "Body", box(2.6, 1.6, 1.3), lam(Color("5f5f70")), Vector3(0, 0.8, 0))
	add(g, "Sign", quad(2.0, 0.7), glow(Color("f2b35b"), 0.65), Vector3(0, 1.05, 0.66))
	add(g, "Awning", box(2.9, 0.12, 1.6), lam(Color("d9794a")), Vector3(0, 1.7, 0.2))
	return g
