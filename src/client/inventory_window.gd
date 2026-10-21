extends PanelContainer
## The bag window (plan/design/ui.md, section 5): the slots with their items, tabs by
## kind of item that dim the rest, the weight against the limit, sorting, and what can
## be done with the chosen item (eat, take it in the hand in use, plant a bush or place
## a thing in front of the player, repair a worn tool at a workbench, throw away, move
## it to another slot (of the bag or the chest), destroy it with the bin, which turns
## red at the first tap and destroys at the second). Opened at a chest, it shows the
## chest's slots under the bag's and moves stacks between them; walking away from the
## chest closes its part. The craft tab (CraftPanel) shows the recipes known and the queue; opened at a
## station it starts there. On a wide screen what is done with the item stands beside
## the slots, else under them. Opens over the running world, which goes on; taps and
## clicks inside it do not reach the world.

const UiStyle := preload("res://src/client/ui_style.gd")
const HotbarSlot := preload("res://src/client/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/item_icons.gd")
const TabRow := preload("res://src/client/tab_row.gd")
const Items := preload("res://src/shared/items.gd")
const Inventory := preload("res://src/shared/inventory.gd")
const CraftPanel := preload("res://src/client/craft_panel.gd")
const Workshop := preload("res://src/client/workshop.gd")

const SLOT := 40
## Room kept between the window and the edges of the screen, in UI pixels.
const EDGE := 4
## Room kept free at the bottom of the screen for the hotbar (its frame and the tab
## with the bag's load on it).
const HOTBAR := 68
## The width of the column beside the slots on a wide screen.
const SIDE := 208

var game
var _weight: Label
var _kinds: TabRow
var _grid: GridContainer
var _slots := []
var _info: Label
var _eat: Button
var _hold: Button
var _plant: Button
var _drop_one: Button
var _drop_all: Button
var _put: Button
var _repair: Button
var _move: Button
## The bin: red after the first tap (_confirming), the second destroys.
var _destroy: Button
var _confirming := false
## «Переместить» was tapped: the next slot tapped is where the chosen stack goes.
var _moving := false
var _bag_tab: Button
var _craft_tab: Button
var _bag_page: BoxContainer
var _bag_side: VBoxContainer
var craft: CraftPanel
var _chosen := -1
var _chest_head: HBoxContainer
var _chest_grid: GridContainer
var _chest_slots := []
var _to_chest: Button
var _to_bag: Button
## The chest shown (an Inventory), null when none is open, its record in Props.placed
## and its chosen slot.
var _chest = null
var _chest_entry := {}
var _chosen_chest := -1


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_bag_tab = _button("Сумка", show_tab.bind("bag"))
	_craft_tab = _button("Крафт", show_tab.bind("craft"))
	head.add_child(_bag_tab)
	head.add_child(_craft_tab)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(_button("Закрыть", close))
	craft = CraftPanel.new(game)
	craft.on_layout = _place
	craft.visible = false
	box.add_child(craft)
	_bag_page = BoxContainer.new()
	_bag_page.vertical = true
	_bag_page.add_theme_constant_override("separation", 8)
	box.add_child(_bag_page)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	_bag_page.add_child(left)
	_kinds = TabRow.new()
	_kinds.picked.connect(func(_k: String) -> void: refresh())
	left.add_child(_kinds)
	_weight = UiStyle.label()
	left.add_child(_weight)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(_grid)
	for i in game.character.inventory.slots.size():
		var s = HotbarSlot.new(SLOT)
		s.pressed.connect(_choose.bind(i))
		_grid.add_child(s)
		_slots.append(s)
	_chest_head = HBoxContainer.new()
	left.add_child(_chest_head)
	var chest_title := UiStyle.label("Сундук", UiStyle.ACCENT)
	chest_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chest_head.add_child(chest_title)
	_chest_head.add_child(TabRow.small_button("Сортировать", func() -> void:
		_chosen_chest = -1
		_chest.sort("kind")))
	_chest_grid = GridContainer.new()
	_chest_grid.add_theme_constant_override("h_separation", 4)
	_chest_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(_chest_grid)
	for i in game.props.CHEST_SLOTS:
		var s = HotbarSlot.new(SLOT)
		s.pressed.connect(_choose_in_chest.bind(i))
		_chest_grid.add_child(s)
		_chest_slots.append(s)

	_bag_side = VBoxContainer.new()
	_bag_side.add_theme_constant_override("separation", 6)
	_bag_page.add_child(_bag_side)
	# Sorting leaves the first row alone: it is the hotbar, laid out by the player.
	var sorts := HFlowContainer.new()
	sorts.add_theme_constant_override("h_separation", 4)
	sorts.add_theme_constant_override("v_separation", 4)
	_bag_side.add_child(sorts)
	var sort_label := UiStyle.label("Сортировать:", UiStyle.MUTED)
	sort_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sorts.add_child(sort_label)
	for k in Inventory.SORTS:
		var b := TabRow.small_button(Inventory.SORTS[k], func() -> void:
			_chosen = -1
			game.character.inventory.sort(k, Inventory.HOTBAR))
		b.tooltip_text = "Кроме первого ряда: это панель внизу экрана"
		sorts.add_child(b)
	_info = UiStyle.label("", UiStyle.MUTED)
	_info.custom_minimum_size = Vector2(120, 22)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_side.add_child(_info)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	_bag_side.add_child(actions)
	_eat = _button("Съесть", func() -> void: game.character.eat(_chosen))
	_hold = _button("В руку", func() -> void: game.controls.hold(game.character.inventory.slots[_chosen][0]))
	_plant = _button("Посадить", func() -> void: game.gathering.plant(game.character.inventory.slots[_chosen][0]))
	_drop_one = _button("Выбросить 1", func() -> void: game.character.throw_away(_chosen, 1))
	_drop_all = _button("Выбросить все", func() -> void: game.character.throw_away(_chosen, 1 << 20))
	_put = _button("Поставить", func() -> void:
		if game.props.put_from_bag(game.character.inventory.slots[_chosen][0]):
			close())
	_repair = _button("Починить", func() -> void: game.workshop.repair(_chosen))
	_to_chest = _button("В сундук", _move_to_chest)
	_to_bag = _button("В сумку", _move_to_bag)
	_move = _button("Переместить", func() -> void:
		_moving = not _moving
		_confirming = false
		refresh())
	_destroy = _button("", func() -> void:
		if _confirming:
			destroy_chosen()
		else:
			_confirming = true
			_moving = false
			refresh())
	_destroy.icon = UiStyle.icon("trash")
	_destroy.custom_minimum_size.x = 34
	for b in [_to_chest, _to_bag, _eat, _hold, _plant, _put, _repair, _move, _drop_one, _drop_all, _destroy]:
		actions.add_child(b)
	game.character.state_changed.connect(refresh)
	show_tab("bag")


## Shows the bag ("bag") or the craft tab ("craft").
func show_tab(tab: String) -> void:
	_bag_page.visible = tab == "bag"
	craft.visible = tab == "craft"
	_bag_tab.modulate = UiStyle.ACCENT if tab == "bag" else Color.WHITE
	_craft_tab.modulate = UiStyle.ACCENT if tab == "craft" else Color.WHITE
	refresh()
	craft.refresh_now()


func open() -> void:
	visible = true
	move_to_front()
	refresh()
	craft.refresh_now()


func close() -> void:
	visible = false
	show_chest({})
	craft.at_station({})


## Shows the chest of placed thing `e` (see Props.placed) under the bag, or hides it
## for {}.
func show_chest(e: Dictionary) -> void:
	if _chest != null and _chest.changed.is_connected(refresh):
		_chest.changed.disconnect(refresh)
	_chest = e.get("items")
	_chest_entry = e
	_chosen_chest = -1
	if _chest != null:
		show_tab("bag")
	if _chest != null:
		_chest.changed.connect(refresh)
	refresh()


## Opens the craft tab at station `e` (see Props.placed).
func show_station(e: Dictionary) -> void:
	show_chest({})
	show_tab("craft")
	craft.at_station(e)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Lays the slots out for a screen `screen` UI pixels large: eight across when they fit
## between the edges with the window's frame (12 px), else four; what is done with
## the item (and the craft tab's blocks) beside the slots when there is room for both,
## else under them.
func fit(screen: Vector2) -> void:
	var room := screen.x - 2 * EDGE - 12
	_grid.columns = 8 if room >= 8 * (SLOT + 4) - 4 else 4
	_chest_grid.columns = _grid.columns
	var slots_width := _grid.columns * (SLOT + 4) - 4
	var wide := _grid.columns == 8 and room >= slots_width + 8 + SIDE
	_bag_page.vertical = not wide
	_bag_side.custom_minimum_size.x = SIDE if wide else 0
	craft.columns = _grid.columns
	craft.side_width = SIDE
	craft.wide = wide
	# The rest of the window (tabs, stations, the kinds of items, and under the cells on
	# a narrow screen the blocks) takes about 200 UI pixels, 420 under; _place takes
	# more off the cells if the window still does not fit.
	craft.list_height = clampi(int(screen.y) - (200 if wide else 420), SLOT, 300)
	craft.refresh()
	_place()


## Sizes the window round what it shows, shortens the list of recipes when the window
## is taller than the room above the hotbar, and centres it there.
func _place() -> void:
	var screen := get_parent_area_size()
	var room := Vector2(screen.x, screen.y - HOTBAR)
	reset_size()
	var over := size.y - (room.y - 2 * EDGE)
	if craft.visible and over > 0.0:
		craft.shrink_list(over)
		reset_size()
	position = ((room - size) * 0.5).floor().max(Vector2(EDGE, EDGE))


func _choose(i: int) -> void:
	if _moving:
		_move_chosen(game.character.inventory, i)
		return
	_chosen = i if _chosen != i else -1
	_chosen_chest = -1
	_confirming = false
	refresh()


func _choose_in_chest(i: int) -> void:
	if _moving:
		_move_chosen(_chest, i)
		return
	_chosen_chest = i if _chosen_chest != i else -1
	_chosen = -1
	_confirming = false
	refresh()


## The chosen stack goes to slot `i` of bag `to` (the bag or the chest), swapping with
## what is there, and stays chosen in its new place.
func _move_chosen(to, i: int) -> void:
	_moving = false
	var from = _chest if _chosen_chest >= 0 else game.character.inventory
	var at := _chosen_chest if _chosen_chest >= 0 else _chosen
	if at >= 0:
		from.put_into(at, to, i)
	var in_chest: bool = to == _chest and _chest != game.character.inventory
	_chosen = -1 if in_chest else i
	_chosen_chest = i if in_chest else -1
	refresh()


## The chosen stack (of the bag or the chest) is gone for good: the second tap of
## «Уничтожить».
func destroy_chosen() -> void:
	_confirming = false
	var from = _chest if _chosen_chest >= 0 else game.character.inventory
	var i := _chosen_chest if _chosen_chest >= 0 else _chosen
	var taken = from.take_slot(i, 1 << 20) if from != null and i >= 0 else null
	if taken != null:
		game.hud.toast("Уничтожено: %s ×%d" % [Items.title(taken[0]), taken[1]])
	refresh()


## The chosen stack of the bag goes into the chest, as much as fits.
func _move_to_chest() -> void:
	var s = game.character.inventory.slots[_chosen]
	if game.character.inventory.move_slot(_chosen, _chest) < s[1]:
		game.character.nag("chest_full", "В сундуке нет места")


## The chosen stack of the chest goes into the bag, as much as fits.
func _move_to_bag() -> void:
	var s = _chest.slots[_chosen_chest]
	if _chest.move_slot(_chosen_chest, game.character.inventory) < s[1]:
		game.character.nag("full", "Сумка полна")


## Shows the bag (and the chest) as it is now.
func refresh() -> void:
	if not visible:
		return
	refresh_state()
	# The craft tab refreshes itself (see CraftPanel.refresh).
	if not _bag_page.visible:
		return
	var inv = game.character.inventory
	_weight.text = "Вес %.1f из %d кг%s" % [inv.weight(), inv.weight_limit, " · перегруз" if inv.overloaded() else ""]
	_weight.add_theme_color_override("font_color", UiStyle.DANGER if inv.overloaded() else UiStyle.INK)
	if _chosen >= 0 and inv.slots[_chosen] == null:
		_chosen = -1
	# Tabs of the kinds of things in the bag and the chest; the rest is dimmed.
	var have := {}
	for s in inv.slots + (_chest.slots if _chest != null else []):
		if s != null:
			have[Items.category(s[0])] = true
	var kinds := Items.CATEGORIES.keys().filter(func(k: String) -> bool: return have.has(k))
	_kinds.set_tabs(kinds, Items.CATEGORIES)
	_kinds.visible = not kinds.is_empty()
	_show_slots(inv, _slots, _chosen)
	for i in _slots.size():
		# The first row is the hotbar: its slots carry their numbers.
		_slots[i].key = str(i + 1) if i < inv.HOTBAR else ""
	_chest_head.visible = _chest != null
	_chest_grid.visible = _chest != null
	if _chest != null:
		if _chosen_chest >= 0 and _chest.slots[_chosen_chest] == null:
			_chosen_chest = -1
		_show_slots(_chest, _chest_slots, _chosen_chest)
	var in_chest = _chest.slots[_chosen_chest] if _chest != null and _chosen_chest >= 0 else null
	var chosen = inv.slots[_chosen] if _chosen >= 0 else null
	_confirming = _confirming and (chosen != null or in_chest != null)
	_moving = _moving and (chosen != null or in_chest != null)
	_to_bag.visible = in_chest != null
	_to_chest.visible = _chest != null and chosen != null
	if _moving:
		_info.text = "Куда положить? Выбери ячейку сумки%s" % (" или сундука" if _chest != null else "")
	elif _confirming:
		var s = in_chest if in_chest != null else chosen
		_info.text = "Уничтожить %s ×%d? Нажми корзину ещё раз" % [Items.title(s[0]), s[1]]
	elif in_chest != null:
		_info.text = "%s ×%d · в сундуке" % [Items.title(in_chest[0]), in_chest[1]]
	elif chosen == null:
		_info.text = "Выбери ячейку" if not inv.is_empty() else "Пусто. Подбирай ветки, ягоды и брёвна."
	else:
		var id: String = chosen[0]
		var food := Items.food(id)
		var worn: int = inv.worn(_chosen)
		_info.text = "%s ×%d · %.1f кг%s%s" % [Items.title(id), chosen[1], Items.weight(id) * chosen[1],
			" · сытость +%d" % roundi(food) if food > 0.0 else "",
			" · прочность %d%%" % roundi(Workshop.condition(id, worn) * 100.0) if worn > 0 else ""]
	_eat.visible = chosen != null and Items.food(chosen[0]) > 0.0
	_hold.visible = chosen != null and game.controls.held() != chosen[0]
	_plant.visible = chosen != null and Items.get_item(chosen[0]).get("plant", "") != ""
	_put.visible = chosen != null and Items.get_item(chosen[0]).get("prop", "none") != "none"
	_repair.visible = chosen != null and inv.worn(_chosen) > 0
	_drop_one.visible = chosen != null
	_drop_all.visible = chosen != null and chosen[1] > 1
	_move.visible = chosen != null or in_chest != null
	_move.modulate = UiStyle.ACCENT if _moving else Color.WHITE
	_destroy.visible = chosen != null or in_chest != null
	_destroy.tooltip_text = "Нажми ещё раз — уничтожить навсегда" if _confirming else "Уничтожить"
	if _confirming != _destroy.has_theme_stylebox_override("normal"):
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			if _confirming:
				_destroy.add_theme_stylebox_override(state, UiStyle.button(state, false, true))
			else:
				_destroy.remove_theme_stylebox_override(state)
	_place()


## Shows the stacks of bag `bag` in cells `cells`, cell `chosen` lit and, with a kind
## of item chosen, the other cells dimmed.
func _show_slots(bag, cells: Array, chosen: int) -> void:
	for i in cells.size():
		var s = bag.slots[i]
		var cell = cells[i]
		cell.texture = ItemIcons.of_item(s[0]) if s != null else null
		cell.number = str(s[1]) if s != null and s[1] > 1 else ""
		cell.selected = i == chosen
		var shown: bool = _kinds.chosen == "" or s != null and Items.category(s[0]) == _kinds.chosen
		cell.modulate = Color.WHITE if shown else Color(1, 1, 1, 0.3)


## What changes while the window is open: the chest's part closes when the player has
## walked away from it, the craft tab follows its queue.
func refresh_state() -> void:
	if _chest != null:
		if not game.props.placed.has(_chest_entry) \
				or game.props.center(_chest_entry).distance_to(game.player.position) > game.gathering.REACH + 1.0:
			show_chest({})
	craft.refresh_progress()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(action)
	return b
