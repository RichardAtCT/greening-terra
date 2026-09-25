class_name SafeArea
extends RefCounted
## Screen insets (notch, home indicator) in UI units, so the HUD can stay clear of them.

const JS := "(function(){var d=document.createElement('div');d.style.cssText='position:fixed;left:0;top:0;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';document.body.appendChild(d);var s=getComputedStyle(d);var r=[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(function(v){return parseFloat(v)||0;}).join(',');d.remove();return r;})()"


## Returns (top, right, bottom, left) insets in UI units.
static func insets(window: Window) -> Vector4:
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval(JS, true)
		if typeof(raw) == TYPE_STRING:
			var p: PackedStringArray = raw.split(",")
			if p.size() == 4:
				# CSS pixels already equal UI units (see DisplayScale).
				return Vector4(p[0].to_float(), p[1].to_float(), p[2].to_float(), p[3].to_float())
		return Vector4.ZERO
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if safe.size == Vector2i.ZERO or screen == Vector2i.ZERO:
		return Vector4.ZERO
	var s := window.content_scale_factor
	return Vector4(safe.position.y, screen.x - safe.end.x, screen.y - safe.end.y, safe.position.x) / s
