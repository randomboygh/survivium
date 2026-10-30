extends SceneTree
## Times the mods' data, the part of the start of the game they cost: reading every file
## under content/ (Content.read_ms), loading the set of every bundle (Content.load_ms), the
## registries (Mods.rescan) and the content graph (ContentGraph, run by the validator and
## the reports, not by the game); then the same with a made-up mod of `bundles` bundles
## added, each of ten things made one of another, to see how it grows with content. Each
## step's least time of three runs; a phone's browser runs GDScript about ten times slower.
## godot --headless --path . --script res://tools/bench_content.gd [bundles]

const Content := preload("res://src/shared/content/content.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const ContentGraph := preload("res://src/shared/content/content_graph.gd")

const MOD := "res://content/_bench"
const CHAIN := 10


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var bundles: int = int(args[0]) if args.size() > 0 else 40
	var base := Mods.all()
	_time("the mods as they are", base)
	_time("with %d made-up bundles" % bundles, base + _write_mod(bundles))
	_remove(MOD)
	Content.BUNDLES = base
	Content.refresh()
	quit()


## Prints the least time of three runs of each step with the bundles of `set` loaded.
func _time(what: String, set: Array) -> void:
	var best := [INF, INF, INF, INF]
	for i in 3:
		Content.BUNDLES = set.duplicate()
		var t := Time.get_ticks_usec()
		Mods.rescan()
		var total := (Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		ContentGraph.new()
		var graph := (Time.get_ticks_usec() - t) / 1000.0
		for step in [[0, Content.read_ms], [1, Content.load_ms], [2, total - Content.read_ms - Content.load_ms], [3, graph]]:
			best[step[0]] = minf(best[step[0]], step[1])
	print("%s: %d records; reading %.0f ms, loading %.0f ms, registries %.0f ms, graph %.0f ms" % [what,
		Content.record_count(), best[0], best[1], best[2], best[3]])
	if not Content.problems.is_empty():
		printerr("problems: %s" % "\n".join(Content.problems))


## Writes the made-up mod: `bundles` bundles of CHAIN things, the first made of branches,
## each next of the one before and fibre. Returns its bundle ids.
func _write_mod(bundles: int) -> Array:
	_write(MOD + "/mod.yaml", "id: _bench\ntitle: Замер\nversion: \"1\"\napi: 1\n")
	var out := []
	for b in bundles:
		var dir := "%s/b%d" % [MOD, b]
		_write(dir + "/bundle.yaml", "title: Набор %d\n" % b)
		var items := ""
		var recipes := ""
		for k in CHAIN:
			var id := "t%d_%d" % [b, k]
			items += "- id: %s\n  title: Вещь %d.%d\n  description: Придуманная вещь для замера.\n  weight: %.1f\n  stack: %d\n" % [
				id, b, k, 0.5 + k * 0.1, 10 + k]
			var needs := "{resources:branch: 2}" if k == 0 else "{t%d_%d: 1, resources:fiber: 1}" % [b, k - 1]
			recipes += "- id: %s\n  title: Вещь %d.%d\n  makes: %s\n  needs: %s\n  time: %d\n" % [id, b, k, id, needs, 1 + k % 3]
		_write(dir + "/data/items.yaml", items)
		_write(dir + "/data/recipes.yaml", recipes)
		out.append("_bench/b%d" % b)
	return out


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _remove(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove("%s/%s" % [dir, sub])
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute("%s/%s" % [dir, f])
	DirAccess.remove_absolute(dir)
