class_name ResourceNodeView
extends Node3D
## A diggable cluster of rocks or crystals that shrinks as it empties and shakes when dug. It only
## places itself; NodeBatch draws every node of one resource in a single MultiMesh.

var def: ResourceNodeDef
## The model's own turn, so neighbours differ.
var yaw := 0.0
var _shake := 0.0
var _time := 0.0


func setup(p_def: ResourceNodeDef, pos: Vector2, rng: RandomNumberGenerator) -> void:
	def = p_def
	position = Vector3(pos.x, 0, pos.y)
	yaw = rng.randf() * TAU


func dug() -> void:
	_shake = 0.2


func update_view(stock: int, max_stock: int, delta: float) -> void:
	_time += delta
	var s := 0.001 if stock <= 0 else 0.45 + 0.55 * float(stock) / max_stock
	scale = Vector3.ONE * s
	rotation.y = 0.0
	if _shake > 0.0:
		_shake -= delta
		rotation.y = sin(_time * 60.0) * 0.08


## Where NodeBatch draws this node's model.
func model_transform() -> Transform3D:
	return transform * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
