extends Node
## Makes one UI unit equal one CSS pixel on web (and one logical point on Hi-DPI desktops),
## so joystick and HUD sizes match the prototype on every screen.


func _ready() -> void:
	get_window().content_scale_factor = maxf(1.0, DisplayServer.screen_get_scale())
