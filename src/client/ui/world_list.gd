extends Control
## The saved worlds (see WorldStore.list_worlds), the one saved last first: a row each
## with its seed, kind and day (and when it was saved, in the tooltip). Tapping a row picks that world
## (`chosen`); the square trash button beside it turns red on the first tap and deletes
## the world from the device on the second. The world being played cannot be deleted
## (its button is greyed). The test world's trash button resets it instead: two taps
## forget its save, so it is laid out anew (played, at once). "Назад" (or Escape) leaves. It covers the whole
## screen over a shade of the world behind, the panel in the middle. `game` is the
## Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const WorldSetup := preload("res://src/client/ui/world_setup.gd")
const Lang := preload("res://src/shared/content/lang.gd")

const ROW_WIDTH := 226
const ROW_H := 36
## The trash button is square.
const DELETE_WIDTH := ROW_H
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
	var title := UiStyle.label("[load_a_world]", UiStyle.ACCENT)
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
	# A finger dragged over the world buttons scrolls them too.
	DragScroll.attach(_scroll)
	var back := Button.new()
	back.text = "[back]"
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
		_rows.remove_child(c)
	_armed = null
	var worlds := WorldStore.list_worlds()
	if worlds.is_empty():
		var none := UiStyle.label("[no_saved_worlds_yet]", UiStyle.MUTED)
		none.custom_minimum_size = Vector2(ROW_WIDTH + DELETE_WIDTH + 4, ROW_H)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows.add_child(none)
	for w: Dictionary in worlds:
		var current: bool = w.seed == game.world_seed and w.settings == game.world_options and game.join_url == ""
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_rows.add_child(row)
		var pick := Button.new()
		pick.text = Lang.f("[seed_day]", [w.seed, _kind(w.settings), w.day])
		if w.seed == WorldStore.TEST_SEED:
			pick.text = Lang.f("[test_world_grounds_day]", [w.day])
		pick.tooltip_text = Lang.f("[saved_played_min]", [w.saved.replace("T", " "), int(w.played / 60.0)])
		if not w.mods.is_empty():
			pick.tooltip_text += Lang.f("[mods]", [Mods.summary(Mods.expand(w.mods))])
		pick.focus_mode = Control.FOCUS_NONE
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.custom_minimum_size = Vector2(ROW_WIDTH, ROW_H)
		# Every row as wide as the widest, its delete button at the same place.
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if current:
			UiStyle.accent(pick)
		var seed_value: int = w.seed
		var options: Dictionary = w.settings
		pick.pressed.connect(func() -> void: chosen.emit(seed_value, options))
		row.add_child(pick)
		var del := Button.new()
		del.focus_mode = Control.FOCUS_NONE
		del.icon = UiStyle.icon("trash")
		del.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		del.custom_minimum_size = Vector2(DELETE_WIDTH, ROW_H)
		if w.seed == WorldStore.TEST_SEED:
			del.tooltip_text = "[reset_the_test_world_tap]"
			del.pressed.connect(func() -> void: _reset(del))
		elif current:
			# The world being played stays.
			del.tooltip_text = "[this_world_is_being_played]"
			del.disabled = true
		else:
			del.tooltip_text = "[delete_the_world_tap_twice]"
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


## Whether `button` was asked already; else asks with it (red) and
## puts back the one asked before.
func _arm(button: Button) -> bool:
	if _armed == button:
		return true
	if _armed != null:
		UiStyle.arm(_armed, false)
	_armed = button
	UiStyle.arm(button, true)
	return false


## The name of the kind of world the settings match (see WorldSetup.KINDS), in the
## language in use, small.
static func _kind(settings: Dictionary) -> String:
	var now: Array = WorldSetup.OPTIONS.map(func(o: String) -> int: return settings.get(o, 1))
	for k: Array in WorldSetup.KINDS:
		if k[1] == now:
			return Lang.t(k[0]).to_lower()
	return Lang.t("[custom_world]")


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
