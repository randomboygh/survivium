extends VBoxContainer
## The craft tab of the bag window (plan/design/ui.md, section 5), as wide as the bag
## tab: a column of tabs by kind of item on the left, the recipes known as cells
## (dimmed when they cannot be made now), the stations near as a column of pictures on
## the right (hands first, then the stations of the recipes known, the far ones
## dimmed). Under them two panels: the recipe chosen, as small wells with pictures in
## columns (see FactChips): what it uses up and what it keeps (have / need, short in
## red), its station and tools («нет» in red when missing), its time (the recipe's: no
## skills yet), then what it makes weighs, does and lasts, and its by-products, with a
## wide «сделать» under «×5 | MAX» on the
## right; and under it, while it holds jobs, the queue, a row as wide: small cells
## for the jobs, the time left of the one chosen and the count over the first job's
## progress, the pause and «отменить | отменить все». Opened at a station, buttons in the window's head (by
## the cross, see station_buttons) take it back into the bag; at a campfire, put it
## out, light it again for a branch and destroy it once it is out. Works through
## Workshop.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const IconTabs := preload("res://src/client/ui/icon_tabs.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const Items := preload("res://src/shared/content/items.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const CraftQueue := preload("res://src/shared/game/craft_queue.gd")

const COLUMNS := 8
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
var _stations: VBoxContainer
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
var _facts: FactChips
var _make: VBoxContainer
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
		if game.placed.take_up(game.character, _station):
			_station = {}
			refresh())
	_fire = TabRow.icon_button(UiStyle.icon("put_out"), "Потушить", func() -> void:
		if _station.lit:
			game.placed.put_out(_station)
		else:
			game.placed.light(game.character, _station)
		refresh())
	_destroy = TabRow.icon_button(UiStyle.icon("trash"), "Уничтожить", func() -> void:
		if game.placed.destroy(_station):
			_station = {}
			refresh())
	for b in [_take_up, _fire, _destroy]:
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
	_stations = VBoxContainer.new()
	_stations.add_theme_constant_override("separation", 2)
	_stations.custom_minimum_size.x = IconTabs.SIDE
	middle.add_child(_stations)

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	_bottom = bottom
	_split.add_child(bottom)
	_details = _panel(bottom)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
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
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	box.add_child(body)
	_facts = FactChips.new()
	_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_facts)
	# «Сделать» is the button most pressed: wide, under «×5 | MAX».
	var more := TabRow.split([
		["×5", "Сделать пять", func() -> void: _start(5)],
		["MAX", "Сделать столько, сколько хватит материалов", func() -> void: _start(MOST)],
	])
	for b in more.get_children():
		b.custom_minimum_size = Vector2(41, 30)
	_make = TabRow.block(more, [UiStyle.icon("hammer"), "Сделать одну", func() -> void: _start(1)], 2 * 41 - 2)
	body.add_child(_make)

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
		game.workshop.paused = not game.workshop.paused
		refresh_now())
	_controls.add_child(_pause)
	_controls.add_child(TabRow.split([
		[UiStyle.icon("close"), "Отменить выбранную", func() -> void: game.workshop.cancel(_job)],
		[UiStyle.icon("cancel_all"), "Отменить все", func() -> void: game.workshop.cancel_all()],
	]))
	game.workshop.changed.connect(refresh)


## The tab is `w` UI pixels wide: the recipe's name is measured at its panel's width
## (a wrapping label is laid out at its least width).
## The recipe and the queue in a column `w` UI pixels wide right of the cells (a wide
## screen low for them under the cells), or under the cells as wide as the tab.
func set_side(on: bool, w: int) -> void:
	_split.vertical = not on
	_bottom.custom_minimum_size.x = w if on else 0
	fit_width(w)


func fit_width(w: int) -> void:
	_title.custom_minimum_size.x = w - 2 * UiStyle.WELL_PAD - 30
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
	var known: Array = shop.recipes()
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
	for r: Dictionary in known:
		if not _cells.has(r.id):
			var cell = HotbarSlot.new(slot)
			cell.texture = ItemIcons.of_item(r.makes)
			cell.number = "×%d" % r.count if r.count > 1 else ""
			cell.tooltip_text = r.title
			cell.pressed.connect(_choose.bind(r.id))
			_grid.add_child(cell)
			_cells[r.id] = cell
		var cell = _cells[r.id]
		cell.custom_minimum_size = Vector2(slot, slot)
		# In the order of the data files.
		_grid.move_child(cell, known.find(r))
		cell.visible = _tabs.chosen == "" or Items.category(r.makes) == _tabs.chosen
		cell.modulate = Color.WHITE if Crafting.why_not(r, inv, stations) == "" else Color(1, 1, 1, 0.45)
		if cell.visible:
			shown.append(r.id)
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


func _choose(id: String) -> void:
	_chosen = id
	refresh_now()


func _start(n: int) -> void:
	game.workshop.start(Crafting.get_recipe(_chosen), n)


## What can be done with the station the tab was opened at.
func _show_head() -> void:
	station_buttons.visible = not _station.is_empty()
	if not station_buttons.visible:
		return
	var fire: bool = game.placed.is_fire(_station)
	_take_up.visible = not fire
	_take_up.tooltip_text = "Забрать в сумку: %s" % Items.title(_station.item)
	_fire.visible = fire
	_destroy.visible = fire and not _station.lit
	if fire:
		_fire.icon = UiStyle.icon("put_out" if _station.lit else "light")
		_fire.tooltip_text = "Потушить костёр" if _station.lit else "Разжечь (ветка или другое топливо)"


## Hands first (what is made anywhere), then the stations of the recipes known: lit
## when near, dimmed when not.
func _show_stations(known: Array, near: Dictionary) -> void:
	var ids := [""]
	for r: Dictionary in known:
		if r.at != "" and not ids.has(r.at):
			ids.append(r.at)
	for id in near:
		if not ids.has(id):
			ids.append(id)
	while _stations.get_child_count() < ids.size():
		var chip := _chip(null, "")
		chip.custom_minimum_size = Vector2(IconTabs.SIDE, IconTabs.SIDE - 2)
		_stations.add_child(chip)
	for i in _stations.get_child_count():
		var chip: PanelContainer = _stations.get_child(i)
		chip.visible = i < ids.size()
		if not chip.visible:
			continue
		var id: String = ids[i]
		_set_chip(chip, ItemIcons.picture("hand") if id == "" else ItemIcons.of_item(id), "")
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
	var needs := []
	for id in r.needs:
		var have: int = inv.count(id)
		needs.append([ItemIcons.of_item(id), "%d/%d" % [have, r.needs[id]], have < r.needs[id], Items.title(id)])
	for id in r.keeps:
		var have: int = inv.count(id)
		needs.append([ItemIcons.of_item(id), "%d/%d" % [have, r.keeps[id]], have < r.keeps[id], "%s: не расходуется" % Items.title(id)])
	var where := []
	if r.at != "":
		where.append([ItemIcons.of_item(r.at), "" if near.has(r.at) else "нет", not near.has(r.at), Items.title(r.at)])
	for kind: String in r.tools:
		var has := Tools.holds(inv, kind)
		var name := Items.tool_title(kind)
		where.append([ItemIcons.of_tool(kind), "" if has else "нет", not has,
			name.left(1).to_upper() + name.substr(1) + (": износ %d за изделие" % r.wear if r.wear > 0 else "")])
	if where.is_empty():
		where.append([ItemIcons.picture("hand"), "", false, "Руками"])
	# The time of the recipe; with skills it will be the time at the character's skill.
	var time := [UiStyle.icon("clock"), "%d с" % roundi(r.time), false, "Время изготовления"]
	var also := []
	for e: Dictionary in r.also:
		var share := roundi(e.chance * 100.0)
		also.append([ItemIcons.of_item(e.item), "+%d" % e.count if share >= 100 else "%d%%" % share, false,
			"Побочно: %s ×%d%s" % [Items.title(e.item), e.count, "" if share >= 100 else ", шанс %d%%" % share]])
	_facts.show_wells(needs + where + [time] + FactChips.item_wells(r.makes, r.count) + also)
	var can := Crafting.why_not(r, inv, near) == ""
	for b in _make.get_child(0).get_children() + [_make.get_child(1)]:
		b.disabled = not can


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
		text = "%d с" % ceili(jobs[0].left)
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
func _fit_list() -> bool:
	var h := float(mini(_cap, maxi(slot, ceili(_grid.get_combined_minimum_size().y))))
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
	var box := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, UiStyle.WELL_PAD)
	p.add_theme_stylebox_override("panel", box)
	parent.add_child(p)
	return p


## A small well with a picture and a few letters (how many, a time).
func _chip(texture: Texture2D, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var box := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, 4)
	p.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(_picture(texture, 12))
	var label := UiStyle.label(text)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return p


func _set_chip(chip: PanelContainer, texture: Texture2D, text: String, short := false) -> void:
	var row := chip.get_child(0)
	row.get_child(0).texture = texture
	var label: Label = row.get_child(1)
	label.text = text
	label.visible = text != ""
	label.add_theme_color_override("font_color", UiStyle.DANGER if short else UiStyle.INK)


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
