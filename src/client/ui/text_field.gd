extends Node
## What every text field of the game's interface gets (TextField.fit), as the sign's lines
## first did on the phone (2026-11-09/10):
## - the caret goes after the text written when the field takes the keys (a phone's keyboard
##   is shown it before the tap's own place), and nothing is selected then;
## - the caret is drawn while the field is edited even when the window has no focus: on the
##   web the keyboard's hidden input takes the page's focus from the canvas, and a LineEdit
##   hides its caret without it;
## - on the web, the browser's tab hidden or shown again takes the keys from the field and
##   closes the keyboard, so the next tap opens it as the first time did (on Android a tab
##   switched and back left the keyboard up with no letter reaching the field). This node,
##   a child of the field, watches the page's count of those switches while the field has
##   the keys.

## Counts the page's tab switches, once per page (strict, no `arguments`: CLAUDE.md).
const TABS := """
(function () {
	'use strict';
	if (window.survivium_tabs) {
		return;
	}
	var me = { gen: 0 };
	document.addEventListener('visibilitychange', function () {
		me.gen += 1;
	});
	window.survivium_tabs = me;
})();
"""
## How often the count is read while the field has the keys, in seconds.
const EVERY := 0.25

static var _tabs = null

var _field: LineEdit
var _seen := 0
var _in := 0.0


## Makes `f` behave as every text field of the game does (see the top); returns it.
static func fit(f: LineEdit) -> LineEdit:
	f.select_all_on_focus = false
	f.focus_entered.connect(_to_end.bind(f))
	f.editing_toggled.connect(_force_caret.bind(f))
	if OS.has_feature("web"):
		if _tabs == null:
			JavaScriptBridge.eval(TABS, true)
			_tabs = JavaScriptBridge.get_interface("survivium_tabs")
	if _tabs != null:
		var watch = (load("res://src/client/ui/text_field.gd") as GDScript).new()
		watch._field = f
		f.add_child(watch)
	return f


static func _to_end(f: LineEdit) -> void:
	f.caret_column = f.text.length()


static func _force_caret(on: bool, f: LineEdit) -> void:
	f.caret_force_displayed = on


func _ready() -> void:
	_field.focus_entered.connect(_watch.bind(true))
	_field.focus_exited.connect(_watch.bind(false))
	_watch(_field.has_focus())


## Reads the count only while the field has the keys.
func _watch(on: bool) -> void:
	set_process(on and _tabs != null)
	if on and _tabs != null:
		_seen = int(_tabs.gen)
		_in = EVERY


func _process(delta: float) -> void:
	_in -= delta
	if _in > 0.0:
		return
	_in = EVERY
	var gen := int(_tabs.gen)
	if gen != _seen:
		_seen = gen
		_field.release_focus()
		DisplayServer.virtual_keyboard_hide()
