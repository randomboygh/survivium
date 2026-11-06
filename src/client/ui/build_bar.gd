extends VBoxContainer
## The build mode's bar (BuildMode), in the hotbar's place while the mode is on: on top
## the panel of the mode (the shape: line, plane, square, cube; how high and how thick
## the walls are, a tap each going round 1–4; drawing or taking off the blueprint; taking
## all of it off near; leaving the mode), under it the palette's filters («Всё»,
## «Материалы», «Интерьер», joined as tabs) and the palette: the bag's blocks and parts
## of a house across the width, two rows when there are enough, arrows scrolling it a
## column at a time when they do not all fit. The chosen one is in the hand in use; the
## hands themselves are not shown. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")

const SLOT := 40
const GAP := 4
const ARROW := 28
## The panel's buttons and the tabs, one button tall.
const BUTTON := 30
const SHAPES := [["build_line", "line", "Линия: стена"], ["build_plane", "plane", "Плоскость: пол"],
	["build_square", "square", "Квадрат: стены вокруг"], ["build_cube", "cube", "Куб: пол, стены и потолок"]]
const FILTER_TITLES := {"all": "Всё", "blocks": "Материалы", "interior": "Интерьер"}

var game
var _shapes: HBoxContainer
var _modes: HBoxContainer
var _height: Button
var _thick: Button
var _filters: HBoxContainer
var _palette: PanelContainer
var _grid: GridContainer
var _prev: Button
var _next: Button
var _slots: Array = []
## The items on the palette, the first column shown, how many columns fit.
var _items: Array[String] = []
var _first := 0
var _columns := 8
var _rows := 1


func _init(g) -> void:
	game = g
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := HBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(panel)
	var parts := []
	for s: Array in SHAPES:
		var k: String = s[1]
		parts.append([UiStyle.icon(s[0]), s[2], func() -> void: game.build.set_kind(k)])
	_shapes = TabRow.split(parts)
	panel.add_child(_shapes)
	_height = _cycle("build_height", "Высота стен", func() -> void: game.build.next_height())
	_thick = _cycle("build_thick", "Толщина стен", func() -> void: game.build.next_thick())
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
	for row: HBoxContainer in [_shapes, _modes, ends]:
		for b: Button in row.get_children():
			b.custom_minimum_size = Vector2(BUTTON, BUTTON)
	_filters = TabRow.tabs([], BUTTON)
	for f: String in FILTER_TITLES:
		var b := TabRow.small_button(FILTER_TITLES[f], func() -> void: game.build.set_filter(f))
		b.custom_minimum_size.y = BUTTON
		_filters.add_child(b)
	_filters.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_filters)
	_palette = PanelContainer.new()
	_palette.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UiStyle.panel()
	for side in ["left", "top", "right", "bottom"]:
		box.set("content_margin_" + side, 4)
	_palette.add_theme_stylebox_override("panel", box)
	_palette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_palette)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	_palette.add_child(row)
	_prev = _arrow(row, "prev", "Предыдущие", func() -> void: _scroll(-1))
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	row.add_child(_grid)
	_next = _arrow(row, "next", "Следующие", func() -> void: _scroll(1))
	game.build.changed.connect(refresh)
	game.character.state_changed.connect(_refresh_later)


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


## Lays the palette out for `width` UI px: as many columns as fit, two rows when the
## items fill more than one.
func fit(width: float) -> void:
	_columns = maxi(1, floori((width - 8 - 2 * (ARROW + GAP) + GAP) / (SLOT + GAP)))
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
	# The height means nothing for a plane: a plane is one level (as thick as chosen, down).
	_height.text = str(b.height)
	_height.disabled = b.kind == "plane"
	_thick.text = str(b.thick)
	TabRow.light(_modes.get_child(0), not b.erasing)
	TabRow.light(_modes.get_child(1), b.erasing, b.erasing)
	var keys := FILTER_TITLES.keys()
	for i in keys.size():
		TabRow.light(_filters.get_child(i), b.filter == keys[i])
	_items = b.palette()
	var cols := _columns
	_rows = 2 if _items.size() > cols else 1
	var total_cols := ceili(float(_items.size()) / _rows) if _rows > 0 else 0
	var shown_cols := mini(cols, maxi(total_cols, 1))
	_first = clampi(_first, 0, maxi(0, total_cols - shown_cols))
	_grid.columns = shown_cols
	var n := shown_cols * _rows
	while _slots.size() < n:
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
		s.visible = i < n
		if i >= n:
			continue
		# Column by column: the first row, then the second, of each column shown.
		var col := _first + i % shown_cols
		var row := i / shown_cols
		var at := col * _rows + row
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
		_slots[0].visible = true
		_slots[0].texture = null
		_slots[0].number = ""
		_slots[0].tooltip_text = "Нечего строить: нет блоков" if b.filter != "interior" else "Нечего строить: нет вещей для дома"


## Slot `k` shown was tapped: its item into the hand.
func _tap(k: int) -> void:
	var shown_cols: int = _grid.columns
	var at: int = (_first + k % shown_cols) * _rows + k / shown_cols
	if at < _items.size():
		game.build.choose(_items[at])


func _scroll(by: int) -> void:
	_first += by
	refresh()
