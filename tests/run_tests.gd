extends SceneTree
## Headless unit tests, one file per topic under tests/unit/ (each extends test_case.gd).
## Run: godot --headless --path . --script res://tests/run_tests.gd [-- topic ...]
## Names as arguments run only those files, e.g. `-- body shapes`.

const FILES := ["generation", "mesher", "body", "shapes", "view", "actions", "clock", "wildlife", "store", "content", "graph", "bundle_system", "character", "session", "net"]


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var checks := 0
	var failures := 0
	for name in FILES:
		if not only.is_empty() and not name in only:
			continue
		var file: GDScript = load("res://tests/unit/%s_test.gd" % name)
		if file == null or not file.can_instantiate():
			printerr("FAIL: tests/unit/%s_test.gd does not load" % name)
			failures += 1
			continue
		var tests = file.new()
		tests.run()
		checks += tests.checks
		failures += tests.failures
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
