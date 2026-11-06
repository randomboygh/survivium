extends VBoxContainer
## The build mode's bar (BuildMode), in the hotbar's place while the mode is on: on top
## the panel of the mode in one row: the palette's filters («Всё», «Материалы»,
## «Интерьер») as picture tabs, then one button each going round its choices: the shape
## (line, plane, square, cube, flattening), the form (a block, the slopes, stairs) with
## its turn, how high and how thick the walls are (1–4), drawing or taking off the
## blueprint joined with taking all of it off near (a second tap to confirm), and leaving
## the mode; under it the palette: the bag's blocks and things in one row as the hotbar's slots
## (no hands), arrows on its sides scrolling it when they do not all fit (eight cells at
## most on a portrait screen, smaller ones). The chosen one is in the hand in use.
## `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")

const SLOT := 40
## A portrait screen's cells and arrows, so eight fit its width.
const SLOT_PORTRAIT := 34
const ARROW_PORTRAIT := 18
const COLUMNS_PORTRAIT := 8
const GAP := 4
const ARROW := 28
## The panel's buttons and the tabs, one button tall; the height and thickness narrower.
const BUTTON := 30
const SIZE_MARGIN := 2
## How long the clear button waits for its second tap, ms.
const CONFIRM_MS := 3000
const SHAPES := {"line": ["build_line", "Линия: стена"], "plane": ["build_plane", "Плоскость: пол"],
	"square": ["build_square", "Квадрат: стены вокруг"], "cube": ["build_cube", "Куб: пол, стены и потолок"],
	"flatten": ["build_flatten", "Выровнять землю: срезать выше, засыпать ямы землёй из сумки"]}
const FORMS := [["form_cube", "Блок: целый"], ["form_ramp", "Скос снизу"], ["form_upper", "Скос сверху"],
	["form_stairs", "Ступени"]]
const FILTER_TITLES := {"all": "Всё", "blocks": "Материалы", "interior": "Интерьер"}

var game
var _rows: VBoxContainer
var _row2: HBoxContainer
var _forms: HBoxContainer
var _shape: Button
var _form: Button
var _turn: Button
var _height: Button
var _thick: Button
var _mode: Button
var _clear: Button
var _filters: HBoxContainer
var _palette: PanelContainer
var _grid: HBoxContainer
var _prev: Button
var _next: Button
var _slots: Array = []
## The items on the palette, the first one shown, how many fit.
var _items: Array[String] = []
var _first := 0
var _columns := 8
## The side of a cell now (SLOT, or SLOT_PORTRAIT on a portrait screen).
var _side := SLOT
## When the clear button was tapped first (ms), 0 when it waits for no second tap.
var _clear_at := 0


func _init(g) -> void:
	game = g
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
	var parts := []
	for k: String in FILTER_TITLES:
		var key := k
		parts.append([UiStyle.icon("all"), FILTER_TITLES[k], func() -> void: game.build.set_filter(key)])
	_filters = TabRow.tabs(parts, BUTTON)
	panel.add_child(_filters)
	_shape = TabRow.icon_button(UiStyle.icon("build_line"), "", func() -> void: game.build.next_kind())
	panel.add_child(_shape)
	_forms = TabRow.split([
		[UiStyle.icon("form_cube"), "", func() -> void: game.build.next_form()],
		[UiStyle.icon("turn_right"), "Повернуть скос или ступени (Y)", func() -> void: game.build.turn()],
	])
	_form = _forms.get_child(0)
	_turn = _forms.get_child(1)
	panel.add_child(_forms)
	_height = _cycle("build_height", "Высота стен", func() -> void: game.build.next_height())
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
	var leave := TabRow.icon_button(UiStyle.icon("close"), "Выйти из режима строительства (B)", func() -> void: game.build.leave())
	panel.add_child(leave)
	for b: Button in _filters.get_children() + [_shape, _form, _turn, _mode, _clear, leave]:
		b.custom_minimum_size = Vector2(BUTTON, BUTTON)
	_palette = PanelContainer.new()
	_palette.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UiStyle.panel()
	for side in ["left", "top", "right", "bottom"]:
		box.set("content_margin_" + side, 4)
	_palette.add_theme_stylebox_override("panel", box)
	# As wide as the bar: the clock under it keeps to its right end.
	_palette.size_flags_horizontal = Control.SIZE_FILL
	add_child(_palette)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_palette.add_child(row)
	_prev = _arrow(row, "prev", "Предыдущие", func() -> void: _scroll(-1))
	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", GAP)
	row.add_child(_grid)
	_next = _arrow(row, "next", "Следующие", func() -> void: _scroll(1))
	_set_filters()
	game.build.changed.connect(refresh)
	game.character.state_changed.connect(_refresh_later)


## The filters' pictures: the blocks' one shows the first block loaded, so it is set
## again until the content is there.
func _set_filters() -> void:
	var block := Items.of_category("blocks")
	var icons := [UiStyle.icon("all"), ItemIcons.of_item(block) if block != "" else UiStyle.icon("build_line"),
		UiStyle.icon("chest")]
	for i in icons.size():
		var b: Button = _filters.get_child(i)
		b.icon = UiStyle.centred(icons[i])


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A button showing a picture and a number, a tap going round the number.
func _cycle(icon: String, tip: String, action: Callable) -> Button:
	var b := TabRow.small_button("", action)
	b.icon = UiStyle.centred(UiStyle.icon(icon))
	b.tooltip_text = tip
	b.add_theme_constant_override("h_separation", 1)
	# Narrower than the others: thin margins at the sides.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBox = b.get_theme_stylebox(state).duplicate()
		box.content_margin_left = SIZE_MARGIN
		box.content_margin_right = SIZE_MARGIN
		b.add_theme_stylebox_override(state, box)
	b.custom_minimum_size = Vector2(0, BUTTON)
	return b


func _arrow(parent: Node, icon: String, tip: String, action: Callable) -> Button:
	var b := TabRow.icon_button(UiStyle.icon(icon), tip, action)
	b.custom_minimum_size = Vector2(ARROW, SLOT)
	b.size_flags_vertical = Control.SIZE_FILL
	parent.add_child(b)
	return b


## The clear button: the first tap lights it red and asks for a second within
## CONFIRM_MS, which takes the blueprints off.
func _tap_clear() -> void:
	if _clear_at > 0 and Time.get_ticks_msec() - _clear_at < CONFIRM_MS:
		_clear_at = 0
		game.build.clear()
		return
	_clear_at = Time.get_ticks_msec()
	game.hud.toast("Нажмите ещё раз, чтобы убрать все чертежи рядом")
	refresh()
	get_tree().create_timer(CONFIRM_MS / 1000.0).timeout.connect(_clear_timeout)


func _clear_timeout() -> void:
	if _clear_at > 0 and Time.get_ticks_msec() - _clear_at >= CONFIRM_MS - 50:
		_clear_at = 0
		refresh()


## The width the palette takes with `columns` of the big cells.
static func width_for(columns: int) -> float:
	return 8 + 2 * (ARROW + GAP) + columns * (SLOT + GAP) - GAP


## Lays the palette out for `width` UI px: as many cells as fit between the arrows,
## eight smaller ones at most on a portrait screen (`portrait`).
func fit(width: float, portrait := false) -> void:
	var side := SLOT_PORTRAIT if portrait else SLOT
	var arrow := ARROW_PORTRAIT if portrait else ARROW
	if side != _side:
		_side = side
		# Out of the row at once: its size is measured in this frame.
		for s in _slots:
			_grid.remove_child(s)
			s.queue_free()
		_slots.clear()
	_prev.custom_minimum_size = Vector2(arrow, side)
	_next.custom_minimum_size = Vector2(arrow, side)
	var fixed := 8 + 2 * (arrow + GAP)
	_columns = maxi(1, floori((width - fixed + GAP) / (side + GAP)))
	if portrait:
		_columns = mini(_columns, COLUMNS_PORTRAIT)
	# The forms in the row of the other buttons when they all fit across, else over it.
	var one: HBoxContainer = _rows.get_child(1)
	var across := 0.0
	for g: Control in one.get_children() + _row2.get_children():
		across += g.get_combined_minimum_size().x + 6
	var two := across - 6 > width
	var home: HBoxContainer = _row2 if two else one
	if _forms.get_parent() != home:
		_forms.get_parent().remove_child(_forms)
		home.add_child(_forms)
		if home == one:
			home.move_child(_forms, 2)
	_row2.visible = two
	refresh()


var _due := false


func _refresh_later() -> void:
	if not _due and visible:
		_due = true
		refresh.call_deferred()


## Shows the mode's state and the palette anew.
func refresh() -> void:
	_due = false
	var b = game.build
	var shape: Array = SHAPES.get(b.kind, SHAPES["line"])
	_shape.icon = UiStyle.centred(UiStyle.icon(shape[0]))
	_shape.tooltip_text = shape[1] + " (нажать — следующая фигура)"
	_form.icon = UiStyle.centred(UiStyle.icon(FORMS[b.form][0]))
	_form.tooltip_text = FORMS[b.form][1] + " (нажать — следующая форма)"
	_turn.disabled = b.form == 0
	# The height means nothing for a plane: a plane is one level (as thick as chosen, down).
	_height.text = str(b.height)
	_height.disabled = b.kind in ["plane", "flatten"]
	_thick.disabled = b.kind == "flatten"
	_thick.text = str(b.thick)
	_mode.icon = UiStyle.centred(UiStyle.icon("build_erase" if b.erasing else "build_draw"))
	_mode.tooltip_text = "Стирать чертёж (нажать — рисовать)" if b.erasing else "Рисовать чертёж (нажать — стирать)"
	TabRow.light(_mode, b.erasing, b.erasing)
	var confirming := _clear_at > 0 and Time.get_ticks_msec() - _clear_at < CONFIRM_MS
	TabRow.light(_clear, confirming, confirming)
	_set_filters()
	var keys := FILTER_TITLES.keys()
	for i in keys.size():
		TabRow.light(_filters.get_child(i), b.filter == keys[i])
	_items = b.palette()
	# Every cell of the width, empty ones where the bag has less.
	var shown := _columns
	_first = clampi(_first, 0, maxi(0, _items.size() - shown))
	while _slots.size() < shown:
		var s = HotbarSlot.new(_side)
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
		s.tooltip_text = Items.title(id) if id != "" else ""
	var scrolls := _items.size() > shown
	_prev.visible = scrolls
	_next.visible = scrolls
	_prev.disabled = _first <= 0
	_next.disabled = _first >= _items.size() - shown
	if _items.is_empty():
		_slots[0].tooltip_text = "Нечего строить: нет блоков" if b.filter != "interior" else "Нечего строить: нет вещей"


## Slot `k` shown was tapped: its item into the hand.
func _tap(k: int) -> void:
	var at := _first + k
	if at < _items.size():
		game.build.choose(_items[at])


## The arrows: a cell at a time, as the hotbar's.
func _scroll(by: int) -> void:
	_first += by
	refresh()
