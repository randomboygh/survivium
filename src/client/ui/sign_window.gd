extends "res://src/client/ui/kit/window.gd"
## The window a tap on a sign opens (decision 183): its name and its text, a field for
## each of its lines (its item's `sign_lines`, `sign_width` letters each) when the
## player may build where it stands (Territory "build", the client's copy of the land),
## else the text to read and who may write it. «Сохранить» writes the lines through the
## server (Protocol.SIGN_WRITE, Placed.write), «Повернуть» turns a sign that is not on a
## wall a quarter (SIGN_TURN), «Закрыть» or Escape closes it. It covers the whole screen
## over a shade of the world behind; when the keyboard leaves the screen too short, the
## panel goes to its top (a window of the UI kit). `game` is the Main node. While a field has the keys, they do
## not walk the player (Controls._typing).
## The fields are the game's text fields (TextField.fit: caret, a tab switch on the web).
## With the playtest switch «Журнал клавиш» (Settings.keys_log) the
## window also shows, under its buttons, what the page did with the keys (KEYS_LOG): which
## element has them, the last keys, input and focus changes, so a phone that fails tells why.

const Items := preload("res://src/shared/content/items.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Lang := preload("res://src/shared/content/lang.gd")

const WIDTH := 240
const FIELD_H := 26
const ROW_H := 30
## What the page does with the keys, kept once per page (strict, no `arguments`: CLAUDE.md).
const KEYS_LOG := """
(function () {
	'use strict';
	if (window.survivium_keys) {
		return;
	}
	var me = { gen: 0, log: [] };
	function tag(t) {
		if (!t || !t.tagName) {
			return String(t);
		}
		var s = t.tagName.toLowerCase();
		if (t.id) {
			s += '#' + t.id;
		}
		if (t.disabled) {
			s += '-off';
		}
		if (t.style && t.style.display === 'none') {
			s += '-hid';
		}
		return s;
	}
	function add(s) {
		me.log.push(s);
		if (me.log.length > 6) {
			me.log.shift();
		}
	}
	document.addEventListener('keydown', function (e) {
		add('key ' + e.key + '/' + e.keyCode + ' ' + tag(e.target));
	}, true);
	document.addEventListener('input', function (e) {
		var v = e.target.value;
		add('in ' + (v === undefined ? '?' : v.length) + ' ' + tag(e.target));
	}, true);
	document.addEventListener('focusin', function (e) {
		add('fin ' + tag(e.target));
	}, true);
	document.addEventListener('focusout', function (e) {
		add('fout ' + tag(e.target));
	}, true);
	document.addEventListener('visibilitychange', function () {
		me.gen += 1;
		add('vis ' + document.visibilityState);
	});
	window.addEventListener('focus', function () {
		add('win focus');
	});
	window.addEventListener('blur', function () {
		add('win blur');
	});
	me.text = function () {
		var v = window.visualViewport;
		var c = document.getElementById('canvas');
		var r = c ? c.getBoundingClientRect() : null;
		var view = 'in ' + window.innerWidth + 'x' + window.innerHeight + ' sy ' + window.scrollY +
			(v ? ' vv ' + Math.round(v.width) + 'x' + Math.round(v.height) + '@' + Math.round(v.offsetTop) : '') +
			(r ? ' cv ' + Math.round(r.width) + 'x' + Math.round(r.height) + '@' + Math.round(r.top) : '');
		var a = navigator.userActivation;
		var page = ' page ' + (document.hasFocus() ? 'F' : '-') + (a ? (a.isActive ? 'A' : '-') + (a.hasBeenActive ? 'a' : '-') : '');
		return 'act ' + tag(document.activeElement) + ' tab ' + me.gen + page + '\\n' + view + '\\n' + me.log.join('\\n');
	};
	window.survivium_keys = me;
})();
"""
## How often the keys' log under the buttons is read again, in seconds.
const KEYS_EVERY := 0.25
## The lines the keys' log takes under the buttons.
const KEYS_LINES := 10

signal closed

var game
## The north-west cell of the sign shown (Placed.at finds it again once it is written or
## turned: the record is set down anew).
var cell: Vector3i
var item: String
var _fields: Array[LineEdit] = []
var _note: Label
## The page's keys log (KEYS_LOG) on the web, the label under the buttons that shows it
## and the time to the next read.
var _keys = null
var _keys_label: Label
var _keys_in := 0.0


func _init(g, e: Dictionary) -> void:
	game = g
	cell = e.cell
	item = e.item


## True when the player may write on the sign (build where it stands).
func may_write() -> bool:
	var land = game.land
	if land == null:
		return true
	return land.copy.allowed(land.copy.claim_at(cell), land.me(), "build")


func _ready() -> void:
	var rec := Items.get_item(item)
	var text: String = game.placed.at(cell).get("text", "")
	var lines := text.split("\n")
	build(Lang.t(Items.title(item)))
	box.get_child(0).custom_minimum_size.x = WIDTH
	var writes := may_write()
	if writes:
		for i in int(rec.get("sign_lines", 0)):
			var f := Kit.field(Lang.f("Строка %d", [(i + 1)]), WIDTH, int(rec.get("sign_width", 20)), FIELD_H)
			f.text = lines[i] if i < lines.size() else ""
			f.text_submitted.connect(func(_t: String) -> void: _next_after(f))
			box.add_child(f)
			_fields.append(f)
	else:
		var read := UiStyle.label(text if text != "" else "Здесь ничего не написано", UiStyle.INK if text != "" else UiStyle.MUTED)
		read.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if text != "":
			read.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		read.custom_minimum_size = Vector2(WIDTH, 0)
		box.add_child(read)
	_note = Kit.note("" if writes else "Писать может тот, кто строит на этой земле", WIDTH)
	_note.visible = _note.text != ""
	box.add_child(_note)
	if writes:
		box.add_child(_button("Сохранить", save, true))
		if not rec.get("wall", false):
			box.add_child(_button("Повернуть", turn))
	box.add_child(_button("Закрыть", close))
	if writes and OS.has_feature("web") and game.settings.keys_log:
		JavaScriptBridge.eval(KEYS_LOG, true)
		_keys = JavaScriptBridge.get_interface("survivium_keys")
		if _keys != null:
			_keys_label = UiStyle.label("", UiStyle.MUTED)
			_keys_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_keys_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			# A fixed height, so the panel stays where it is as the lines change.
			_keys_label.custom_minimum_size = Vector2(WIDTH, KEYS_LINES * 12)
			_keys_label.max_lines_visible = KEYS_LINES
			box.add_child(_keys_label)
	show_fitted()
	if not _fields.is_empty() and not game.controls.touch:
		_fields[0].grab_focus()


func _button(text: String, call: Callable, accent := false) -> Button:
	return (Kit.accent_button if accent else Kit.button).call(text, call, WIDTH, ROW_H)


## Enter in a field goes to the next one, in the last one saves.
func _next_after(f: LineEdit) -> void:
	var i := _fields.find(f)
	if i < _fields.size() - 1:
		_fields[i + 1].grab_focus()
	else:
		f.release_focus()
		save()


## True while one of the fields has the keys.
func typing() -> bool:
	for f in _fields:
		if f.has_focus():
			return true
	return false


## Writes the lines on the sign through the server and closes the window.
func save() -> void:
	var lines: Array[String] = []
	for f in _fields:
		lines.append(f.text)
	game.net.request(Protocol.SIGN_WRITE, [cell, "\n".join(lines)])
	close()


## Turns the sign a quarter (a signpost's arrow points another way); the window stays.
func turn() -> void:
	game.net.request(Protocol.SIGN_TURN, [cell])


func close() -> void:
	# The field lets the keys go first, so the phone's keyboard closes with the window.
	for f in _fields:
		f.release_focus()
	closed.emit()
	queue_free()


func back() -> void:
	close()


## Escape closes it even while a field has the keys.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if _keys_label == null:
		return
	_keys_in -= delta
	if _keys_in > 0.0:
		return
	_keys_in = KEYS_EVERY
	var fields := ""
	for f in _fields:
		fields += ("E" if f.is_editing() else "-") + ("F" if f.has_focus() else "-") + " "
	_keys_label.text = "%s\nwin %s fields %s" % [str(_keys.text()), "Y" if get_window().has_focus() else "N", fields]
