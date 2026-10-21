extends PanelContainer
## The bag window (plan/design/ui.md, section 5), as wide whatever it shows: the bag's
## slots with a column of tabs by kind of item on the left (the other slots dim) and
## the sorting buttons on the right (they sort the bag past the hotbar row and the
## chest shown), the switch of sorting by hand over them. The chests within reach stand
## under the bag, one at a time, picked by their tabs on the right; the head of the
## window has, by the cross, the chest's buttons: the chosen stack into it, all the bag
## past the hotbar row into it, take it up. A tap picks a slot, a tap on another picks
## that one; with sorting by hand on, a tap on another slot (of the bag or a chest)
## moves the stack there, swaps the two or tops up a stack of the same item, and lets
## it go; a tap on the chosen one lets it go. The panel at the bottom names the chosen
## stack (eat, plant, set down, repair by the name), shows what it is in small wells
## (FactChips: weight, food, work, wear) and, on the right, a wide «Взять» (into the
## hand in use) under throwing the stack away and the bin (red at the first tap, it
## destroys at the second). The craft tab (CraftPanel) has its own cells and
## panels; opened at a station it starts there.
## Opens over the running world, which goes on; taps inside it do not reach the world.

const UiStyle := preload("res://src/client/ui_style.gd")
const HotbarSlot := preload("res://src/client/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/item_icons.gd")
const TabRow := preload("res://src/client/tab_row.gd")
const IconTabs := preload("res://src/client/icon_tabs.gd")
const Items := preload("res://src/shared/items.gd")
const Inventory := preload("res://src/shared/inventory.gd")
const CraftPanel := preload("res://src/client/craft_panel.gd")
const FactChips := preload("res://src/client/fact_chips.gd")

## Room kept between the window and the edges of the screen, in UI pixels.
const EDGE := 4
## Room kept free at the bottom of the screen for the hotbar (its frame and the tab
## with the bag's load on it).
const HOTBAR := 68
## The gap between the columns of tabs and the slots.
const GAP := 4
## Slots across; and the side of a slot, the larger when the window fits the screen.
const COLUMNS := 8
const SLOT := 40
const SLOT_SMALL := 36

var game
## The side of a slot now (see fit).
var slot := SLOT
var _bag_tab: Button
var _craft_tab: Button
var _bag_page: VBoxContainer
var craft: CraftPanel
var _kinds: IconTabs
var _chest_tabs: IconTabs
var _weight: Label
var _grid: GridContainer
var _slots := []
## The chest's buttons in the head, and the gap over its slots.
var _chest_buttons: HBoxContainer
var _to_chest: Button
var _chest_gap: Control
var _chest_grid: GridContainer
## Sorting by hand: a tap on a second slot moves the chosen stack there.
var _manual := false
var _manual_button: Button
var _chest_slots := []
var _info: Label
var _facts: FactChips
var _eat: Button
var _hold: Button
var _plant: Button
var _put: Button
var _repair: Button
## Throw the stack away, and the bin.
var _throw: Button
var _destroy: Button
## The bin waits for its second tap.
var _confirming := false
## The chosen stack: the bag it is in (the character's or a chest's) and its slot.
var _from = null
var _at := -1
## The chests within reach (records of Props.placed), the one shown, and what they were
## at the last look (to notice walking up to one or away).
var _chests: Array = []
var _chest_entry := {}
var _chests_seen := ""
## A _place waits for the end of the frame.
var _place_queued := false


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# Containers learn their least size late (and a wrapping label its height only once
	# laid out at its width): size the window again once that settles, or it would keep
	# the height of what it showed before.
	minimum_size_changed.connect(func() -> void:
		if not _place_queued:
			_place_queued = true
			_place.call_deferred())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_bag_tab = _button("Сумка", show_tab.bind("bag"))
	_craft_tab = _button("Крафт", show_tab.bind("craft"))
	head.add_child(_bag_tab)
	head.add_child(_craft_tab)
	# The bag's weight in the free room of the head, on the bag tab.
	_weight = UiStyle.label()
	_weight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weight.tooltip_text = "Вес сумки"
	_weight.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_weight)
	# What can be done with the chest shown (bag tab) or the station (craft tab).
	_chest_buttons = HBoxContainer.new()
	_chest_buttons.add_theme_constant_override("separation", 4)
	head.add_child(_chest_buttons)
	var into := TabRow.split([
		[UiStyle.icon("to_chest"), "Скинуть в сундук", _put_in_chest],
		[UiStyle.icon("to_chest_all"), "Скинуть всё в сундук (без первого ряда)", _put_all_in_chest],
	])
	_to_chest = into.get_child(0)
	_chest_buttons.add_child(into)
	_chest_buttons.add_child(TabRow.icon_button(UiStyle.icon("take"), "Забрать сундук в сумку", func() -> void:
		var e := _chest_entry
		_let_go()
		game.props.take_up(e)
		refresh()))
	for b in [_to_chest, into.get_child(1), _chest_buttons.get_child(1)]:
		b.custom_minimum_size = Vector2(30, 30)
	craft = CraftPanel.new(game)
	craft.on_layout = _place
	craft.visible = false
	box.add_child(craft)
	head.add_child(craft.station_buttons)
	var shut := TabRow.icon_button(UiStyle.icon("close"), "Закрыть", close)
	shut.custom_minimum_size = Vector2(30, 30)
	head.add_child(shut)

	_bag_page = VBoxContainer.new()
	_bag_page.add_theme_constant_override("separation", 6)
	box.add_child(_bag_page)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", GAP)
	_bag_page.add_child(middle)
	_kinds = IconTabs.new()
	_kinds.picked.connect(func(_k: String) -> void: refresh())
	middle.add_child(_kinds)
	var cells := VBoxContainer.new()
	cells.add_theme_constant_override("separation", 4)
	middle.add_child(cells)
	_grid = _slot_grid(cells, game.character.inventory.slots.size(), _slots, _tap.bind(true))
	_chest_gap = Control.new()
	_chest_gap.custom_minimum_size.y = 4
	cells.add_child(_chest_gap)
	_chest_grid = _slot_grid(cells, game.props.CHEST_SLOTS, _chest_slots, _tap.bind(false))
	# Sorting on the right, over the tabs of the chests near.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.custom_minimum_size.x = IconTabs.SIDE
	middle.add_child(right)
	_manual_button = TabRow.icon_button(UiStyle.icon("swap"), "Сортировать вручную: тап по второй ячейке перекладывает", func() -> void:
		_manual = not _manual
		_let_go()
		refresh())
	_manual_button.custom_minimum_size = Vector2(IconTabs.SIDE, IconTabs.SIDE - 2)
	right.add_child(_manual_button)
	for k in Inventory.SORTS:
		var icon: Texture2D = ItemIcons.picture("weight") if k == "weight" else UiStyle.icon("sort_" + k)
		var b := TabRow.icon_button(icon, "Сортировать %s (без первого ряда)" % Inventory.SORTS[k], sort.bind(k))
		b.custom_minimum_size = Vector2(IconTabs.SIDE, IconTabs.SIDE - 2)
		right.add_child(b)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	right.add_child(spacer)
	_chest_tabs = IconTabs.new()
	_chest_tabs.picked.connect(func(k: String) -> void:
		_show_chest(_chests[int(k)])
		refresh())
	right.add_child(_chest_tabs)

	# The panel at the bottom: the chosen stack and what can be done with it.
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _well())
	_bag_page.add_child(bottom)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	bottom.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	# As tall with buttons as without, so the window keeps its height.
	name_row.custom_minimum_size.y = 30
	info.add_child(name_row)
	_info = UiStyle.label("", UiStyle.MUTED)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info.custom_minimum_size.x = 120
	name_row.add_child(_info)
	_eat = _button("Съесть", func() -> void: game.character.eat(_at))
	_plant = _button("Посадить", func() -> void: game.gathering.plant(_from.slots[_at][0]))
	_put = _button("Поставить", func() -> void:
		if game.props.put_from_bag(_from.slots[_at][0], _at):
			close())
	_repair = _button("Починить", func() -> void: game.workshop.repair(_at))
	for b in [_eat, _plant, _put, _repair]:
		name_row.add_child(b)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	info.add_child(body)
	_facts = FactChips.new()
	_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_facts)
	# «Взять» wide under «выбросить» and the bin, apart.
	var block := TabRow.block([
		[UiStyle.icon("drop"), "Выбросить", func() -> void: game.character.throw_away(_at, 1 << 20)],
		[UiStyle.icon("trash"), "Уничтожить", func() -> void:
			if _confirming:
				destroy_chosen()
			else:
				_confirming = true
				refresh()],
	], ["Взять", "Взять в руку", func() -> void: game.controls.hold(_from.slots[_at][0])], 80, false)
	body.add_child(block)
	_throw = block.get_child(0).get_child(0)
	_destroy = block.get_child(0).get_child(1)
	_hold = block.get_child(1)
	game.character.state_changed.connect(refresh)
	show_tab("bag")


## A grid of `n` slots in `parent`, kept in `cells`; a tap on slot i calls `tap` with i.
func _slot_grid(parent: Node, n: int, cells: Array, tap: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for i in n:
		var s = HotbarSlot.new(SLOT)
		s.pressed.connect(func() -> void: tap.call(i))
		grid.add_child(s)
		cells.append(s)
	return grid


## Shows the bag ("bag") or the craft tab ("craft").
func show_tab(tab: String) -> void:
	_bag_page.visible = tab == "bag"
	# Off the bag tab the label stays, empty, to keep the cross on the right.
	if tab != "bag":
		_weight.text = ""
		_chest_buttons.visible = false
	craft.visible = tab == "craft"
	craft.station_buttons.visible = false
	_bag_tab.modulate = UiStyle.ACCENT if tab == "bag" else Color.WHITE
	_craft_tab.modulate = UiStyle.ACCENT if tab == "craft" else Color.WHITE
	refresh()
	craft.refresh_now()


func open() -> void:
	visible = true
	move_to_front()
	_chests_seen = "-"
	refresh()
	craft.refresh_now()


func close() -> void:
	visible = false
	_let_go()
	_chest_entry = {}
	craft.at_station({})


## Shows the chest of placed thing `e` (see Props.placed) under the bag, on the bag tab.
func show_chest(e: Dictionary) -> void:
	_chests_seen = "-"
	_show_chest(e)
	show_tab("bag")


func _show_chest(e: Dictionary) -> void:
	_chest_entry = e
	_confirming = false


## Opens the craft tab at station `e` (see Props.placed).
func show_station(e: Dictionary) -> void:
	show_tab("craft")
	craft.at_station(e)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Lays the window out for a screen `screen` UI pixels large: eight slots across with
## a column of tabs on each side, the slots smaller when the larger do not fit; the
## window keeps that width on both tabs.
func fit(screen: Vector2) -> void:
	var room := screen.x - 2 * EDGE - 12
	slot = SLOT if room >= _width(SLOT) else SLOT_SMALL
	for s in _slots + _chest_slots:
		s.custom_minimum_size = Vector2(slot, slot)
	_bag_page.custom_minimum_size.x = _width(slot)
	# A wrapping label is measured at its least width: as wide as the panel it is in
	# (less the buttons by it, see _show_info).
	_info.custom_minimum_size.x = _width(slot) - 12
	craft.slot = slot
	craft.custom_minimum_size.x = _width(slot)
	craft.fit_width(_width(slot))
	# The rest of the craft tab (tabs, the station's line, the panels at the bottom)
	# takes about 200 UI pixels; _place takes more off the cells if the window still
	# does not fit.
	craft.list_height = clampi(int(screen.y) - HOTBAR - 220, slot, 300)
	craft.refresh()
	_place()


## The width inside the window's frame with slots `side` across.
static func _width(side: int) -> int:
	return 2 * IconTabs.SIDE + 2 * GAP + COLUMNS * (side + 4) - 4


## Sizes the window round what it shows, shortens the craft tab's cells when the window
## is taller than the room above the hotbar, and centres it there.
func _place() -> void:
	_place_queued = false
	var screen := get_parent_area_size()
	var room := Vector2(screen.x, screen.y - HOTBAR)
	reset_size()
	var over := size.y - (room.y - 2 * EDGE)
	if craft.visible and over > 0.0:
		craft.shrink_list(over)
		reset_size()
	position = ((room - size) * 0.5).floor().max(Vector2(EDGE, EDGE))


## A tap on slot `i` of the bag (`in_bag`) or of the chest shown: picks it, lets the
## chosen one go, or (sorting by hand) moves the chosen stack there and lets it go.
func _tap(i: int, in_bag: bool) -> void:
	var to = game.character.inventory if in_bag else _chest_entry.get("items")
	if to == null:
		return
	_confirming = false
	if _from == to and _at == i:
		_let_go()
	elif _from == null or not _manual:
		_let_go()
		if to.slots[i] != null:
			_from = to
			_at = i
	else:
		if not _from.put_into(_at, to, i):
			game.character.nag("nest", "Сундук с вещами в сундук не положить: сначала поставь его")
		_let_go()
	refresh()


## «Скинуть в сундук»: the chosen stack of the bag into the chest shown.
func _put_in_chest() -> void:
	var chest = _chest_entry.get("items")
	var inv = game.character.inventory
	if chest == null or _from != inv:
		return
	var at := _at
	if inv.move_slot(at, chest) == 0:
		game.character.nag("chest", "Сундук с вещами в сундук не положить" if inv.contents(at) != null else "Сундук полон")
	if inv.slots[at] == null:
		_let_go()
	refresh()


## «Скинуть всё в сундук»: the bag past the hotbar row into the chest shown.
func _put_all_in_chest() -> void:
	var chest = _chest_entry.get("items")
	var inv = game.character.inventory
	if chest == null:
		return
	_let_go()
	var had: bool = inv.slots.slice(Inventory.HOTBAR).any(func(s) -> bool: return s != null)
	if inv.move_all(chest, Inventory.HOTBAR) == 0 and had:
		game.character.nag("chest", "Сундук полон")
	refresh()


func _let_go() -> void:
	_from = null
	_at = -1
	_confirming = false


## Sorts the bag past the hotbar row and the chest shown, by `by` (see Inventory.SORTS).
func sort(by: String) -> void:
	_let_go()
	game.character.inventory.sort(by, Inventory.HOTBAR)
	if _chest_entry.get("items") != null:
		_chest_entry.items.sort(by)
	refresh()


## The chosen stack is gone for good: the second tap of the bin.
func destroy_chosen() -> void:
	var taken = _from.take_slot(_at, 1 << 20) if _from != null else null
	_let_go()
	if taken != null:
		game.hud.toast("Уничтожено: %s ×%d" % [Items.title(taken[0]), taken[1]])
	refresh()


## Shows the bag and the chest as they are now.
func refresh() -> void:
	if not visible:
		return
	refresh_state()
	# The craft tab refreshes itself (see CraftPanel.refresh).
	if not _bag_page.visible:
		return
	var inv = game.character.inventory
	var chest = _chest_entry.get("items")
	_weight.text = "%.1f / %d кг" % [inv.weight(), inv.weight_limit]
	_weight.add_theme_color_override("font_color", UiStyle.DANGER if inv.overloaded() else UiStyle.INK)
	if _from != null and (_from.slots[_at] == null or (_from != inv and not _chests.any(
			func(e: Dictionary) -> bool: return e.items == _from))):
		_let_go()
	# Tabs of the kinds of things in the bag and the chest; the rest is dimmed.
	var have := {}
	for s in inv.slots + (chest.slots if chest != null else []):
		if s != null:
			have[Items.category(s[0])] = true
	var kinds := IconTabs.kinds(have)
	_kinds.set_tabs(kinds[0], kinds[1], kinds[2])
	_show_slots(inv, _slots)
	for i in _slots.size():
		# The first row is the hotbar: its slots carry their numbers.
		_slots[i].key = str(i + 1) if i < inv.HOTBAR else ""
	_chest_buttons.visible = chest != null
	_chest_gap.visible = chest != null
	_chest_grid.visible = chest != null
	if chest != null:
		_to_chest.disabled = _from != inv
		_show_slots(chest, _chest_slots)
		for i in _chests.size():
			_chest_tabs.set_tip(str(i), "Сундук %d · %.1f кг" % [i + 1, _chests[i].items.weight()])
	TabRow.light(_manual_button, _manual)
	_show_info(inv)
	_place()


## The stacks of bag `bag` in cells `cells`, the chosen one lit and, with a kind of item
## chosen, the other cells dimmed.
func _show_slots(bag, cells: Array) -> void:
	for i in cells.size():
		var s = bag.slots[i]
		var cell = cells[i]
		cell.texture = ItemIcons.of_item(s[0]) if s != null else null
		cell.number = "×%d" % s[1] if s != null and s[1] > 1 else ""
		cell.selected = bag == _from and i == _at
		var shown: bool = _kinds.chosen == "" or s != null and Items.category(s[0]) == _kinds.chosen
		cell.modulate = Color.WHITE if shown else Color(1, 1, 1, 0.3)


## The panel at the bottom: the chosen stack, its weight and what it is, and the
## buttons for what can be done with it.
func _show_info(inv) -> void:
	var s = _from.slots[_at] if _from != null else null
	var mine: bool = s != null and _from == inv
	if s == null:
		_info.text = ("Выбери ячейку, затем ту, куда её переложить" if _manual else "Выбери ячейку, чтобы узнать о вещи") \
			if not inv.is_empty() else "Пусто. Подбирай ветки, ягоды и брёвна."
		_facts.show_wells([])
	else:
		var id: String = s[0]
		_info.text = "%s ×%d%s%s" % [Items.title(id), s[1],
			" · с вещами" if _from.contents(_at) != null else "",
			"" if mine else " · в сундуке"]
		_facts.show_wells(FactChips.item_wells(id, s[1], _from.worn(_at), Inventory.stack_weight(s)))
	_info.add_theme_color_override("font_color", UiStyle.INK if s != null else UiStyle.MUTED)
	_eat.visible = mine and Items.food(s[0]) > 0.0
	_plant.visible = mine and Items.get_item(s[0]).get("plant", "") != ""
	_put.visible = mine and Items.get_item(s[0]).get("prop", "none") != "none"
	_repair.visible = mine and inv.worn(_at) > 0
	# The name wraps in what the buttons by it leave.
	var room := _width(slot) - 12
	for b in [_eat, _plant, _put, _repair]:
		if b.visible:
			room -= int(b.get_combined_minimum_size().x) + 6
	_info.custom_minimum_size.x = room
	_hold.disabled = not mine or game.controls.held() == s[0]
	_throw.disabled = not mine
	_destroy.disabled = s == null
	_destroy.tooltip_text = "Нажми ещё раз — уничтожить навсегда" if _confirming else "Уничтожить"
	TabRow.light(_destroy, _confirming, _confirming)


## What changes while the window is open: the chests within reach (walking up to one
## adds its tab, walking away takes it off), the craft tab's queue.
func refresh_state() -> void:
	var near := []
	var here: Vector3 = game.player.position
	for e: Dictionary in game.props.placed:
		if e.items != null and game.props.center(e).distance_to(here) <= game.gathering.REACH + 1.0:
			near.append(e)
	var seen := ""
	for e in near:
		seen += str(e.cell)
	if seen != _chests_seen:
		_chests_seen = seen
		for e in _chests:
			if e.items.changed.is_connected(refresh):
				e.items.changed.disconnect(refresh)
		_chests = near
		for e in _chests:
			e.items.changed.connect(refresh)
		if not _chests.has(_chest_entry):
			_show_chest(_chests[0] if not _chests.is_empty() else {})
		var keys := []
		var icons := {}
		var tips := {}
		for i in _chests.size():
			keys.append(str(i))
			icons[str(i)] = ItemIcons.picture("chest")
			tips[str(i)] = "Сундук %d" % (i + 1)
		_chest_tabs.set_tabs(keys, icons, tips)
		_chest_tabs.visible = _chests.size() > 1
		refresh.call_deferred()
	_chest_tabs.select(str(_chests.find(_chest_entry)))
	craft.refresh_progress()


func _well() -> StyleBox:
	var box := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, 6)
	return box


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(action)
	return b
