extends VBoxContainer
## The craft tab of the bag window (plan/design/ui.md, section 5; the look and the
## knowledge book are the «Интерфейс игры» thread's): the stations near, the queue
## with how far the first job has come and a cancel for each job, and the recipes the
## character knows, each with what it needs (missing in red) and buttons to make one
## or five. A recipe of a station that is not near says where it is made. Opened at a
## station, it can take the station back into the bag. Works through Workshop.

const UiStyle := preload("res://src/client/ui_style.gd")
const ItemIcons := preload("res://src/client/item_icons.gd")
const Items := preload("res://src/shared/items.gd")
const Crafting := preload("res://src/shared/crafting.gd")

## Jobs of the queue shown, the rest counted.
const SHOWN_JOBS := 2

var game
## How tall the list of recipes may grow before it scrolls, in UI pixels (set by the
## window for the screen, see InventoryWindow.fit).
var list_height := 160
## The list's height limit now: list_height, less what the window took off so it fits.
var _cap := 160
## A narrow window (a phone held upright): a recipe's buttons go under its text.
var narrow := false
## Called after a refresh changed what the tab shows, to fit the window round it.
var on_layout := Callable()
var _near: Label
var _take_up: Button
var _queue_box: VBoxContainer
var _progress: ProgressBar
var _list: VBoxContainer
var _scroll: ScrollContainer
## The station the tab was opened at (a record of Props.placed), or {}.
var _station := {}
## What the stations near were at the last refresh, to notice walking up to one.
var _stations_seen := ""
## Rows of the recipes known, by recipe id (see _row), and whether they were laid out
## for a narrow window.
var _rows := {}
var _rows_narrow := false
## The queue's lines (a name and a cancel each), "the queue is empty" and "and N more".
var _jobs: Array[HBoxContainer] = []
var _idle: Label
var _more: Label
var _empty: Label
var _left_shown := -1
var _dirty := true


func _init(g) -> void:
	game = g


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	# The take-up button goes under the stations near when they do not fit side by side.
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 6)
	head.add_theme_constant_override("v_separation", 4)
	add_child(head)
	_near = UiStyle.label("", UiStyle.MUTED)
	_near.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_near.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label with no width of its own would be laid out a letter a line.
	_near.custom_minimum_size.x = 120
	head.add_child(_near)
	_take_up = _button("Забрать", func() -> void:
		if game.props.take_up(_station):
			_station = {}
			refresh())
	head.add_child(_take_up)
	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 2)
	add_child(_queue_box)
	_idle = UiStyle.label("Очередь пуста", UiStyle.MUTED)
	_queue_box.add_child(_idle)
	for i in SHOWN_JOBS:
		var line := HBoxContainer.new()
		var label := UiStyle.label()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# A long name is cut, the cancel button stays on the screen.
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(label)
		line.add_child(_button("Отмена", func() -> void: game.workshop.cancel(i)))
		_queue_box.add_child(line)
		_jobs.append(line)
	_more = UiStyle.label("", UiStyle.MUTED)
	_queue_box.add_child(_more)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.max_value = 1.0
	add_child(_progress)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	_empty = UiStyle.label("Рецептов пока нет. Собери волокно (копай траву), ветки и кремень (копай землю).", UiStyle.MUTED)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size.x = 160
	_list.add_child(_empty)
	game.workshop.changed.connect(refresh)


## Opened at placed thing `e` (a station), or {} for none.
func at_station(e: Dictionary) -> void:
	_station = e
	refresh_now()


## Shows the stations, the queue and the recipes as they are now: at the next frame
## (see refresh_progress), so several changes in one frame cost one refresh.
func refresh() -> void:
	_dirty = true


## Refreshes at once (when the window opens).
func refresh_now() -> void:
	_dirty = false
	if not is_visible_in_tree():
		return
	var shop = game.workshop
	var stations: Dictionary = shop.stations()
	_stations_seen = str(stations.keys())
	if not _station.is_empty() and not game.props.placed.has(_station):
		_station = {}
	var names: PackedStringArray = []
	for id in stations:
		names.append(Items.title(id))
	_near.text = "Рядом: %s" % ", ".join(names) if not names.is_empty() else "Рядом станков нет: делается то, что руками"
	_take_up.visible = not _station.is_empty()
	if _take_up.visible:
		_take_up.text = "Забрать: %s" % Items.title(_station.item)
	_show_queue()
	if _rows_narrow != narrow:
		for id in _rows:
			_rows[id].row.queue_free()
		_rows = {}
		_rows_narrow = narrow
	var known: Array = shop.recipes()
	_empty.visible = known.is_empty()
	for i in known.size():
		var r: Dictionary = known[i]
		if not _rows.has(r.id):
			_rows[r.id] = _row(r)
			# In the order of the data files, after the line for no recipes.
			_list.add_child(_rows[r.id].row)
			_list.move_child(_rows[r.id].row, i + 1)
		_update_row(r, _rows[r.id])
	_cap = list_height
	_fit_list()
	if on_layout.is_valid():
		on_layout.call()


func _show_queue() -> void:
	var jobs: Array = game.workshop.queue.jobs
	_progress.visible = not jobs.is_empty()
	_idle.visible = jobs.is_empty()
	for i in SHOWN_JOBS:
		var line: HBoxContainer = _jobs[i]
		line.visible = i < jobs.size()
		if not line.visible:
			continue
		var r := Crafting.get_recipe(jobs[i].recipe)
		var text := r.get("title", jobs[i].recipe) as String
		if i == 0:
			text += " · ждёт: %s" % _where(r) if game.workshop.waiting() else " · ещё %d с" % ceili(jobs[0].left)
		var label: Label = line.get_child(0)
		label.text = text
		label.add_theme_color_override("font_color", UiStyle.INK if i == 0 else UiStyle.MUTED)
	_more.visible = jobs.size() > SHOWN_JOBS
	_more.text = "и ещё %d" % (jobs.size() - SHOWN_JOBS)
	_progress.value = game.workshop.queue.progress()


## What the first job waits for: its station or its tool.
func _where(r: Dictionary) -> String:
	if r.at != "" and not game.workshop.stations().has(r.at):
		return Items.title(r.at)
	return Crafting.TOOL_NAMES.get(r.tool, r.tool)


## Takes `px` UI pixels off the list of recipes (it scrolls), so the window fits the
## screen's height.
func shrink_list(px: float) -> void:
	_cap = maxi(40, int(_scroll.custom_minimum_size.y - ceilf(px)))
	_fit_list()


## The list as tall as its rows (their wrapped text is known once laid out at the
## list's width), up to the limit; true when that changed the height.
func _fit_list() -> bool:
	var h := float(mini(_cap, maxi(40, ceili(_list.get_combined_minimum_size().y))))
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
	# Rows that wrapped differently at the list's real width.
	if _fit_list() and on_layout.is_valid():
		on_layout.call()
	var jobs: Array = game.workshop.queue.jobs
	if not jobs.is_empty():
		_progress.value = game.workshop.queue.progress()
		var left := ceili(jobs[0].left)
		if left != _left_shown:
			_left_shown = left
			_show_queue()


## A recipe's row, made once: its picture, name, time and materials, and the buttons.
func _row(r: Dictionary) -> Dictionary:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var row: BoxContainer = line
	if narrow:
		row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.add_child(line)
	var icon := TextureRect.new()
	icon.texture = ItemIcons.of_item(r.makes)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := "%s%s · %d с" % [r.title, " ×%d" % r.count if r.count > 1 else "", roundi(r.time)]
	if r.at != "":
		title += " · %s" % Items.title(r.at)
	var title_label := UiStyle.label(title)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size.x = 100
	text.add_child(title_label)
	var needs := UiStyle.label()
	needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs.custom_minimum_size.x = 100
	text.add_child(needs)
	line.add_child(text)
	var one := _button("Сделать", func() -> void: game.workshop.start(r, 1))
	var five := _button("×5", func() -> void: game.workshop.start(r, 5))
	var buttons: BoxContainer = line
	if narrow:
		buttons = HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(buttons)
	buttons.add_child(one)
	buttons.add_child(five)
	return {"row": row, "title": title_label, "needs": needs, "one": one, "five": five, "why": null}


## What can be done with a recipe now: its materials, or in red why not.
func _update_row(r: Dictionary, row: Dictionary) -> void:
	var why: String = game.workshop.why_not(r)
	if why == row.why:
		return
	row.why = why
	row.title.add_theme_color_override("font_color", UiStyle.INK if why == "" else UiStyle.MUTED)
	row.needs.text = Crafting.amounts_text(r.needs) if why == "" else why
	row.needs.add_theme_color_override("font_color", UiStyle.MUTED if why == "" else UiStyle.DANGER)
	row.one.disabled = why != ""
	row.five.disabled = why != ""


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(action)
	return b
