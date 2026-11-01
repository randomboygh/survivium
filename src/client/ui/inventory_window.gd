extends PanelContainer
## The inventory window (plan/design/ui.md, section 5): the character (PersonPanel: what
## is worn and held, the skills) beside the bag or the craft tab on a wide screen, over
## the bag on a tall one (hidden on the craft tab there). A tap on a slot of the figure
## works as a tap on a hand of the hotbar (the next tool) or takes off and puts on what
## is worn there (see _tap_person). The bag part is as wide whatever it shows: the bag's
## slots, ROWS rows and a half of them showing (they scroll), with a column of tabs by
## kind of item on the left (the other slots dim) and the sorting buttons on the right
## (they sort the bag past the hotbar row and the chest shown), the switch of sorting by
## hand over them. The chests within reach stand under the bag, one at a time, picked by
## their tabs on the right; the head of the window has, by the cross, the chest's
## buttons: the chosen stack into it, all the bag past the hotbar row into it, take it
## up. A tap picks a slot, a tap on another picks that one; with sorting by hand on, a
## tap on another slot (of the bag or a chest) moves the stack there, swaps the two or
## tops up a stack of the same item, and lets it go; a tap on the chosen one lets it go.
## The panel at the bottom names the chosen stack (repair by the name), shows what it is
## as named groups of small wells side by side (FactChips.item_groups: weight, food, the
## bag, the tool's work, wear) and a line of buttons on the right: throwing away one |
## all, the bin (red at the first tap, it destroys at the second) and a wide «Взять»
## (into the hand in use; «Съесть» for food, «Поставить» for a chest, station or
## campfire, «Надеть»...); the line goes under the groups in a tall window and by the
## name in a wide one. The craft tab (CraftPanel) has its own cells and panels; opened
## at a station it starts there.
## Opens over the running world, which goes on; taps inside it do not reach the world.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const IconTabs := preload("res://src/client/ui/icon_tabs.gd")
const Items := preload("res://src/shared/content/items.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const CraftPanel := preload("res://src/client/ui/craft_panel.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const PersonPanel := preload("res://src/client/ui/person_panel.gd")
const Placed := preload("res://src/shared/game/placed.gd")

## Room kept between the window and the edges of the screen, in UI pixels.
const EDGE := 4
## Room kept free at the bottom of the screen for the hotbar (its frame and the tab
## with the bag's load on it).
const HOTBAR := 68
## The room inside the window's frame (UiStyle.TIGHT).
const FRAME := 6
## The gap between the columns of tabs and the slots.
const GAP := 4
## Slots across; and the side of a slot, the larger when the window fits the screen.
const COLUMNS := 8
## The rows of the bag's slots shown before they scroll (and half the next).
const ROWS := 3
const SLOT := 40
const SLOT_SMALL := 36
## The width of the craft tab's column of the recipe and the queue beside the cells on
## a wide screen, in UI pixels.
const CRAFT_SIDE := 300
## The gap between the character and the bag or craft tab.
const GAP_MAIN := 6

var game
## The side of a slot now (see fit).
var slot := SLOT
var _bag_tab: Button
var _craft_tab: Button
var _bag_page: VBoxContainer
## The character, and the box that holds it beside (or over) the bag and craft tabs.
var person: PersonPanel
var _main: BoxContainer
## Whether the character stands over the bag (a tall screen) rather than beside it.
var _stacked := false
## The slot of the figure chosen (a slot of Inventory.WEAR_SLOTS, "hand0", "hand1"), "" for none.
var _worn := ""
## The bag's slots scroll when there are more than the screen has room for.
var _scroll: ScrollContainer
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
## «Взять» into the hand in use, «Съесть» for food, «Поставить» for what is set down,
## «Посадить» for a bush.
var _use: Button
var _repair: Button
## Sets a light (a torch, a candle) down in front; the wide button takes it in hand.
var _set_down: Button
## The row of buttons for the chosen stack: under the facts in a tall window, beside the
## name in a wide one (one line less, so more of the bag shows).
var _buttons: HBoxContainer
var _name_row: HBoxContainer
var _info_box: VBoxContainer
## Throw away one and all, and the bin.
var _throw: HBoxContainer
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
	# A frame round slots and buttons, not text: kept thin for the phone's width.
	add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.TIGHT))
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
		game.net.request(Protocol.PROP_TAKE, [e.cell]).then(func(_v: Variant) -> void: refresh())))
	for b in [_to_chest, into.get_child(1), _chest_buttons.get_child(1)]:
		b.custom_minimum_size = Vector2(30, 30)
	_main = BoxContainer.new()
	_main.add_theme_constant_override("separation", GAP_MAIN)
	box.add_child(_main)
	person = PersonPanel.new(game)
	person.picked.connect(_tap_person)
	person.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_main.add_child(person)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_main.add_child(tabs)
	craft = CraftPanel.new(game)
	craft.on_layout = _place
	craft.visible = false
	tabs.add_child(craft)
	head.add_child(craft.station_buttons)
	var shut := TabRow.icon_button(UiStyle.icon("close"), "Закрыть", close)
	shut.custom_minimum_size = Vector2(30, 30)
	head.add_child(shut)

	_bag_page = VBoxContainer.new()
	_bag_page.add_theme_constant_override("separation", 6)
	tabs.add_child(_bag_page)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", GAP)
	_bag_page.add_child(middle)
	_kinds = IconTabs.new()
	_kinds.picked.connect(func(_k: String) -> void: refresh())
	middle.add_child(_kinds)
	var cells := VBoxContainer.new()
	cells.add_theme_constant_override("separation", 4)
	middle.add_child(cells)
	# The bag's slots scroll (ROWS rows and a half show); the chest's stand under them.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cells.add_child(_scroll)
	_grid = _slot_grid(_scroll, game.character.inventory.slots.size(), _slots, _tap.bind(true))
	_chest_gap = Control.new()
	_chest_gap.custom_minimum_size.y = 4
	cells.add_child(_chest_gap)
	_chest_grid = _slot_grid(cells, Items.most_storage(), _chest_slots, _tap.bind(false))
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
	bottom.add_theme_stylebox_override("panel", UiStyle.well())
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
	_repair = _button("Починить", func() -> void: game.net.request(Protocol.REPAIR, [_at]))
	name_row.add_child(_repair)
	_set_down = _button("Поставить", func() -> void:
		if game.props.put_light(_from.slots[_at][0]):
			close())
	name_row.add_child(_set_down)
	_facts = FactChips.new()
	_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_facts)
	# The buttons in a line on the right: «выбросить | выбросить все», the bin, then
	# «Взять» (or «Съесть», «Посадить» for a bush...), wide.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.alignment = BoxContainer.ALIGNMENT_END
	info.add_child(top)
	_buttons = top
	_name_row = name_row
	_info_box = info
	_throw = TabRow.split([
		[UiStyle.icon("drop_one"), "Выбросить одну", func() -> void: game.net.request(Protocol.THROW, [_at, 1])],
		[UiStyle.icon("drop_all"), "Выбросить все", func() -> void: game.net.request(Protocol.THROW, [_at, 1 << 20])],
	])
	top.add_child(_throw)
	_destroy = TabRow.icon_button(UiStyle.icon("trash"), "Уничтожить", func() -> void:
		if _confirming:
			destroy_chosen()
		else:
			_confirming = true
			refresh())
	top.add_child(_destroy)
	for b in _throw.get_children() + [_destroy]:
		b.custom_minimum_size = Vector2(30, 30)
	_use = _button("Взять", func() -> void:
		if _worn != "":
			_use_worn()
			return
		var id: String = _from.slots[_at][0]
		if Items.wear_on(id) != "":
			game.net.request(Protocol.WEAR, [_at])
			_let_go()
			refresh()
		elif Items.food(id) > 0.0 or Items.heal(id) > 0.0:
			game.net.request(Protocol.EAT, [_at])
		elif _plantable(id):
			game.net.request(Protocol.PLANT, [id])
		elif _placeable(id):
			if game.props.put_from_bag(id, _at):
				close()
		else:
			game.controls.hold(id))
	_use.custom_minimum_size.x = 3 * 30 - 2 + 4
	top.add_child(_use)
	game.character.state_changed.connect(refresh)
	show_tab("bag")


## A bush dug up: its wide button plants it in front of the player instead of taking
## it in hand.
static func _plantable(id: String) -> bool:
	return Items.get_item(id).get("plant", "") != ""


## A thing set down on the ground (a chest, a station, a campfire): its wide button
## puts it down instead of taking it in hand.
static func _placeable(id: String) -> bool:
	return Items.get_item(id).get("prop", "none") != "none"


## A grid of `n` slots in `parent`, kept in `cells`; a tap on slot i calls `tap` with i.
func _slot_grid(parent: Node, n: int, cells: Array, tap: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	_grow_grid(grid, n, cells, tap)
	return grid


## Makes grid `grid` (its slots kept in `cells`) `n` slots long: a bag worn on the back
## adds slots, taken off it takes them away.
func _grow_grid(grid: GridContainer, n: int, cells: Array, tap: Callable) -> void:
	while cells.size() > n:
		var last: Control = cells.pop_back()
		# Out of the grid at once, so the window is measured without it.
		grid.remove_child(last)
		last.queue_free()
	while cells.size() < n:
		var i := cells.size()
		var s = HotbarSlot.new(slot)
		s.pressed.connect(func() -> void: tap.call(i))
		grid.add_child(s)
		cells.append(s)


## A tap on slot `k` of the figure (see PersonPanel.picked), as a tap on a hand of the
## hotbar: a hand becomes the hand in use, and a tap on the hand in use gives it the next
## tool (or brush); a body slot takes off what is worn there, or puts on what the bag has
## for it (the chosen thing if it fits, else the bag with the most slots for the back).
## The slot is chosen then, for the panel at the bottom.
func _tap_person(k: String) -> void:
	_confirming = false
	var inv = game.character.inventory
	var chosen: int = _at if _from == inv and _from.slots[_at] != null and Items.wear_on(_from.slots[_at][0]) == k else -1
	_let_go()
	_worn = k
	if k.begins_with("hand"):
		game.hud.tap_hand(int(k.right(1)))
	elif chosen < 0 and inv.gear.get(k, "") != "":
		game.net.request(Protocol.TAKE_OFF, [k])
	else:
		if chosen < 0:
			chosen = _to_wear(inv, k)
		if chosen >= 0:
			game.net.request(Protocol.WEAR, [chosen])
		else:
			game.character.nag("wear", "В сумке нечего надеть сюда")
	refresh()


## The slot of bag `inv` with a thing worn in body slot `k`, the bag with the most slots
## for the back; -1 for none.
static func _to_wear(inv, k: String) -> int:
	var best := -1
	for i in inv.slots.size():
		var s = inv.slots[i]
		if s != null and Items.wear_on(s[0]) == k and not (k == "back" and i >= inv.base) \
				and (best < 0 or Items.bag_slots(s[0]) > Items.bag_slots(inv.slots[best][0])):
			best = i
	return best


## The wide button with a slot of the figure chosen: takes off what is worn there, or
## empties the hand.
func _use_worn() -> void:
	if _worn.begins_with("hand"):
		game.controls.put_in_hand("", int(_worn.right(1)))
	else:
		game.net.request(Protocol.TAKE_OFF, [_worn])
		_let_go()
	refresh()


## Shows the bag ("bag") or the craft tab ("craft").
func show_tab(tab: String) -> void:
	_bag_page.visible = tab == "bag"
	# On a tall screen the craft tab needs the height the character takes.
	person.visible = tab == "bag" or not _stacked
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
	var room := screen.x - 2 * EDGE - 2 * FRAME
	slot = SLOT if room >= _width(SLOT) else SLOT_SMALL
	# The character beside the bag on a wide screen (with the smaller slots if need be),
	# over it on a tall one.
	_stacked = true
	if screen.x > screen.y:
		for side: int in [SLOT, SLOT_SMALL]:
			if room >= PersonPanel.width(side) + GAP_MAIN + _width(side):
				slot = side
				_stacked = false
				room -= PersonPanel.width(side) + GAP_MAIN
				break
	for s in _slots + _chest_slots:
		s.custom_minimum_size = Vector2(slot, slot)
	person.set_slot(slot)
	_main.vertical = _stacked
	var by_name := not _stacked
	if (_buttons.get_parent() == _name_row) != by_name:
		_buttons.get_parent().remove_child(_buttons)
		(_name_row if by_name else _info_box).add_child(_buttons)
	person.visible = _bag_page.visible or not _stacked
	_bag_page.custom_minimum_size.x = _width(slot)
	# A wrapping label is measured at its least width: as wide as the panel it is in
	# (less the buttons by it, see _show_info).
	_info.custom_minimum_size.x = _width(slot) - 2 * UiStyle.WELL_PAD - _beside()
	craft.slot = slot
	# On a wide screen the craft tab's recipe and queue go right of the cells, so the
	# window is not too tall for it; the window is that much wider on the craft tab.
	var side := screen.x > screen.y and room >= _width(slot) + 6 + CRAFT_SIDE
	craft.custom_minimum_size.x = _width(slot) + (6 + CRAFT_SIDE if side else 0)
	craft.set_side(side, CRAFT_SIDE if side else _width(slot))
	# The rest of the craft tab (tabs, the station's line, the panels at the bottom or
	# only the head beside them) takes about 250 or 90 UI pixels; _place takes more off
	# the cells if the window still does not fit.
	craft.list_height = clampi(int(screen.y) - HOTBAR - (90 if side else 266), slot, 300)
	craft.refresh()
	_place()


## The width inside the window's frame with slots `side` across.
static func _width(side: int) -> int:
	return 2 * IconTabs.SIDE + 2 * GAP + COLUMNS * (side + 4) - 4


## Sizes the window round what it shows, shortens the craft tab's cells or the bag's
## (they scroll then) when the window is taller than the room above the hotbar, and
## centres it there.
func _place() -> void:
	_place_queued = false
	var screen := get_parent_area_size()
	var room := Vector2(screen.x, screen.y - HOTBAR)
	var full := _grid.get_combined_minimum_size()
	var row := slot + 4
	# Up to ROWS rows, the next one cut through its middle when there are more, so the
	# half row shows the slots scroll.
	var most := ROWS * row + slot * 0.5
	_scroll.custom_minimum_size = Vector2(full.x, minf(full.y, most))
	reset_size()
	var over := size.y - (room.y - 2 * EDGE)
	if craft.visible and over > 0.0:
		craft.shrink_list(over)
		reset_size()
	elif _bag_page.visible and over > 0.0:
		# Less room on the screen: fewer rows, still cut through the last one.
		var rows := clampi(floori((_scroll.custom_minimum_size.y - over - slot * 0.5) / row), 0, ROWS)
		_scroll.custom_minimum_size.y = maxf(slot * 0.5, rows * row + slot * 0.5)
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
		var r = game.net.request(Protocol.BAG_PUT, [_where(_from), _at, _where(to), i])
		if r.done and not (r.value is bool and r.value):
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
	var r = game.net.request(Protocol.BAG_MOVE, [null, at, _chest_entry.cell])
	if r.done and r.value is int and r.value == 0:
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
	var r = game.net.request(Protocol.BAG_ALL, [null, _chest_entry.cell, Inventory.HOTBAR])
	if r.done and r.value is int and r.value == 0 and had:
		game.character.nag("chest", "Сундук полон")
	refresh()


func _let_go() -> void:
	_from = null
	_at = -1
	_worn = ""
	_confirming = false


## Sorts the bag past the hotbar row and the chest shown, by `by` (see Inventory.SORTS).
func sort(by: String) -> void:
	_let_go()
	game.net.request(Protocol.SORT, [null, by, Inventory.HOTBAR])
	if _chest_entry.get("items") != null:
		game.net.request(Protocol.SORT, [_chest_entry.cell, by, 0])
	refresh()


## The chosen stack is gone for good: the second tap of the bin.
func destroy_chosen() -> void:
	if _from != null:
		game.net.request(Protocol.BAG_DESTROY, [_where(_from), _at]).then(_destroyed)
	_let_go()
	refresh()


## Stack `taken` (as Inventory.take_slot gave it) is gone: the bin's toast.
func _destroyed(taken: Variant) -> void:
	if taken is Array and taken.size() >= 2:
		game.hud.toast("Уничтожено: %s ×%d" % [Items.title(taken[0]), taken[1]])
	refresh()


## How a request names bag `inv` (Protocol): null for the player's own, the cell of the
## chest that holds it.
func _where(inv) -> Variant:
	if inv == game.character.inventory:
		return null
	for e: Dictionary in _chests:
		if e.get("items") == inv:
			return e.cell
	return _chest_entry.get("cell")


## Shows the bag and the chest as they are now.
func refresh() -> void:
	if not visible:
		return
	refresh_state()
	person.refresh()
	# The craft tab refreshes itself (see CraftPanel.refresh).
	if not _bag_page.visible:
		return
	var inv = game.character.inventory
	var chest = _chest_entry.get("items")
	if _slots.size() != inv.slots.size():
		_grow_grid(_grid, inv.slots.size(), _slots, _tap.bind(true))
	person.chosen = _worn
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
		# A chest of fewer slots than the most any holds (Items.most_storage) shows only its own.
		cells[i].visible = i < bag.slots.size()
		if not cells[i].visible:
			continue
		var s = bag.slots[i]
		var cell = cells[i]
		cell.texture = ItemIcons.of_item(s[0]) if s != null else null
		cell.number = "×%d" % s[1] if s != null and s[1] > 1 else ""
		cell.fill = bag.freshness(i)
		cell.selected = bag == _from and i == _at
		var shown: bool = _kinds.chosen == "" or s != null and Items.category(s[0]) == _kinds.chosen
		cell.modulate = Color.WHITE if shown else Color(1, 1, 1, 0.3)


## The panel at the bottom: the chosen stack, its weight and what it is, and the
## buttons for what can be done with it.
func _show_info(inv) -> void:
	if _worn != "":
		_show_worn(inv)
		return
	_use.visible = true
	var s = _from.slots[_at] if _from != null else null
	var mine: bool = s != null and _from == inv
	if s == null:
		_info.text = ("Выбери ячейку, затем ту, куда её переложить" if _manual else "Выбери ячейку, чтобы узнать о вещи") \
			if not inv.is_empty() else "Пусто. Подбирай ветки, ягоды и брёвна."
		_facts.show_groups([])
	else:
		var id: String = s[0]
		_info.text = "%s ×%d%s%s" % [Items.title(id), s[1],
			" · с вещами" if _from.contents(_at) != null else "",
			"" if mine else " · в сундуке"]
		_facts.show_groups(FactChips.item_groups(id, s[1], _from.worn(_at), Inventory.stack_weight(s),
			game.character.burn_left(id) if mine else 1.0, _from.freshness(_at)))
	_info.add_theme_color_override("font_color", UiStyle.INK if s != null else UiStyle.MUTED)
	_repair.visible = mine and inv.worn(_at) > 0
	_set_down.visible = mine and Placed.is_light_item(s[0])
	# The name wraps in what the buttons by it leave.
	var room := _width(slot) - 2 * UiStyle.WELL_PAD
	for b: Button in [_repair, _set_down]:
		if b.visible:
			room -= int(b.get_combined_minimum_size().x) + 6
	_info.custom_minimum_size.x = room - _beside()
	var heals: bool = s != null and Items.heal(s[0]) > 0.0
	var food: bool = s != null and Items.food(s[0]) > 0.0 or heals
	var put: bool = s != null and _placeable(s[0])
	var plant: bool = s != null and not food and _plantable(s[0])
	var wear: bool = s != null and Items.wear_on(s[0]) != ""
	_use.text = "Надеть" if wear else ("Перевязать" if heals else ("Съесть" if food else ("Поставить" if put else ("Посадить" if plant else "Взять"))))
	_use.tooltip_text = "Надеть на персонажа" if wear else ("Перевязать раны" if heals else ("Съесть одну" if food else ("Поставить рядом" if put \
		else ("Посадить перед собой" if plant else "Взять в руку"))))
	_use.disabled = not mine or not wear and not food and not put and not plant and game.controls.held() == s[0]
	_throw.get_child(0).disabled = not mine
	_throw.get_child(1).disabled = not mine or s[1] < 2
	_destroy.disabled = s == null
	_destroy.tooltip_text = "Нажми ещё раз — уничтожить навсегда" if _confirming else "Уничтожить"
	TabRow.light(_destroy, _confirming, _confirming)


## The width the buttons take beside the name (none when they are under the facts).
func _beside() -> int:
	return int(_buttons.get_combined_minimum_size().x) + 6 if _buttons.get_parent() == _name_row else 0


## The panel at the bottom with a slot of the figure chosen: what is worn or held
## there, «Снять» (or «Убрать» for a hand).
func _show_worn(inv) -> void:
	var hand := _worn.begins_with("hand")
	var id: String = game.controls.hands[int(_worn.right(1))] if hand else inv.gear.get(_worn, "")
	var title: String = PersonPanel.TITLES[_worn]
	if id != "":
		var extra := ""
		if _worn == "back":
			extra = " · +%d ячеек" % Items.bag_slots(id)
		_info.text = "%s: %s%s" % [title, Items.title(id), extra]
		var h := int(_worn.right(1))
		# A light in the second hand is the second one lit when the first holds one too.
		var k := 1 if hand and h == 1 and game.controls.hands[0] == id and inv.count(id) > 1 else 0
		_facts.show_groups(FactChips.item_groups(id, 1, 0, Items.weight(id), game.character.burn_left(id, k) if hand else 1.0))
	elif _worn == "back":
		_info.text = "Сумка: %d ячеек, всегда с собой. Надень котомку, сумку или рюкзак — станет больше" % inv.base
		_facts.show_groups([])
	else:
		_info.text = "%s: пусто" % title
		_facts.show_groups([])
	_info.add_theme_color_override("font_color", UiStyle.INK if id != "" else UiStyle.MUTED)
	_repair.visible = false
	_set_down.visible = false
	_info.custom_minimum_size.x = _width(slot) - 2 * UiStyle.WELL_PAD - _beside()
	_use.visible = true
	_use.text = "Убрать" if hand else "Снять"
	_use.tooltip_text = "Освободить руку" if hand else "Снять в сумку"
	_use.disabled = id == ""
	_throw.get_child(0).disabled = true
	_throw.get_child(1).disabled = true
	_destroy.disabled = true
	TabRow.light(_destroy, false, false)


## What changes while the window is open: the chests within reach (walking up to one
## adds its tab, walking away takes it off), the craft tab's queue.
func refresh_state() -> void:
	var near := []
	var here: Vector3 = game.player.position
	for e: Dictionary in game.placed.things:
		if e.items != null and game.placed.center(e).distance_to(here) <= game.gathering.REACH + 1.0:
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
			icons[str(i)] = ItemIcons.of_item(_chests[i].item) if _chests[i].has("item") else UiStyle.icon("to_chest")
			tips[str(i)] = "Сундук %d" % (i + 1)
		_chest_tabs.set_tabs(keys, icons, tips)
		_chest_tabs.visible = not _chests.is_empty()
		refresh.call_deferred()
	_chest_tabs.select(str(_chests.find(_chest_entry)))
	craft.refresh_progress()



func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(action)
	return b
