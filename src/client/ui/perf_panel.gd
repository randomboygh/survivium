extends PanelContainer
## Performance statistics for playtests, shown by the chart button or F3: frame rate
## (now, average, 1% low), frame time, freezes (over 50 / over 100 ms) and what took
## their time or came just before them (mark), drops below 30 FPS, a graph of the last frames and what the renderer draws. Counters run from
## the start or the last reset.
## The numbers are coloured like the graph's bars: green is fine, amber is below 60 FPS
## or a slow frame, red is below 30 FPS or a freeze.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const GlWatch := preload("res://src/client/ui/gl_watch.gd")

## Frames kept for the graph and the 1% low; the graph shows as many of the newest as
## it is pixels wide.
const HISTORY := 300
## Narrowest the graph gets, in UI pixels (one pixel per frame), and how tall it is.
const GRAPH_MIN := 150
const GRAPH_HEIGHT := 20
## The panel's width beside the buttons on a wide screen, in UI pixels: always the
## same, so it does not jump as the numbers change. Its longest lines fit in it (and
## across a phone held upright, where the panel takes the whole top).
const WIDTH := 372
## A frame longer than this is a freeze (three frames lost at 60 FPS).
const FREEZE_MS := 50.0
const BIG_FREEZE_MS := 100.0
const DROP_FPS := 30.0
const REFRESH := 0.5
## The parts of a frame beside the game's code noted, timed from the engine's
## signals: its own work before drawing (the other nodes, the interface's layout, the
## things freed), the drawing, and the rest of the frame, outside the engine: the
## page, its garbage collection, waiting for the screen.
const ENGINE := "движок"
const DRAW := "отрисовка"
const REST := "браузер"
## Parts of a freeze written to the log and shown in the panel, the biggest first.
const FREEZE_PARTS := 3
const PANEL_FREEZE_PARTS := 2
## Freezes are written to the log at most this often (milliseconds), so a device that
## cannot keep up does not fill the log every frame.
const FREEZE_LOG_EVERY := 1000
## Longest line of the panel, in letters of the pixel font: an upright phone's width.
const LINE := 45
## What a freeze with no mark before it is counted as.
const NO_MARK := "ничего"
## Freezes the log keeps.
const LOG_SIZE := 40
## A change of video memory (textures and meshes sent to the GPU) or of the objects
## drawn from one frame to the next that is marked.
const VIDEO_JUMP := 256 * 1024
const OBJECTS_JUMP := 40
## Time the browser spent sending data to the GPU in a frame that is marked, ms.
const SEND_MS := 4.0
## Room kept between the panel and the right edge of the screen, in UI pixels.
const EDGE := 8.0

## The panel's width the HUD sets (WIDTH, or across the top of the screen), else 0: as
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
## What the frame under way sent the engine or the browser to do beyond the game's
## code (a mesh or a texture to the renderer, a file to write, a fire's shadow
## switched), which lands in REST: told beside a freeze, which it may have caused.
var _marks := {}
## The freezes kept for the log in «Отладка» (see freeze_log.gd), the newest last:
## [seconds since the start, ms, parts, marks with what they say].
var freeze_log := []
## Video memory and objects drawn in the frame before, to mark a jump (see _engine_marks).
var _video := 0.0
var _objects := 0.0
## The engine's clock in the frame under way and the one before (Time.get_ticks_usec):
## its process began, its drawing began and ended.
var _frame_at := 0
var _last_frame_at := 0
var _draw_at := 0
var _drawn_at := 0
var _gl := GlWatch.new()
## How many freezes each mark came before since the reset (NO_MARK: none).
var freeze_marks := {}
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
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("default_color", UiStyle.INK)
	# Lines close together (each line is a paragraph here), to keep the panel low.
	_text.add_theme_constant_override("paragraph_separation", 1)
	box.add_child(_text)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(GRAPH_MIN, GRAPH_HEIGHT)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	_graph.resized.connect(_graph.queue_redraw)
	box.add_child(_graph)
	get_tree().process_frame.connect(_on_process_frame)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	reset()


func _on_process_frame() -> void:
	_last_frame_at = _frame_at
	_frame_at = Time.get_ticks_usec()


func _on_pre_draw() -> void:
	_draw_at = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_drawn_at = Time.get_ticks_usec()


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
	freeze_marks.clear()
	freeze_log.clear()
	_marks.clear()


## Marks that the frame under way made the engine or the browser do `what` outside
## the game's code (see _marks), or that the game did it (a jump, dusk); `detail` is
## shown with it in the log.
func mark(what: String, detail := "") -> void:
	_marks[what] = detail


## Marks what the renderer's counters show of the frame before: much sent to the
## video memory, many things drawn more or fewer; in the browser, shaders built and
## data sent to the GPU (GlWatch).
func _engine_marks() -> void:
	var gl := _gl.take()
	if not gl.is_empty():
		if gl[0] > 0.0 or gl[1] >= 1.0:
			mark("шейдеры", "%d за %d мс" % [roundi(gl[0]), roundi(gl[1])])
		if gl[3] >= SEND_MS:
			mark("загрузка", "%d КБ за %d мс" % [roundi(gl[2]), roundi(gl[3])])
	var video := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if _video > 0.0 and absf(video - _video) >= VIDEO_JUMP:
		mark("видео", "%+d КБ" % roundi((video - _video) / 1024.0))
	if _objects > 0.0 and absf(objects - _objects) >= OBJECTS_JUMP:
		mark("объекты", "%+d" % roundi(objects - _objects))
	_video = video
	_objects = objects


## Adds the time from `since` (Time.get_ticks_usec) until now to part `what` of the
## game's code in this frame; returns now, where the next part starts.
func note(what: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	_work[what] = _work.get(what, 0) + now - since
	return now


## Records one frame; called every frame first thing (Main._process), also while the
## panel is hidden. `delta` is the time of the frame before, whose work was noted.
func add_frame(delta: float) -> void:
	# The frame's time on the clock where it is known: the engine's delta is smoothed
	# toward whole frames of the screen and comes out shorter after a long frame.
	var ms := maxf(delta * 1000.0, (_frame_at - _last_frame_at) / 1000.0 if _last_frame_at > 0 else 0.0)
	_engine_marks()
	_frames[_next] = ms
	_next = (_next + 1) % HISTORY
	_total_time += ms / 1000.0
	_total_frames += 1
	if ms > FREEZE_MS:
		_freezes += 1
		_record_freeze(ms)
	_work.clear()
	_marks.clear()
	if ms > BIG_FREEZE_MS:
		_big_freezes += 1
	_second_time += ms / 1000.0
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
	# The frame's drawing, when the engine's signals came in it.
	if _draw_at >= _last_frame_at and _drawn_at >= _draw_at and _last_frame_at > 0:
		var engine := maxf((_draw_at - _last_frame_at) / 1000.0 - game_ms, 0.0)
		var draw := (_drawn_at - _draw_at) / 1000.0
		parts.append([ENGINE, engine])
		parts.append([DRAW, draw])
		game_ms += engine + draw
	parts.append([REST, maxf(ms - game_ms, 0.0)])
	parts.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var marks: Array = _marks.keys()
	marks.sort()
	for m: String in marks if not marks.is_empty() else [NO_MARK]:
		freeze_marks[m] = freeze_marks.get(m, 0) + 1
	last_freeze = [ms, parts.slice(0, FREEZE_PARTS), marks]
	var told := []
	for m: String in marks:
		told.append(m + (" " + _marks[m] if _marks[m] != "" else ""))
	freeze_log.append([Time.get_ticks_msec() / 1000.0, ms, parts.slice(0, FREEZE_PARTS), told,
		roundi(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	if freeze_log.size() > LOG_SIZE:
		freeze_log.pop_front()
	if worst_freeze.is_empty() or ms > worst_freeze[0]:
		worst_freeze = last_freeze
	if Time.get_ticks_msec() - _freeze_logged >= FREEZE_LOG_EVERY:
		_freeze_logged = Time.get_ticks_msec()
		print("freeze %s" % freeze_text(last_freeze))


## A freeze as "84 мс: отрисовка 52, чанки 30 · сетка", with its `parts` biggest
## parts and what was marked before it.
static func freeze_text(f: Array, parts_shown := FREEZE_PARTS) -> String:
	var parts := []
	for p: Array in f[1].slice(0, parts_shown):
		parts.append("%s %d" % [p[0], roundi(p[1])])
	var text := "%d мс: %s" % [roundi(f[0]), ", ".join(parts)]
	if f.size() > 2:
		# As many marks as fit the panel's line after "Фриз ".
		for i in f[2].size():
			var item: String = (" · " if i == 0 else ", ") + f[2][i]
			if text.length() + item.length() > LINE - 5:
				break
			text += item
	return text


## What came before the freezes, the most frequent first, as many as fit a line:
## "Фризы после: сетка 30, запись 12, ничего 8".
func marks_text() -> String:
	var marks: Array = freeze_marks.keys()
	marks.sort_custom(func(a: String, b: String) -> bool: return freeze_marks[a] > freeze_marks[b])
	var text := "Фризы после:"
	for i in marks.size():
		var item := "%s %s %d" % ["" if i == 0 else ",", marks[i], freeze_marks[marks[i]]]
		if text.length() + item.length() > LINE:
			break
		text += item
	return text


func refresh() -> void:
	_refresh = 0.0
	_text.text = summary(true, true)
	_fit(summary(true))
	_graph.queue_redraw()


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
	# Few short lines, so the panel is low and fits across a phone held upright
	# (WIDTH): 45 letters of the pixel font at most.
	var lines := [
		"FPS %s · ср. %s · 1%% %s · кадр %s мс" % [c.call(str(now), fps_color(now)),
			c.call(str(roundi(avg)), fps_color(avg)), c.call(str(low), fps_color(low)),
			c.call("%.1f" % last, frame_color(last))],
		"Макс %s мс · фризы %s / %s · <30 FPS %s" % [c.call("%.0f" % worst, frame_color(worst)),
			c.call(str(_freezes), UiStyle.GOOD if _freezes == 0 else UiStyle.ACCENT),
			c.call(str(_big_freezes), UiStyle.GOOD if _big_freezes == 0 else UiStyle.DANGER),
			c.call(str(_drops), UiStyle.GOOD if _drops == 0 else UiStyle.DANGER)],
	]
	var parts := PANEL_FREEZE_PARTS if colored else FREEZE_PARTS
	if not last_freeze.is_empty():
		# With marks the panel shows the biggest part alone, so the line fits.
		var marked: bool = last_freeze.size() > 2 and not last_freeze[2].is_empty()
		lines.append("Фриз %s" % freeze_text(last_freeze, 1 if full and marked else parts))
		lines.append(marks_text() if full else "Худший %s" % freeze_text(worst_freeze, parts))
	if full:
		var p := Performance
		lines.append("Вызовы %d · объекты %d · треуг. %dк" % [
			p.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			p.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			roundi(p.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)])
		var video := p.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		var world := "Мир за %.1f с · чанков %d" % [world_ms / 1000.0, chunks]
		# The memory is counted in debug builds alone (not in the browser's).
		var memory := p.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		if memory > 0.0:
			lines.append(world)
			lines.append("Видео %d МБ · память %d МБ" % [roundi(video), roundi(memory)])
		else:
			lines.append(world + " · видео %d МБ" % roundi(video))
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
