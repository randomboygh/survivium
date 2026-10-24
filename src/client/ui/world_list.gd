extends Control
## The saved worlds (see WorldStore.list_worlds), the one saved last first: a row each
## with its seed, kind and day (and when it was saved, in the tooltip). Tapping a row picks that world
## (`chosen`); "Удалить" asks again and then deletes it from the device. The world
## being played cannot be deleted. The test world has "Сбросить" in its place, which
## asks again and forgets its save, so it is laid out anew (played, at once). "Назад" (or Escape) leaves. It covers the whole
## screen over a shade of the world behind, the panel in the middle. `game` is the
## Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const WorldSetup := preload("res://src/client/ui/world_setup.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")

const ROW_WIDTH := 170
const ROW_H := 36
## As wide as the widest of «Удалить», «Сбросить», «сейчас».
const DELETE_WIDTH := 96
## Rows shown before the list scrolls.
const VISIBLE_ROWS := 5
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)

signal chosen(seed_value: int, options: Dictionary)
signal cancelled

var game
var _panel: PanelContainer
var _rows: VBoxContainer
var _scroll: ScrollContainer
## The delete button waiting for its second tap.
var _armed: Button


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)
	var title := UiStyle.label("Миры", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	var back := Button.new()
	back.text = "Назад"
	back.focus_mode = Control.FOCUS_NONE
	# Across the panel, as wide as the rows over it.
	back.custom_minimum_size = Vector2(0, 36)
	back.pressed.connect(cancelled.emit)
	outer.add_child(back)
	_fill()
	get_parent().resized.connect(_fit)
	_fit()


## One row per saved world.
func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_armed = null
	var worlds := WorldStore.list_worlds()
	if worlds.is_empty():
		var none := UiStyle.label("Сохранённых миров пока нет", UiStyle.MUTED)
		none.custom_minimum_size = Vector2(ROW_WIDTH + DELETE_WIDTH + 4, ROW_H)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows.add_child(none)
	for w: Dictionary in worlds:
		var current: bool = w.seed == game.world_seed and w.settings == game.world_options
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_rows.add_child(row)
		var pick := Button.new()
		pick.text = "зерно %d\n%s · день %d" % [w.seed, _kind(w.settings), w.day]
		if w.seed == TestGround.SEED:
			pick.text = "Тестовый мир\nплощадки · день %d" % w.day
		pick.tooltip_text = "Сохранён %s, в игре %d мин" % [w.saved.replace("T", " "), int(w.played / 60.0)]
		pick.focus_mode = Control.FOCUS_NONE
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.custom_minimum_size = Vector2(ROW_WIDTH, ROW_H)
		# Every row as wide as the widest, its delete button at the same place.
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if current:
			for state in ["normal", "hover", "pressed", "hover_pressed"]:
				pick.add_theme_stylebox_override(state, UiStyle.button(state, true))
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
				pick.add_theme_color_override(c, UiStyle.DARK_INK)
		var seed_value: int = w.seed
		var options: Dictionary = w.settings
		pick.pressed.connect(func() -> void: chosen.emit(seed_value, options))
		row.add_child(pick)
		var del := Button.new()
		del.focus_mode = Control.FOCUS_NONE
		del.custom_minimum_size = Vector2(DELETE_WIDTH, ROW_H)
		if w.seed == TestGround.SEED:
			del.text = "Сбросить"
			del.tooltip_text = "Вернуть тестовый мир к началу"
			del.pressed.connect(func() -> void: _reset(del))
		elif current:
			# The world being played stays.
			del.text = "сейчас"
			del.disabled = true
		else:
			del.text = "Удалить"
			var dir: String = w.dir
			del.pressed.connect(func() -> void: _delete(del, dir))
		row.add_child(del)
	var shown := mini(maxi(worlds.size(), 1), VISIBLE_ROWS)
	_scroll.custom_minimum_size = Vector2(ROW_WIDTH + DELETE_WIDTH + 4, shown * (ROW_H + 4) - 4)


## The first tap asks, the second deletes.
func _delete(button: Button, dir: String) -> void:
	if not _arm(button):
		return
	WorldStore.new(dir).erase()
	print("world deleted: %s" % dir)
	_fill()
	_fit.call_deferred()


## The first tap asks, the second forgets the test world's save (Settings.reset_test_world).
func _reset(button: Button) -> void:
	if not _arm(button):
		return
	print("test world reset")
	game.settings.reset_test_world()
	_fill()
	_fit.call_deferred()


## Whether `button` was asked already; else asks with it ("Точно?") and puts back the
## one asked before.
func _arm(button: Button) -> bool:
	if _armed == button:
		return true
	if _armed != null:
		_armed.text = _armed.get_meta("text")
		_armed.remove_theme_color_override("font_color")
	_armed = button
	button.set_meta("text", button.text)
	button.text = "Точно?"
	button.add_theme_color_override("font_color", UiStyle.DANGER)
	return false


## The name of the kind of world the settings match (see WorldSetup.KINDS).
static func _kind(settings: Dictionary) -> String:
	var now: Array = WorldSetup.OPTIONS.map(func(o: String) -> int: return settings.get(o, 1))
	for k: Array in WorldSetup.KINDS:
		if k[1] == now:
			return (k[0] as String).to_lower()
	return "свой"


func _fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	_panel.reset_size()
	_panel.position = ((screen - _panel.size) * 0.5).floor()
	move_to_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelled.emit()
