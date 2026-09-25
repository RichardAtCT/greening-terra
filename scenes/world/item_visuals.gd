class_name ItemVisuals
extends RefCounted
## Shared meshes and materials for items, so every stack and flyer reuses the same resources.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func mesh(shape: ItemDef.Shape) -> Mesh:
	if _meshes.has(shape):
		return _meshes[shape]
	var m: Mesh
	match shape:
		ItemDef.Shape.ROCK:
			m = MeshUtil.icosahedron(0.19)
		ItemDef.Shape.CRYSTAL:
			m = MeshUtil.octahedron(0.21)
		ItemDef.Shape.PLATE:
			var b := BoxMesh.new()
			b.size = Vector3(0.42, 0.12, 0.42)
			m = b
		ItemDef.Shape.CANISTER:
			var c := CylinderMesh.new()
			c.top_radius = 0.13
			c.bottom_radius = 0.13
			c.height = 0.34
			c.radial_segments = 10
			c.rings = 0
			m = c
		_:
			var s := SphereMesh.new()
			s.radius = 0.18
			s.height = 0.36
			s.radial_segments = 10
			s.rings = 5
			m = s
	_meshes[shape] = m
	return m


static func material(item: ItemDef) -> StandardMaterial3D:
	if _materials.has(item.id):
		return _materials[item.id]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.color
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if item.emissive != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = item.emissive
	_materials[item.id] = mat
	return mat


## A standalone mesh instance for one item (flyers, drone cargo).
static func instance(item: ItemDef) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(item.shape)
	mi.material_override = material(item)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Plain Lambert-style material for placeholder geometry.
static func lambert(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
