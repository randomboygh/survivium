extends Control
## The first screen: the world to make. The seed (typed in or rolled with the dice),
## a kind of world that sets the rest at once, and the settings of WorldGen one by one
## as rows "name ‹ value ›" like the settings window, with a map of the land around
## the spawn drawn a few rows a frame as the choice changes. The mods of the new world
## are a page of their own, opened from the row «Моды», with a page per mod of several
## bundles, each left with "Назад" (or Escape). "Создать мир" (or Enter) keeps the choice in Settings and starts the world,
## "Назад" (or Escape) leaves it.
## It covers the whole screen over a shade of the world behind, the panel in the
## middle. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Mods := preload("res://src/shared/content/mods.gd")

const NAME_WIDTH := 112
## The names of the mods are longer than the settings' and have the room the map leaves.
const MOD_NAME_WIDTH := 168
const VALUE_WIDTH := 84
const ARROW := 32
## Room for the scroll bar beside the rows.
const BAR_ROOM := UiStyle.SCROLL_BAR + 4
## The map: pixels each way and cells per pixel.
const MAP := 128
const MAP_STEP := 32
## Time the map may take a frame, in microseconds.
const MAP_BUDGET_US := 4000
const LEVELS := ["мало", "средне", "много"]
## Kinds of world and the settings each picks: size, water, mountains, rivers, biomes
## (caves are set apart from the kind).
const KINDS := [
	["Обычный", [1, 1, 1, 1, 1]],
	["Материк", [2, 1, 1, 1, 1]],
	["Острова", [0, 2, 1, 0, 1]],
	["Горы", [1, 1, 2, 1, 1]],
	["Равнины", [2, 0, 0, 2, 2]],
]
const OPTIONS := ["size", "water", "mountains", "rivers", "biomes"]
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)

signal done
signal cancelled

var game
var _rows := []
var _focus := 0
## The page of rows shown: "world" (the seed and the land), "mods" or "mod:<id>" (its bundles).
var _page := "world"
var _panel: PanelContainer
var _box: BoxContainer
var _list: VBoxContainer
## The rows scroll when the panel is taller than the screen (a phone in landscape).
var _scroll: ScrollContainer
var _seed: LineEdit
var _map: TextureRect
var _image: Image
var _texture: ImageTexture
## The world the map is drawn from and the next row to draw.
var _gen: WorldGen
var _map_row := 0
var _start_button: Button
var _shown := false


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)
	var title := UiStyle.label("Новый мир", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	_box = BoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	outer.add_child(_box)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.slot())
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(frame)
	_image = Image.create_empty(MAP, MAP, false, Image.FORMAT_RGB8)
	_image.fill(Color(0.1, 0.1, 0.12))
	_texture = ImageTexture.create_from_image(_image)
	_map = TextureRect.new()
	_map.texture = _texture
	_map.custom_minimum_size = Vector2(MAP, MAP)
	_map.stretch_mode = TextureRect.STRETCH_KEEP
	_map.tooltip_text = "Земля вокруг места старта, %d клеток в ширину" % (MAP * MAP_STEP)
	frame.add_child(_map)
	var marker := Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func() -> void:
		var mid := (Vector2(MAP, MAP) * 0.5).floor()
		marker.draw_rect(Rect2(mid - Vector2(2, 2), Vector2(5, 5)), UiStyle.DARK_INK)
		marker.draw_rect(Rect2(mid - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT))
	_map.add_child(marker)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	_build_rows()
	_set_focus(1)
	var start := Button.new()
	start.text = "Создать мир"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(0, 36)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		start.add_theme_stylebox_override(state, UiStyle.button(state, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		start.add_theme_color_override(c, UiStyle.DARK_INK)
	start.pressed.connect(_start)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	outer.add_child(buttons)
	var back := Button.new()
	back.text = "Назад"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(96, 36)
	back.pressed.connect(_back)
	buttons.add_child(back)
	buttons.add_child(start)
	_start_button = start
	get_parent().resized.connect(_fit)
	_fit()


## Fills the list with the rows of `_page`: the seed, the kind of world and the land's
## settings with the row «Моды» last, or the mods, or the bundles of one mod.
func _build_rows() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()
	var s = game.settings
	if _page != "world":
		_mod_rows(s)
		_refresh()
		return
	_seed_row()
	_add_row("Вид мира", KINDS.map(func(k: Array) -> String: return k[0]) + ["Свой"],
		_kind, func(i: int) -> void:
			if i < KINDS.size():
				for j in OPTIONS.size():
					s.values["world_" + OPTIONS[j]] = KINDS[i][1][j]
				s.save())
	_add_row("Материки", ["малые", "средние", "огромные"], _getter("size"), _setter("size"))
	_add_row("Вода", LEVELS, _getter("water"), _setter("water"))
	_add_row("Горы", LEVELS, _getter("mountains"), _setter("mountains"))
	_add_row("Реки и озёра", LEVELS, _getter("rivers"), _setter("rivers"))
	_add_row("Биомы", ["мелкие", "обычные", "крупные"], _getter("biomes"), _setter("biomes"))
	_add_row("Пещеры", LEVELS, _getter("caves"), _setter("caves"))
	_mods_row()
	_refresh()


## The rows of the mods page, one per mod besides the base game («выкл», «вкл» or how
## many of its bundles are on, with a button to its page when it has several), or of a
## mod's page, one per bundle (under one left out for want of another, which, and what
## that one wants in turn: _why_line). A world is made with what is switched on and keeps
## it (a saved world's set cannot change here).
func _mod_rows(s) -> void:
	var state: Dictionary = Mods.resolve(s.world_mods_on())
	var on: Array = state.order
	if _page == "mods":
		for mod: String in Mods.available():
			if mod == "core":
				continue
			var m := mod
			var mine: Array = Mods.bundles(mod)
			var lit: int = mine.filter(func(b: String) -> bool: return b in on).size()
			_add_row(Mods.mod_title(mod), ["выкл", "вкл"],
				func() -> int: return 1 if lit == mine.size() else 0,
				func(i: int) -> void: s.set_world_mod(m, i == 1), MOD_NAME_WIDTH,
				"%d из %d" % [lit, mine.size()] if lit > 0 and lit < mine.size() else "",
				_show_page.bind("mod:" + mod) if mine.size() > 1 else Callable())
		return
	var mod := _page.trim_prefix("mod:")
	_header(Mods.mod_title(mod))
	# The bundles by their names, so the player reads a list, not the folders' order.
	var bundles: Array = Mods.bundles(mod).duplicate()
	bundles.sort_custom(func(a: String, b: String) -> bool: return Mods.title(a).naturalnocasecmp_to(Mods.title(b)) < 0)
	for bundle: String in bundles:
		var b := bundle
		_add_row(Mods.title(bundle), ["выкл", "вкл"],
			func() -> int: return 1 if b in on else 0,
			func(i: int) -> void: s.set_world_mod(b, i == 1), MOD_NAME_WIDTH)
		_why_line(Mods.why(bundle, state.dropped))


## A line under the row of a bundle left out for want of another: what it needs, and what
## that one needs in turn, to the one switched off («нужен «Дерево», а ему «Волокно»»).
func _why_line(chain: Array) -> void:
	if chain.is_empty():
		return
	var parts: PackedStringArray = []
	for need: String in chain:
		parts.append(("нужен «%s»" if parts.is_empty() else "а ему «%s»") % Mods.title(need))
	var label := UiStyle.label(", ".join(parts), UiStyle.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Indented, and further from the next row than from its own.
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("margin_left", 12)
	box.add_theme_constant_override("margin_bottom", 10)
	box.add_child(label)
	_list.add_child(box)


## A line over the rows of a page: the name of what they belong to.
func _header(text: String) -> void:
	var label := UiStyle.label(text, UiStyle.ACCENT)
	label.custom_minimum_size = Vector2(0, ARROW)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_list.add_child(label)


## Shows page `page` (see _page) and fits the panel to its rows.
func _show_page(page: String) -> void:
	_page = page
	_build_rows()
	_set_focus(1 if _page == "world" else 0)
	if is_inside_tree():
		_fit()


## "Назад": a mod's page goes back to the mods, the mods page to the world's rows, the
## world's rows leave the screen.
func _back() -> void:
	if _page.begins_with("mod:"):
		_show_page("mods")
	elif _page == "mods":
		_show_page("world")
	else:
		cancelled.emit()


func _getter(option: String) -> Callable:
	return func() -> int: return game.settings.values["world_" + option]


func _setter(option: String) -> Callable:
	return func(i: int) -> void:
		game.settings.values["world_" + option] = i
		game.settings.save()


## The kind of world the settings match, or "Свой" after the last kind.
func _kind() -> int:
	var now: Array = OPTIONS.map(func(o: String) -> int: return game.settings.values["world_" + o])
	for i in KINDS.size():
		if KINDS[i][1] == now:
			return i
	return KINDS.size()


func _seed_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_list.add_child(row)
	var label := UiStyle.label("Зерно")
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_seed = LineEdit.new()
	_seed.custom_minimum_size = Vector2(VALUE_WIDTH + ARROW + 2, ARROW)
	_seed.max_length = 10
	_seed.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_seed.text = str(game.settings.values.world_seed)
	_seed.text_changed.connect(func(t: String) -> void:
		var digits := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != t:
			_seed.text = digits
			_seed.caret_column = digits.length()
		if not digits.is_empty():
			game.settings.values.world_seed = int(digits)
			game.settings.save()
			_restart_map())
	_seed.text_submitted.connect(func(_t: String) -> void: _seed.release_focus())
	row.add_child(_seed)
	var dice := Button.new()
	dice.icon = UiStyle.icon("dice")
	dice.tooltip_text = "Случайное зерно"
	dice.focus_mode = Control.FOCUS_NONE
	dice.custom_minimum_size = Vector2(ARROW, ARROW)
	dice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice.pressed.connect(func() -> void:
		var v := randi_range(1, 999999999)
		_seed.text = str(v)
		game.settings.values.world_seed = v
		game.settings.save()
		_restart_map())
	row.add_child(dice)
	_rows.append({"name": label, "values": [], "get": Callable(), "set": Callable(), "label": null})


## The row «Моды»: how many of the mods besides the base game are on, and an arrow
## that opens their page.
func _mods_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_list.add_child(row)
	var label := UiStyle.label("Моды")
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var index := _rows.size()
	var value := UiStyle.label()
	value.custom_minimum_size = Vector2(VALUE_WIDTH + ARROW + 2, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var all: int = Mods.all().filter(func(b: String) -> bool: return Mods.mod_of(b) != "core").size()
	var on: int = game.settings.world_mods().filter(func(b: String) -> bool: return Mods.mod_of(b) != "core").size()
	value.text = "%d из %d" % [on, all] if on < all else "все"
	row.add_child(value)
	var b := Button.new()
	b.icon = UiStyle.icon("next")
	b.tooltip_text = "Выбрать моды нового мира"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ARROW, ARROW)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func() -> void:
		_set_focus(index)
		_show_page("mods"))
	row.add_child(b)
	_rows.append({"name": label, "values": [], "get": Callable(), "set": Callable(), "label": null,
		"open": _show_page.bind("mods")})


## A row "name ‹ value ›" of `values` read by `getter` and set by `setter`. A mod's row:
## `show` stands in for the value's text ("2 из 6", "нужен «Дуб»"), `open` is what its
## extra button does (its bundles' page), and its arrows go straight to the first or the
## last value (off, on) instead of round.
func _add_row(name: String, values: Array, getter: Callable, setter: Callable, name_width := NAME_WIDTH,
		show := "", open := Callable()) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_list.add_child(row)
	var label := UiStyle.label(name)
	label.custom_minimum_size = Vector2(name_width, 0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var index := _rows.size()
	_arrow(row, "prev", index, -1)
	var value := UiStyle.label()
	value.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)
	_arrow(row, "next", index, 1)
	if open.is_valid():
		var b := Button.new()
		b.icon = UiStyle.icon("menu")
		b.tooltip_text = "Что входит"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(ARROW, ARROW)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(open)
		row.add_child(b)
	_rows.append({"name": label, "values": values, "get": getter, "set": setter, "label": value, "show": show,
		"direct": _page != "world"})


func _arrow(parent: Node, icon: String, row: int, dir: int) -> void:
	var b := Button.new()
	b.icon = UiStyle.icon(icon)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ARROW, ARROW)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func() -> void:
		_set_focus(row)
		_step(row, dir))
	parent.add_child(b)


## Picks the next (`dir` = 1) or the previous value of row `i`, wrapping around.
func _step(i: int, dir: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	var r: Dictionary = _rows[i]
	var n: int = r.values.size()
	if n == 0:
		# The row «Моды» opens its page to the right.
		if dir > 0 and r.has("open"):
			r.open.call()
		return
	var cur: int = clampi(r.get.call(), 0, n - 1)
	var next := posmod(cur + dir, n)
	if r.get("direct", false):
		next = 0 if dir < 0 else n - 1
	# "Свой" is what the rows below make, not a choice of its own.
	if _page == "world" and i == 1 and next == KINDS.size():
		next = posmod(next + dir, n)
	r.set.call(next)
	if _page == "world":
		_refresh()
		_restart_map()
	else:
		# What a mod's switch did to the others shows only on rows made anew.
		_build_rows()
		_set_focus(i)
		_fit()


func _refresh() -> void:
	for r in _rows:
		if r.label != null:
			var i: int = r.get.call()
			r.label.text = r.values[clampi(i, 0, r.values.size() - 1)] if r.get("show", "") == "" else r.show


func _set_focus(i: int) -> void:
	if _rows.is_empty():
		# A page with no rows (the mods' page with core alone).
		_focus = 0
		return
	_focus = posmod(i, _rows.size())
	for j in _rows.size():
		_rows[j].name.add_theme_color_override("font_color", UiStyle.ACCENT if j == _focus else UiStyle.INK)
	if _scroll != null and _scroll.is_inside_tree():
		_scroll.ensure_control_visible(_rows[_focus].name)


## Side by side on a wide screen, the map over the rows on a tall one; centred. When the
## panel is taller than the screen the rows scroll, so the buttons stay in sight (every
## mod adds a row).
func _fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	_box.vertical = screen.x < screen.y
	_list.reset_size()
	_scroll.custom_minimum_size = Vector2(_list.size.x + BAR_ROOM, _list.size.y)
	_panel.reset_size()
	var over := _panel.size.y - screen.y
	if over > 0.0:
		_scroll.custom_minimum_size.y = maxf(_list.size.y - over, ARROW * 2)
		_panel.reset_size()
	_panel.position = ((screen - _panel.size) * 0.5).floor()
	move_to_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


func _start() -> void:
	if _seed.text.is_empty():
		_seed.text = str(game.settings.values.world_seed)
	game.settings.save()
	done.emit()


# --- The map ----------------------------------------------------------------------

func _restart_map() -> void:
	_gen = null
	_map_row = 0


func _process(_delta: float) -> void:
	if not _shown:
		# Laid out by now; the browser test taps the button from this line.
		_shown = true
		print("world setup shown: start %s" % _start_button.get_global_rect())
	var t0 := Time.get_ticks_usec()
	if _gen == null:
		_gen = WorldGen.new(game.settings.values.world_seed, 48, game.settings.world_options())
		_map_row = 0
	if _map_row >= MAP:
		return
	var at: Vector3i = _gen.spawn_guess
	while _map_row < MAP and Time.get_ticks_usec() - t0 < MAP_BUDGET_US:
		var lay := _gen.lay_out(at.x - MAP / 2 * MAP_STEP, at.z + (_map_row - MAP / 2) * MAP_STEP, MAP, 1, MAP_STEP)
		for i in MAP:
			_image.set_pixel(i, _map_row, _gen.column_color(lay, i))
		_map_row += 1
	_texture.update(_image)


## Up and down pick a row, left and right change it (right opens the mods from «Моды»),
## Enter makes the world, Escape leaves the mods page or the screen.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				_start()
		KEY_ESCAPE:
			if not event.echo:
				_back()
		KEY_UP, KEY_W:
			_set_focus(_focus - 1)
		KEY_DOWN, KEY_S:
			_set_focus(_focus + 1)
		KEY_LEFT, KEY_A:
			_step(_focus, -1)
		KEY_RIGHT, KEY_D:
			_step(_focus, 1)
		_:
			return
	get_viewport().set_input_as_handled()
