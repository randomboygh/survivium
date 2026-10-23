extends PanelContainer
## Performance statistics for playtests, shown by the chart button or F3: frame rate
## (now, average, 1% low), frame time, freezes (over 50 / over 100 ms) and what took
## their time, drops below 30 FPS, a graph of the last frames and what the renderer draws. Counters run from
## the start or the last reset.
## The numbers are coloured like the graph's bars: green is fine, amber is below 60 FPS
## or a slow frame, red is below 30 FPS or a freeze.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## Frames kept for the graph and the 1% low; the graph shows as many of the newest as
## it is pixels wide.
const HISTORY := 300
## Narrowest the graph gets, in UI pixels (one pixel per frame).
const GRAPH_MIN := 150
## A frame longer than this is a freeze (three frames lost at 60 FPS).
const FREEZE_MS := 50.0
const BIG_FREEZE_MS := 100.0
const DROP_FPS := 30.0
const REFRESH := 0.5
## What the time of the frame not spent in the parts of the game's code noted is
## called: mostly drawing, and the browser's and the engine's own work.
const REST := "отрисовка"
## Parts of a freeze shown and written to the log, the biggest first.
const FREEZE_PARTS := 3
## Freezes are written to the log at most this often (milliseconds), so a device that
## cannot keep up does not fill the log every frame.
const FREEZE_LOG_EVERY := 1000
## Room kept between the panel and the right edge of the screen, in UI pixels.
const EDGE := 8.0

## The panel's width when the HUD sets it (across the top of the screen), else 0: as
## wide as the longest line, up to the screen's edge.
var width := 0.0

var world_ms := 0
var chunks := 0

var _frames := PackedFloat32Array()
var _next := 0
var _total_time := 0.0
var _total_frames := 0
var _freezes := 0
var _big_freezes := 0
var _drops := 0
var _in_drop := false
## Microseconds each part of the game's code took in the frame under way, by name
## (see note).
var _work := {}
## The last freeze and the longest one: [ms, [[part, ms], ...] biggest first], or [].
var last_freeze := []
var worst_freeze := []
var _freeze_logged := -FREEZE_LOG_EVERY
var _second_time := 0.0
var _second_frames := 0
var _refresh := 0.0
var _text: RichTextLabel
var _graph: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("default_color", UiStyle.INK)
	# Lines 4 px apart like a Label's (each line is a paragraph here).
	_text.add_theme_constant_override("paragraph_separation", 4)
	box.add_child(_text)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(GRAPH_MIN, 34)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	_graph.resized.connect(_graph.queue_redraw)
	box.add_child(_graph)
	reset()


func reset() -> void:
	_frames.resize(HISTORY)
	_frames.fill(0.0)
	_next = 0
	_total_time = 0.0
	_total_frames = 0
	_freezes = 0
	_big_freezes = 0
	_drops = 0
	_in_drop = false
	last_freeze = []
	worst_freeze = []


## Adds the time from `since` (Time.get_ticks_usec) until now to part `what` of the
## game's code in this frame; returns now, where the next part starts.
func note(what: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	_work[what] = _work.get(what, 0) + now - since
	return now


## Records one frame; called every frame first thing (Main._process), also while the
## panel is hidden. `delta` is the time of the frame before, whose work was noted.
func add_frame(delta: float) -> void:
	var ms := delta * 1000.0
	_frames[_next] = ms
	_next = (_next + 1) % HISTORY
	_total_time += delta
	_total_frames += 1
	if ms > FREEZE_MS:
		_freezes += 1
		_record_freeze(ms)
	_work.clear()
	if ms > BIG_FREEZE_MS:
		_big_freezes += 1
	_second_time += delta
	_second_frames += 1
	if _second_time >= 1.0:
		var fps := _second_frames / _second_time
		if fps < DROP_FPS and not _in_drop:
			_drops += 1
		_in_drop = fps < DROP_FPS
		_second_time = 0.0
		_second_frames = 0
	_refresh += delta
	if visible and _refresh >= REFRESH:
		refresh()


## Keeps what took the time of a freeze of `ms`, the parts of the game's code noted
## and the rest, and writes it to the log.
func _record_freeze(ms: float) -> void:
	var parts := []
	var game_ms := 0.0
	for what: String in _work:
		parts.append([what, _work[what] / 1000.0])
		game_ms += _work[what] / 1000.0
	parts.append([REST, maxf(ms - game_ms, 0.0)])
	parts.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	last_freeze = [ms, parts.slice(0, FREEZE_PARTS)]
	if worst_freeze.is_empty() or ms > worst_freeze[0]:
		worst_freeze = last_freeze
	if Time.get_ticks_msec() - _freeze_logged >= FREEZE_LOG_EVERY:
		_freeze_logged = Time.get_ticks_msec()
		print("freeze %s" % freeze_text(last_freeze))


## A freeze as "84 мс: отрисовка 52, чанки 30".
static func freeze_text(f: Array) -> String:
	var parts := []
	for p: Array in f[1]:
		parts.append("%s %d" % [p[0], roundi(p[1])])
	return "%d мс: %s" % [roundi(f[0]), ", ".join(parts)]


func refresh() -> void:
	_refresh = 0.0
	_text.text = summary(true, true)
	_fit(summary(true))
	_graph.queue_redraw()


## How wide the panel is with its longest line unwrapped, in UI pixels.
func natural_width() -> float:
	var font := _text.get_theme_font("normal_font")
	var font_size := _text.get_theme_font_size("normal_font_size")
	var widest := float(GRAPH_MIN)
	for line in summary(true).split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var frame := get_theme_stylebox("panel").get_minimum_size().x if has_theme_stylebox("panel") else 0.0
	return ceilf(widest + 1.0 + frame)


## Keeps the panel within the screen: as wide as its longest line where that fits,
## the lines wrapped to the screen's edge where it does not (a phone held upright).
func _fit(plain: String) -> void:
	var font := _text.get_theme_font("normal_font")
	var font_size := _text.get_theme_font_size("normal_font_size")
	var widest := 0.0
	for line in plain.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var frame := get_theme_stylebox("panel").get_minimum_size().x if has_theme_stylebox("panel") else 0.0
	# On the screen, where the HUD may be drawn scaled.
	var on_screen := get_global_transform_with_canvas()
	var room := (get_viewport_rect().size.x - on_screen.origin.x) / on_screen.get_scale().x - EDGE - frame
	if width > 0.0:
		room = width - frame
	var wrap := widest + 1.0 > room
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	_text.custom_minimum_size.x = floorf(room) if wrap or width > 0.0 else 0.0


## The statistics as text; `full` adds the renderer lines, `colored` marks the numbers
## with BBCode colours for the panel (the log gets plain text).
func summary(full := false, colored := false) -> String:
	var recent := _recent()
	var worst := 0.0
	for ms in recent:
		worst = maxf(worst, ms)
	var sorted := recent.duplicate()
	sorted.sort()
	var low_ms: float = sorted[int(sorted.size() * 0.99)] if not sorted.is_empty() else 0.0
	var avg := _total_frames / _total_time if _total_time > 0.0 else 0.0
	var last: float = _frames[(_next - 1 + HISTORY) % HISTORY]
	var now := roundi(Engine.get_frames_per_second())
	var low := roundi(1000.0 / low_ms) if low_ms > 0.0 else 0
	var c := func(text: String, color: Color) -> String:
		return "[color=#%s]%s[/color]" % [color.to_html(false), text] if colored else text
	# Short lines, so the panel fits across a phone held upright.
	var lines := [
		"FPS %s · ср. %s · 1%% %s · кадр %s мс" % [c.call(str(now), fps_color(now)),
			c.call(str(roundi(avg)), fps_color(avg)), c.call(str(low), fps_color(low)),
			c.call("%.1f" % last, frame_color(last))],
		"Макс %s мс · фризы %s / %s · <30 FPS %s" % [c.call("%.0f" % worst, frame_color(worst)),
			c.call(str(_freezes), UiStyle.GOOD if _freezes == 0 else UiStyle.ACCENT),
			c.call(str(_big_freezes), UiStyle.GOOD if _big_freezes == 0 else UiStyle.DANGER),
			c.call(str(_drops), UiStyle.GOOD if _drops == 0 else UiStyle.DANGER)],
	]
	if not last_freeze.is_empty():
		lines.append("Фриз %s" % freeze_text(last_freeze))
		if worst_freeze != last_freeze:
			lines.append("Худший %s" % freeze_text(worst_freeze))
	if full:
		var p := Performance
		lines.append("Вызовы %d · объекты %d · треуг. %dк" % [
			p.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			p.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			roundi(p.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)])
		var video := p.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		var memory := p.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var mem := "Видео %d МБ" % roundi(video)
		if memory > 0.0:
			mem += " · память %d МБ" % roundi(memory)
		lines.append(mem)
		lines.append("Мир за %.1f с · чанков %d" % [world_ms / 1000.0, chunks])
	return "\n".join(lines)


## Colour of a frame rate: green from 55 FPS, amber from 30, red below.
static func fps_color(fps: float) -> Color:
	if fps >= 55.0:
		return UiStyle.GOOD
	return UiStyle.ACCENT if fps >= DROP_FPS else UiStyle.DANGER


## Colour of a frame time, the same as the graph's bars.
static func frame_color(ms: float) -> Color:
	if ms > FREEZE_MS:
		return UiStyle.DANGER
	return UiStyle.ACCENT if ms > 1000.0 / DROP_FPS else UiStyle.GOOD


## Frame times of the last HISTORY frames that have been recorded.
func _recent() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for ms in _frames:
		if ms > 0.0:
			out.append(ms)
	return out


## One bar per frame across the whole width, newest on the right; lines at 60 and
## 30 FPS. Bars over 50 ms (freezes) are red, over 33 ms amber. A graph wider than
## HISTORY pixels draws the bars wider, so they still reach the left edge.
func _draw_graph() -> void:
	var h := _graph.size.y
	var scale := h / 66.0
	var n := mini(floori(_graph.size.x), HISTORY)
	if n <= 0:
		return
	var step := _graph.size.x / n
	_graph.draw_rect(Rect2(Vector2.ZERO, _graph.size), Color(0, 0, 0, 0.35))
	for i in n:
		var ms: float = _frames[(_next - n + i + HISTORY) % HISTORY]
		if ms <= 0.0:
			continue
		var bar := minf(h, ceilf(ms * scale))
		var x := floorf(i * step)
		_graph.draw_rect(Rect2(x, h - bar, floorf((i + 1) * step) - x, bar), frame_color(ms))
	for fps in [60.0, 30.0]:
		var y := floorf(h - 1000.0 / fps * scale)
		_graph.draw_rect(Rect2(0, y, _graph.size.x, 1), Color(UiStyle.INK, 0.45))
