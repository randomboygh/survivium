extends VBoxContainer
## The build mode's bar (BuildMode), in the hotbar's place while the mode is on: on top
## the panel of the mode in one row, one button each going round its choices: the shape
## (line, plane, square, cube) with flattening beside it, the form (a block, the slopes, stairs) with
## its turn, how high and how thick the walls are (1–4), drawing or taking off the
## blueprint joined with taking all of it off near (a second tap to confirm), on a PC the
## action button's work (building the blueprint, F; on a touch screen the big action button
## does it), and leaving the mode; under it the palette: the bag's blocks and things in one row made as the
## hotbar (its frame, cells, arrows and a finger dragging the cells along) with no hands,
## its cells in their room: as wide as the hotbar. The chosen one is in the hand in use.
## `game` is the Main node, `mode` the mode the bar is of (BuildMode; FarmBar, which
## extends it, is the farming mode's bar with its own panel).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## The hotbar's cells, gaps and arrows (Hud.SLOT, Hud.GAP).
const SLOT := 40
const GAP := 4
const ARROW := 28
## The most cells shown: the hotbar's slots and its hands' two (eight and two, four and
## two on a portrait screen), so the palette is as wide as the hotbar.
const COLUMNS := 10
const COLUMNS_PORTRAIT := 6
## The panel's buttons, one button tall and at least as wide.
const BUTTON := 30
## How long the clear button waits for its second tap, ms.
const CONFIRM_MS := 3000
const SHAPES := {"line": ["build_line", "Линия: стена"], "plane": ["build_plane", "Плоскость: пол"],
	"square": ["build_square", "Квадрат: стены вокруг"], "cube": ["build_cube", "Куб: пол, стены и потолок"]}
const FORMS := [["form_cube", "Блок: целый"], ["form_ramp", "Скос снизу"], ["form_upper", "Скос сверху"],
	["form_stairs", "Ступени"]]

var game
var mode
var _rows: VBoxContainer
var _row2: HBoxContainer
var _forms: HBoxContainer
var _shape: Button
var _flatten: Button
var _form: Button
var _turn: Button
var _height: Button
var _thick: Button
var _mode: Button
var _clear: Button
## The mode's action on a PC (the touch screen's action button, F): starts the work of the
## whole blueprint or the marks near, a second press stops it.
var _go: Button
var _palette: PanelContainer
var _grid: HBoxContainer
var _prev: Button
var _next: Button
var _slots: Array = []
## The items on the palette, the first one shown, how many fit.
var _items: Array[String] = []
var _first := 0
var _columns := 8
## The finger dragging the cells along (-1 none), its x in the row where the drag
## stands, and whether it moved far enough to be a drag, not a tap (as the hotbar's).
var _swipe := -1
var _swipe_x := 0.0
var _swiped := false
var _cells_row: HBoxContainer
## When the clear button was tapped first (ms), 0 when it waits for no second tap.
var _clear_at := 0


func _init(g, m = null) -> void:
	game = g
	mode = m if m != null else g.build
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The groups of buttons in a row; on a narrow screen the forms go to a second row
	# over it (fit).
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	_row2 = _row()
	_rows.add_child(_row2)
	var panel := _row()
	_rows.add_child(panel)
	_make_panel(panel)
	_palette = PanelContainer.new()
	_palette.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UiStyle.panel()
	for side in ["left", "top", "right", "bottom"]:
		box.set("content_margin_" + side, 4)
	_palette.add_theme_stylebox_override("panel", box)
	# As wide as its cells, as the hotbar: the clock goes under its right end (right_edge).
	_palette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_palette)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	_palette.add_child(row)
	_cells_row = row
	_prev = _arrow(row, "prev", "Предыдущие", func() -> void: _scroll(-1))
	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", GAP)
	row.add_child(_grid)
	_next = _arrow(row, "next", "Следующие", func() -> void: _scroll(1))
	mode.changed.connect(refresh)
	game.character.state_changed.connect(_refresh_later)


## The mode's buttons in row `panel`.
func _make_panel(panel: HBoxContainer) -> void:
	var shapes := TabRow.split([
		[UiStyle.icon("build_line"), "", func() -> void: game.build.next_kind()],
		[UiStyle.icon("build_flatten"), "Выровнять землю: срезать выше, засыпать ямы землёй из сумки",
			func() -> void: game.build.set_kind("flatten")],
	])
	_shape = shapes.get_child(0)
	_flatten = shapes.get_child(1)
	panel.add_child(shapes)
	_forms = TabRow.split([
		[UiStyle.icon("form_cube"), "", func() -> void: game.build.next_form()],
		[UiStyle.icon("turn_right"), "Повернуть скос или ступени (Y)", func() -> void: game.build.turn()],
	])
	_form = _forms.get_child(0)
	_turn = _forms.get_child(1)
	panel.add_child(_forms)
	_height = _cycle("build_height", "Высота", func() -> void: game.build.next_height())
	_thick = _cycle("build_thick", "Толщина стен", func() -> void: game.build.next_thick())
	var sizes := TabRow.split([])
	sizes.add_child(_height)
	sizes.add_child(_thick)
	panel.add_child(sizes)
	var marks := TabRow.split([
		[UiStyle.icon("build_draw"), "", func() -> void: game.build.set_erasing(not game.build.erasing)],
		[UiStyle.icon("trash"), "Убрать все чертежи рядом (нажать дважды)", _tap_clear],
	])
	_mode = marks.get_child(0)
	_clear = marks.get_child(1)
	panel.add_child(marks)
	_add_go(panel)
	var leave := TabRow.icon_button(UiStyle.icon("close"), "Выйти из режима строительства (B)", func() -> void: game.build.leave())
	panel.add_child(leave)
	for b: Button in [_shape, _flatten, _form, _turn, _mode, _clear, leave]:
		b.custom_minimum_size = Vector2(BUTTON, BUTTON)


## The action button of the panel (`_go`) into row `panel`: shown on a PC only (`_show_go`).
func _add_go(panel: HBoxContainer) -> void:
	_go = TabRow.icon_button(UiStyle.icon("go"), "", func() -> void: mode.toggle_auto())
	_go.custom_minimum_size = Vector2(BUTTON, BUTTON)
	panel.add_child(_go)


## The tip of the action button.
func _go_tip() -> String:
	return "Построить весь чертёж рядом (F)"


## Shows the action button anew: a PC only, a picture alone (the tip names it), lit with
## «Остановить» while the work goes on.
func _show_go() -> void:
	_go.visible = not game.hud.touch
	var working: bool = mode.auto
	_go.icon = UiStyle.centred(UiStyle.icon("halt" if working else "go"))
	_go.tooltip_text = "Остановить (F)" if working else _go_tip()
	TabRow.light(_go, working)


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A button showing a picture and a number side by side in its middle, a tap going round
## the number (`_number` sets it).
func _cycle(icon: String, tip: String, action: Callable) -> Button:
	var b := TabRow.small_button("", action)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(BUTTON, BUTTON)
	# Over the button's inner area, as the other buttons' pictures are (its frame's margins).
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 4
	box.offset_bottom = -6
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var pic := TextureRect.new()
	pic.texture = UiStyle.centred(UiStyle.icon(icon))
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var number := Label.new()
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", UiStyle.INK)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(number)
	return b


## Sets the number of a `_cycle` button and whether it can be tapped.
func _number(b: Button, n: int, off: bool) -> void:
	var box: HBoxContainer = b.get_child(0)
	(box.get_child(1) as Label).text = str(n)
	b.disabled = off
	box.modulate.a = 0.4 if off else 1.0
	b.custom_minimum_size.x = maxf(BUTTON, box.get_combined_minimum_size().x + 8)


## An arrow made as the hotbar's (Hud._icon_button).
func _arrow(parent: Node, icon: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ARROW, SLOT)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", UiStyle.panel())
	b.add_theme_stylebox_override("hover", UiStyle.panel())
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## The clear button: the first tap lights it red and asks for a second within
## CONFIRM_MS, which takes the blueprints off.
func _tap_clear() -> void:
	if _clear_at > 0 and Time.get_ticks_msec() - _clear_at < CONFIRM_MS:
		_clear_at = 0
		mode.clear()
		return
	_clear_at = Time.get_ticks_msec()
	game.hud.toast(_clear_ask())
	refresh()
	get_tree().create_timer(CONFIRM_MS / 1000.0).timeout.connect(_clear_timeout)


## What the clear button asks on its first tap.
func _clear_ask() -> String:
	return "Нажмите ещё раз, чтобы убрать все чертежи рядом"


func _clear_timeout() -> void:
	if _clear_at > 0 and Time.get_ticks_msec() - _clear_at >= CONFIRM_MS - 50:
		_clear_at = 0
		refresh()


## The width the palette takes with `columns` of the big cells.
static func width_for(columns: int) -> float:
	return 8 + 2 * (ARROW + GAP) + columns * (SLOT + GAP) - GAP


## Lays the palette out for `width` UI px: as many cells as fit between the arrows, as
## many as the hotbar's room holds at most (COLUMNS, COLUMNS_PORTRAIT on a portrait screen).
func fit(width: float, portrait := false) -> void:
	var fixed := 8 + 2 * (ARROW + GAP)
	_columns = clampi(floori((width - fixed + GAP) / (SLOT + GAP)), 1, COLUMNS_PORTRAIT if portrait else COLUMNS)
	_show_go()
	# The forms in the row of the other buttons when they all fit across, else over it.
	var one: HBoxContainer = _rows.get_child(1)
	var across := 0.0
	for g: Control in one.get_children() + _row2.get_children():
		across += g.get_combined_minimum_size().x + 6
	var two := across - 6 > width
	var home: HBoxContainer = _row2 if two else one
	var wide := _wide_group()
	if wide != null and wide.get_parent() != home:
		wide.get_parent().remove_child(wide)
		home.add_child(wide)
		if home == one:
			home.move_child(wide, 1)
	_row2.visible = two
	refresh()


## The forms' buttons (moved to a second row on a narrow screen by fit), null for none.
func _wide_group() -> Control:
	return _forms


var _due := false


func _refresh_later() -> void:
	if not _due and visible:
		_due = true
		refresh.call_deferred()


## Shows the mode's state and the palette anew.
func refresh() -> void:
	_due = false
	_show_panel()
	_show_palette()


## Shows the mode's buttons anew.
func _show_panel() -> void:
	var b = game.build
	var shape: Array = SHAPES.get(b.shape, SHAPES["line"])
	_shape.icon = UiStyle.centred(UiStyle.icon(shape[0]))
	_shape.tooltip_text = Lang.f("%s (нажать — следующая фигура)", [shape[1]])
	TabRow.light(_shape, b.kind != "flatten")
	TabRow.light(_flatten, b.kind == "flatten")
	_form.icon = UiStyle.centred(UiStyle.icon(FORMS[b.form][0]))
	_form.tooltip_text = Lang.f("%s (нажать — следующая форма)", [FORMS[b.form][1]])
	_turn.disabled = b.form == 0
	# A plane is as many levels as its height and has no walls to thicken.
	_number(_height, b.height, b.kind == "flatten")
	_number(_thick, b.thick, b.kind in ["plane", "flatten"])
	_height.tooltip_text = Lang.f("Высота: пол %s, стены %s, куб %s (с полом и потолком)", [
		b.heights.plane, b.heights.line, b.heights.cube])
	_mode.icon = UiStyle.centred(UiStyle.icon("build_erase" if b.erasing else "build_draw"))
	_mode.tooltip_text = "Стирать чертёж (нажать — рисовать)" if b.erasing else "Рисовать чертёж (нажать — стирать)"
	TabRow.light(_mode, b.erasing, b.erasing)
	var confirming := _clear_at > 0 and Time.get_ticks_msec() - _clear_at < CONFIRM_MS
	TabRow.light(_clear, confirming, confirming)
	_show_go()


## Shows the palette anew: the mode's items, the chosen one marked.
func _show_palette() -> void:
	var b = mode
	_items = b.palette()
	# Every cell of the width, empty ones where the bag has less.
	var shown := _columns
	_first = clampi(_first, 0, maxi(0, _items.size() - shown))
	while _slots.size() < shown:
		var s = HotbarSlot.new(SLOT)
		s.on_release = true
		var k := _slots.size()
		s.pressed.connect(func() -> void: _tap(k))
		_grid.add_child(s)
		_slots.append(s)
	var inv = game.character.inventory
	var held: String = b.chosen()
	for i in _slots.size():
		var s = _slots[i]
		s.visible = i < shown
		if i >= shown:
			continue
		var at := _first + i
		var id: String = _items[at] if at < _items.size() else ""
		s.texture = ItemIcons.of_item(id) if id != "" else null
		var count: int = inv.count(id) if id != "" else 0
		s.number = "×%d" % count if count > 1 else ""
		s.selected = id != "" and id == held
		s.tooltip_text = Lang.t(Items.title(id)) if id != "" else ""
	var scrolls := _items.size() > shown
	_prev.visible = scrolls
	_next.visible = scrolls
	_prev.disabled = _first <= 0
	_next.disabled = _first >= _items.size() - shown
	if _items.is_empty():
		_slots[0].tooltip_text = _nothing()


## The tip of the empty palette.
func _nothing() -> String:
	return "Нечего строить: нет блоков" if mode.filter != "interior" else "Нечего строить: нет вещей"


## Slot `k` shown was tapped: its item into the hand.
func _tap(k: int) -> void:
	var at := _first + k
	if at < _items.size():
		mode.choose(_items[at])


## The arrows: a cell at a time, as the hotbar's; none past the ends.
func _scroll(by: int) -> void:
	var first := clampi(_first + by, 0, maxi(0, _items.size() - _columns))
	if first != _first:
		_first = first
		refresh()


## The x of the palette's right edge in the bar (the clock goes under it).
func right_edge() -> float:
	return _palette.position.x + _palette.size.x


## A finger dragged along the cells moves them a cell for each cell it passes, as on
## the hotbar; the tap it began with picks nothing.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _prev.visible:
		_swipe = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and _swipe < 0 and _in_cells(event.position):
			_swipe = event.index
			_swipe_x = _row_point(event.position).x
			_swiped = false
		elif not event.pressed and event.index == _swipe:
			_swipe = -1
	elif event is InputEventScreenDrag and event.index == _swipe:
		var x := _row_point(event.position).x
		if not _swiped and absf(x - _swipe_x) > 6.0:
			_swiped = true
			for s in _slots:
				s.cancel_tap()
		if _swiped:
			var step := SLOT + GAP
			while _swipe_x - x >= step:
				_scroll(1)
				_swipe_x -= step
			while x - _swipe_x >= step:
				_scroll(-1)
				_swipe_x += step


## Screen point `pos` in UI pixels of the row of cells.
func _row_point(pos: Vector2) -> Vector2:
	return _cells_row.get_global_transform_with_canvas().affine_inverse() * pos


## Whether screen point `pos` is on the cells between the arrows.
func _in_cells(pos: Vector2) -> bool:
	var p := _row_point(pos)
	return p.y >= 0.0 and p.y <= _cells_row.size.y and p.x >= _prev.position.x \
		and p.x <= _next.position.x + _next.size.x
