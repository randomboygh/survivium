extends Node
## What every text field of the game's interface gets (TextField.fit), as the sign's lines
## first did on the phone (2026-11-09/11):
## - the caret goes after the text written when the field takes the keys (a phone's keyboard
##   is shown it before the tap's own place), and nothing is selected then;
## - the caret is drawn while the field is edited even when the window has no focus: on the
##   web the keyboard's hidden input takes the page's focus from the canvas, and a LineEdit
##   hides its caret without it;
## - on the web, the browser's tab hidden or shown again takes the keys from the field and
##   closes the keyboard, so the next tap opens it as the first time did (on Android a tab
##   switched and back left the keyboard up with no letter reaching the field);
## - on a touch screen a touch that begins off the field being edited (on the world, on a
##   button, on the window's empty place) lets the field go as the finger lifts, after a
##   button's action, and so the keyboard closes; one that begins on the field never does,
##   wherever the keyboard coming up moved the field from under the finger. While
##   the keyboard is up a touch leaves the page's focus with it (tools/web_patch.py reads `up`
##   below), so the keyboard stays up under a finger on a button or on another field, and the
##   window does not move under the finger; once the phone puts the keyboard away (`up`
##   false) a touch gives the canvas the focus as the engine does, and the next tap on a field
##   opens the keyboard again.
## This node, a child of the field, watches the page's count of tab switches while the field
## has the keys, and the touches.

## Counts the page's tab switches and tells whether the keyboard is up: the visible area
## lower than the tallest seen at this width (strict, no `arguments`: CLAUDE.md).
const TABS := """
(function () {
	'use strict';
	if (window.survivium_tabs) {
		return;
	}
	var me = { gen: 0, up: false, tall: 0, wide: 0 };
	document.addEventListener('visibilitychange', function () {
		me.gen += 1;
	});
	function seen() {
		var v = window.visualViewport;
		return v ? v.height : window.innerHeight;
	}
	function check() {
		if (window.innerWidth !== me.wide) {
			me.wide = window.innerWidth;
			me.tall = 0;
		}
		var h = seen();
		if (h > me.tall) {
			me.tall = h;
		}
		me.up = h < me.tall * 0.85;
	}
	if (window.visualViewport) {
		window.visualViewport.addEventListener('resize', check);
	}
	window.addEventListener('resize', check);
	check();
	window.survivium_tabs = me;
})();
"""
## How often the count is read while the field has the keys, in seconds.
const EVERY := 0.25

static var _tabs = null

var _field: LineEdit
var _seen := 0
var _in := 0.0
## The touch began off the field while it had the keys: it lets it go as it lifts.
var _armed := false


## Makes `f` behave as every text field of the game does (see the top); returns it.
static func fit(f: LineEdit) -> LineEdit:
	f.select_all_on_focus = false
	f.focus_entered.connect(_to_end.bind(f))
	f.editing_toggled.connect(_force_caret.bind(f))
	if OS.has_feature("web"):
		if _tabs == null:
			JavaScriptBridge.eval(TABS, true)
			_tabs = JavaScriptBridge.get_interface("survivium_tabs")
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


## Reads the count and the touches only while the field has the keys.
func _watch(on: bool) -> void:
	set_process(on and _tabs != null)
	set_process_input(on)
	_armed = false
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


## A touch that began off the field lets it go as the finger lifts, once the interface has
## had the touch (a button acts first), unless the field took the keys again or another one
## did. Where the finger lifts does not matter: the keyboard coming up moves the field.
func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch or event.index != 0:
		return
	if event.pressed:
		_armed = not _field.get_global_rect().has_point(event.position)
	elif _armed:
		_armed = false
		_let_go.call_deferred()


func _let_go() -> void:
	if _field.has_focus():
		_field.release_focus()
