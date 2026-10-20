extends PanelContainer
## The bag window (plan/design/ui.md, section 5): the slots with their items, the
## weight against the limit, the character's state in numbers, and what can be done
## with the chosen item (eat, throw away). Opens over the running world, which goes
## on; taps and clicks inside it do not reach the world. Crafting by hand comes here
## as a tab with the crafting step.

const UiStyle := preload("res://src/client/ui_style.gd")
const HotbarSlot := preload("res://src/client/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/item_icons.gd")
const Items := preload("res://src/shared/items.gd")

const SLOT := 40

var game
var _state: Label
var _weight: Label
var _grid: GridContainer
var _slots := []
var _info: Label
var _eat: Button
var _drop_one: Button
var _drop_all: Button
var _chosen := -1


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
	var title := UiStyle.label("Сумка", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Закрыть", close))
	_state = UiStyle.label()
	box.add_child(_state)
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
	_info = UiStyle.label("", UiStyle.MUTED)
	_info.custom_minimum_size.y = 22
	box.add_child(_info)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	box.add_child(actions)
	_eat = _button("Съесть", func() -> void: game.character.eat(_chosen))
	_drop_one = _button("Выбросить 1", func() -> void: game.character.throw_away(_chosen, 1))
	_drop_all = _button("Выбросить все", func() -> void: game.character.throw_away(_chosen, 1 << 20))
	for b in [_eat, _drop_one, _drop_all]:
		actions.add_child(b)
	game.character.state_changed.connect(refresh)


func open() -> void:
	visible = true
	move_to_front()
	refresh()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Lays the slots out for a screen `screen` UI pixels large: eight across on a wide
## screen, four on a narrow one, the window in the middle.
func fit(screen: Vector2) -> void:
	_grid.columns = 8 if screen.x >= 8 * (SLOT + 4) + 40 else 4
	reset_size()
	position = ((screen - size) * 0.5).floor()


func _choose(i: int) -> void:
	_chosen = i if _chosen != i else -1
	refresh()


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
	var chosen = inv.slots[_chosen] if _chosen >= 0 else null
	if chosen == null:
		_info.text = "Выбери ячейку" if not inv.is_empty() else "Пусто. Подбирай ветки, ягоды и брёвна."
	else:
		var id: String = chosen[0]
		var food := Items.food(id)
		_info.text = "%s ×%d · %.1f кг%s" % [Items.title(id), chosen[1], Items.weight(id) * chosen[1],
			" · сытость +%d" % roundi(food) if food > 0.0 else ""]
	_eat.visible = chosen != null and Items.food(chosen[0]) > 0.0
	_drop_one.visible = chosen != null
	_drop_all.visible = chosen != null and chosen[1] > 1
	reset_size()
	position = ((get_parent_area_size() - size) * 0.5).floor()


## The state line alone, which changes every frame.
func refresh_state() -> void:
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
