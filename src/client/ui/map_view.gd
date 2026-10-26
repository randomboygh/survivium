extends Control
## The whole map over the screen, in a panel like the game's other windows: the title,
## where the player is and the clock along the top; everything explored so far sunk
## into it with rounded corners (the regions the minimap paints, see
## Minimap.draw_ground), the north and a scale bar on it; the buttons down the right
## (close, closer, farther, back to the player). It opens centred on the player, moves
## by dragging (a finger or the mouse), zooms by pinching, the mouse wheel or the
## buttons, and closes by the cross, Escape or M. A tap (or a click) on the map sets a
## marker there (Markers): a small window by it picks the colour, says where it is and
## how far; a tap on a marker opens the same window to recolour it or take it off.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Minimap := preload("res://src/client/ui/minimap.gd")
const Markers := preload("res://src/client/game/markers.gd")

## UI pixels per map pixel (a map pixel is two by two cells); below one the map
## shrinks, so a long walk fits on the screen; the closest parts the marks of things
## placed side by side.
const ZOOMS := [0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 6.0, 9.0, 12.0]
## The zoom the map opens at the first time.
const FIRST_ZOOM := 3
const BUTTON := 32
const MARGIN := 8
## Room between the panel's frame and what it holds, and between its parts.
const PAD := 8
const GAP := 6
## The radius of the map's rounded corners.
const CORNER := 5
## The game behind the window, dimmed.
const SHADE := Color(0, 0, 0, 0.55)
## Mouse events this soon after a touch come from the finger (see Controls.input).
const TOUCH_MOUSE_MS := 1000
## A press that moves less than this (UI pixels) is a tap.
const TAP_SLOP := 6.0
## Lengths of the scale bar, in cells; the one drawn is the longest no wider than
## SCALE_WIDTH.
const SCALES := [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
const SCALE_WIDTH := 72
const SWATCH := 12

var minimap: Minimap
## The player's markers, set by Hud; null in a map without them.
var markers: Markers
## The Main node (where the player is, the clock); null in tools that draw the map alone.
var game
## The column in the middle of the map, in cells.
var centre := Vector2.ZERO
var zoom_index := FIRST_ZOOM
## The map's sunken rectangle, in this control's pixels, and where the scale bar is drawn.
var well := Rect2()
var _scale_at := Vector2.ZERO
## The marker whose window is open, -1 for a new one at _new_cell, -2 when none is.
var editing := -2
## Fingers on the map by index, and how far apart two of them were when the pinch
## last changed the zoom.
var _fingers := {}
var _pinch := 0.0
var _mouse_drag := false
var _last_touch := -100000
var _last_player := Vector2i(1 << 30, 0)
## Where a press began and whether it moved past TAP_SLOP (then it is no tap).
var _press_at := Vector2.ZERO
var _moved := false
var _new_cell := Vector2i.ZERO
var _panel := UiStyle.panel()
var _buttons: VBoxContainer
## The zoom buttons, dimmed at the largest and the smallest zoom.
var _plus: Button
var _minus: Button
var _title: Label
var _where: Label
var _clock: Label
var _hint: Label
var _ground: Minimap.Layer
var _top: Minimap.Layer
var _popup: PanelContainer
var _popup_info: Label
var _swatches: Array[Button] = []
var _remove: Button
var _touch := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ground = Minimap.ground_layer(func(l: Control) -> void:
		minimap.draw_ground(l, Rect2(Vector2.ZERO, l.size), centre, zoom()), CORNER)
	add_child(_ground)
	_top = Minimap.Layer.new(_draw_top)
	add_child(_top)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", GAP)
	add_child(_buttons)
	_button("close", "Закрыть (M)", close)
	_plus = _button("plus", "Крупнее", func() -> void: zoom_by(1))
	_minus = _button("minus", "Мельче", func() -> void: zoom_by(-1))
	zoom_by(0)
	_button("target", "К игроку", func() -> void:
		centre = Vector2(minimap.player_cell)
		_hide_popup()
		redraw())
	_title = UiStyle.label("Карта", UiStyle.ACCENT)
	_title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	add_child(_title)
	_where = UiStyle.label("", UiStyle.INK)
	add_child(_where)
	_clock = UiStyle.label("", UiStyle.MUTED)
	add_child(_clock)
	_hint = UiStyle.label("", UiStyle.MUTED)
	add_child(_hint)
	_build_popup()


func _button(icon: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BUTTON, BUTTON)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


## The window of a marker: where it is and how far, the colours, and a bin to take it off.
func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.TIGHT))
	_popup.visible = false
	add_child(_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_popup.add_child(box)
	_popup_info = UiStyle.label("", UiStyle.MUTED)
	box.add_child(_popup_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	box.add_child(row)
	for i in Markers.COLORS.size():
		var b := Button.new()
		b.icon = _swatch(Markers.COLORS[i][1])
		b.tooltip_text = (Markers.COLORS[i][0] as String).capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(BUTTON - 4, BUTTON - 4)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("h_separation", 0)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, _swatch_box(state, false))
		b.pressed.connect(_pick_color.bind(i))
		row.add_child(b)
		_swatches.append(b)
	_remove = Button.new()
	_remove.icon = UiStyle.icon("trash")
	_remove.tooltip_text = "Убрать маркер"
	_remove.focus_mode = Control.FOCUS_NONE
	_remove.custom_minimum_size = Vector2(BUTTON - 4, BUTTON - 4)
	_remove.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remove.pressed.connect(_remove_marker)
	row.add_child(_remove)


## A square of `color` outlined dark, for a colour's button.
static func _swatch(color: Color) -> ImageTexture:
	var img := Image.create_empty(SWATCH, SWATCH, false, Image.FORMAT_RGBA8)
	img.fill(UiStyle.DARK_INK)
	img.fill_rect(Rect2i(1, 1, SWATCH - 2, SWATCH - 2), color)
	img.fill_rect(Rect2i(1, SWATCH - 3, SWATCH - 2, 2), color.darkened(0.3))
	return ImageTexture.create_from_image(img)


## A colour button's frame, lit amber for the marker's own colour; little room inside.
static func _swatch_box(state: String, lit: bool) -> StyleBox:
	var box := UiStyle.button(state, lit)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 3
	box.content_margin_bottom = 5
	return box


## Covers a screen `screen` UI pixels large; `touch` picks the hint.
func fit(screen: Vector2, touch: bool) -> void:
	_touch = touch
	position = Vector2.ZERO
	size = screen
	var inner := Rect2(Vector2(MARGIN, MARGIN), screen - 2 * Vector2(MARGIN, MARGIN)).grow(-PAD)
	_buttons.reset_size()
	_buttons.position = Vector2(inner.end.x - _buttons.size.x, inner.position.y)
	_title.reset_size()
	_title.position = inner.position
	var right := _buttons.position.x - GAP
	# Where the player is and the clock: two lines beside the title, or under it on a
	# narrow screen.
	_update_info()
	_where.reset_size()
	_clock.reset_size()
	var info_x := inner.position.x + _title.size.x + 12
	var info_y := inner.position.y
	if info_x + maxf(_where.size.x, _clock.size.x) + 40 > right:
		info_x = inner.position.x
		info_y = inner.position.y + _title.size.y + 2
	_where.position = Vector2(info_x, info_y)
	_clock.position = Vector2(info_x, info_y + UiStyle.FONT_SIZE + 4)
	var top := maxf(inner.position.y + _title.size.y, _clock.position.y + UiStyle.FONT_SIZE) + GAP + 1
	_hint.text = "Касание ставит маркер, щипок меняет масштаб" if touch \
			else "Щелчок ставит маркер, колесо меняет масштаб"
	# The hint right of the scale bar, or on a line of its own under it on a narrow screen.
	var natural := UiStyle.font().get_string_size(_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE).x
	var bottom := 0.0
	if natural <= right - inner.position.x - SCALE_WIDTH - 48:
		_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		_hint.size = Vector2(natural, UiStyle.FONT_SIZE)
		_hint.position = Vector2(right - natural, inner.end.y - _hint.size.y)
		bottom = _hint.position.y - GAP - 1
	else:
		# A wrapped label knows its lines once it has its width.
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint.size = Vector2(right - inner.position.x, 0)
		var lines := _hint.get_line_count()
		_hint.size.y = lines * _hint.get_line_height() + (lines - 1) * 4
		_hint.position = Vector2(inner.position.x, inner.end.y - _hint.size.y)
		bottom = _hint.position.y - GAP - UiStyle.FONT_SIZE - 4 - GAP - 1
	well = Rect2(inner.position.x + 1, top, right - inner.position.x - 2, bottom - top)
	_scale_at = Vector2(well.position.x, well.end.y + GAP + 1)
	Minimap.place_ground(_ground, well)
	_top.position = well.position
	_top.size = well.size
	_hide_popup()
	redraw()


## Redraws the panel, the ground and what is drawn over it.
func redraw() -> void:
	queue_redraw()
	_ground.queue_redraw()
	_top.queue_redraw()


func open() -> void:
	centre = Vector2(minimap.player_cell)
	_fingers.clear()
	_hide_popup()
	visible = true
	move_to_front()
	_update_info()
	redraw()


func close() -> void:
	visible = false
	_fingers.clear()
	_mouse_drag = false
	_hide_popup()


func zoom_by(d: int) -> void:
	zoom_index = clampi(zoom_index + d, 0, ZOOMS.size() - 1)
	_plus.disabled = zoom_index == ZOOMS.size() - 1
	_minus.disabled = zoom_index == 0
	_hide_popup()
	redraw()


func zoom() -> float:
	return ZOOMS[zoom_index]


func _process(_delta: float) -> void:
	if not visible:
		return
	if minimap.player_cell != _last_player:
		_last_player = minimap.player_cell
		_top.queue_redraw()
	_update_info()


## Where the player is (column and level) and the clock, as the corner of the game shows it.
func _update_info() -> void:
	var c := minimap.player_cell
	var where := "X %d · Y %d" % [c.x, c.y]
	var clock := ""
	if game != null and game.player != null:
		where += " · ур. %d" % game.player.level()
		clock = game.hud.clock_text()
	if where != _where.text or clock != _clock.text:
		_where.text = where
		_clock.text = clock


func _pan(screen_moved: Vector2) -> void:
	centre -= screen_moved / zoom() * Minimap.STEP
	redraw()


## The column under point `p` of this control.
func cell_at(p: Vector2) -> Vector2:
	return Minimap.to_cell(p - well.position, Rect2(Vector2.ZERO, well.size), centre, zoom())


## Where column `cell` is on this control.
func point_of(cell: Vector2) -> Vector2:
	return well.position + Minimap.to_screen(cell, Rect2(Vector2.ZERO, well.size), centre, zoom())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_last_touch = Time.get_ticks_msec()
		if event.pressed:
			if _fingers.is_empty():
				_press_at = event.position
				_moved = false
			else:
				_moved = true
			_fingers[event.index] = event.position
		else:
			_fingers.erase(event.index)
			if _fingers.is_empty() and not _moved:
				tap(event.position)
		_pinch = _spread()
	elif event is InputEventScreenDrag:
		_last_touch = Time.get_ticks_msec()
		_fingers[event.index] = event.position
		if not _moved and event.position.distance_to(_press_at) > TAP_SLOP:
			_moved = true
			_hide_popup()
		if _fingers.size() == 1 and _moved:
			_pan(event.relative)
		elif _fingers.size() == 2:
			var d := _spread()
			if _pinch > 0.0 and d > _pinch * 1.35:
				zoom_by(1)
				_pinch = d
			elif _pinch > 0.0 and d < _pinch / 1.35:
				zoom_by(-1)
				_pinch = d
	elif Time.get_ticks_msec() - _last_touch < TOUCH_MOUSE_MS:
		pass
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_drag = event.pressed
				if event.pressed:
					_press_at = event.position
					_moved = false
				elif not _moved:
					tap(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_by(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_by(-1)
	elif event is InputEventMouseMotion and _mouse_drag:
		if not _moved and event.position.distance_to(_press_at) > TAP_SLOP:
			_moved = true
			_hide_popup()
		if _moved:
			_pan(event.relative)
	accept_event()


## Distance between the first two fingers on the map, 0 with fewer.
func _spread() -> float:
	if _fingers.size() < 2:
		return 0.0
	var p: Array = _fingers.values()
	return (p[0] as Vector2).distance_to(p[1])


## A tap at `p`: closes the marker's window when one is open, else opens it for the
## marker whose flag is there, or for a new marker at that spot.
func tap(p: Vector2) -> void:
	if editing != -2:
		_hide_popup()
		return
	if markers == null or not well.has_point(p):
		return
	var hit := -1
	for i in range(markers.list.size() - 1, -1, -1):
		var at := point_of(Vector2(markers.list[i].cell))
		if Rect2(at.x - 3, at.y - 13, 13, 16).has_point(p):
			hit = i
			break
	if hit < 0:
		var c := cell_at(p).floor()
		_new_cell = Vector2i(c)
	_show_popup(hit)


## Opens the window of marker `i`, or of a new one at _new_cell (-1).
func _show_popup(i: int) -> void:
	editing = i
	var cell := _new_cell if i < 0 else (markers.list[i].cell as Vector2i)
	var away := Vector2(cell).distance_to(Vector2(minimap.player_cell))
	_popup_info.text = "X %d · Y %d · %d кл. от вас" % [cell.x, cell.y, roundi(away)]
	for j in _swatches.size():
		var lit: bool = i >= 0 and markers.list[i].color == j
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			_swatches[j].add_theme_stylebox_override(state, _swatch_box(state, lit))
	_remove.visible = i >= 0
	_popup.visible = true
	_popup.reset_size()
	# Below and to the right of the spot, inside the map.
	var at := point_of(Vector2(cell)) + Vector2(8, 6)
	at.x = clampf(at.x, well.position.x + 2, well.end.x - _popup.size.x - 2)
	if at.y + _popup.size.y > well.end.y - 2:
		at.y = point_of(Vector2(cell)).y - 16 - _popup.size.y
	at.y = clampf(at.y, well.position.y + 2, well.end.y - _popup.size.y - 2)
	_popup.position = at.floor()
	_top.queue_redraw()


func _hide_popup() -> void:
	if editing == -2:
		return
	editing = -2
	_popup.visible = false
	_top.queue_redraw()


func _pick_color(color: int) -> void:
	if editing == -1:
		markers.add(_new_cell, color)
	elif editing >= 0:
		markers.recolor(editing, color)
	_hide_popup()


func _remove_marker() -> void:
	if editing >= 0:
		markers.remove(editing)
	_hide_popup()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_M and not get_tree().paused:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and visible:
		if editing != -2:
			_hide_popup()
		else:
			close()
		get_viewport().set_input_as_handled()


## The game dimmed behind, the panel, and the map's sunken rectangle with its outline;
## the scale bar under it.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)
	# The panel's fill is see-through; the corner of the game would show through it.
	var frame := Rect2(Vector2(MARGIN, MARGIN), size - 2 * Vector2(MARGIN, MARGIN))
	draw_rect(frame.grow(-2), Color(UiStyle.PANEL, 1.0))
	draw_style_box(_panel, frame)
	Minimap.round_rect(self, well.grow(1), UiStyle.EDGE, CORNER + 1)
	Minimap.round_rect(self, well, Minimap.UNSEEN, CORNER)
	_draw_scale(_scale_at)


## A bar as long as a round number of cells, with the number beside it.
func _draw_scale(at: Vector2) -> void:
	var cells: int = SCALES[0]
	for s: int in SCALES:
		if s / float(Minimap.STEP) * zoom() <= SCALE_WIDTH:
			cells = s
	var w := roundf(cells / float(Minimap.STEP) * zoom())
	var y := at.y + 3
	draw_rect(Rect2(at.x, y, w + 2, 4), UiStyle.EDGE)
	draw_rect(Rect2(at.x + 1, y + 1, w, 2), UiStyle.INK)
	draw_rect(Rect2(at.x + 1, y + 1, floorf(w * 0.5), 2), UiStyle.MUTED)
	draw_string(UiStyle.font(), Vector2(at.x + w + 8, at.y + UiStyle.FONT_SIZE), "%d кл." % cells,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, UiStyle.MUTED)


## Over the ground: the marks of things placed and the sacks as pictures, the markers
## as flags, the player, the shade along the top and left of the sunken map and the
## north in its corner.
func _draw_top(l: Control) -> void:
	var rect := Rect2(Vector2.ZERO, l.size)
	minimap.draw_marks(l, rect, centre, zoom(), true)
	minimap.draw_markers(l, rect, centre, zoom(), true, editing)
	if editing == -1:
		# The spot a new marker would go.
		var s := Minimap.to_screen(Vector2(_new_cell), rect, centre, zoom())
		l.draw_rect(Rect2(s - Vector2(2, 2), Vector2(5, 5)), UiStyle.DARK_INK)
		l.draw_rect(Rect2(s - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT)
	var p := Minimap.to_screen(Vector2(minimap.player_cell), rect, centre, zoom())
	var r := 1.0 + clampi(zoom_index - 2, 0, 4)
	if rect.grow(-r - 1).has_point(p):
		l.draw_rect(Rect2(p - Vector2(r + 1, r + 1), Vector2(2 * r + 3, 2 * r + 3)), UiStyle.DARK_INK)
		l.draw_rect(Rect2(p - Vector2(r, r), Vector2(2 * r + 1, 2 * r + 1)), UiStyle.ACCENT)
	l.draw_rect(Rect2(CORNER, 0, rect.size.x - 2 * CORNER, 1), UiStyle.WELL_SHADE)
	l.draw_rect(Rect2(0, CORNER, 1, rect.size.y - 2 * CORNER), UiStyle.WELL_SHADE)
	# The north: a letter under an arrow, on a dark plate in the top right corner.
	var plate := Rect2(rect.end.x - 6 - 14, 6, 14, 22)
	l.draw_rect(plate, Color(UiStyle.DARK_INK, 0.75))
	var mid := plate.position.x + 7
	for i in 4:
		l.draw_rect(Rect2(mid - i - 1, plate.position.y + 3 + i, 2 * i + 2, 1), UiStyle.ACCENT)
	l.draw_string(UiStyle.font(), Vector2(plate.position.x + 3, plate.end.y - 3), "С",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, UiStyle.INK)
