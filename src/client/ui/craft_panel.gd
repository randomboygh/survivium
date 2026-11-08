extends VBoxContainer
## The craft tab of the bag window (plan/design/ui.md, section 5), as wide as the bag
## tab: a column of tabs by kind of item on the left, the recipes known as cells sorted
## by kind (Items.CATEGORIES: stations, then tools...; dimmed when they cannot be made
## now), the stations near as a column of pictures on the right (hands first, then the
## stations of the recipes known, the far ones dimmed). Under them two panels: the recipe
## chosen, as named groups of small wells laid side by side (see FactChips): «Материалы»
## and «Не тратится» (have / need, short in red), «На чём» (the station or hands), «Чем» (the tools,
## «нет» in red when missing), the time (at the character's skill), what it makes
## (weight, work, how long it lasts) and its by-products, then an amber «сделать» with
## «×5» (five can be made) and «MAX» (more than one) joined, in one line on the left; and under it, while it holds jobs, the queue, a
## row as wide: small cells for the jobs, the time left of the one chosen and the count
## over the first job's progress, the pause and «отменить | отменить все». Opened at a
## station, buttons in the window's head (by the cross, see station_buttons) take it
## back into the bag; at a campfire, put it out or light it again for a branch, feed it one piece of fuel (its charge drawn on that button) and destroy it once it is out. Works through Workshop.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const IconTabs := preload("res://src/client/ui/icon_tabs.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const Items := preload("res://src/shared/content/items.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const CraftQueue := preload("res://src/shared/game/craft_queue.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Placed := preload("res://src/shared/game/placed.gd")

const COLUMNS := 8
## The most cells of recipes made in one refresh (see refresh_now).
const NEW_CELLS := 2
## The rows of recipes shown whole before the list scrolls.
const ROWS := 4
const JOB_SLOT := 24
## What the queue's row keeps beside its cells, in UI pixels: the time and count over
## the progress, the pause and the two buttons to cancel.
const QUEUE_INFO := 56
const QUEUE_BUTTONS := 94
## What «MAX» asks for: the whole queue, as far as the materials go.
const MOST := CraftQueue.MAX_JOBS

var game
## The side of a cell (set by the window, see InventoryWindow.fit).
var slot := 40
## How tall the cells of recipes may grow before they scroll, in UI pixels (set by the
## window for the screen); the limit now, less what the window took off so it fits.
var list_height := 160
var _cap := 160
## Called after a refresh changed what the tab shows, to fit the window round it.
var on_layout := Callable()

## The buttons of the station the tab was opened at, put in the window's head.
var station_buttons: HBoxContainer
var _take_up: Button
## A campfire's buttons: put it out or light it again, and destroy it once it is out.
var _fire: Button
var _destroy: Button
var _tabs: IconTabs
var _stations: HBoxContainer
## How many stations fit the line of «Сделать» (see fit_width).
var _stations_fit := 6
## Dragging over the cells scrolls them.
var _drag: DragScroll
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
## The cells over the recipe and the queue, or beside them on a wide screen (set_side).
var _split: BoxContainer
var _bottom: VBoxContainer
## The panel of the recipe chosen.
var _details: PanelContainer
var _icon: TextureRect
var _title: Label
## «Получить» in the recipe's top right corner, while the playtest switch «Бесплатные
## предметы» is on (Rules.free_items): what the recipe makes, for nothing.
var _get: Button
var _facts: FactChips
## The width the recipe's name may take beside its picture (see fit_width).
var _title_room := 100
var _make: HBoxContainer
## «сделать», «×5» and «MAX».
var _make_one: Button
var _make_five: Button
var _make_most: Button
## The panel of the queue.
var _queue_panel: Control
## The cells of jobs that fit the queue's row (see fit_width).
var _job_fit := 1
## The time and count of the job chosen over the first job's progress.
var _job_info: VBoxContainer
var _queue_count: Label
var _controls: HBoxContainer
var _pause: Button
var _job_row: HBoxContainer
var _job_slots := []
var _job_more: Label
var _job_label: Label
var _progress: ProgressBar
## At a campfire, by the button that puts it out or lights it: feed it one piece of
## fuel from the bag; a bar along its bottom shows how full the fire is (Placed.fuel_share),
## its tooltip how long it burns on.
var _feed: Button
var _fuel_bar: Control
## The station the tab was opened at (a record of Props.placed), or {}.
var _station := {}
## What the stations near were at the last refresh, to notice walking up to one.
var _stations_seen := ""
## Cells of the recipes known by recipe id, and the recipe chosen.
var _cells := {}
var _chosen := ""
## The job of the queue chosen, and the seconds left last shown.
var _job := 0
var _left_shown := -1
var _dirty := true


func _init(g) -> void:
	game = g


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	station_buttons = HBoxContainer.new()
	station_buttons.add_theme_constant_override("separation", 4)
	station_buttons.visible = false
	_take_up = TabRow.icon_button(UiStyle.icon("take"), "Забрать в сумку", func() -> void:
		game.net.request(Protocol.PROP_TAKE, [_station.cell]).then(_station_gone))
	_fire = TabRow.icon_button(UiStyle.icon("put_out"), "Потушить", func() -> void:
		game.net.request(Protocol.PROP_FIRE, [_station.cell, not _station.lit]).then(func(_v: Variant) -> void: refresh()))
	_feed = TabRow.icon_button(UiStyle.icon("feed"), "Подкинуть топливо", func() -> void:
		game.net.request(Protocol.PROP_FIRE, [_station.cell, true]).then(func(_v: Variant) -> void: refresh()))
	_fuel_bar = Control.new()
	_fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuel_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fuel_bar.draw.connect(_draw_fuel)
	_feed.add_child(_fuel_bar)
	game.placed.lit_changed.connect(_on_fire)
	game.placed.fuel_changed.connect(_on_fire)
	_destroy = TabRow.icon_button(UiStyle.icon("trash"), "Уничтожить", func() -> void:
		game.net.request(Protocol.PROP_DESTROY, [_station.cell]).then(_station_gone))
	for b in [_take_up, _fire, _feed, _destroy]:
		b.custom_minimum_size = Vector2(30, 30)
		station_buttons.add_child(b)

	_split = BoxContainer.new()
	_split.vertical = true
	_split.add_theme_constant_override("separation", 6)
	add_child(_split)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(middle)
	_tabs = IconTabs.new()
	_tabs.picked.connect(func(_k: String) -> void: refresh_now())
	middle.add_child(_tabs)
	var cells := VBoxContainer.new()
	cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(cells)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# As tall as the row (the tabs beside may be taller), so the cells scroll only when
	# they do not fit.
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cells.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)
	_empty = UiStyle.label("Рецептов пока нет. Собери волокно (копай траву), ветки и кремень (копай землю).", UiStyle.MUTED)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size.x = 160
	cells.add_child(_empty)
	_drag = DragScroll.new()
	_scroll.add_child(_drag)

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	_bottom = bottom
	_split.add_child(bottom)
	_details = _panel(bottom)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_details.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	_icon = _picture(null, 24)
	top.add_child(_icon)
	_title = UiStyle.label()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.custom_minimum_size.x = 100
	top.add_child(_title)
	_get = TabRow.icon_button(UiStyle.icon("gift"), "Получить бесплатно", _get_free)
	_get.custom_minimum_size = Vector2(30, 30)
	_get.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_get)
	_facts = FactChips.new()
	_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_facts)
	# One line: «сделать» (amber, as wide as the inventory's action button) on the left,
	# joined to «×5» when five can be made and «MAX» when more than one can (then
	# «сделать» takes two thirds of its width and each of them a third); the stations on
	# the right (hands first, then those near, then the far ones dimmed).
	_make = HBoxContainer.new()
	_make.add_theme_constant_override("separation", 4)
	box.add_child(_make)
	var make := TabRow.split([
		[UiStyle.icon("hammer"), "Сделать одну", func() -> void: _start(1)],
		["×5", "Сделать пять", func() -> void: _start(5)],
		["MAX", "Сделать столько, сколько хватит материалов", func() -> void: _start(MOST)],
	])
	_make_one = make.get_child(0)
	_make_five = make.get_child(1)
	_make_most = make.get_child(2)
	for b: Button in [_make_one, _make_five, _make_most]:
		b.custom_minimum_size.y = 30
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.accent(_make_one)
	# Its picture dark on the amber.
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		_make_one.add_theme_color_override(c, UiStyle.DARK_INK)
	_make_one.add_theme_color_override("icon_disabled_color", Color(UiStyle.DARK_INK, 0.5))
	_make.add_child(make)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make.add_child(gap)
	_stations = HBoxContainer.new()
	_stations.add_theme_constant_override("separation", 2)
	_stations.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_make.add_child(_stations)

	var queue := _panel(bottom)
	_queue_panel = queue
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	queue.add_child(row)
	_job_row = HBoxContainer.new()
	_job_row.add_theme_constant_override("separation", 4)
	row.add_child(_job_row)
	_job_more = UiStyle.label("", UiStyle.MUTED)
	_job_more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_job_row.add_child(_job_more)
	_job_info = VBoxContainer.new()
	_job_info.add_theme_constant_override("separation", 4)
	_job_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_job_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_job_info.custom_minimum_size.x = QUEUE_INFO
	row.add_child(_job_info)
	var line := HBoxContainer.new()
	_job_info.add_child(line)
	_job_label = UiStyle.label()
	# A long word is cut, the row keeps its width.
	_job_label.clip_text = true
	_job_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_job_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_job_label.custom_minimum_size.x = 24
	line.add_child(_job_label)
	_queue_count = UiStyle.label("", UiStyle.MUTED)
	_queue_count.tooltip_text = "Работ в очереди"
	_queue_count.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(_queue_count)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.max_value = 1.0
	_job_info.add_child(_progress)
	_controls = HBoxContainer.new()
	_controls.add_theme_constant_override("separation", 4)
	_controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_controls)
	_pause = TabRow.icon_button(UiStyle.icon("pause"), "Пауза", func() -> void:
		game.net.request(Protocol.CRAFT_PAUSE, [not game.workshop.paused]).then(func(_v: Variant) -> void: refresh_now()))
	_controls.add_child(_pause)
	_controls.add_child(TabRow.split([
		[UiStyle.icon("close"), "Отменить выбранную", func() -> void: game.net.request(Protocol.CRAFT_CANCEL, [_job])],
		[UiStyle.icon("cancel_all"), "Отменить все", func() -> void: game.net.request(Protocol.CRAFT_CANCEL_ALL, [])],
	]))
	game.workshop.changed.connect(refresh)


## The recipe and the queue in a column `w` UI pixels wide right of the cells (a wide
## screen low for them under the cells), or under the cells as wide as the tab.
func set_side(on: bool, w: int) -> void:
	_split.vertical = not on
	_bottom.custom_minimum_size.x = w if on else 0
	fit_width(w)


## The recipe's name takes what its line leaves: less the playtest's «получить» beside
## it when that shows, or the button widens the window past the bag's (#386).
func _fit_title() -> void:
	_title.custom_minimum_size.x = _title_room - (6 + int(_get.custom_minimum_size.x) if _get.visible else 0)


## The tab is `w` UI pixels wide: the recipe's name is measured at its panel's width
## (a wrapping label is laid out at its least width).
func fit_width(w: int) -> void:
	_title_room = w - 2 * UiStyle.WELL_PAD - 30
	_fit_title()
	# What «Сделать | ×5 | MAX» leaves of the line for the stations.
	_stations_fit = maxi(1, (w - 2 * UiStyle.WELL_PAD - roundi(TabRow.WIDE * 4.0 / 3.0) - 8) / (IconTabs.SIDE + 2))
	var room := w - 2 * UiStyle.WELL_PAD - QUEUE_INFO - QUEUE_BUTTONS - 3 * 6 - 16
	_job_fit = maxi(1, room / (JOB_SLOT + 4))



## Opened at placed thing `e` (a station), or {} for none.
func at_station(e: Dictionary) -> void:
	_station = e
	refresh_now()


## Shows the stations, the recipes and the queue as they are now: at the next frame
## (see refresh_progress), so several changes in one frame cost one refresh.
func refresh() -> void:
	_dirty = true


## Refreshes at once (when the window opens).
func refresh_now() -> void:
	_dirty = false
	if not is_visible_in_tree():
		return
	var shop = game.workshop
	var inv = game.character.inventory
	var known: Array = _by_kind(_all_recipes() if _free() else shop.recipes())
	var stations: Dictionary = shop.stations()
	_stations_seen = str(stations.keys())
	if not _station.is_empty() and not game.placed.things.has(_station):
		_station = {}
	_show_head()
	_show_stations(known, stations)
	# Tabs of the kinds of things the recipes known make.
	var have := {}
	for r: Dictionary in known:
		have[Items.category(r.makes)] = true
	var kinds := IconTabs.kinds(have)
	_tabs.set_tabs(kinds[0], kinds[1], kinds[2])
	_empty.visible = known.is_empty()
	_scroll.visible = not known.is_empty()
	var shown := []
	var made := 0
	for i in known.size():
		var r: Dictionary = known[i]
		if not _cells.has(r.id):
			# Many recipes learnt at once (a cord makes a dozen known): their cells come
			# a few a frame, as each reads its picture from the disk.
			if made >= NEW_CELLS:
				_dirty = true
				continue
			made += 1
			var cell = HotbarSlot.new(slot)
			cell.texture = ItemIcons.of_item(r.makes)
			cell.number = "×%d" % r.count if r.count > 1 else ""
			cell.tooltip_text = r.title
			# Picked as the finger lifts: a finger dragged over the cells scrolls them.
			cell.on_release = true
			cell.pressed.connect(func() -> void:
				if _drag.take_tap():
					_choose(r.id))
			_grid.add_child(cell)
			_cells[r.id] = cell
		var cell = _cells[r.id]
		cell.custom_minimum_size = Vector2(slot, slot)
		# By kind (see _by_kind; a move sorts the grid again: only when needed).
		var at := mini(i, _grid.get_child_count() - 1)
		if cell.get_index() != at:
			_grid.move_child(cell, at)
		cell.visible = _tabs.chosen == "" or Items.category(r.makes) == _tabs.chosen
		cell.modulate = Color.WHITE if Crafting.why_not(r, inv, stations) == "" else Color(1, 1, 1, 0.45)
		if cell.visible:
			shown.append(r.id)
	# Cells of recipes no longer listed (the playtest's free items turned off) hide.
	if _cells.size() > known.size():
		var listed := {}
		for r: Dictionary in known:
			listed[r.id] = true
		for id: String in _cells:
			if not listed.has(id):
				_cells[id].visible = false
	if not shown.has(_chosen):
		_chosen = shown[0] if not shown.is_empty() else ""
	for id in _cells:
		_cells[id].selected = id == _chosen
	_show_details(stations)
	_show_queue()
	_cap = list_height
	_fit_list()
	if on_layout.is_valid():
		on_layout.call()


## Recipes `known` by the kind of what they make, in the order of Items.CATEGORIES
## (stations first, then tools...), in the order of the data files within a kind.
static func _by_kind(known: Array) -> Array:
	var order := Items.CATEGORIES.keys()
	var keyed := []
	for i in known.size():
		keyed.append([order.find(Items.category(known[i].makes)), i, known[i]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or a[0] == b[0] and a[1] < b[1])
	return keyed.map(func(k: Array) -> Dictionary: return k[2])


## Whether the playtest switch «Бесплатные предметы» is on.
func _free() -> bool:
	return game.rules != null and game.rules.free_items


## Every recipe this world can make (Crafting.possible), known or not.
static func _all_recipes() -> Array:
	return Crafting.RECIPES.filter(func(r: Dictionary) -> bool: return Crafting.possible(r))


## «Получить»: the server gives what the recipe chosen makes; the button lights green
## for a moment when it came.
func _get_free() -> void:
	var b := _get
	game.net.request(Protocol.CRAFT_FREE, [_chosen]).then(func(got: Variant) -> void:
		if not is_instance_valid(b) or not (got is int and got > 0):
			return
		UiStyle.succeed(b, true)
		b.get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_instance_valid(b):
				UiStyle.succeed(b, false)))


func _choose(id: String) -> void:
	_chosen = id
	refresh_now()


func _start(n: int) -> void:
	game.net.request(Protocol.CRAFT, [_chosen, n])


## The station the tab was opened at was taken up or destroyed (`done` true).
func _station_gone(done: Variant) -> void:
	if done is bool and done:
		_station = {}
		refresh()


## What can be done with the station the tab was opened at.
func _show_head() -> void:
	station_buttons.visible = not _station.is_empty()
	if not station_buttons.visible:
		return
	var fire: bool = game.placed.is_fire(_station)
	# A fireplace put out is taken up whole; a campfire put out is only taken apart.
	var hearth := Placed.is_hearth(_station)
	_take_up.visible = not fire or hearth and not _station.lit
	_take_up.tooltip_text = "Забрать в сумку: %s" % Items.title(_station.item)
	_fire.visible = fire
	_destroy.visible = fire and not _station.lit and not hearth
	var burns: bool = fire and Items.get_item(_station.item).fuel_max > 0.0
	_feed.visible = burns
	if burns:
		var left := roundi(float(_station.get("fuel", 0.0))) if _station.lit else 0
		var room: bool = Items.get_item(_station.item).fuel_max - float(_station.get("fuel", 0.0)) >= Placed.FUEL_ROOM
		var has := Items.fuel_in(game.character.inventory) != ""
		_feed.disabled = not _station.lit or not room or not has
		_feed.tooltip_text = ("Подкинуть топливо (горит ещё %d:%02d)" % [left / 60, left % 60] if _station.lit else "Огонь не горит") \
			+ ("" if room or not _station.lit else ": полон") + ("" if has or not _station.lit else ": в сумке нет топлива")
		_fuel_bar.queue_redraw()
	if fire:
		_fire.icon = UiStyle.icon("put_out" if _station.lit else "light")
		_fire.tooltip_text = "Потушить огонь" if _station.lit else "Разжечь (ветка или другое топливо)"


## The fire's charge along the bottom of the feed button.
func _draw_fuel() -> void:
	if _station.is_empty() or not Placed.is_fire(_station):
		return
	var share := Placed.fuel_share(_station) if _station.lit else 0.0
	var r := Rect2(5, _fuel_bar.size.y - 6, _fuel_bar.size.x - 10, 3)
	_fuel_bar.draw_rect(r, UiStyle.WELL)
	var color := UiStyle.DANGER if share < 0.2 else UiStyle.ACCENT
	_fuel_bar.draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * share), r.size.y)), color)


## A campfire burned down, was fed or went out: the one the tab is open at shows it.
func _on_fire(e: Dictionary) -> void:
	if is_same(e, _station):
		_show_head()


## Hands first (what is made anywhere), then the stations of the recipes known: lit
## when near, dimmed when not.
func _show_stations(known: Array, near: Dictionary) -> void:
	var ids := [""]
	for id in near:
		if not ids.has(id):
			ids.append(id)
	for r: Dictionary in known:
		if r.at != "" and not ids.has(r.at):
			ids.append(r.at)
	# As many as the line has room for: the far ones go first.
	ids.resize(mini(ids.size(), _stations_fit))
	while _stations.get_child_count() < ids.size():
		var chip := _chip()
		chip.custom_minimum_size = Vector2(IconTabs.SIDE, IconTabs.SIDE - 2)
		_stations.add_child(chip)
	var chips := _stations.get_children()
	for i in chips.size():
		var chip: PanelContainer = chips[i]
		chip.visible = i < ids.size()
		if not chip.visible:
			continue
		var id: String = ids[i]
		_set_chip(chip, ItemIcons.picture("hand") if id == "" else ItemIcons.of_item(id))
		chip.tooltip_text = "Руками" if id == "" else "%s%s" % [Items.title(id), "" if near.has(id) else ": далеко"]
		chip.modulate = Color.WHITE if id == "" or near.has(id) else Color(1, 1, 1, 0.35)


## The panel of the recipe chosen: what it makes and its weight, a picture for each
## thing it uses up and keeps with how many the bag has of how many, its station and
## tools (red when missing), its time, its by-products; the buttons work only when it
## can be made now.
func _show_details(near: Dictionary) -> void:
	var r := Crafting.get_recipe(_chosen)
	_details.visible = not r.is_empty()
	if r.is_empty():
		return
	var inv = game.character.inventory
	_icon.texture = ItemIcons.of_item(r.makes)
	_title.text = "%s%s" % [r.title, " ×%d" % r.count if r.count > 1 else ""]
	_get.visible = _free()
	_fit_title()
	var needs := []
	for id in r.needs:
		var have: int = inv.count(id)
		needs.append([ItemIcons.of_item(id), "%d/%d" % [have, r.needs[id]], have < r.needs[id], Items.title(id)])
	var keeps := []
	for id in r.keeps:
		var have: int = inv.count(id)
		keeps.append([ItemIcons.of_item(id), "%d/%d" % [have, r.keeps[id]], have < r.keeps[id], "%s: не расходуется" % Items.title(id)])
	var at := []
	if r.at != "":
		at.append([ItemIcons.of_item(r.at), "" if near.has(r.at) else "нет", not near.has(r.at), Items.title(r.at)])
	else:
		at.append([ItemIcons.picture("hand"), "", false, "Руками, без станка"])
	var tools := []
	for kind: String in r.tools:
		var has := Tools.holds(inv, kind)
		var name := Items.tool_title(kind)
		tools.append([ItemIcons.of_tool(kind), "" if has else "нет", not has,
			name.left(1).to_upper() + name.substr(1) + (": износ %d за изделие" % r.wear if r.wear > 0 else "")])
	# The time of the recipe at the character's skill of its work.
	var secs: float = game.workshop.time_of(r)
	var time := [[UiStyle.icon("clock"), "%d с" % roundi(secs), false, "Время изготовления" +
		(" (без навыка %d с)" % roundi(r.time) if roundi(secs) < roundi(r.time) else "")]]
	var also := []
	for e: Dictionary in r.also:
		var share := roundi(e.chance * 100.0)
		also.append([ItemIcons.of_item(e.item), "+%d" % e.count if share >= 100 else "%d%%" % share, false,
			"Побочно: %s ×%d%s" % [Items.title(e.item), e.count, "" if share >= 100 else ", шанс %d%%" % share]])
	var made := []
	for g: Array in FactChips.item_groups(r.makes, r.count):
		made.append_array(g[1])
	_facts.show_groups([["Материалы", needs], ["Не тратится", keeps], ["На чём", at],
		["Чем", tools], ["Время", time], ["Изделие", made], ["Побочно", also]])
	var can := Crafting.why_not(r, inv, near) == ""
	var times := _times(r, inv) if can else 0
	_make_one.disabled = not can
	_make_five.visible = times >= 5
	_make_most.visible = times > 1
	if _make_most.visible:
		_make_one.custom_minimum_size.x = roundf(TabRow.WIDE * 2.0 / 3.0)
		for b: Button in [_make_five, _make_most]:
			b.custom_minimum_size.x = TabRow.WIDE - _make_one.custom_minimum_size.x + 2
	else:
		_make_one.custom_minimum_size.x = TabRow.WIDE


## How many times recipe `r` can be made from what bag `inv` holds (its materials and
## what it keeps), MOST at the most.
static func _times(r: Dictionary, inv) -> int:
	var n := MOST
	for id in r.needs:
		n = mini(n, inv.count(id) / int(r.needs[id]))
	for id in r.keeps:
		if inv.count(id) < int(r.keeps[id]):
			n = 0
	return n


## The panel of the queue: a cell for each job that fits, the one chosen named with
## its time left (or what it waits for), the first job's progress, the buttons.
func _show_queue() -> void:
	var shop = game.workshop
	var jobs: Array = shop.queue.jobs
	# An empty queue is not shown.
	_queue_panel.visible = not jobs.is_empty()
	_queue_count.text = "%d/%d" % [jobs.size(), CraftQueue.MAX_JOBS]
	for c in [_controls, _job_row, _job_info]:
		c.visible = not jobs.is_empty()
	_pause.icon = UiStyle.icon("play" if shop.paused else "pause")
	_pause.tooltip_text = "Продолжить" if shop.paused else "Пауза"
	TabRow.light(_pause, shop.paused)
	if jobs.is_empty():
		_job = 0
		return
	_job = clampi(_job, 0, jobs.size() - 1)
	var n := mini(jobs.size(), _job_fit)
	while _job_slots.size() < n:
		var cell = HotbarSlot.new(JOB_SLOT)
		cell.pressed.connect(_choose_job.bind(_job_slots.size()))
		_job_row.add_child(cell)
		_job_row.move_child(cell, _job_slots.size())
		_job_slots.append(cell)
	for i in _job_slots.size():
		var cell = _job_slots[i]
		cell.visible = i < n
		if cell.visible:
			var r := Crafting.get_recipe(jobs[i].recipe)
			cell.texture = ItemIcons.of_item(r.get("makes", ""))
			cell.number = "×%d" % r.count if r.get("count", 1) > 1 else ""
			cell.selected = i == _job
	_job_more.visible = jobs.size() > n
	_job_more.text = "+%d" % (jobs.size() - n)
	# The job chosen by its time left (its name is on its cell's tooltip).
	var r := Crafting.get_recipe(jobs[_job].recipe)
	var name := r.get("title", jobs[_job].recipe) as String
	var text := ""
	if _job > 0:
		text = "%d-я" % (_job + 1)
	elif shop.paused:
		text = "пауза"
	elif shop.waiting():
		text = "ждёт"
		name += ", ждёт: %s" % _where(r)
	else:
		text = "%d с" % ceili(jobs[0].left * game.workshop.time_of(r) / maxf(0.001, float(r.get("time", 1.0))))
	_job_label.text = text
	_job_label.tooltip_text = name
	for i in n:
		_job_slots[i].tooltip_text = Crafting.get_recipe(jobs[i].recipe).get("title", "")
	_progress.value = shop.queue.progress()


func _choose_job(i: int) -> void:
	_job = i
	_show_queue()


## What the first job waits for: its station, a tool or a thing it keeps.
func _where(r: Dictionary) -> String:
	return game.workshop.waits_for(r)


## Takes `px` UI pixels off the cells of recipes (they scroll), so the window fits the
## screen's height.
func shrink_list(px: float) -> void:
	_cap = maxi(slot, int(_scroll.custom_minimum_size.y - ceilf(px)))
	_fit_list()


## The cells as tall as their rows, up to the limit; true when that changed the height.
## Past ROWS whole rows (or the room the window has) the list scrolls.
func _fit_list() -> bool:
	var full := maxi(slot, ceili(_grid.get_combined_minimum_size().y))
	var row := slot + 4
	var h := float(full)
	if full > mini(_cap, ROWS * row - 4):
		var rows := clampi((mini(_cap, ROWS * row - 4) + 4) / row, 1, ROWS)
		h = rows * row - 4
	# As many kinds on the left as fit beside ROWS rows of cells.
	_tabs.fit_height(ROWS * row - 4)
	if h == _scroll.custom_minimum_size.y:
		return false
	_scroll.custom_minimum_size.y = h
	return true


## Called every frame while the window is open: the refresh asked for, a refresh when
## the player walked up to a station or away, else the progress of the first job.
func refresh_progress() -> void:
	if not is_visible_in_tree():
		return
	if _dirty or str(game.workshop.stations().keys()) != _stations_seen:
		refresh_now()
		return
	var jobs: Array = game.workshop.queue.jobs
	if not jobs.is_empty():
		_progress.value = game.workshop.queue.progress()
		var left := ceili(jobs[0].left)
		if left != _left_shown:
			_left_shown = left
			_show_queue()


## A sunken panel in `parent`.
func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.well())
	parent.add_child(p)
	return p


## A small well with a picture (a station's).
func _chip() -> PanelContainer:
	var p := PanelContainer.new()
	var box := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, 4)
	p.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(_picture(null, 12))
	return p


func _set_chip(chip: PanelContainer, texture: Texture2D) -> void:
	chip.get_child(0).get_child(0).texture = texture


func _picture(texture: Texture2D, side: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side, side)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
