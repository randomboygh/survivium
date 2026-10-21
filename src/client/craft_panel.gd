extends BoxContainer
## The craft tab of the bag window (plan/design/ui.md, section 5): the stations near as
## pictures (hands first, the stations of the recipes known, the far ones dimmed), tabs
## by kind of item, the recipes known as cells (dimmed when they cannot be made now),
## and two blocks: the recipe chosen, with pictures of what it needs (have / need, short
## in red), its station, its tool and its time (the recipe's: no skills yet), and
## buttons to make one, five or as many as the bag allows; and the queue, a cell for each job, the one chosen named
## with its time left and a cancel. Side by side on a wide screen, the blocks under
## the cells on a narrow one. Opened at a station, it can take the station back into
## the bag. Works through Workshop.

const UiStyle := preload("res://src/client/ui_style.gd")
const ItemIcons := preload("res://src/client/item_icons.gd")
const HotbarSlot := preload("res://src/client/hotbar_slot.gd")
const TabRow := preload("res://src/client/tab_row.gd")
const Items := preload("res://src/shared/items.gd")
const Crafting := preload("res://src/shared/crafting.gd")
const CraftQueue := preload("res://src/shared/craft_queue.gd")

const SLOT := 40
const JOB_SLOT := 32
## What «Максимум» asks for: the whole queue, as far as the materials go.
const MOST := CraftQueue.MAX_JOBS

var game
## Cells of recipes across, as many as the bag's (set by the window, see
## InventoryWindow.fit), and the width of the blocks.
var columns := 8
var side_width := 208
## The blocks beside the cells (a wide screen) or under them.
var wide := false:
	set(v):
		wide = v
		vertical = not v
## How tall the cells of recipes may grow before they scroll, in UI pixels (set by the
## window for the screen); the limit now, less what the window took off so it fits.
var list_height := 160
var _cap := 160
## Called after a refresh changed what the tab shows, to fit the window round it.
var on_layout := Callable()

var _left: VBoxContainer
var _right: VBoxContainer
var _stations: HBoxContainer
var _take_up: Button
var _tabs: TabRow
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
## The block of the recipe chosen.
var _details: PanelContainer
var _icon: TextureRect
var _title: Label
var _needs: HFlowContainer
var _why: Label
var _make: Array[Button] = []
## The block of the queue.
var _queue_title: Label
var _queue_count: Label
var _job_row: HBoxContainer
var _job_slots := []
var _job_more: Label
var _job_line: HBoxContainer
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
	add_theme_constant_override("separation", 8)
	vertical = not wide
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 6)
	add_child(_left)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 6)
	add_child(_right)

	# The stations near; the take-up button goes under them when they do not fit.
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 6)
	head.add_theme_constant_override("v_separation", 4)
	_left.add_child(head)
	var near := HBoxContainer.new()
	near.add_theme_constant_override("separation", 4)
	near.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(near)
	var label := UiStyle.label("Рядом:", UiStyle.MUTED)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	near.add_child(label)
	_stations = HBoxContainer.new()
	_stations.add_theme_constant_override("separation", 4)
	near.add_child(_stations)
	_take_up = TabRow.small_button("Забрать", func() -> void:
		if game.props.take_up(_station):
			_station = {}
			refresh())
	head.add_child(_take_up)
	_tabs = TabRow.new()
	_tabs.picked.connect(func(_k: String) -> void: refresh_now())
	_left.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)
	_empty = UiStyle.label("Рецептов пока нет. Собери волокно (копай траву), ветки и кремень (копай землю).", UiStyle.MUTED)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size.x = 160
	_left.add_child(_empty)

	_details = _block()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_details.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	_icon = _picture(null, 24)
	top.add_child(_icon)
	_title = UiStyle.label("", UiStyle.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.custom_minimum_size.x = 100
	top.add_child(_title)
	_needs = HFlowContainer.new()
	_needs.add_theme_constant_override("h_separation", 4)
	_needs.add_theme_constant_override("v_separation", 4)
	box.add_child(_needs)
	_why = UiStyle.label("", UiStyle.DANGER)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.custom_minimum_size.x = 100
	box.add_child(_why)
	var buttons := HFlowContainer.new()
	buttons.alignment = FlowContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("h_separation", 4)
	buttons.add_theme_constant_override("v_separation", 4)
	box.add_child(buttons)
	for b in [["Сделать", 1], ["×5", 5], ["Максимум", MOST]]:
		var n: int = b[1]
		var button := TabRow.small_button(b[0], func() -> void: game.workshop.start(Crafting.get_recipe(_chosen), n))
		button.custom_minimum_size.y = 30
		buttons.add_child(button)
		_make.append(button)
	_make[2].tooltip_text = "Поставить в очередь столько, сколько хватит материалов"

	var queue := _block()
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	queue.add_child(box)
	var title := HBoxContainer.new()
	box.add_child(title)
	_queue_title = UiStyle.label("Очередь", UiStyle.MUTED)
	_queue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(_queue_title)
	_queue_count = UiStyle.label("", UiStyle.MUTED)
	title.add_child(_queue_count)
	_job_row = HBoxContainer.new()
	_job_row.add_theme_constant_override("separation", 4)
	box.add_child(_job_row)
	_job_more = UiStyle.label("", UiStyle.MUTED)
	_job_more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_job_row.add_child(_job_more)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.max_value = 1.0
	box.add_child(_progress)
	_job_line = HBoxContainer.new()
	_job_line.add_theme_constant_override("separation", 4)
	box.add_child(_job_line)
	_job_label = UiStyle.label()
	_job_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_job_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A long name is cut, the cancel button stays on the screen.
	_job_label.clip_text = true
	_job_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_job_line.add_child(_job_label)
	_job_line.add_child(TabRow.small_button("Отмена", func() -> void: game.workshop.cancel(_job)))
	game.workshop.changed.connect(refresh)


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
	_grid.columns = columns
	# As wide as a full row of cells, however few recipes are known.
	_left.custom_minimum_size.x = columns * (SLOT + 4) - 4
	_details.custom_minimum_size.x = side_width if wide else 0
	_right.custom_minimum_size.x = side_width if wide else 0
	var shop = game.workshop
	var inv = game.character.inventory
	var known: Array = shop.recipes()
	var stations: Dictionary = shop.stations()
	_stations_seen = str(stations.keys())
	if not _station.is_empty() and not game.props.placed.has(_station):
		_station = {}
	_show_stations(known, stations)
	_take_up.visible = not _station.is_empty()
	if _take_up.visible:
		_take_up.text = "Забрать: %s" % Items.title(_station.item)
	# Tabs of the kinds of things the recipes known make.
	var kinds := []
	for k in Items.CATEGORIES:
		if known.any(func(r: Dictionary) -> bool: return Items.category(r.makes) == k):
			kinds.append(k)
	_tabs.set_tabs(kinds, Items.CATEGORIES)
	_tabs.visible = not known.is_empty()
	_empty.visible = known.is_empty()
	_scroll.visible = not known.is_empty()
	var shown := []
	for r: Dictionary in known:
		if not _cells.has(r.id):
			var cell = HotbarSlot.new(SLOT)
			cell.texture = ItemIcons.of_item(r.makes)
			cell.number = str(r.count) if r.count > 1 else ""
			cell.tooltip_text = r.title
			cell.pressed.connect(_choose.bind(r.id))
			_grid.add_child(cell)
			_cells[r.id] = cell
		var cell = _cells[r.id]
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
		_stations.add_child(_chip(null, ""))
	for i in _stations.get_child_count():
		var chip: PanelContainer = _stations.get_child(i)
		chip.visible = i < ids.size()
		if not chip.visible:
			continue
		var id: String = ids[i]
		_set_chip(chip, ItemIcons.picture("hand") if id == "" else ItemIcons.of_item(id), "")
		chip.tooltip_text = "Руками" if id == "" else "%s%s" % [Items.title(id), "" if near.has(id) else ": далеко"]
		chip.modulate = Color.WHITE if id == "" or near.has(id) else Color(1, 1, 1, 0.35)


## The block of the recipe chosen: what it makes, a picture for each thing it needs
## with how many the bag has of how many, its station and tool (red when missing),
## its time, and why it cannot be made now.
func _show_details(near: Dictionary) -> void:
	var r := Crafting.get_recipe(_chosen)
	_details.visible = not r.is_empty()
	if r.is_empty():
		return
	var inv = game.character.inventory
	_icon.texture = ItemIcons.of_item(r.makes)
	_title.text = "%s%s" % [r.title, " ×%d" % r.count if r.count > 1 else ""]
	var chips := []
	for id in r.needs:
		var have: int = inv.count(id)
		chips.append([ItemIcons.of_item(id), "%d/%d" % [have, r.needs[id]], have < r.needs[id], Items.title(id)])
	if r.at != "":
		chips.append([ItemIcons.of_item(r.at), "" if near.has(r.at) else "нет", not near.has(r.at), Items.title(r.at)])
	if r.tool != "none":
		var has := Crafting.has_tool(r, inv)
		var name: String = Crafting.TOOL_NAMES.get(r.tool, r.tool)
		chips.append([ItemIcons.picture(r.tool), "" if has else "нет", not has, name.capitalize()])
	# The time of the recipe; with skills it will be the time at the character's skill.
	chips.append([UiStyle.icon("clock"), "%d с" % roundi(r.time), false, "Время"])
	while _needs.get_child_count() < chips.size():
		_needs.add_child(_chip(null, ""))
	for i in _needs.get_child_count():
		var chip: PanelContainer = _needs.get_child(i)
		chip.visible = i < chips.size()
		if chip.visible:
			_set_chip(chip, chips[i][0], chips[i][1], chips[i][2])
			chip.tooltip_text = chips[i][3]
	var why := Crafting.why_not(r, inv, near)
	_why.text = why
	_why.visible = why != ""
	for b in _make:
		b.disabled = why != ""


## The block of the queue: a cell for each job that fits, the one chosen named with
## its time left (or what it waits for) and a cancel, the first job's progress.
func _show_queue() -> void:
	var jobs: Array = game.workshop.queue.jobs
	_queue_title.text = "Очередь" if not jobs.is_empty() else "Очередь пуста"
	_queue_count.text = "%d/%d" % [jobs.size(), CraftQueue.MAX_JOBS] if not jobs.is_empty() else ""
	_job_row.visible = not jobs.is_empty()
	_progress.visible = not jobs.is_empty()
	_job_line.visible = not jobs.is_empty()
	if jobs.is_empty():
		_job = 0
		return
	_job = clampi(_job, 0, jobs.size() - 1)
	var width: int = side_width - 12 if wide else columns * (SLOT + 4) - 16
	var fit := maxi(1, (width - 24) / (JOB_SLOT + 4))
	var n := mini(jobs.size(), fit)
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
			cell.number = str(r.count) if r.get("count", 1) > 1 else ""
			cell.selected = i == _job
	_job_more.visible = jobs.size() > n
	_job_more.text = "+%d" % (jobs.size() - n)
	var r := Crafting.get_recipe(jobs[_job].recipe)
	var text := r.get("title", jobs[_job].recipe) as String
	if _job == 0:
		text += " · ждёт: %s" % _where(r) if game.workshop.waiting() else " · %d с" % ceili(jobs[0].left)
	else:
		text += " · %d-й" % (_job + 1)
	_job_label.text = text
	_job_label.tooltip_text = text
	_progress.value = game.workshop.queue.progress()


func _choose_job(i: int) -> void:
	_job = i
	_show_queue()


## What the first job waits for: its station or its tool.
func _where(r: Dictionary) -> String:
	if r.at != "" and not game.workshop.stations().has(r.at):
		return Items.title(r.at)
	return Crafting.TOOL_NAMES.get(r.tool, r.tool)


## Takes `px` UI pixels off the cells of recipes (they scroll), so the window fits the
## screen's height.
func shrink_list(px: float) -> void:
	_cap = maxi(SLOT, int(_scroll.custom_minimum_size.y - ceilf(px)))
	_fit_list()


## The cells as tall as their rows, up to the limit; true when that changed the height.
func _fit_list() -> bool:
	var h := float(mini(_cap, maxi(SLOT, ceili(_grid.get_combined_minimum_size().y))))
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


## A sunken block of the tab.
func _block() -> PanelContainer:
	var p := PanelContainer.new()
	var box := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, 6)
	p.add_theme_stylebox_override("panel", box)
	_right.add_child(p)
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

