extends PanelContainer
## The bag window (plan/design/ui.md, section 5): the slots with their items, the
## weight against the limit, the character's state in numbers, and what can be done
## with the chosen item (eat, take it in the hand in use, plant a bush or place a thing in
## front of the player, repair a worn tool at a workbench, throw away). Opened at a
## chest, it shows the chest's slots under the bag's and moves whole stacks between
## them; walking away from the chest closes its part. The craft tab (CraftPanel) shows
## the recipes known and the queue; opened at a station it starts there. Opens over
## the running world, which goes on; taps and clicks inside it do not reach the world.

const UiStyle := preload("res://src/client/ui_style.gd")
const HotbarSlot := preload("res://src/client/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/item_icons.gd")
const Items := preload("res://src/shared/items.gd")
const CraftPanel := preload("res://src/client/craft_panel.gd")
const Workshop := preload("res://src/client/workshop.gd")

const SLOT := 40

var game
var _state: Label
var _weight: Label
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
var _bag_tab: Button
var _craft_tab: Button
var _bag_page: VBoxContainer
var craft: CraftPanel
var _chosen := -1
var _chest_title: Label
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
	_state = UiStyle.label()
	box.add_child(_state)
	craft = CraftPanel.new(game)
	craft.on_layout = func() -> void:
		reset_size()
		position = ((get_parent_area_size() - size) * 0.5).floor()
	craft.visible = false
	box.add_child(craft)
	_bag_page = VBoxContainer.new()
	_bag_page.add_theme_constant_override("separation", 6)
	box.add_child(_bag_page)
	box = _bag_page
	_weight = UiStyle.label()
	box.add_child(_weight)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_grid)
	for i in game.character.inventory.slots.size():
		var s = HotbarSlot.new(SLOT)
		s.pressed.connect(_choose.bind(i))
		_grid.add_child(s)
		_slots.append(s)
	_chest_title = UiStyle.label("Сундук", UiStyle.ACCENT)
	box.add_child(_chest_title)
	_chest_grid = GridContainer.new()
	_chest_grid.add_theme_constant_override("h_separation", 4)
	_chest_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_chest_grid)
	for i in game.props.CHEST_SLOTS:
		var s = HotbarSlot.new(SLOT)
		s.pressed.connect(_choose_in_chest.bind(i))
		_chest_grid.add_child(s)
		_chest_slots.append(s)
	_info = UiStyle.label("", UiStyle.MUTED)
	_info.custom_minimum_size.y = 22
	box.add_child(_info)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	box.add_child(actions)
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
	for b in [_to_chest, _to_bag, _eat, _hold, _plant, _put, _repair, _drop_one, _drop_all]:
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


## Lays the slots out for a screen `screen` UI pixels large: eight across on a wide
## screen, four on a narrow one, the window in the middle.
func fit(screen: Vector2) -> void:
	_grid.columns = 8 if screen.x >= 8 * (SLOT + 4) + 40 else 4
	_chest_grid.columns = _grid.columns
	craft.custom_minimum_size.x = _grid.columns * (SLOT + 4) - 4
	craft.narrow = _grid.columns < 8
	# The rest of the window (tabs, state, stations, queue) takes about 170 UI pixels.
	craft.list_height = clampi(int(screen.y) - 190, 70, 300)
	reset_size()
	position = ((screen - size) * 0.5).floor()


func _choose(i: int) -> void:
	_chosen = i if _chosen != i else -1
	_chosen_chest = -1
	refresh()


func _choose_in_chest(i: int) -> void:
	_chosen_chest = i if _chosen_chest != i else -1
	_chosen = -1
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


## Shows the bag and the state as they are now.
func refresh() -> void:
	if not visible:
		return
	refresh_state()
	var inv = game.character.inventory
	_weight.text = "Вес %.1f из %d кг%s" % [inv.weight(), inv.weight_limit, " · перегруз" if inv.overloaded() else ""]
	_weight.add_theme_color_override("font_color", UiStyle.DANGER if inv.overloaded() else UiStyle.INK)
	if _chosen >= 0 and inv.slots[_chosen] == null:
		_chosen = -1
	for i in _slots.size():
		var s = inv.slots[i]
		var slot = _slots[i]
		slot.texture = ItemIcons.of_item(s[0]) if s != null else null
		slot.number = str(s[1]) if s != null and s[1] > 1 else ""
		slot.selected = i == _chosen
		# The first row is the hotbar: its slots carry their numbers.
		slot.key = str(i + 1) if i < inv.HOTBAR else ""
	_chest_title.visible = _chest != null
	_chest_grid.visible = _chest != null
	if _chest != null:
		if _chosen_chest >= 0 and _chest.slots[_chosen_chest] == null:
			_chosen_chest = -1
		for i in _chest_slots.size():
			var s = _chest.slots[i]
			_chest_slots[i].texture = ItemIcons.of_item(s[0]) if s != null else null
			_chest_slots[i].number = str(s[1]) if s != null and s[1] > 1 else ""
			_chest_slots[i].selected = i == _chosen_chest
	var in_chest = _chest.slots[_chosen_chest] if _chest != null and _chosen_chest >= 0 else null
	_to_bag.visible = in_chest != null
	_to_chest.visible = _chest != null and _chosen >= 0 and inv.slots[_chosen] != null
	var chosen = inv.slots[_chosen] if _chosen >= 0 else null
	if in_chest != null:
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
	reset_size()
	position = ((get_parent_area_size() - size) * 0.5).floor()


## The state line alone, which changes every frame; the chest's part closes when the
## player has walked away from it.
func refresh_state() -> void:
	if _chest != null:
		if not game.props.placed.has(_chest_entry) \
				or game.props.center(_chest_entry).distance_to(game.player.position) > game.gathering.REACH + 1.0:
			show_chest({})
	craft.refresh_progress()
	var v = game.character.vitals
	var text := "Здоровье %d · Сытость %d · Силы %d" % [roundi(v.health), roundi(v.satiety), roundi(v.stamina)]
	if _state.text != text:
		_state.text = text


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(action)
	return b
