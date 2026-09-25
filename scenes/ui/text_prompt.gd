class_name TextPrompt
extends RefCounted
## Asks the player for a line of text, or shows text to copy.
## On web it uses the browser's own prompt(), which works with the iPhone keyboard and clipboard
## (Godot's text fields don't open the iOS keyboard). Elsewhere it shows a small Godot dialog.


## Calls done(text) with what was entered, or done(null) if cancelled.
static func ask(parent: Node, title: String, initial: String, done: Callable) -> void:
	if OS.has_feature("web"):
		var js := "(function(){var r=window.prompt(%s,%s);return r===null?'\\u0000':r;})()" % [JSON.stringify(title), JSON.stringify(initial)]
		var result = JavaScriptBridge.eval(js, true)
		done.call(null if result == null or result == "\u0000" else str(result))
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	var edit := LineEdit.new()
	edit.text = initial
	edit.custom_minimum_size.x = 320
	edit.select_all_on_focus = true
	dialog.add_child(edit)
	dialog.register_text_enter(edit)
	dialog.confirmed.connect(func():
		done.call(edit.text)
		dialog.queue_free())
	dialog.canceled.connect(func():
		done.call(null)
		dialog.queue_free())
	parent.add_child(dialog)
	dialog.popup_centered()
	edit.grab_focus()


## Shows text the player can copy. Also tries to put it on the clipboard directly.
static func show_copyable(parent: Node, title: String, text: String) -> void:
	DisplayServer.clipboard_set(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.prompt(%s,%s)" % [JSON.stringify(title), JSON.stringify(text)], true)
		return
	ask(parent, title, text, func(_t): pass)
