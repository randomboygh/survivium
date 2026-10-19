extends PanelContainer
## Performance statistics for playtests, shown by the chart button or F3: frame rate
## (now, average, 1% low), frame time, freezes, drops below 30 FPS, a graph of the last
## frames and what the renderer draws. Counters run from the start or the last reset.

const UiStyle := preload("res://src/client/ui_style.gd")

## Frames kept for the graph and the 1% low.
const HISTORY := 300
const GRAPH_FRAMES := 150
## A frame longer than this is a freeze (three frames lost at 60 FPS).
const FREEZE_MS := 50.0
const BIG_FREEZE_MS := 100.0
const DROP_FPS := 30.0
const REFRESH := 0.5

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
var _second_time := 0.0
var _second_frames := 0
var _refresh := 0.0
var _text: Label
var _graph: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_text = UiStyle.label()
	box.add_child(_text)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(GRAPH_FRAMES, 34)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
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


## Records one frame; called every frame, also while the panel is hidden.
func add_frame(delta: float) -> void:
	var ms := delta * 1000.0
	_frames[_next] = ms
	_next = (_next + 1) % HISTORY
	_total_time += delta
	_total_frames += 1
	if ms > FREEZE_MS:
		_freezes += 1
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


func refresh() -> void:
	_refresh = 0.0
	_text.text = summary(true)
	_graph.queue_redraw()


## The statistics as text; `full` adds the renderer lines.
func summary(full := false) -> String:
	var recent := _recent()
	var worst := 0.0
	for ms in recent:
		worst = maxf(worst, ms)
	var sorted := recent.duplicate()
	sorted.sort()
	var low_ms: float = sorted[int(sorted.size() * 0.99)] if not sorted.is_empty() else 0.0
	var avg := _total_frames / _total_time if _total_time > 0.0 else 0.0
	var last: float = _frames[(_next - 1 + HISTORY) % HISTORY]
	var lines := [
		"FPS %d · ср. %d · 1%% %d" % [Engine.get_frames_per_second(), roundi(avg), roundi(1000.0 / low_ms) if low_ms > 0.0 else 0],
		"Кадр %.1f мс · макс %.0f мс" % [last, worst],
		"Фризы >50 мс: %d · >100 мс: %d" % [_freezes, _big_freezes],
		"Просадки ниже 30 FPS: %d" % _drops,
	]
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
		lines.append("Мир построен за %.1f с · чанков %d" % [world_ms / 1000.0, chunks])
	return "\n".join(lines)


## Frame times of the last HISTORY frames that have been recorded.
func _recent() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for ms in _frames:
		if ms > 0.0:
			out.append(ms)
	return out


## One bar per frame, newest on the right; lines at 60 and 30 FPS. Bars over 50 ms
## (freezes) are red, over 33 ms amber.
func _draw_graph() -> void:
	var h := _graph.size.y
	var scale := h / 66.0
	_graph.draw_rect(Rect2(Vector2.ZERO, _graph.size), Color(0, 0, 0, 0.35))
	for i in GRAPH_FRAMES:
		var ms: float = _frames[(_next - GRAPH_FRAMES + i + HISTORY) % HISTORY]
		if ms <= 0.0:
			continue
		var bar := minf(h, ceilf(ms * scale))
		var color := UiStyle.GOOD
		if ms > FREEZE_MS:
			color = UiStyle.DANGER
		elif ms > 1000.0 / DROP_FPS:
			color = UiStyle.ACCENT
		_graph.draw_rect(Rect2(i, h - bar, 1, bar), color)
	for fps in [60.0, 30.0]:
		var y := floorf(h - 1000.0 / fps * scale)
		_graph.draw_rect(Rect2(0, y, _graph.size.x, 1), Color(UiStyle.INK, 0.45))
