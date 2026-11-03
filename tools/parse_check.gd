extends SceneTree
## Loads every GDScript of the project and fails on any that does not compile, in a few
## seconds: the tests load only the scripts they reach, so a parse error in a tool, an art
## script or a module no test touches would otherwise wait for the run that needs it.
## Nothing is instantiated. Run after --import (CI's `lint` job):
##     godot --headless --path . --script res://tools/parse_check.gd

## Folders whose scripts are checked; `.godot/` and the export are left out.
const ROOTS := ["res://src", "res://tests", "res://tools", "res://scenes", "res://shaders"]


## Counts the script errors the engine reports while loading (a parse error is one).
class Errors extends Logger:
	var lines: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			var text := "%s:%d: %s" % [file, line, rationale if rationale != "" else code]
			_mutex.lock()
			if not text in lines:
				lines.append(text)
			_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _init() -> void:
	var errors := Errors.new()
	OS.add_logger(errors)
	var paths: PackedStringArray = []
	for root in ROOTS:
		_collect(root, paths)
	paths.sort()
	var bad: PackedStringArray = []
	for path in paths:
		var before := errors.lines.size()
		var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if script == null or not script.can_instantiate() or errors.lines.size() > before:
			bad.append(path)
	OS.remove_logger(errors)
	for path in bad:
		printerr("FAIL: %s does not compile" % path)
	for line in errors.lines:
		printerr("  " + line)
	print("%d scripts, %d do not compile" % [paths.size(), bad.size()])
	quit(1 if bad.size() > 0 else 0)


func _collect(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_collect(dir.path_join(d), out)
