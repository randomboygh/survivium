extends "res://src/client/ui/kit/window.gd"
## «Витрина интерфейса»: every kind of element the game's windows are made of, on tabs,
## each working when tapped (the user's ask 2026-11-11), so a change to a shared piece
## (the UI kit in src/client/ui/kit/, UiStyle, TabRow, HotbarSlot, FactChips, IconTabs,
## ScrollColumn) is seen at once in all its looks, on a phone too. It is made of the kit
## itself: a KitWindow, Kit's buttons and fields, TwoTap, ChoiceRows, SlotStrip. Opened from «Тестирование» →
## «Отладка» (SettingsMenu), over a shade of the screen; «Закрыть» or Escape closes it.
## The line under the tabs' page tells what the last tap did. Nothing here changes the
## game: the rows' values, the weight and the slots' choice live in the window only.
## `game` is the Main node.

const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const SlotStrip := preload("res://src/client/ui/kit/slot_strip.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const IconTabs := preload("res://src/client/ui/icon_tabs.gd")
const ScrollColumn := preload("res://src/client/ui/scroll_column.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## The tabs: key and name.
const SECTIONS := [["buttons", "Кнопки"], ["rows", "Строки"], ["slots", "Ячейки"],
	["fields", "Поля"], ["lists", "Списки"], ["look", "Вид"]]
## The widest and tallest the panel's page grows on a big screen.
const MOST_WIDTH := 480
const MOST_HEIGHT := 560
## The height of the window's buttons and tabs (as the settings').
const BUTTON_H := Kit.BUTTON_H
## The settings' rows: a name, arrows and the value between (SettingsMenu).
const NAME_WIDTH := 150
const VALUE_WIDTH := 112
const ARROW := 32
const ROW_WIDTH := NAME_WIDTH + VALUE_WIDTH + 2 * ARROW + 3 * 2
## How long a two-tap button waits for its second tap, and a green one stays green.
const CONFIRM_WAIT := 4.0
const GREEN_TIME := 1.5
## The bag's limit the weight meter shows, in kg.
const LIMIT := 40

signal closed

var game
## The tab shown.
var section := "buttons"
var _tab_buttons := {}
var _scroll: ScrollContainer
var _room: MarginContainer
var _list: VBoxContainer
var _said: Label
## The settings' rows of the «Строки» tab: the index chosen of each, by name, and the rows.
var _picked := {}
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, ARROW)
## The buttons that ask first.
var _asks := TwoTap.new(CONFIRM_WAIT)
## The weight on the meter of the «Ячейки» tab, and the meter.
var _weight := 25.0
var _meter: Control
## The slot chosen on the «Ячейки» tab and the chips that tell about its thing.
var _chosen: HotbarSlot = null
var _chips: FactChips


func _init(g) -> void:
	game = g


func _ready() -> void:
	build("Витрина интерфейса")
	var parts := []
	for s: Array in SECTIONS:
		parts.append([s[1], "", show_section.bind(s[0])])
	var tabs := TabRow.tabs(parts, BUTTON_H)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	for i in SECTIONS.size():
		_tab_buttons[SECTIONS[i][0]] = tabs.get_child(i)
	_list = Kit.column(4)
	_scroll = Kit.scroll(_list)
	_room = _list.get_parent()
	box.add_child(_scroll)
	_said = UiStyle.label("Нажмите на что-нибудь", UiStyle.MUTED)
	_said.clip_text = true
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_said)
	box.add_child(Kit.button("Закрыть", close))
	_choices.stepped.connect(_stepped)
	get_parent().resized.connect(fit)
	show_section(section)


## Shows tab `key` (see SECTIONS).
func show_section(key: String) -> void:
	section = key
	for k: String in _tab_buttons:
		TabRow.light(_tab_buttons[k], k == key)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_chosen = null
	_chips = null
	_meter = null
	_choices.clear()
	_asks.disarm()
	match key:
		"buttons":
			_buttons_page()
		"rows":
			_rows_page()
		"slots":
			_slots_page()
		"fields":
			_fields_page()
		"lists":
			_lists_page()
		"look":
			_look_page()
	_scroll.scroll_vertical = 0
	fit()


func close() -> void:
	closed.emit()
	queue_free()


func back() -> void:
	close()


## Tells under the page what the last tap did: `what` (a phrase) was pressed.
func say(what: String) -> void:
	_said.text = Lang.f("Нажато: %s", [what])


# --- The pages --------------------------------------------------------------------


func _buttons_page() -> void:
	_caption("Кнопки окна: обычная, главная, недоступная")
	var row := _flow()
	row.add_child(Kit.button("Обычная", say.bind("Обычная")))
	var main := Kit.accent_button("Главная", say.bind("Главная"))
	row.add_child(main)
	var off := Kit.button("Недоступна", say.bind("Недоступна"))
	off.disabled = true
	row.add_child(off)
	_caption("Опасное — в два касания (первое красит красным), удачное горит зелёным")
	row = _flow()
	var bin := Kit.button("Удалить")
	_asks.guard(bin, func() -> void:
		say("Удалить")
		_green(bin))
	row.add_child(bin)
	var copy := Kit.button("Скопировать")
	copy.pressed.connect(func() -> void:
		say("Скопировать")
		_green(copy))
	row.add_child(copy)
	_caption("Маленькие кнопки и кнопки со значком")
	row = _flow()
	row.add_child(TabRow.small_button("Выбор", say.bind("Выбор")))
	for icon: String in ["sort_kind", "chest", "lock", "trash", "all"]:
		row.add_child(TabRow.icon_button(UiStyle.icon(icon), icon, say.bind(icon)))
	row.add_child(Kit.icon_button("dice", "dice", say.bind("dice")))
	_caption("Сдвоенные кнопки")
	row = _flow()
	row.add_child(TabRow.split([[UiStyle.icon("prev"), "Назад", say.bind("Назад")],
		["Середина", "", say.bind("Середина")], [UiStyle.icon("next"), "Вперёд", say.bind("Вперёд")]]))
	var two := TabRow.split([["взять", "", say.bind("взять")], ["поставить", "", say.bind("поставить")]])
	UiStyle.accent(two.get_child(0))
	row.add_child(two)
	_caption("Вкладки: одной группой, выбранная горит")
	row = _flow()
	var tabs := TabRow.tabs([["Один", "", _nothing], ["Два", "", _nothing], ["Три", "", _nothing]], BUTTON_H)
	for b: Button in tabs.get_children():
		b.pressed.connect(_pick_tab.bind(tabs, b))
	TabRow.light(tabs.get_child(0), true)
	row.add_child(tabs)
	_caption("Блок в углу окна: ряд и широкая кнопка")
	row = _flow()
	var top := TabRow.split([["MAX", "", say.bind("MAX")], ["×5", "", say.bind("×5")]])
	var block := TabRow.block(top, ["сделать", "", say.bind("сделать")], TabRow.WIDE)
	UiStyle.accent(block.get_child(1))
	row.add_child(block)
	_caption("Кнопки цвета земли")
	row = _flow()
	for i in UiStyle.LAND_COLORS.size():
		var land := Kit.button(str(i + 1), say.bind(str(i + 1)))
		land.custom_minimum_size.x = BUTTON_H
		UiStyle.tint(land, UiStyle.LAND_COLORS[i])
		row.add_child(land)
	_caption("Кнопки экрана игры: действие, прыжок, прозрачная")
	row = _flow()
	var act := Kit.button("Собрать", say.bind("Собрать"))
	Kit.octagon_look(act, UiStyle.ACCENT, UiStyle.ACCENT_DARK, UiStyle.DARK_INK)
	act.custom_minimum_size = Vector2(64, 48)
	row.add_child(act)
	var jump := Kit.button("", say.bind("Прыжок"))
	jump.icon = UiStyle.icon("up")
	jump.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.octagon_look(jump, UiStyle.BUTTON, UiStyle.BUTTON_SHADE, UiStyle.INK)
	jump.custom_minimum_size = Vector2(48, 48)
	row.add_child(jump)
	var clear := Kit.button("+1", say.bind("+1"))
	Kit.see_through(clear)
	clear.custom_minimum_size = Vector2(BUTTON_H, BUTTON_H)
	row.add_child(clear)


func _rows_page() -> void:
	_caption("Строка настройки: стрелки листают значения")
	_choice_row("Размер", ["мелкий", "обычный", "крупный"], 1)
	_choice_row("Звук", ["выкл", "вкл"], 1)
	_choice_row("Время суток", ["ночь", "утро", "день", "вечер"], 2)
	# One that cannot change now: faded, its arrows off.
	_choice_row("Погода", ["сама", "ясно", "дождь"], 0, {"works": func() -> bool: return false})
	_choices.refresh()
	_choices.set_focus(0)
	_caption("Строка-действие и действие в два касания")
	_list.add_child(Kit.button("Перейти в тестовый мир", say.bind("Перейти в тестовый мир"), ROW_WIDTH, ARROW))
	_list.add_child(_asks.guard(Kit.button("Очистить все данные", Callable(), ROW_WIDTH, ARROW),
		say.bind("Очистить все данные")))
	_caption("Пояснение")
	var note := Kit.note("Маркеров нет: поставьте их на карте (M).", ROW_WIDTH)
	note.custom_minimum_size.y = ARROW
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_list.add_child(note)
	_caption("Место: цвет, имя, кнопка")
	for i in 2:
		var place := Kit.row(6)
		place.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
		_list.add_child(place)
		place.add_child(Kit.swatch(UiStyle.LAND_COLORS[i]))
		var where := UiStyle.label(Lang.f("Маркер %d · X %d, Y %d", [i + 1, 12 * (i + 1), -40 + 7 * i]))
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		where.clip_text = true
		place.add_child(where)
		place.add_child(Kit.button("Перейти", say.bind("Перейти"), 0, ARROW))


func _slots_page() -> void:
	var things := _sample_items()
	_caption("Ячейки: пустая, с вещью, с числом, рука, клавиша")
	var row := _flow()
	_slot(row, "")
	for i in mini(4, things.size()):
		var s := _slot(row, things[i])
		match i:
			1:
				s.number = "12"
			2:
				s.tag = "Л"
			3:
				s.key = "3"
	_caption("Лента ячеек со стрелками, как хотбар и палитры строительства и земледелия")
	_add_strip(things)
	_caption("Полоска: свет горит, еда свежая, сумка полна")
	row = _flow()
	var strips := [[0.8, Color(0, 0, 0, 0)], [0.15, Color(0, 0, 0, 0)], [0.6, UiStyle.GOOD], [1.0, UiStyle.DANGER]]
	for i in strips.size():
		var s := _slot(row, things[i % things.size()] if not things.is_empty() else "")
		s.fill = strips[i][0]
		s.fill_color = strips[i][1]
	_caption("Качество: плохое, простое, обычное, хорошее, отличное")
	row = _flow()
	for g in HotbarSlot.GRADE_TINTS.size():
		var s := _slot(row, things[0] if not things.is_empty() else "")
		s.grade = g
	_caption("Бледная: вещью нельзя пользоваться (нечем стрелять)")
	row = _flow()
	var pale := _slot(row, things[things.size() - 1] if not things.is_empty() else "")
	pale.inactive = true
	_caption("Что за вещь: чипы выбранной ячейки")
	_chips = FactChips.new()
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_chips)
	if not things.is_empty():
		_chips.show_groups(FactChips.item_groups(things[0], 1))
	_caption("Вес сумки: красный при перегрузе")
	row = _flow()
	_meter = Control.new()
	_meter.custom_minimum_size = Vector2(UiStyle.weight_width(LIMIT), 16)
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meter.draw.connect(_draw_meter)
	row.add_child(_meter)
	row.add_child(TabRow.split([["-5", "", _add_weight.bind(-5.0)], ["+5", "", _add_weight.bind(5.0)]]))
	_caption("Виды вещей столбцом со стрелками")
	row = _flow()
	var kinds := IconTabs.new()
	var have := {}
	for k: String in Items.CATEGORIES:
		have[k] = true
	var k3: Array = IconTabs.kinds(have)
	kinds.set_tabs(k3[0], k3[1], k3[2])
	kinds.picked.connect(func(key: String) -> void: say(k3[2].get(key, key)))
	row.add_child(kinds)


func _fields_page() -> void:
	_caption("Поле ввода: что набрано, видно внизу")
	var who := _field("Имя", 24)
	who.text_changed.connect(func(t: String) -> void: _said.text = Lang.f("Введено: %s", [t]))
	_caption("Поле с подписью, как в «Присоединиться»")
	_list.add_child(Kit.caption("Адрес сервера"))
	_field("wss://… или ws://адрес:порт", 0)
	_caption("Пароль")
	var secret := _field("Пароль", 32)
	secret.secret = true
	_caption("Не длиннее восьми букв")
	_field("До 8 букв", 8)
	_caption("Поле и кнопка в ряд")
	var row := Kit.row(6)
	_list.add_child(row)
	var line := Kit.field("ws://адрес:порт")
	row.add_child(line)
	row.add_child(Kit.button("Войти", func() -> void: say(line.text if line.text != "" else "Войти")))


func _lists_page() -> void:
	_caption("Список прокручивается пальцем и полосой")
	var rows := Kit.column(4)
	var inner := Kit.scroll(rows)
	inner.custom_minimum_size = Vector2(0, 140)
	_list.add_child(inner)
	UiStyle.bar_room(rows.get_parent(), true, inner)
	for i in 20:
		var label := Lang.f("Строка %d", [i + 1])
		var b := Kit.button(label, say.bind(label))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(b)
	_caption("Столбец кнопок со стрелками")
	var column := ScrollColumn.new(28)
	var buttons := []
	var names: Array = UiStyle.ICONS.keys().slice(0, 12)
	for n: String in names:
		var b := TabRow.icon_button(UiStyle.icon(n), n, say.bind(n))
		b.custom_minimum_size = Vector2(28, 26)
		buttons.append(b)
	column.set_items(buttons)
	var row := _flow()
	row.add_child(column)


func _look_page() -> void:
	_caption("Цвета текста")
	var row := _flow()
	for c: Array in [["Основной", UiStyle.INK], ["Приглушённый", UiStyle.MUTED], ["Акцент", UiStyle.ACCENT],
			["Опасность", UiStyle.DANGER], ["Удачно", UiStyle.GOOD], ["Холод", UiStyle.COLD], ["Команда", UiStyle.TEAM]]:
		row.add_child(UiStyle.label(c[0], c[1]))
	_caption("Крупный шрифт заголовков")
	var big := UiStyle.label("Заголовок", UiStyle.ACCENT)
	big.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	_list.add_child(big)
	_caption("Панель, ямка с текстом, поле")
	row = _flow()
	for b: Array in [["Панель", UiStyle.panel(UiStyle.TIGHT)], ["Ямка", UiStyle.well()], ["Поле", UiStyle.field()],
			["Ячейка", UiStyle.slot(true)]]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", b[1])
		var l := UiStyle.label(b[0])
		if b[0] == "Ячейка":
			p.custom_minimum_size = Vector2(40, 40)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
	_caption("Значки (касание называет значок)")
	row = _flow()
	row.add_theme_constant_override("h_separation", 2)
	row.add_theme_constant_override("v_separation", 2)
	for n: String in UiStyle.ICONS:
		row.add_child(TabRow.icon_button(UiStyle.icon(n), n, say.bind(n)))


# --- Pieces -----------------------------------------------------------------------


## A muted line naming what follows.
func _caption(text: String) -> void:
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _list.get_child_count() > 0:
		# A little room after the elements above.
		var gap := Control.new()
		gap.custom_minimum_size.y = 6
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(gap)
	_list.add_child(l)


## A row whose elements go on the next line when they do not fit.
func _flow() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(row)
	return row


## Lights `b` green for a moment: what it did worked.
func _green(b: Button) -> void:
	UiStyle.succeed(b, true)
	get_tree().create_timer(GREEN_TIME, true).timeout.connect(func() -> void:
		if is_instance_valid(b):
			UiStyle.succeed(b, false))


func _nothing() -> void:
	pass


## Lights tab `b` of row `tabs`, the others not.
func _pick_tab(tabs: HBoxContainer, b: Button) -> void:
	for t: Button in tabs.get_children():
		TabRow.light(t, t == b)
	say(b.text)


## A settings' row of the kit (ChoiceRows): `title` over `values`, `at` chosen.
func _choice_row(title: String, values: Array, at: int, opts := {}) -> void:
	_picked[title] = at
	var o := {"wrap": true}
	o.merge(opts)
	_choices.add(_list, title, values, func() -> int: return _picked[title],
		func(i: int) -> void: _picked[title] = i, o)


## A row was stepped: tells the value shown.
func _stepped(index: int) -> void:
	var r: Dictionary = _choices.rows[index]
	say(r.label.text)


## A cell with the picture of thing `id` ("" for none) in `parent`; a tap chooses it and
## shows what the thing is under the cells.
## A strip of the kit (SlotStrip) of all `things`, three cells shown: the arrows and a
## finger move them along.
func _add_strip(things: Array) -> void:
	var strip := SlotStrip.new()
	_list.add_child(strip)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var cells: Array[HotbarSlot] = []
	for i in 3:
		var c := HotbarSlot.new(SlotStrip.SLOT)
		c.on_release = true
		c.pressed.connect(func() -> void:
			var at: int = strip.first + i
			say(Items.title(things[at]) if at < things.size() else "пусто"))
		strip.cells.add_child(c)
		cells.append(c)
	var show := func() -> void:
		for i in cells.size():
			var at: int = strip.first + i
			var id: String = things[at] if at < things.size() else ""
			cells[i].texture = ItemIcons.of_item(id) if id != "" else null
			cells[i].key = str(at + 1)
	strip.scrolled.connect(show)
	strip.scrolled.connect(func() -> void: say(Lang.f("с %d", [strip.first + 1])))
	strip.set_counts(things.size(), 3)
	show.call()


func _slot(parent: Node, id: String) -> HotbarSlot:
	var s := HotbarSlot.new(40)
	if id != "":
		s.texture = ItemIcons.of_item(id)
	s.pressed.connect(_choose.bind(s, id))
	parent.add_child(s)
	return s


func _choose(s: HotbarSlot, id: String) -> void:
	if _chosen != null and is_instance_valid(_chosen):
		_chosen.selected = false
	_chosen = s
	s.selected = true
	if id == "":
		say("пусто")
		return
	say(Items.title(id))
	if _chips != null:
		_chips.show_groups(FactChips.item_groups(id, 1))


## A thing of each kind there is (Items.CATEGORIES), the first loaded of each.
func _sample_items() -> Array:
	var out := []
	for k: String in Items.CATEGORIES:
		var id := Items.of_category(k)
		if id != "":
			out.append(id)
	return out


## A text field in the list: `hint` while empty, at most `most` letters (0: any).
func _field(hint: String, most: int) -> LineEdit:
	var f := Kit.field(hint, 0, most)
	_list.add_child(f)
	return f


func _draw_meter() -> void:
	UiStyle.draw_weight(_meter, Rect2(Vector2.ZERO, _meter.size), _weight, LIMIT)


func _add_weight(kg: float) -> void:
	_weight = clampf(_weight + kg, 0.0, LIMIT * 2.0)
	say(Lang.f("%d / %d кг", [roundi(_weight), LIMIT]))
	if _meter != null:
		_meter.queue_redraw()


# --- Window -----------------------------------------------------------------------


## The panel's page as tall as the screen lets it.
func layout(screen: Vector2) -> void:
	var width := minf(screen.x - 2 * MARGIN - UiStyle.PAD.x - UiStyle.PAD.z, MOST_WIDTH)
	width = maxf(width, ROW_WIDTH + 2 * UiStyle.BAR_GAP + UiStyle.SCROLL_BAR)
	_scroll.custom_minimum_size = Vector2(width, 0)
	UiStyle.bar_room(_room, true, _scroll)
	panel.reset_size()
	var rest := panel.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(screen.y - 2 * MARGIN - rest, 80.0, MOST_HEIGHT)
