class_name SoundDef
extends Resource
## One sound effect: a few variations, picked at random, played on the SFX bus.

@export var id: StringName
@export var streams: Array[AudioStream] = []
@export var volume_db: float = 0.0
## Random pitch spread, e.g. 0.08 plays between 0.92 and 1.08.
@export var pitch_jitter: float = 0.06
## The same sound won't start again sooner than this (seconds), so bursts don't pile up.
@export var min_interval: float = 0.05
