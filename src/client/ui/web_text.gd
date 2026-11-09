extends RefCounted
## Typing into fields on a phone's browser with the page's own text box instead of the
## engine's (the sign window's lines, SignWindow). The engine's virtual keyboard keeps a
## hidden box it disables when the page loses focus; after the player switched the
## browser's tab and came back, the keyboard came up but no letter reached the field
## (2026-11-09, on Android). Here one box of the page, never disabled, takes the letters:
## a touch that ends on an armed field focuses it right in the browser's touch handler
## (so the browser always opens the keyboard for it), its text is the field's, and every
## change is copied into the field. Off the web or without a touch screen nothing is
## armed (`on` is false) and the fields type as they always did.

## The box and its touch watch, set up once per page (strict, no `arguments`: CLAUDE.md).
const SCRIPT := """
(function () {
	'use strict';
	if (window.survivium_text) {
		return;
	}
	var canvas = document.getElementById('canvas');
	var box = document.createElement('input');
	box.type = 'text';
	box.autocomplete = 'off';
	box.spellcheck = false;
	box.setAttribute('autocapitalize', 'sentences');
	box.setAttribute('aria-hidden', 'true');
	var s = box.style;
	s.position = 'fixed';
	s.left = '0px';
	s.top = '0px';
	s.width = '100%';
	s.height = '32px';
	s.fontSize = '16px';
	s.opacity = '0';
	s.border = '0';
	s.padding = '0';
	s.margin = '0';
	s.background = 'transparent';
	s.color = 'transparent';
	s.zIndex = '-1';
	s.pointerEvents = 'none';
	document.body.appendChild(box);
	var me = {
		fields: [],
		at: -1,
		onfocus: null,
		oninput: null,
		onenter: null,
		onblur: null
	};
	function css(r) {
		var b = canvas.getBoundingClientRect();
		var k = canvas.width > 0 ? b.width / canvas.width : 1;
		return [b.left + r[0] * k, b.top + r[1] * k, r[2] * k, r[3] * k];
	}
	function open(i) {
		var f = me.fields[i];
		me.at = i;
		box.maxLength = f.max;
		box.value = f.text;
		box.focus({ preventScroll: true });
		var n = box.value.length;
		box.setSelectionRange(n, n);
		if (me.onfocus) {
			me.onfocus(i);
		}
	}
	canvas.addEventListener('touchend', function (e) {
		if (me.fields.length === 0 || e.changedTouches.length === 0) {
			return;
		}
		var t = e.changedTouches[0];
		for (var i = 0; i < me.fields.length; i++) {
			var r = css(me.fields[i].rect);
			if (t.clientX >= r[0] && t.clientX < r[0] + r[2] && t.clientY >= r[1] && t.clientY < r[1] + r[3]) {
				open(i);
				return;
			}
		}
	}, true);
	box.addEventListener('input', function () {
		if (me.at >= 0) {
			me.fields[me.at].text = box.value;
			if (me.oninput) {
				me.oninput(me.at, box.value, box.selectionEnd);
			}
		}
	});
	box.addEventListener('keydown', function (e) {
		if (e.key === 'Enter' && me.at >= 0) {
			e.preventDefault();
			if (me.onenter) {
				me.onenter(me.at);
			}
		}
	});
	box.addEventListener('blur', function () {
		var i = me.at;
		me.at = -1;
		if (i >= 0 && me.onblur) {
			me.onblur(i);
		}
	});
	// The fields as JSON: [{rect: [x, y, w, h] in the canvas's pixels, text, max}].
	me.arm = function (json) {
		me.fields = JSON.parse(json);
		if (me.at >= me.fields.length) {
			me.disarm();
		}
	};
	me.focus = function (i) {
		if (i >= 0 && i < me.fields.length) {
			open(i);
		}
	};
	me.disarm = function () {
		me.fields = [];
		me.at = -1;
		box.blur();
		box.value = '';
	};
	window.survivium_text = me;
})();
"""

## A field took the box (its index); its letters changed (index, text, caret); Enter
## was pressed in it (index); the box let go of it (index).
signal focused(i: int)
signal typed(i: int, text: String, caret: int)
signal entered(i: int)
signal left(i: int)

## True when the fields go through the page's box (the web on a touch screen).
var on := false
var _js = null
## The browser's callbacks, kept while the box may call them.
var _calls: Array = []


func _init() -> void:
	if not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return
	JavaScriptBridge.eval(SCRIPT, true)
	_js = JavaScriptBridge.get_interface("survivium_text")
	if _js == null:
		return
	on = true
	_calls = [JavaScriptBridge.create_callback(_on_focus), JavaScriptBridge.create_callback(_on_input),
		JavaScriptBridge.create_callback(_on_enter), JavaScriptBridge.create_callback(_on_blur)]
	_js.onfocus = _calls[0]
	_js.oninput = _calls[1]
	_js.onenter = _calls[2]
	_js.onblur = _calls[3]


## Arms `fields` (LineEdits on the screen): a touch ending on one gives it the box. Call
## again when they move or their text changes.
func arm(fields: Array) -> void:
	if not on:
		return
	var list := []
	for f: LineEdit in fields:
		var r := f.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, f.size)
		list.append({"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "text": f.text, "max": f.max_length if f.max_length > 0 else 524288})
	_js.arm(JSON.stringify(list))


## Gives field `i` of the armed ones the box (Enter going to the next line).
func focus(i: int) -> void:
	if on:
		_js.focus(i)


## Lets go of the fields and closes the keyboard.
func disarm() -> void:
	if on:
		_js.disarm()


func _on_focus(args: Array) -> void:
	focused.emit(int(args[0]))


func _on_input(args: Array) -> void:
	typed.emit(int(args[0]), str(args[1]), int(args[2]))


func _on_enter(args: Array) -> void:
	entered.emit(int(args[0]))


func _on_blur(args: Array) -> void:
	left.emit(int(args[0]))
