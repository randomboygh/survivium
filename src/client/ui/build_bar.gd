extends VBoxContainer
## The build mode's bar (BuildMode), in the hotbar's place while the mode is on: on top
## the panel of the mode (the shape: line, plane, square, cube; how high and how thick
## the walls are, a tap each going round 1–4; drawing or taking off the blueprint; taking
## all of it off near; leaving the mode), under it the palette: its filters («Всё»,
## «Материалы», «Интерьер») as a column of picture tabs on its left, as the bag's kinds
## (IconTabs), then the bag's blocks and things in two rows across the width (eight
## columns on a portrait screen, smaller cells), arrows scrolling it a column at a time
## when they do not all fit. The chosen one is in the hand in use; the hands themselves
## are not shown. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const IconTabs := preload("res://src/client/ui/icon_tabs.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")

const SLOT := 40
## A portrait screen's cells and arrows, so eight columns fit its width.
const SLOT_PORTRAIT := 34
const ARROW_PORTRAIT := 18
const COLUMNS_PORTRAIT := 8
const ROWS := 2
const GAP := 4
const ARROW := 28
## The panel's buttons and the tabs, one button tall.
const BUTTON := 30
const SHAPES := [["build_line", "line", "Линия: стена"], ["build_plane", "plane", "Плоскость: пол"],
	["build_square", "square", "Квадрат: стены вокруг"], ["build_cube", "cube", "Куб: пол, стены и потолок"]]
const FORMS := [["form_cube", "Блок: целый"], ["form_ramp", "Скос снизу"], ["form_upper", "Скос сверху"],
	["form_stairs", "Ступени"]]
const FILTER_TITLES := {"all": "Всё", "blocks": "Материалы", "interior": "Интерьер"}

var game
var _shapes: HBoxContainer
var _forms: HBoxContainer
var _rows: VBoxContainer
var _row2: HBoxContainer
var _turn: Button
var _modes: HBoxContainer
var _height: Button
var _thick: Button
var _filters: IconTabs
var _palette: PanelContainer
var _grid: GridContainer
var _prev: Button
var _next: Button
var _slots: Array = []
## The items on the palette, the first column shown, how many columns fit.
var _items: Array[String] = []
var _first := 0
var _columns := 8
## The side of a cell now (SLOT, or SLOT_PORTRAIT on a portrait screen).
var _side := SLOT


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
	for s: Array in SHAPES:
		var k: String = s[1]
		parts.append([UiStyle.icon(s[0]), s[2], func() -> void: game.build.set_kind(k)])
	_shapes = TabRow.split(parts)
	panel.add_child(_shapes)
	_height = _cycle("build_height", "Высота стен", func() -> void: game.build.next_height())
	_thick = _cycle("build_thick", "Толщина стен", func() -> void: game.build.next_thick())
	var form_parts := []
	for i in FORMS.size():
		var k := i
		form_parts.append([UiStyle.icon(FORMS[i][0]), FORMS[i][1], func() -> void: game.build.set_form(k)])
	_forms = TabRow.split(form_parts)
	_turn = TabRow.icon_button(UiStyle.icon("turn_right"), "Повернуть скос или ступени (Y)", func() -> void: game.build.turn())
	_forms.add_child(_turn)
	panel.add_child(_forms)
	var sizes := TabRow.split([])
	sizes.add_child(_height)
	sizes.add_child(_thick)
	panel.add_child(sizes)
	_modes = TabRow.split([
		[UiStyle.icon("build_draw"), "Рисовать чертёж", func() -> void: game.build.set_erasing(false)],
		[UiStyle.icon("build_erase"), "Стирать чертёж", func() -> void: game.build.set_erasing(true)],
	])
	panel.add_child(_modes)
	var ends := TabRow.split([
		[UiStyle.icon("trash"), "Убрать все чертежи рядом", func() -> void: game.build.clear()],
		[UiStyle.icon("close"), "Выйти из режима строительства (B)", func() -> void: game.build.leave()],
	])
	panel.add_child(ends)
	for row: HBoxContainer in [_shapes, _forms, _modes, ends]:
		for b: Button in row.get_children():
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
	_palette.add_child(row)
	_filters = IconTabs.new()
	_filters.picked.connect(func(k: String) -> void: game.build.set_filter(k))
	row.add_child(_filters)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(room)
	_prev = _arrow(row, "prev", "Предыдущие", func() -> void: _scroll(-1))
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	row.add_child(_grid)
	_next = _arrow(row, "next", "Следующие", func() -> void: _scroll(1))
	var room_end := Control.new()
	room_end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(room_end)
	_set_filters()
	game.build.changed.connect(refresh)
	game.character.state_changed.connect(_refresh_later)


## The filters' tabs: the blocks' one shows the first block loaded, so it is set again
## until the content is there.
func _set_filters() -> void:
	var block := Items.of_category("blocks")
	var icons := {"all": UiStyle.icon("all"), "blocks": ItemIcons.of_item(block) if block != "" else UiStyle.icon("build_line"),
		"interior": UiStyle.icon("chest")}
	_filters.set_tabs(FILTER_TITLES.keys(), icons, FILTER_TITLES)


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
	b.custom_minimum_size = Vector2(44, BUTTON)
	return b


func _arrow(parent: Node, icon: String, tip: String, action: Callable) -> Button:
	var b := TabRow.icon_button(UiStyle.icon(icon), tip, action)
	b.custom_minimum_size = Vector2(ARROW, SLOT)
	b.size_flags_vertical = Control.SIZE_FILL
	parent.add_child(b)
	return b


## The width the palette takes with `columns` columns of the big cells.
static func width_for(columns: int) -> float:
	return 8 + IconTabs.SIDE + GAP + 2 * (ARROW + GAP) + columns * (SLOT + GAP) - GAP


## Lays the palette out for `width` UI px: as many columns as fit beside the filters
## and the arrows, eight of smaller cells on a portrait screen (`portrait`).
func fit(width: float, portrait := false) -> void:
	var side := SLOT_PORTRAIT if portrait else SLOT
	var arrow := ARROW_PORTRAIT if portrait else ARROW
	if side != _side:
		_side = side
		# Out of the grid at once: its size is measured in this frame.
		for s in _slots:
			_grid.remove_child(s)
			s.queue_free()
		_slots.clear()
	_prev.custom_minimum_size = Vector2(arrow, side)
	_next.custom_minimum_size = Vector2(arrow, side)
	var fixed := 8 + IconTabs.SIDE + GAP + 2 * (arrow + GAP)
	_columns = maxi(1, floori((width - fixed + GAP) / (side + GAP)))
	if portrait:
		_columns = mini(_columns, COLUMNS_PORTRAIT)
	# All three filters shown, none scrolled: the palette a little taller than its rows
	# on a portrait screen.
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
			home.move_child(_forms, 1)
	_row2.visible = two
	_filters.fit_height(maxf(ROWS * side + GAP, FILTER_TITLES.size() * (IconTabs.SIDE + 2) - 2))
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
	for i in SHAPES.size():
		TabRow.light(_shapes.get_child(i), b.kind == SHAPES[i][1])
	for i in FORMS.size():
		TabRow.light(_forms.get_child(i), b.form == i)
	_turn.disabled = b.form == 0
	# The height means nothing for a plane: a plane is one level (as thick as chosen, down).
	_height.text = str(b.height)
	_height.disabled = b.kind == "plane"
	_thick.text = str(b.thick)
	TabRow.light(_modes.get_child(0), not b.erasing)
	TabRow.light(_modes.get_child(1), b.erasing, b.erasing)
	_set_filters()
	_filters.select(b.filter)
	_items = b.palette()
	# Always two rows and every column of the width, empty cells where the bag has less.
	var total_cols := ceili(float(_items.size()) / ROWS)
	var shown_cols := _columns
	_first = clampi(_first, 0, maxi(0, total_cols - shown_cols))
	_grid.columns = shown_cols
	var n := shown_cols * ROWS
	while _slots.size() < n:
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
		s.visible = i < n
		if i >= n:
			continue
		# Column by column: the first row, then the second, of each column shown.
		var col := _first + i % shown_cols
		var row := i / shown_cols
		var at := col * ROWS + row
		var id: String = _items[at] if at < _items.size() else ""
		s.texture = ItemIcons.of_item(id) if id != "" else null
		var count: int = inv.count(id) if id != "" else 0
		s.number = "×%d" % count if count > 1 else ""
		s.selected = id != "" and id == held
		s.tooltip_text = Items.title(id) if id != "" else ""
	var scrolls := total_cols > shown_cols
	_prev.visible = scrolls
	_next.visible = scrolls
	_prev.disabled = _first <= 0
	_next.disabled = _first >= total_cols - shown_cols
	if _items.is_empty():
		_slots[0].tooltip_text = "Нечего строить: нет блоков" if b.filter != "interior" else "Нечего строить: нет вещей"


## Slot `k` shown was tapped: its item into the hand.
func _tap(k: int) -> void:
	var shown_cols: int = _grid.columns
	var at: int = (_first + k % shown_cols) * ROWS + k / shown_cols
	if at < _items.size():
		game.build.choose(_items[at])


func _scroll(by: int) -> void:
	_first += by
	refresh()
