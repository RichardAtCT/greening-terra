extends Node3D
## M0 pipeline test scene: wires the joystick to the player and shows a small debug readout.

@onready var _player: PlayerController = $Player
@onready var _joystick: TouchJoystick = $HUD/Joystick
@onready var _readout: Label = $HUD/Readout


func _ready() -> void:
	_player.joystick = _joystick


func _process(_delta: float) -> void:
	var p := _player.global_position
	_readout.text = "Greening Tessera · M0\n%d fps · x %.1f  z %.1f\ndrag anywhere or WASD" % [
		Engine.get_frames_per_second(), p.x, p.z]
