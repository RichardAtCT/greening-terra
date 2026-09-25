class_name PadView
extends Node3D
## A floor pad: where it is, whether it's in play and whether the player is on it. PadBatch draws
## every pad (its dark slab, its bordered top with the title and subtitle, and its floating icons)
## in shared MultiMeshes, so a pad costs no draw calls of its own.

const LIFT := 0.03

var info: PadInfo
## Where this pad's title and subtitle sit in PadBatch's text atlas.
var atlas_cell: int = -1
var near := false
## The subtitle changed and PadBatch hasn't redrawn it yet.
var label_dirty := false


func setup(p_info: PadInfo) -> void:
	info = p_info
	name = "Pad_" + info.key
	position = Vector3(info.position.x, 0, info.position.y)


## The icons floating over this pad: item ids, or &"coin" for a pay pad. PadBatch draws them.
func icon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if info.kind == PadInfo.Kind.PAY:
		ids.append(PadBatch.COIN)
	else:
		ids.assign(info.icons)
	return ids


## Changes the subtitle (an UPGRADE pad's next mark and cost). PadBatch redraws the pad's text.
func set_label(text: String) -> void:
	if info.label != text:
		info.label = text
		label_dirty = true


func set_near(p_near: bool) -> void:
	if p_near == near:
		return
	near = p_near
	position.y = LIFT if near else 0.0
