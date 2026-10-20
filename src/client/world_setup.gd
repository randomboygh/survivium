extends Control
## The first screen: the world to make. The seed (typed in or rolled with the dice),
## a kind of world that sets the rest at once, and the settings of WorldGen one by one
## as rows "name ‹ value ›" like the settings window, with a map of the land around
## the spawn drawn a few rows a frame as the choice changes. "Создать мир" (or Enter)
## keeps the choice in Settings and starts the world. It covers the whole screen, the
## panel in the middle. `game` is the Main node.

const UiStyle := preload("res://src/client/ui_style.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")

const NAME_WIDTH := 112
const VALUE_WIDTH := 84
const ARROW := 32
## The map: pixels each way and cells per pixel.
const MAP := 128
const MAP_STEP := 32
## Time the map may take a frame, in microseconds.
const MAP_BUDGET_US := 4000
const LEVELS := ["мало", "средне", "много"]
## Kinds of world and the settings each picks: size, water, mountains, rivers, biomes.
const KINDS := [
	["Обычный", [1, 1, 1, 1, 1]],
	["Материк", [2, 1, 1, 1, 1]],
	["Острова", [0, 2, 1, 0, 1]],
	["Горы", [1, 1, 2, 1, 1]],
	["Равнины", [2, 0, 0, 2, 2]],
]
const OPTIONS := ["size", "water", "mountains", "rivers", "biomes"]
const BACKDROP := Color(0.06, 0.06, 0.07)

signal done

var game
var _rows := []
var _focus := 0
var _panel: PanelContainer
var _box: BoxContainer
var _list: VBoxContainer
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
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_box.add_child(_list)
	_seed_row()
	var s = game.settings
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
	var start := Button.new()
	start.text = "Создать мир"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(0, 36)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		start.add_theme_stylebox_override(state, UiStyle.button(state, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		start.add_theme_color_override(c, UiStyle.DARK_INK)
	start.pressed.connect(_start)
	outer.add_child(start)
	_start_button = start
	_refresh()
	_set_focus(1)
	get_parent().resized.connect(_fit)
	_fit()


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


func _add_row(name: String, values: Array, getter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_list.add_child(row)
	var label := UiStyle.label(name)
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var index := _rows.size()
	_arrow(row, "prev", index, -1)
	var value := UiStyle.label()
	value.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	_arrow(row, "next", index, 1)
	_rows.append({"name": label, "values": values, "get": getter, "set": setter, "label": value})


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
	var r: Dictionary = _rows[i]
	var n: int = r.values.size()
	if n == 0:
		return
	var cur: int = clampi(r.get.call(), 0, n - 1)
	var next := posmod(cur + dir, n)
	# "Свой" is what the rows below make, not a choice of its own.
	if i == 1 and next == KINDS.size():
		next = posmod(next + dir, n)
	r.set.call(next)
	_refresh()
	_restart_map()


func _refresh() -> void:
	for r in _rows:
		if r.label != null:
			var i: int = r.get.call()
			r.label.text = r.values[clampi(i, 0, r.values.size() - 1)]


func _set_focus(i: int) -> void:
	_focus = posmod(i, _rows.size())
	for j in _rows.size():
		_rows[j].name.add_theme_color_override("font_color", UiStyle.ACCENT if j == _focus else UiStyle.INK)


## Side by side on a wide screen, the map over the rows on a tall one; centred.
func _fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	_box.vertical = screen.x < screen.y
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


## Up and down pick a row, left and right change it, Enter makes the world.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				_start()
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
