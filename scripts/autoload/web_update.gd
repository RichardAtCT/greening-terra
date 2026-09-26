extends Node
## On web, notices when a new version of the game has been deployed and offers to switch to it.
## The exported service worker serves the game from its cache, so a new version would otherwise
## load only on the second launch after every copy of the game was closed. This checks for a new
## service worker at start, every 30 minutes and whenever the page is shown again. Once one is
## waiting, a bar offers Update: it saves, tells the waiting worker to take over (with the listener
## tools/export_web.sh adds to it) and reloads.

signal update_ready

const CHECK_INTERVAL := 1800.0
## Every call is guarded: a page without a service worker (first visit, storage blocked) never offers.
const JS := """
(function () {
	if (window.gtUpdate || !('serviceWorker' in navigator)) return;
	var sw = navigator.serviceWorker;
	var u = window.gtUpdate = { reg: null, cb: null, found: false };
	function offer() {
		// No controller means this is the first install, not an update.
		if (u.found || !u.reg || !u.reg.waiting || !sw.controller) return;
		u.found = true;
		if (u.cb) u.cb();
	}
	u.watch = function (cb) {
		u.cb = cb;
		sw.ready.then(function (reg) {
			u.reg = reg;
			offer();
			reg.addEventListener('updatefound', function () {
				var w = reg.installing;
				if (w) w.addEventListener('statechange', function () { if (w.state === 'installed') offer(); });
			});
		});
	};
	u.check = function () {
		if (u.reg) u.reg.update().catch(function () {});
	};
	u.apply = function () {
		var w = u.reg && u.reg.waiting;
		var done = false;
		function go() { if (!done) { done = true; location.reload(); } }
		if (!w) { go(); return; }
		sw.addEventListener('controllerchange', go);
		w.postMessage('skip-waiting');
		// A worker without the listener never takes over; reload anyway.
		setTimeout(go, 3000);
	};
	document.addEventListener('visibilitychange', function () { if (!document.hidden) u.check(); });
})();
"""

var is_ready := false
var _ready_cb: JavaScriptObject
var _check_t := 0.0
var _layer: CanvasLayer
var _bar: PanelContainer
var _update_btn: Button


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	JavaScriptBridge.eval(JS, true)
	var api := JavaScriptBridge.get_interface("gtUpdate")
	if api == null:
		set_process(false)
		return
	_ready_cb = JavaScriptBridge.create_callback(func(_args): offer_update())
	api.watch(_ready_cb)


func _process(delta: float) -> void:
	_check_t += delta
	if _check_t >= CHECK_INTERVAL:
		_check_t = 0.0
		JavaScriptBridge.eval("window.gtUpdate && window.gtUpdate.check()", true)


## Shows the Update bar. Called from the page once a new version is waiting.
func offer_update() -> void:
	if is_ready:
		return
	is_ready = true
	set_process(false)
	if not _bar:
		_build_bar()
	_bar.offset_top = SafeArea.insets(get_window()).x + 12.0
	_layer.visible = true
	update_ready.emit()


func is_bar_shown() -> bool:
	return _layer != null and _layer.visible


func _on_later() -> void:
	_layer.visible = false


func _on_update() -> void:
	_update_btn.disabled = true
	_update_btn.text = "Updating…"
	GameState.save()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gtUpdate.apply()", true)


func _build_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	_layer.visible = false
	add_child(_layer)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", UiStyle.panel(12, 12, 8, Color(UiStyle.PANEL, 0.94)))
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_child(row)
	var text := UiStyle.label("New version ready", UiStyle.DISPLAY, 15, UiStyle.INK)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)
	var later := UiStyle.button("Later")
	later.pressed.connect(_on_later)
	row.add_child(later)
	_update_btn = UiStyle.button("Update", true)
	_update_btn.pressed.connect(_on_update)
	row.add_child(_update_btn)
