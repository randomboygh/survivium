extends SceneTree
## Headless unit tests, one file per topic under tests/unit/ (each extends test_case.gd).
## Run: godot --headless --path . --script res://tests/run_tests.gd [-- topic ...]
## Names as arguments run only those files, e.g. `-- body shapes`.

const FILES := ["generation", "mesher", "body", "shapes", "view", "actions", "clock", "wildlife", "store", "content", "graph", "bundle_system", "character", "session", "net"]


## Counts the runtime errors of scripts: one aborts the function it is in and the test
## goes on without the checks after it, so each is a failure.
class ScriptErrors extends Logger:
	var count := 0
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			_mutex.lock()
			count += 1
			_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var checks := 0
	var failures := 0
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	for name in FILES:
		if not only.is_empty() and not name in only:
			continue
		var file: GDScript = load("res://tests/unit/%s_test.gd" % name)
		if file == null or not file.can_instantiate():
			printerr("FAIL: tests/unit/%s_test.gd does not load" % name)
			failures += 1
			continue
		var tests = file.new()
		var errors_before := errors.count
		tests.run()
		checks += tests.checks
		failures += tests.failures
		if errors.count > errors_before:
			printerr("FAIL: tests/unit/%s_test.gd hit %d script errors (see SCRIPT ERROR above)" % [name, errors.count - errors_before])
			failures += errors.count - errors_before
	OS.remove_logger(errors)
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
