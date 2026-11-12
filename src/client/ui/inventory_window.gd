extends PanelContainer
## The inventory window (plan/design/ui.md, section 5): the character (PersonPanel: what
## is worn and held, the skills) beside the bag on a wide screen, over it on a tall one,
## and only on the bag's tab (the others take its room); the tabs «Инвентарь»,
## «Крафт», «Земля» (LandPage, only on land claimed) and «Команда» (TeamPage, only on
## a server) are joined as one, a button tall (TabRow.tabs). A tap on a slot of the figure
## works as a tap on a hand of the hotbar (the next tool) or takes off and puts on what
## is worn there (see _tap_person). The bag part is as wide whatever it shows: the bag's
## slots, ROWS rows of them showing (they scroll), with a column of tabs by kind of
## item on the left (the other slots dim; as many as fit beside the slots, the rest
## scroll). The chests within reach stand under the bag
## in the same list; the head of the window has, by the cross, the button that takes the
## chest up. A tap picks a slot, a tap on another picks that one; with sorting by hand
## on, a tap on another slot (of the bag or a chest) moves the stack there, swaps the
## two or tops up a stack of the same item, and lets it go; a tap on the chosen one lets
## it go. The panel at the bottom keeps its height whether a stack is chosen or not: at
## its top the chosen stack's picture and name (its count only for more than one) and
## at the top right the lock of the hotbar row, sorting by hand and «по виду | по весу»
## (they sort the bag past the hotbar row and the chests shown); then what it is as
## named groups of small wells side by side (FactChips.item_groups: weight, food, the
## bag, the tool's work, what a weapon shoots, wear) and a line of buttons: on the left
## the wide amber one with a picture of what it does (take in hand, eat, set down,
## plant, put on...; for a light «взять | поставить», two thirds and one third), on the
## right, with a chest shown, the chosen stack into it (out of it when it lies there; it
## stays chosen), all the bag into it (past the hotbar row while the lock is on) and,
## when it holds something, all of it back; the spanner for a worn tool, throwing away
## one | all and the bin (red at the first tap, it destroys at the second). A weapon with nothing in the
## bag to shoot shows inactive (HotbarSlot.inactive), its «Заряды» a red «нет». The craft
## tab (CraftPanel) has its own cells and panels; opened at a station it starts there.
## Opens over the running world, which goes on; taps inside it do not reach the world.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const LandPage := preload("res://src/client/ui/land_page.gd")
const TeamPage := preload("res://src/client/ui/team_page.gd")
const IconTabs := preload("res://src/client/ui/icon_tabs.gd")
const Items := preload("res://src/shared/content/items.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Quality := preload("res://src/shared/game/quality.gd")
const CraftPanel := preload("res://src/client/ui/craft_panel.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const PersonPanel := preload("res://src/client/ui/person_panel.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")
const BuildMode := preload("res://src/client/input/build_mode.gd")
const FarmMode := preload("res://src/client/input/farm_mode.gd")
const Lang := preload("res://src/shared/content/lang.gd")

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
const ROWS := 4
## The room between the bag's slots and a chest's, and between chests.
const CHEST_GAP := 2
const SLOT := 40
const SLOT_SMALL := 36
## The width of the craft tab's column of the recipe and the queue beside the cells on
## a wide screen, in UI pixels.
const CRAFT_SIDE := 300
## The gap between the character and the bag or craft tab.
const GAP_MAIN := 6
## The width of the wide button of the panel at the bottom (as three small ones joined).
const USE_WIDTH := TabRow.WIDE
## What the wide button does: its picture and tooltip.
const USES := {
	"take": ["act_take", "[take_in_hand]"], "eat": ["act_eat", "[eat_one]"], "drink": ["act_eat", "[drink]"], "heal": ["act_heal", "[bandage_wounds]"],
	"place": ["act_place", "[place_nearby]"], "plant": ["act_plant", "[plant_in_front]"],
	"wear": ["act_wear", "[put_on_the_character]"], "build": ["hammer", "[build_build_mode]"],
	"farm": ["act_plant", "[garden_farming_mode]"], "launch": ["act_place", "[launch_on_the_water]"], "off": ["take", "[take_off]"], "free": ["take", "[free_the_hand]"],
}

var game
## The side of a slot now (see fit).
var slot := SLOT
var _bag_tab: Button
var _craft_tab: Button
## The tab «Земля», shown while the player stands on land claimed (LandPage).
var _land_tab: Button
var land_page: LandPage
## The tab «Команда», shown only on a server (TeamPage).
var _team_tab: Button
var team_page: TeamPage
var _tab := "bag"
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
var _grid: GridContainer
var _slots := []
## The chest's buttons in the head, and the gap over its slots.
var _chest_buttons: HBoxContainer
var _to_chest: Button
## The list of the bag's slots and the chests'.
var _list: VBoxContainer
## A grid and its cells for each chest within reach, in the order of _chests.
var _chest_grids := []
## Sorting by hand: a tap on a second slot moves the chosen stack there.
var _manual := false
var _manual_button: Button
## The lock of the hotbar row: on, «всё в сундук» leaves the first row in the bag.
var _lock := true
var _lock_button: Button
## «забрать всё из сундука», shown when the chest holds something.
var _all_out: Button
var _info: Label
var _facts: FactChips
## «Взять» into the hand in use, «Съесть» for food, «Поставить» for what is set down,
## «Посадить» for a bush.
var _use: Button
var _repair: Button
## Sets a light (a torch, a candle) down in front; the wide button takes it in hand.
var _set_down: Button
## The line of buttons for the chosen stack: the wide one on the left, the sorting in the
## middle, what moves or destroys it on the right (the two sides as wide, so the middle is).
var _left: HBoxContainer
var _sorts: HBoxContainer
var _right: HBoxContainer
## The chosen stack's picture by its name.
var _icon: TextureRect
## «в сундук | всё в сундук», shown with a chest.
var _into: HBoxContainer
## Dragging over the bag's slots scrolls them.
var _drag: DragScroll
## Throw away one and all, and the bin.
var _throw: HBoxContainer
var _destroy: Button
## The bin waits for its second tap.
var _confirming := false
## The chosen stack: the bag it is in (the character's or a chest's) and its slot.
var _from = null
var _at := -1
## The chests within reach (records of Props.placed), the one the chest buttons work on
## (of the stack chosen last in a chest, else the nearest), and what they were at the
## last look (to notice walking up to one or away).
var _chests: Array = []
## The entries of _chests for the bags and chests lying in the bag, by slot: the item,
## the bag opened from it (Inventory.open), the slot as `cell` (how requests name it).
var _packed := {}
## The bag _packed was opened from, and whether it changed since.
var _packed_of = null
var _packed_dirty := true
## A refresh is asked for this frame (see _refresh_later).
var _refresh_due := false
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
	# The tabs joined as one, a button tall, the one shown lit amber (TabRow.tabs).
	var tabs_row := TabRow.tabs([["[inventory]", "", show_tab.bind("bag")], ["[craft]", "", show_tab.bind("craft")],
		["[land]", "", show_tab.bind("land")], ["[team_n3]", "", show_tab.bind("team")]], 30)
	head.add_child(tabs_row)
	_bag_tab = tabs_row.get_child(0)
	_craft_tab = tabs_row.get_child(1)
	_land_tab = tabs_row.get_child(2)
	_land_tab.visible = false
	_team_tab = tabs_row.get_child(3)
	_team_tab.visible = false
	game.land.changed.connect(_show_land_tab)
	# The free room of the head keeps the cross on the right.
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(room)
	# What can be done with the chest shown (bag tab) or the station (craft tab).
	_chest_buttons = HBoxContainer.new()
	_chest_buttons.add_theme_constant_override("separation", 4)
	head.add_child(_chest_buttons)
	_chest_buttons.add_child(TabRow.icon_button(UiStyle.icon("take"), "[take_the_chest_into_the]", func() -> void:
		var e := _chest_entry
		_let_go()
		game.net.request(Protocol.PROP_TAKE, [e.cell]).then(func(_v: Variant) -> void: refresh())))
	_chest_buttons.get_child(0).custom_minimum_size = Vector2(30, 30)
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
	land_page = LandPage.new(game)
	land_page.on_layout = _place
	land_page.visible = false
	tabs.add_child(land_page)
	team_page = TeamPage.new(game)
	team_page.on_layout = _place
	team_page.visible = false
	tabs.add_child(team_page)
	head.add_child(craft.station_buttons)
	head.add_child(land_page.head_buttons)
	var shut := TabRow.icon_button(UiStyle.icon("close"), "[close]", close)
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
	# The bag's slots and under them those of each chest within reach, one list: it
	# scrolls past ROWS rows, by its thin bar or a finger dragged over the slots.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(_scroll)
	_drag = DragScroll.new()
	_scroll.add_child(_drag)
	_list = VBoxContainer.new()
	# Between the bag and a chest, and between chests, a little more than between slots.
	_list.add_theme_constant_override("separation", CHEST_GAP)
	_scroll.add_child(_list)
	_grid = _slot_grid(_list, game.character.inventory.slots.size(), _slots, _tap.bind(-1))

	# The panel at the bottom: the chosen stack and what can be done with it.
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", UiStyle.well())
	_bag_page.add_child(bottom)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	bottom.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info.add_child(name_row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_icon)
	_info = UiStyle.label("", UiStyle.MUTED)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info.custom_minimum_size.x = 120
	name_row.add_child(_info)
	# At the top right: sorting by hand, and by kind | by weight joined.
	var sorts := HBoxContainer.new()
	sorts.add_theme_constant_override("separation", 4)
	sorts.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_row.add_child(sorts)
	_sorts = sorts
	# The lock: on, «всё в сундук» leaves the hotbar row in the bag; off, everything
	# that fits goes.
	_lock_button = TabRow.icon_button(UiStyle.icon("lock"), "", func() -> void:
		_lock = not _lock
		refresh())
	sorts.add_child(_lock_button)
	_manual_button = TabRow.icon_button(UiStyle.icon("swap"), "[sort_by_hand_a_tap]", func() -> void:
		# The chosen slot stays chosen: the next tap may move it.
		_manual = not _manual
		_confirming = false
		refresh())
	sorts.add_child(_manual_button)
	var by := []
	for k in Inventory.SORTS:
		var icon: Texture2D = ItemIcons.picture("weight") if k == "weight" else UiStyle.icon("sort_" + k)
		by.append([icon, Lang.f("[sort_except_the_first_row]", [Inventory.SORTS[k]]), sort.bind(k)])
	var sort_by := TabRow.split(by)
	sorts.add_child(sort_by)
	# As tall as the stack's picture by the name, so the row keeps its height.
	for b in [_lock_button, _manual_button] + sort_by.get_children():
		b.custom_minimum_size = Vector2(30, 24)
	_facts = FactChips.new()
	_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_facts)
	# The buttons in one line: the wide amber one with the picture of what it does (take
	# in hand, eat, set down, plant...) on the left, for a light «взять | поставить»
	# joined; on the right «в сундук | всё в сундук» (with a chest shown), «выбросить |
	# выбросить все» and the bin.
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	info.add_child(line)
	_left = HBoxContainer.new()
	_left.add_theme_constant_override("separation", -2)
	line.add_child(_left)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(gap)
	_right = HBoxContainer.new()
	_right.add_theme_constant_override("separation", 4)
	_right.alignment = BoxContainer.ALIGNMENT_END
	line.add_child(_right)
	_use = _button("", func() -> void:
		if _worn != "":
			_use_worn()
			return
		var id: String = _from.slots[_at][0]
		var on: String = _from.worn_on(_at) if _from == game.character.inventory else ""
		if on != "":
			game.net.request(Protocol.TAKE_OFF, [on])
			refresh()
		elif Items.wear_on(id) != "":
			# Worn, it stays in its slot, chosen: the button turns to «Снять».
			game.net.request(Protocol.WEAR, [_at])
			refresh()
		elif Items.food(id) > 0.0 or Items.drink(id) > 0.0 or Items.heal(id) > 0.0:
			game.net.request(Protocol.EAT, [_at])
		elif FarmMode.farms_with(id):
			close()
			game.farm.enter(id)
		elif _launchable(id):
			game.net.request(Protocol.VESSEL_LAUNCH, [id])
			close()
		elif _plantable(id):
			game.net.request(Protocol.PLANT, [id])
		elif BuildMode.builds_with(id):
			close()
			game.build.enter(id)
		elif _placeable(id):
			if game.props.put_from_bag(id, _at):
				close()
		else:
			game.controls.hold(id))
	_use.custom_minimum_size.x = USE_WIDTH
	_use.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.accent(_use)
	# Its picture dark on the amber.
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		_use.add_theme_color_override(c, UiStyle.DARK_INK)
	_use.add_theme_color_override("icon_disabled_color", Color(UiStyle.DARK_INK, 0.5))
	_left.add_child(_use)
	# A light (a torch, a candle) is set down in front by the narrow plain part.
	_set_down = _button("", func() -> void:
		if game.props.put_light(_from.slots[_at][0]):
			close())
	_set_down.icon = UiStyle.centred(UiStyle.icon("act_place"))
	_set_down.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_down.tooltip_text = "[place_in_front]"
	_left.add_child(_set_down)
	# The chosen stack into the chest (out of it when it lies there); all the bag into
	# it, and all of it back when it holds something.
	_into = TabRow.split([
		[UiStyle.icon("to_chest"), "[move_to_the_chest]", _move_chosen],
		[UiStyle.icon("to_chest_all"), "", _put_all_in_chest],
		[UiStyle.icon("from_chest_all"), "[take_everything_from_the_chest]", _take_all_from_chest],
	])
	_to_chest = _into.get_child(0)
	_all_out = _into.get_child(2)
	_right.add_child(_into)
	_throw = TabRow.split([
		[UiStyle.icon("drop_one"), "[drop_one]", func() -> void: game.net.request(Protocol.THROW, [_at, 1])],
		[UiStyle.icon("drop_all"), "[drop_all]", func() -> void: game.net.request(Protocol.THROW, [_at, 1 << 20])],
	])
	# Repair a worn tool (at a station that mends, with what it is mended with), before
	# throwing away.
	_repair = TabRow.icon_button(UiStyle.icon("act_repair"), "[repair_at_a_repair_station]", func() -> void:
		game.net.request(Protocol.REPAIR, [_at]))
	_right.add_child(_repair)
	_right.add_child(_throw)
	_destroy = TabRow.icon_button(UiStyle.icon("trash"), "[destroy]", func() -> void:
		if _confirming:
			destroy_chosen()
		else:
			_confirming = true
			refresh())
	_right.add_child(_destroy)
	for b in _into.get_children() + _throw.get_children() + [_repair, _destroy]:
		b.custom_minimum_size = Vector2(30, 30)
	game.character.state_changed.connect(_refresh_later)
	show_tab("bag")


## A bush dug up: its wide button plants it in front of the player instead of taking
## it in hand.
static func _plantable(id: String) -> bool:
	return Items.get_item(id).get("plant", "") != ""


## Whether `id` is a raft or a boat, launched by the wide button (see refresh).
func _launchable(id: String) -> bool:
	return game.actions != null and game.actions.vessel_of(id) > 0.0


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
		# Picked as the finger lifts: a finger dragged over the bag scrolls it instead.
		s.on_release = true
		s.pressed.connect(func() -> void: tap.call(i))
		grid.add_child(s)
		cells.append(s)


## A tap on slot `k` of the figure (see PersonPanel.picked), as a tap on a hand of the
## hotbar: the first tap chooses the slot (the panel at the bottom tells what is there),
## the next changes what is worn there to the next thing of the bag for it, and after
## the last takes it off (see _next_wear). With a thing for it chosen in the bag, the
## tap puts that on at once. A hand becomes the hand in use, and a tap on the hand in
## use gives it the next tool (or brush).
func _tap_person(k: String) -> void:
	_confirming = false
	var inv = game.character.inventory
	var chosen: int = _at if _from == inv and _from.slots[_at] != null and Items.wear_on(_from.slots[_at][0]) == k else -1
	var again := _worn == k
	_let_go()
	_worn = k
	if k.begins_with("hand"):
		game.hud.tap_hand(int(k.right(1)))
	elif chosen >= 0 and chosen != inv.worn_slot(k):
		game.net.request(Protocol.WEAR, [chosen])
	elif again or chosen >= 0:
		var next := _next_wear(inv, k)
		if next >= 0:
			game.net.request(Protocol.WEAR, [next])
		elif inv.gear.get(k, "") != "":
			game.net.request(Protocol.TAKE_OFF, [k])
		else:
			game.character.nag("wear", "[nothing_in_the_bag_to]")
	refresh()


## The slot of bag `inv` with the next thing to wear in body slot `k`: the first after
## the one worn there that is another thing, -1 past the last (take off then). Nothing
## worn: the first, the bag with the most slots for the back.
static func _next_wear(inv, k: String) -> int:
	var at: int = inv.worn_slot(k)
	if at < 0 and inv.gear.get(k, "") == "":
		return _to_wear(inv, k)
	var worn: String = inv.gear.get(k, "")
	for i in range(at + 1, inv.base if k == "back" else inv.slots.size()):
		var s = inv.slots[i]
		if s != null and Items.wear_on(s[0]) == k and s[0] != worn:
			return i
	return -1


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


## Shows the bag ("bag"), the craft tab ("craft"), the land's ("land") or the team's
## ("team").
func show_tab(tab: String) -> void:
	_show_team_tab()
	if (tab == "land" and not _land_tab.visible) or (tab == "team" and not _team_tab.visible):
		tab = "bag"
	_tab = tab
	_bag_page.visible = tab == "bag"
	# The character only by the bag: the other tabs need the room it takes.
	person.visible = tab == "bag"
	# Off the bag tab the label stays, empty, to keep the cross on the right.
	if tab != "bag":
		_chest_buttons.visible = false
	craft.visible = tab == "craft"
	craft.station_buttons.visible = false
	land_page.visible = tab == "land"
	land_page.head_buttons.visible = false
	team_page.visible = tab == "team"
	TabRow.light(_bag_tab, tab == "bag")
	TabRow.light(_craft_tab, tab == "craft")
	TabRow.light(_land_tab, tab == "land")
	TabRow.light(_team_tab, tab == "team")
	land_page.refresh()
	team_page.refresh()
	refresh()
	craft.refresh_now()


## The tab «Земля» shows while the player stands on land claimed; leaving it, the window
## goes back to the bag.
func _show_land_tab() -> void:
	var on: bool = not game.land.here().is_empty()
	if _land_tab.visible == on:
		return
	_land_tab.visible = on
	if not on and _tab == "land":
		show_tab("bag")


## The tab «Команда» shows only on a server (teams are a server's: Main.welcome).
func _show_team_tab() -> void:
	_team_tab.visible = not game.welcome.is_empty()


func open() -> void:
	_show_team_tab()
	if _tab == "team" and not _team_tab.visible:
		show_tab("bag")
	visible = true
	move_to_front()
	_chests_seen = "-"
	refresh()
	craft.refresh_now()


func close() -> void:
	visible = false
	_let_go()
	# Sorting by hand is for one look into the bag.
	_manual = false
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
	for s in _slots + _chest_cells():
		s.custom_minimum_size = Vector2(slot, slot)
	person.set_slot(slot)
	_main.vertical = _stacked
	person.visible = _bag_page.visible
	_bag_page.custom_minimum_size.x = _width(slot)
	land_page.custom_minimum_size.x = _width(slot)
	team_page.custom_minimum_size.x = _width(slot)
	# A wrapping label is measured at its least width: as wide as the panel it is in
	# (less the buttons by it, see _fit_name).
	_fit_name()
	craft.slot = slot
	# On a wide screen the craft tab's recipe and queue go right of the cells, so the
	# window is not too tall for it; the window is that much wider on the craft tab.
	# The character is not shown there, so the craft tab has the whole width.
	var whole := screen.x - 2 * EDGE - 2 * FRAME
	var side := screen.x > screen.y and whole >= _width(slot) + 6 + CRAFT_SIDE
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
	return IconTabs.SIDE + 2 * GAP + COLUMNS * (side + 4) - 4 + UiStyle.SCROLL_BAR


## Sizes the window round what it shows, shortens the craft tab's cells or the bag's
## (they scroll then) when the window is taller than the room above the hotbar, and
## centres it there.
func _place() -> void:
	_place_queued = false
	var screen := get_parent_area_size()
	var room := Vector2(screen.x, screen.y - HOTBAR)
	var full := _list.get_combined_minimum_size()
	var row := slot + 4
	# Up to ROWS whole rows; the rest scrolls (its bar a gap right of the slots).
	var most := ROWS * row - 4
	_scroll.custom_minimum_size = Vector2(full.x + GAP + UiStyle.SCROLL_BAR, minf(full.y, most))
	# As many kinds on the left as fit beside ROWS rows of slots (they scroll past that).
	_kinds.fit_height(most)
	var page: ScrollContainer = land_page if land_page.visible else (team_page if team_page.visible else null)
	if page != null:
		page.custom_minimum_size.y = page.full_height()
	reset_size()
	var over := size.y - (room.y - 2 * EDGE)
	if page != null and over > 0.0:
		# It scrolls in the room there is.
		page.custom_minimum_size.y = maxf(90.0, page.full_height() - over)
		reset_size()
	elif craft.visible and over > 0.0:
		craft.shrink_list(over)
		reset_size()
	elif _bag_page.visible and over > 0.0:
		# Less room on the screen: fewer rows, whole ones.
		var rows := clampi(floori((_scroll.custom_minimum_size.y + 4 - over) / row), 1, ROWS)
		_scroll.custom_minimum_size.y = rows * row - 4
		reset_size()
	position = ((room - size) * 0.5).floor().max(Vector2(EDGE, EDGE))


## A tap on slot `i` of the bag (`chest` -1) or of chest `chest` of _chests: picks it,
## lets the chosen one go, or (sorting by hand) moves the chosen stack there and lets it
## go. A chest tapped is the one the chest buttons work on.
func _tap(i: int, chest := -1) -> void:
	if not _drag.take_tap():
		return
	if chest >= _chests.size():
		return
	if chest >= 0:
		_chest_entry = _chests[chest]
	var to = game.character.inventory if chest < 0 else _chest_entry.get("items")
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
			game.character.nag("nest", "[a_chest_with_things_cant_n2]")
		_let_go()
	refresh()


## The chosen stack into the chest shown, or out of it into the bag when it lies in a
## chest; it stays chosen where it went (the button then moves it back).
func _move_chosen() -> void:
	var chest = _chest_entry.get("items")
	var inv = game.character.inventory
	if chest == null or _from == null or _from.slots[_at] == null:
		return
	var from = _from
	var at := _at
	var to = chest if from == inv else inv
	var id: String = from.slots[at][0]
	var before: Array = to.slots.duplicate(true)
	game.net.request(Protocol.BAG_MOVE, [_where(from), at, _where(to)]).then(func(v: Variant) -> void:
		if v is int and v == 0:
			game.character.nag("chest", ("[a_chest_with_things_cant_n3]" if from.contents(at) != null else "[the_chest_is_full]") \
				if to == chest else "[no_room_in_the_bag]")
		elif from.slots[at] == null:
			# Chosen where the stack went: the first slot of it that changed.
			var land := -1
			for i in to.slots.size():
				var t = to.slots[i]
				if t != null and t[0] == id and (i >= before.size() or str(before[i]) != str(t)):
					land = i
					break
			_let_go()
			if land >= 0:
				_from = to
				_at = land
		refresh())


## «Всё в сундук»: the bag into the chest shown, past the hotbar row while the lock is on.
func _put_all_in_chest() -> void:
	var chest = _chest_entry.get("items")
	var inv = game.character.inventory
	if chest == null:
		return
	_let_go()
	var first := Inventory.HOTBAR if _lock else 0
	var had: bool = inv.slots.slice(first).any(func(s) -> bool: return s != null)
	game.net.request(Protocol.BAG_ALL, [null, _chest_entry.cell, first]).then(func(v: Variant) -> void:
		if v is int and v == 0 and had:
			game.character.nag("chest", "[the_chest_is_full]")
		refresh())


## «Забрать всё из сундука»: what of the chest shown fits into the bag.
func _take_all_from_chest() -> void:
	var chest = _chest_entry.get("items")
	if chest == null:
		return
	_let_go()
	game.net.request(Protocol.BAG_ALL, [_chest_entry.cell, null, 0]).then(func(v: Variant) -> void:
		if v is int and v == 0:
			game.character.nag("chest", "[no_room_in_the_bag]")
		refresh())


func _let_go() -> void:
	_from = null
	_at = -1
	_worn = ""
	_confirming = false


## Sorts the bag (past the hotbar row while the lock is on) and the chests shown, by
## `by` (see Inventory.SORTS).
func sort(by: String) -> void:
	_let_go()
	# The lock keeps the hotbar row as it is; off, it is sorted too.
	game.net.request(Protocol.SORT, [null, by, Inventory.HOTBAR if _lock else 0])
	for e: Dictionary in _chests:
		game.net.request(Protocol.SORT, [e.cell, by, 0])
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
		game.hud.toast(Lang.line("[destroyed]", [Items.title(taken[0]), taken[1]]))
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


func _bag_changed() -> void:
	_packed_dirty = true


## The bag, the state or a chest changed: the window is shown anew at the end of the
## frame, once however many of the server's events changed it.
func _refresh_later() -> void:
	if not _refresh_due:
		_refresh_due = true
		refresh.call_deferred()


## Shows the bag and the chest as they are now.
func refresh() -> void:
	_refresh_due = false
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
		_grow_grid(_grid, inv.slots.size(), _slots, _tap.bind(-1))
	person.chosen = _worn
	if _from != null and (_from.slots[_at] == null or (_from != inv and not _chests.any(
			func(e: Dictionary) -> bool: return e.items == _from))):
		_let_go()
	# Tabs of the kinds of things in the bag and the chest; the rest is dimmed.
	var have := {}
	var all: Array = inv.slots.duplicate()
	for e: Dictionary in _chests:
		all.append_array(e.items.slots)
	for s in all:
		if s != null:
			have[Items.category(s[0])] = true
	var kinds := IconTabs.kinds(have)
	_kinds.set_tabs(kinds[0], kinds[1], kinds[2])
	_show_slots(inv, _slots)
	for i in _slots.size():
		# The first row is the hotbar: its slots carry their numbers.
		_slots[i].key = str(i + 1) if i < inv.HOTBAR else ""
	_chest_buttons.visible = chest != null
	# A chest set down is taken up; one in the bag is there already.
	_chest_buttons.get_child(0).visible = chest != null and not _chest_entry.has("packed")
	_into.visible = chest != null
	if chest != null:
		var out: bool = _from != null and _from != inv
		_to_chest.disabled = _from == null
		_to_chest.icon = UiStyle.centred(UiStyle.icon("from_chest" if out else "to_chest"))
		_to_chest.tooltip_text = "[take_from_the_chest]" if out else "[move_to_the_chest]"
		_into.get_child(1).tooltip_text = Lang.t("[move_everything_to_the_chest]") + (Lang.t("[except_the_first_row_locked]") if _lock else "")
		_all_out.visible = not chest.is_empty()
	TabRow.light(_lock_button, _lock)
	_lock_button.tooltip_text = "[first_row_lock_sorting_and]" if _lock \
		else "[lock_off_the_first_row]"
	for i in _chest_grids.size():
		var g: Dictionary = _chest_grids[i]
		_show_slots(_chests[i].items, g.cells)
		g.grid.tooltip_text = Lang.f("[kg_n2]", [Lang.t(Items.title(_chests[i].item)), _chests[i].items.weight()])
	TabRow.light(_manual_button, _manual)
	_show_info(inv)
	# The wide button (with a light's «поставить» joined) narrower on a narrow window
	# with a chest's buttons too.
	var room := _width(slot) - 2 * UiStyle.WELL_PAD - 4 - _right.get_combined_minimum_size().x
	var wide := clampf(room, 56, USE_WIDTH)
	if _set_down.visible:
		# «взять» two thirds of it, «поставить» the rest (they overlap by their frames).
		_use.custom_minimum_size.x = roundf(wide * 2.0 / 3.0)
		_set_down.custom_minimum_size.x = wide - _use.custom_minimum_size.x + 2
	else:
		_use.custom_minimum_size.x = wide
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
		# What is worn stays in the bag, marked.
		cell.tag = "[w]" if bag == game.character.inventory and bag.worn_on(i) != "" else ""
		cell.number = "×%d" % s[1] if s != null and s[1] > 1 else ""
		cell.fill = bag.freshness(i)
		cell.grade = Quality.grade(Inventory.quality(s)) if s != null else -1
		# A bag or a chest: how full it is, as the bag's strip on the figure.
		var full: float = bag.fullness(i)
		cell.fill_color = UiStyle.ACCENT if full >= 0.0 else Color(0, 0, 0, 0)
		if full >= 0.0:
			cell.fill = full
		# A weapon with nothing in the player's bag to shoot shows inactive.
		cell.inactive = s != null and FactChips.unarmed(game.character.inventory, s[0])
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
		_info.text = ("[pick_a_slot_then_where]" if _manual else "[pick_a_slot]") \
			if not inv.is_empty() else "[empty_pick_up_branches_and]"
		_facts.show_groups([])
	else:
		var id: String = s[0]
		# The count only for more than one.
		# Where it lies the window shows by itself: no «в сундуке» after the name.
		_info.text = "%s%s%s" % [Lang.t(Items.title(id)), " ×%d" % s[1] if s[1] > 1 else "",
			Lang.t("[with_things]") if _from.contents(_at) != null else Lang.t("[with_writing]") if Inventory.text_of(s) != "" else ""]
		var shoots: String = Items.get_item(id).get("ammo", "")
		_facts.show_groups(FactChips.item_groups(id, s[1], _from.worn(_at), Inventory.stack_weight(s),
			game.character.burn_left(id) if mine else 1.0, _from.freshness(_at), inv.count(shoots) if shoots != "" else -1,
			_from.quality_at(_at)))
	_info.add_theme_color_override("font_color", UiStyle.INK if s != null else UiStyle.MUTED)
	_icon.texture = ItemIcons.of_item(s[0]) if s != null else null
	_icon.visible = _icon.texture != null
	_repair.visible = mine and inv.worn(_at) > 0
	_set_down.visible = mine and Placed.is_light_item(s[0])
	_fit_name()
	var heals: bool = s != null and Items.heal(s[0]) > 0.0 and Items.food(s[0]) <= 0.0
	var drinks: bool = s != null and Items.drink(s[0]) > 0.0 and Items.food(s[0]) <= 0.0
	var food: bool = s != null and Items.food(s[0]) > 0.0 or heals or drinks
	var build: bool = s != null and BuildMode.builds_with(s[0])
	var put: bool = s != null and _placeable(s[0]) and not build
	var farm: bool = s != null and not food and FarmMode.farms_with(s[0])
	var plant: bool = s != null and not food and _plantable(s[0]) and not farm
	var wear: bool = s != null and Items.wear_on(s[0]) != ""
	var off: bool = mine and inv.worn_on(_at) != ""
	var vessel: bool = s != null and _launchable(s[0])
	_show_use("off" if off else "wear" if wear else ("launch" if vessel else ("heal" if heals else (("drink" if drinks else "eat") if food else ("build" if build else ("farm" if farm else ("place" if put else ("plant" if plant else "take"))))))))
	_use.disabled = not mine or not wear and not food and not put and not plant and not build and not farm and not vessel \
		and game.controls.held() == s[0]
	if vessel and mine:
		# A raft or a boat goes on the water near, and only where there is some.
		_use.disabled = game.character.vessel != 0 or game.actions.launch_near(game.character).is_empty()
	_throw.get_child(0).disabled = not mine
	_throw.get_child(1).disabled = not mine or s[1] < 2
	_destroy.disabled = s == null
	_destroy.tooltip_text = "[press_again_to_destroy_it]" if _confirming else "[destroy]"
	TabRow.light(_destroy, _confirming, _confirming)


## The panel at the bottom with a slot of the figure chosen: what is worn or held
## there, «Снять» (or «Убрать» for a hand).
func _show_worn(inv) -> void:
	var hand := _worn.begins_with("hand")
	var id: String = game.controls.hands[int(_worn.right(1))] if hand else inv.gear.get(_worn, "")
	var title: String = PersonPanel.TITLES[_worn]
	if id != "":
		# What it adds (slots, warmth) is in the facts under the name.
		_info.text = "%s: %s" % [title, Lang.t(Items.title(id))]
		var h := int(_worn.right(1))
		# A light in the second hand is the second one lit when the first holds one too.
		var k := 1 if hand and h == 1 and game.controls.hands[0] == id and inv.count(id) > 1 else 0
		var q: int = inv.tool_quality(id) if hand else inv.quality_at(inv.worn_slot(_worn))
		_facts.show_groups(FactChips.item_groups(id, 1, 0, Items.weight(id), game.character.burn_left(id, k) if hand else 1.0,
			-1.0, -1, q))
	elif _worn == "back":
		_info.text = Lang.f("[bag_slots_always_with_you]", [inv.base])
		_facts.show_groups([])
	else:
		_info.text = Lang.f("[empty]", [title])
		_facts.show_groups([])
	_info.add_theme_color_override("font_color", UiStyle.INK if id != "" else UiStyle.MUTED)
	_icon.texture = ItemIcons.of_item(id) if id != "" else null
	_icon.visible = _icon.texture != null
	_repair.visible = false
	_set_down.visible = false
	_fit_name()
	_use.visible = true
	_show_use("free" if hand else "off")
	_use.disabled = id == ""
	_throw.get_child(0).disabled = true
	_throw.get_child(1).disabled = true
	_destroy.disabled = true
	TabRow.light(_destroy, false, false)


## The wide button doing `what` (see USES): its picture and tooltip.
func _show_use(what: String) -> void:
	_use.icon = UiStyle.centred(UiStyle.icon(USES[what][0]))
	_use.tooltip_text = USES[what][1]


## The name wraps in what the sorting by it leaves.
func _fit_name() -> void:
	var room := _width(slot) - 2 * UiStyle.WELL_PAD - 24 - 6 - int(_sorts.get_combined_minimum_size().x) - 6
	_info.custom_minimum_size.x = maxi(room, 40)


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
	# Then the bags and chests lying in the bag, each opened as a chest of its own: opened
	# again only when the bag changed (this runs every frame the window is open).
	var inv = game.character.inventory
	if _packed_of != inv:
		if _packed_of != null and _packed_of.changed.is_connected(_bag_changed):
			_packed_of.changed.disconnect(_bag_changed)
		_packed_of = inv
		inv.changed.connect(_bag_changed)
		_packed_dirty = true
	if _packed_dirty:
		_packed_dirty = false
		var packed := {}
		for k in inv.slots.size():
			var bag = inv.open(k)
			if bag == null:
				continue
			var id: String = inv.slots[k][0]
			var e: Dictionary = _packed.get(k, {})
			if e.get("item", "") != id:
				e = {"item": id, "items": bag, "cell": k, "packed": true}
			else:
				e.items.from_dict(bag.to_dict())
			packed[k] = e
		_packed = packed
	for k: int in _packed:
		near.append(_packed[k])
		seen += "%d%s" % [k, _packed[k].item]
	if seen != _chests_seen:
		_chests_seen = seen
		for e in _chests:
			if e.items.changed.is_connected(_refresh_later):
				e.items.changed.disconnect(_refresh_later)
		_chests = near
		for e in _chests:
			# A bag in the bag changes with it (and is refilled here, which would loop).
			if not e.has("packed"):
				e.items.changed.connect(_refresh_later)
		if not _chests.has(_chest_entry):
			_show_chest(_chests[0] if not _chests.is_empty() else {})
		_make_chest_grids()
		refresh.call_deferred()
	craft.refresh_progress()



## A grid under the bag for each chest within reach and each bag or chest lying in the
## bag, as many slots as it holds.
func _make_chest_grids() -> void:
	for g: Dictionary in _chest_grids:
		for n: Control in [g.line, g.grid]:
			_list.remove_child(n)
			n.queue_free()
	_chest_grids.clear()
	for i in _chests.size():
		var cells := []
		var line := _chest_line(_chests[i])
		_list.add_child(line)
		var grid := _slot_grid(_list, _chests[i].items.slots.size(), cells, _tap.bind(i))
		_chest_grids.append({"grid": grid, "cells": cells, "line": line})


## The strip between the bag and a chest (or two chests): a pale line with a schematic
## picture of what holds the slots, drawn like the weight's on the load line: of its kind
## when UiStyle draws one by its `prop` (a cupboard, a barrel), else a chest's (a sack's for
## a bag in the bag).
func _chest_line(e: Dictionary) -> Control:
	var kind: String = Items.get_item(e.item).get("prop", "none")
	if not UiStyle.ICONS.has(kind):
		kind = "chest" if Items.bag_slots(e.item) <= 0 else "sack"
	return Kit.section(kind, Lang.t(Items.title(e.item)))


## The slots of every chest shown.
func _chest_cells() -> Array:
	var out := []
	for g: Dictionary in _chest_grids:
		out.append_array(g.cells)
	return out


func _button(text: String, action: Callable) -> Button:
	return Kit.button(text, action, 0, 30)
