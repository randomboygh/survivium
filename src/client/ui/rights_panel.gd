extends PanelContainer
## The window «Права на земле» of the pause menu on a server (plan/design/territory-pvp.md,
## the user's pick 3А): what the player lets their team and the others do in all the land
## they claimed, a row for each of Territory.ACTIONS with a button for the team and one
## for the others, lit green where it is allowed; a tap turns it over at once
## (Land.set_rights). «Назад» goes back to the pause. It follows game.land as it changes.
## `game` is the Main node; the HUD holds it and places it in the middle.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Territory := preload("res://src/shared/game/territory.gd")

## The widths of the names of the actions and of each button.
const NAME_WIDTH := 170
const CELL_WIDTH := 96

## «Назад» was pressed.
signal closed

var game
var _scroll: ScrollContainer
var _box: VBoxContainer


func _init(g) -> void:
	game = g


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Scrolled when the screen is lower than the window (a phone held sideways).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_scroll.add_child(_box)
	game.land.changed.connect(_fill)


func open() -> void:
	visible = true
	_fill()


func close() -> void:
	visible = false
	closed.emit()


func _fill() -> void:
	if not visible:
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var title := UiStyle.label("Права на земле", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	_box.add_child(head)
	_cell_label(head, "", NAME_WIDTH)
	_cell_label(head, "Команда", CELL_WIDTH)
	_cell_label(head, "Остальные", CELL_WIDTH)
	var r: Array = game.land.my_rights()
	for i in Territory.ACTIONS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_box.add_child(row)
		var what := UiStyle.label(Territory.TITLES[Territory.ACTIONS[i]])
		what.custom_minimum_size = Vector2(NAME_WIDTH, 0)
		what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(what)
		for who in 2:
			var on: bool = int(r[who]) & (1 << i) != 0
			var b := Button.new()
			b.text = "можно" if on else "нельзя"
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(CELL_WIDTH, 30)
			UiStyle.succeed(b, on)
			b.pressed.connect(_flip.bind(who, i))
			row.add_child(b)
	var hint := UiStyle.label("На всей вашей земле. Двери, ручные звери и бои игроков появятся позже.", UiStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(NAME_WIDTH + CELL_WIDTH * 2 + 8, 0)
	_box.add_child(hint)
	var back := Button.new()
	back.text = "Назад"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 30)
	back.pressed.connect(close)
	_box.add_child(back)
	var hud: Control = get_parent()
	var want := _box.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(want.x, minf(want.y, hud.size.y - 40.0))
	reset_size()
	position = ((hud.size - size) * 0.5).floor()


## Turns over right `bit` for the team (`who` 0) or the others (1).
func _flip(who: int, bit: int) -> void:
	var r: Array = game.land.my_rights().duplicate()
	r[who] = int(r[who]) ^ (1 << bit)
	game.land.set_rights(r[0], r[1])


func _cell_label(row: Node, text: String, width: int) -> void:
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(l)
