extends Control
## «Витрина интерфейса»: every kind of element the game's windows are made of, on tabs,
## each working when tapped (the user's ask 2026-11-11), so a change to a shared piece
## (UiStyle, TabRow, HotbarSlot, FactChips, IconTabs, ScrollColumn, the settings' rows) is
## seen at once in all its looks, on a phone too. Opened from «Тестирование» →
## «Отладка» (SettingsMenu), over a shade of the screen; «Закрыть» or Escape closes it.
## The line under the tabs' page tells what the last tap did. Nothing here changes the
## game: the rows' values, the weight and the slots' choice live in the window only.
## `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const IconTabs := preload("res://src/client/ui/icon_tabs.gd")
const ScrollColumn := preload("res://src/client/ui/scroll_column.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")
const TextField := preload("res://src/client/ui/text_field.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## The tabs: key and name.
const SECTIONS := [["buttons", "Кнопки"], ["rows", "Строки"], ["slots", "Ячейки"],
	["fields", "Поля"], ["lists", "Списки"], ["look", "Вид"]]
## Room round the panel, in UI pixels.
const MARGIN := 8
## The widest and tallest the panel's page grows on a big screen.
const MOST_WIDTH := 480
const MOST_HEIGHT := 560
## The height of the window's buttons and tabs (as the settings').
const BUTTON_H := 30
## The settings' rows: a name, arrows and the value between (SettingsMenu).
const NAME_WIDTH := 150
const VALUE_WIDTH := 112
const ARROW := 32
const ROW_WIDTH := NAME_WIDTH + VALUE_WIDTH + 2 * ARROW + 3 * 2
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)
## How long a two-tap button waits for its second tap, and a green one stays green.
const CONFIRM_WAIT := 4.0
const GREEN_TIME := 1.5
## The bag's limit the weight meter shows, in kg.
const LIMIT := 40

signal closed

var game
## The tab shown.
var section := "buttons"
var _panel: PanelContainer
var _tab_buttons := {}
var _scroll: ScrollContainer
var _room: MarginContainer
var _list: VBoxContainer
var _said: Label
## The settings' rows of the «Строки» tab: their values and the index chosen, by name.
var _choices := {}
## The weight on the meter of the «Ячейки» tab, and the meter.
var _weight := 25.0
var _meter: Control
## The slot chosen on the «Ячейки» tab and the chips that tell about its thing.
var _chosen: HotbarSlot = null
var _chips: FactChips


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var title := UiStyle.label("Витрина интерфейса", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var parts := []
	for s: Array in SECTIONS:
		parts.append([s[1], "", show_section.bind(s[0])])
	var tabs := TabRow.tabs(parts, BUTTON_H)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	for i in SECTIONS.size():
		_tab_buttons[SECTIONS[i][0]] = tabs.get_child(i)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room = UiStyle.inset(_list)
	_scroll.add_child(_room)
	DragScroll.attach(_scroll)
	_said = UiStyle.label("Нажмите на что-нибудь", UiStyle.MUTED)
	_said.clip_text = true
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_said)
	box.add_child(_button("Закрыть", close))
	get_parent().resized.connect(_fit)
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
	_fit()


func close() -> void:
	closed.emit()
	queue_free()


## Tells under the page what the last tap did: `what` (a phrase) was pressed.
func say(what: String) -> void:
	_said.text = Lang.f("Нажато: %s", [what])


# --- The pages --------------------------------------------------------------------


func _buttons_page() -> void:
	_caption("Кнопки окна: обычная, главная, недоступная")
	var row := _flow()
	row.add_child(_button("Обычная", say.bind("Обычная")))
	var main := _button("Главная", say.bind("Главная"))
	UiStyle.accent(main)
	row.add_child(main)
	var off := _button("Недоступна", say.bind("Недоступна"))
	off.disabled = true
	row.add_child(off)
	_caption("Опасное — в два касания (первое красит красным), удачное горит зелёным")
	row = _flow()
	var bin := _button("Удалить", Callable())
	bin.pressed.connect(_confirm.bind(bin, func() -> void:
		say("Удалить")
		_green(bin)))
	row.add_child(bin)
	var copy := _button("Скопировать", Callable())
	copy.pressed.connect(func() -> void:
		say("Скопировать")
		_green(copy))
	row.add_child(copy)
	_caption("Маленькие кнопки и кнопки со значком")
	row = _flow()
	row.add_child(TabRow.small_button("Выбор", say.bind("Выбор")))
	for icon: String in ["sort_kind", "chest", "lock", "trash", "all"]:
		row.add_child(TabRow.icon_button(UiStyle.icon(icon), icon, say.bind(icon)))
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
		var land := _button(str(i + 1), say.bind(str(i + 1)))
		land.custom_minimum_size.x = BUTTON_H
		UiStyle.tint(land, UiStyle.LAND_COLORS[i])
		row.add_child(land)
	_caption("Кнопки экрана игры: действие, прыжок, прозрачная")
	row = _flow()
	var act := _button("Собрать", say.bind("Собрать"))
	_octagon(act, UiStyle.ACCENT, UiStyle.ACCENT_DARK, UiStyle.DARK_INK)
	act.custom_minimum_size = Vector2(64, 48)
	row.add_child(act)
	var jump := _button("", say.bind("Прыжок"))
	jump.icon = UiStyle.icon("up")
	jump.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_octagon(jump, UiStyle.BUTTON, UiStyle.BUTTON_SHADE, UiStyle.INK)
	jump.custom_minimum_size = Vector2(48, 48)
	row.add_child(jump)
	var clear := _button("+1", say.bind("+1"))
	for state in ["normal", "hover", "disabled", "focus"]:
		clear.add_theme_stylebox_override(state, UiStyle.frame())
	for state in ["pressed", "hover_pressed"]:
		clear.add_theme_stylebox_override(state, UiStyle.frame(true))
	clear.custom_minimum_size = Vector2(BUTTON_H, BUTTON_H)
	row.add_child(clear)


func _rows_page() -> void:
	_caption("Строка настройки: стрелки листают значения")
	_choice_row("Размер", ["мелкий", "обычный", "крупный"], 1)
	_choice_row("Звук", ["выкл", "вкл"], 1)
	_choice_row("Время суток", ["ночь", "утро", "день", "вечер"], 2)
	var off := _choice_row("Погода", ["сама", "ясно", "дождь"], 0)
	off.modulate.a = 0.4
	for c in off.get_children():
		if c is Button:
			c.disabled = true
	_caption("Строка-действие и действие в два касания")
	var go := _button("Перейти в тестовый мир", say.bind("Перейти в тестовый мир"))
	go.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	_list.add_child(go)
	var wipe := _button("Очистить все данные", Callable())
	wipe.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	wipe.pressed.connect(_confirm.bind(wipe, say.bind("Очистить все данные")))
	_list.add_child(wipe)
	_caption("Пояснение")
	var note := UiStyle.label("Маркеров нет: поставьте их на карте (M).", UiStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_list.add_child(note)
	_caption("Место: цвет, имя, кнопка")
	for i in 2:
		var place := HBoxContainer.new()
		place.add_theme_constant_override("separation", 6)
		place.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
		_list.add_child(place)
		var swatch := ColorRect.new()
		swatch.color = UiStyle.LAND_COLORS[i]
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		place.add_child(swatch)
		var where := UiStyle.label(Lang.f("Маркер %d · X %d, Y %d", [i + 1, 12 * (i + 1), -40 + 7 * i]))
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		where.clip_text = true
		place.add_child(where)
		var b := _button("Перейти", say.bind("Перейти"))
		b.custom_minimum_size.y = ARROW
		place.add_child(b)


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
	_caption("Пароль")
	var secret := _field("Пароль", 32)
	secret.secret = true
	_caption("Не длиннее восьми букв")
	_field("До 8 букв", 8)
	_caption("Поле и кнопка в ряд")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_list.add_child(row)
	var line := LineEdit.new()
	line.placeholder_text = "ws://адрес:порт"
	line.custom_minimum_size = Vector2(0, BUTTON_H - 4)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TextField.fit(line)
	row.add_child(line)
	row.add_child(_button("Войти", func() -> void: say(line.text if line.text != "" else "Войти")))


func _lists_page() -> void:
	_caption("Список прокручивается пальцем и полосой")
	var inner := ScrollContainer.new()
	inner.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.custom_minimum_size = Vector2(0, 140)
	_list.add_child(inner)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var room := UiStyle.inset(rows)
	inner.add_child(room)
	UiStyle.bar_room(room, true, inner)
	DragScroll.attach(inner)
	for i in 20:
		var label := Lang.f("Строка %d", [i + 1])
		var b := _button(label, say.bind(label))
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


## A window's button doing `call` (none when it is not valid).
func _button(text: String, call: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, BUTTON_H)
	if call.is_valid():
		b.pressed.connect(call)
	return b


## The first tap turns `b` red for a while, the second does `action` (SettingsMenu._confirm).
func _confirm(b: Button, action: Callable) -> void:
	if not b.get_meta("armed", false):
		b.set_meta("armed", true)
		UiStyle.arm(b, true)
		get_tree().create_timer(CONFIRM_WAIT, true).timeout.connect(_unarm.bind(b))
		return
	_unarm(b)
	action.call()


func _unarm(b: Button) -> void:
	if is_instance_valid(b) and b.get_meta("armed", false):
		b.set_meta("armed", false)
		UiStyle.arm(b, false)


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


## The look of a big touch button of the game's screen (Hud._octagon_look).
func _octagon(b: Button, fill: Color, shade: Color, ink: Color) -> void:
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)


## A settings' row (SettingsMenu._add_row): `title`, ◀ value ▶ over `values`, `at` chosen.
func _choice_row(title: String, values: Array, at: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_list.add_child(row)
	var label := UiStyle.label(title)
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var value := UiStyle.label(values[at])
	value.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value.clip_text = true
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_choices[title] = at
	for dir in [-1, 1]:
		var b := Button.new()
		b.icon = UiStyle.icon("prev" if dir < 0 else "next")
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(ARROW, ARROW)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func() -> void:
			var i: int = posmod(int(_choices[title]) + dir, values.size())
			_choices[title] = i
			value.text = values[i]
			say(values[i]))
		row.add_child(b)
		if dir < 0:
			row.add_child(value)
	return row


## A cell with the picture of thing `id` ("" for none) in `parent`; a tap chooses it and
## shows what the thing is under the cells.
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


## A text field in the list: `hint` while empty, at most `most` letters.
func _field(hint: String, most: int) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = hint
	f.max_length = most
	f.custom_minimum_size = Vector2(0, BUTTON_H - 4)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TextField.fit(f)
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


## The panel in the middle of the screen, its page as tall as the screen lets it.
func _fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	var width := minf(screen.x - 2 * MARGIN - UiStyle.PAD.x - UiStyle.PAD.z, MOST_WIDTH)
	width = maxf(width, ROW_WIDTH + 2 * UiStyle.BAR_GAP + UiStyle.SCROLL_BAR)
	_scroll.custom_minimum_size = Vector2(width, 0)
	UiStyle.bar_room(_room, true, _scroll)
	_panel.reset_size()
	var rest := _panel.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(screen.y - 2 * MARGIN - rest, 80.0, MOST_HEIGHT)
	_panel.reset_size()
	var s := _panel.size
	_panel.position = Vector2(floorf((screen.x - s.x) * 0.5), maxf(MARGIN, floorf((screen.y - s.y) * 0.5)))
	move_to_front()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
