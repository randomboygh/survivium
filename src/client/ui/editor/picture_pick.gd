extends RefCounted
## A PNG picked from the device for the content editor (stage 2 item 3, step 4): the
## system's file picker on a computer and a phone (as ModImport picks a zip), a file input
## of the page in the browser. `done` gets the file's bytes and its name; nothing is called
## when the picker is left. What the bytes are is the caller's to check (ModFiles.may_be).

const Lang := preload("res://src/shared/content/lang.gd")

## The page's part in the browser: a hidden file input opened at a tap, the file read as
## base64 and given back to `done` (a callback of the game).
const PAGE := """(function () {
	'use strict';
	var p = window.survivium_pick = window.survivium_pick || {};
	p.open = function () {
		var input = document.createElement('input');
		input.type = 'file';
		input.accept = 'image/png';
		input.onchange = function () {
			var f = input.files && input.files[0];
			if (!f || !p.done) { return; }
			var r = new FileReader();
			r.onload = function () {
				var s = String(r.result);
				p.done(f.name, s.substring(s.indexOf(',') + 1));
			};
			r.readAsDataURL(f);
		};
		input.click();
	};
})();"""

## The callback the page calls and what it calls in turn, kept while a pick is open.
static var _callback = null
static var _done := Callable()


## Whether a picture can be picked here.
static func can_pick() -> bool:
	return OS.has_feature("web") or DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## Opens the picker; `done(bytes: PackedByteArray, name: String)` gets the file picked.
static func pick(done: Callable) -> void:
	if OS.has_feature("web"):
		_done = done
		if _callback == null:
			JavaScriptBridge.eval(PAGE, true)
			_callback = JavaScriptBridge.create_callback(_picked)
			JavaScriptBridge.get_interface("survivium_pick").done = _callback
		JavaScriptBridge.eval("window.survivium_pick.open();", true)
		return
	DisplayServer.file_dialog_show(Lang.t("[editor_pick_png]"), "", "", false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.png;PNG;image/png"]),
		func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			if ok and not paths.is_empty():
				done.call(FileAccess.get_file_as_bytes(paths[0]), paths[0].uri_decode().get_file()))


## The page read a file: [name, base64 of its bytes].
static func _picked(args: Array) -> void:
	if args.size() < 2 or not _done.is_valid():
		return
	_done.call(Marshalls.base64_to_raw(str(args[1])), str(args[0]))
