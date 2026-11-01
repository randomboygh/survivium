extends RefCounted
## Where the start of the game goes, for the line «Загрузка» of «Данные для теста»
## (SettingsMenu.report_text) and the last starts kept on the device (FILE): on the web
## the page and its two downloads (the engine's wasm and the game's pck, from the network
## or the browser's cache), then in the engine the graphics, the game's scripts compiled,
## the modules built, the main menu, and the world near the player built. Each step is
## marked once per scene (mark) in the engine's msec; the page's moments come from the
## browser's own timings (`performance`), the moment the graphics were up from the
## engine's line «OpenGL API» caught by the page (export_presets.cfg, `svStart`).

const Content := preload("res://src/shared/content/content.gd")

## The last starts kept, the newest first, a line each.
const FILE := "user://starts.txt"
const KEEP := 6

## The steps of this scene's start: name → Time.get_ticks_msec when it ended.
static var marks := {}
## When main.gd was compiled with every script it loads (msec): set by main.gd's own
## static var, which the engine fills right after compiling it.
static var compiled_ms := -1
## The scene was started again (another world, a server): the page's part is not new.
static var again := false
## The page's timings, read once (page): {} off the web.
static var _page := {}
static var _page_read := false
## How long the land of the spawn took to lay out (msec), before the chunks.
static var spawn_ms := 0
## The world's chunks near the player: generated and meshed (msec).
static var chunks_ms := 0
static var mesh_ms := 0
## The line of this start was kept in FILE.
static var _kept := false


## A new scene starts: its steps are marked anew.
static func begin() -> void:
	again = marks.has("scene")
	marks = {"scene": Time.get_ticks_msec()}
	spawn_ms = 0
	chunks_ms = 0
	mesh_ms = 0


## Step `step` of this scene ended now (only its first time counts).
static func mark(step: String) -> void:
	if not marks.has(step):
		marks[step] = Time.get_ticks_msec()


## The browser's timings of the page, msec since it was opened: `html`, `wasm` and `pck`
## [end, bytes, bytes over the network], `engine` (the engine's clock began),
## `gl` (the graphics were up), `cores`.
static func page() -> Dictionary:
	if _page_read or not OS.has_feature("web"):
		return _page
	_page_read = true
	var js: Variant = JavaScriptBridge.eval("""(function () {
		'use strict';
		var r = {now: performance.now(), cores: navigator.hardwareConcurrency || 0};
		var n = performance.getEntriesByType('navigation')[0];
		r.html = n ? n.responseEnd : 0;
		performance.getEntriesByType('resource').forEach(function (e) {
			var k = /\\.wasm(\\?|$)/.test(e.name) ? 'wasm' : (/\\.pck(\\?|$)/.test(e.name) ? 'pck' : '');
			if (k) r[k] = [e.responseEnd, e.encodedBodySize || e.decodedBodySize, e.transferSize];
		});
		if (window.svStart && window.svStart.gl) r.gl = window.svStart.gl;
		return JSON.stringify(r);
	})()""", true)
	var parsed: Variant = JSON.parse_string(str(js)) if js != null else null
	if parsed is Dictionary:
		_page = parsed
		# The engine's clock counts from its start: where that is on the page's.
		_page.engine = float(_page.now) - Time.get_ticks_msec()
	return _page


## Seconds of `ms`, one decimal.
static func _s(ms: float) -> String:
	return "%.1f" % (ms / 1000.0)


## A download: "wasm 9.2 МБ по сети" / "из кэша", and when it ended.
static func _download(what: String, d: Array) -> String:
	var mb := float(d[1]) / 1048576.0
	# A file from the cache moves no bytes, or a few hundred for asking it is still fresh.
	var net := "по сети" if float(d[2]) > 4096.0 else "из кэша"
	return "%s %.1f МБ %s к %s" % [what, mb, net, _s(float(d[0]))]


## The engine's steps one after another: each with how long it took, from the engine's
## start (msec 0 of its clock); `full` names the mods' records too.
static func _steps(full := true) -> Array:
	var out := []
	var at := 0.0
	var p := page()
	if p.has("gl") and not again:
		var gl: float = float(p.gl) - float(p.engine)
		out.append("графика %s" % _s(gl))
		at = gl
	if compiled_ms >= 0 and not again:
		# The mods' data is read and loaded while the scripts compile (Materials' static
		# init asks for it); off the web the engine's own start is in the scripts too.
		var mods := Content.read_ms + Content.load_ms
		out.append("%s %s" % ["скрипты" if at > 0.0 else "движок и скрипты", _s(maxf(0.0, compiled_ms - at - mods))])
		if full:
			out.append("данные модов %s (записей %d: чтение %d мс, набор %d мс)" % [_s(mods), Content.record_count(),
				roundi(Content.read_ms), roundi(Content.load_ms)])
		else:
			out.append("моды %s" % _s(mods))
		at = compiled_ms
	var scene: float = marks.get("scene", at)
	if not again:
		out.append("сцена %s" % _s(scene - at))
	at = scene
	for step: Array in [["modules", "модули"], ["menu", "меню"]]:
		if marks.has(step[0]):
			out.append("%s %s" % [step[1], _s(marks[step[0]] - at)])
			at = marks[step[0]]
	return out


## «Загрузка»: from the page's opening (on the web) through the engine's steps to the
## world, with the cores of the device.
static func line() -> String:
	var parts := []
	var p := page()
	if not p.is_empty() and not again:
		parts.append("страница %s" % _s(float(p.get("html", 0.0))))
		for k: String in ["wasm", "pck"]:
			if p.has(k):
				parts.append(_download(k, p[k]))
		parts.append("движок с %s" % _s(float(p.engine)))
	elif again:
		parts.append("сцена заново")
	parts.append_array(_steps())
	if marks.has("world"):
		var from: float = marks.get("modules", marks.scene)
		var w := "мир %s (место %s, чанки %s, сетки %s" % [_s(marks.world - from), _s(spawn_ms), _s(chunks_ms), _s(mesh_ms)]
		if marks.has("play"):
			# What the player waited after leaving the menu, the rest was built behind it.
			w += ", после меню %s" % _s(maxf(0.0, marks.world - marks.play))
		parts.append(w + ")")
	var total := ""
	if marks.has("menu"):
		total = ", до меню %s с" % _s(_on_page(marks.menu))
	return "Загрузка, с: %s%s%s" % [", ".join(parts), total, (", ядер %d" % int(p.cores)) if p.has("cores") else ""]


## Msec `ms` of the engine's clock on the page's (the same off the web).
static func _on_page(ms: float) -> float:
	var p := page()
	return ms + (float(p.engine) if p.has("engine") and not again else 0.0)


## The world is built: this start is kept as a short line in FILE, the newest first.
static func keep() -> void:
	if _kept or again or not marks.has("world"):
		return
	_kept = true
	var short := "%s: до меню %s с (%s), мир %s с" % [Time.get_datetime_string_from_system().replace("T", " ").left(16),
		_s(_on_page(marks.get("menu", marks.world))), ", ".join(_steps(false)), _s(marks.world - marks.get("modules", marks.scene))]
	var lines := past()
	lines.push_front(short)
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines.slice(0, KEEP)))


## The starts kept before, the newest first (this one too once kept).
static func past() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	return Array(FileAccess.get_file_as_string(FILE).split("\n", false))
