extends Control
## The death screen (plan/design/ui.md, "Смерть"): shown over the darkened world while
## the character lies dead (Character.death), and again whenever the player comes back
## into a world they left dead. It says how the character died and when, what was lost
## (the bag's things, in a sack where they fell, and how far it is from where they
## come back) and what stays, and offers to come back at a respawn point
## (Character.respawn_points), to go to the main menu or to start a new world. A
## second panel tells what that life did (Character.life: how long it lasted, how far
## the character walked, what they dug, built, felled, gathered, ate and made) and how
## many deaths the world has seen. The
## game's interface is hidden meanwhile; the screen takes the interface's scale and
## safe rect, as the main menu does, and leaves the place of death in sight. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const CharacterScript := preload("res://src/client/game/character.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

const WIDTH := 252
const BUTTON_H := 30
const SLOT := 32
const COLUMNS := 8
const MARGIN := 16
const STATS_WIDTH := 200
## The statistics shown, in order, as [name in Character.life, caption, the forms of
## the noun counted (one, two, five)]; "days" and "walked" always, the rest when there
## are any.
const STATS := [["days", "прожито", []], ["walked", "пройдено", []],
	["dug", "выкопано", ["блок", "блока", "блоков"]], ["built", "построено", ["блок", "блока", "блоков"]],
	["trees", "срублено", ["дерево", "дерева", "деревьев"]], ["got", "добыто", ["вещь", "вещи", "вещей"]],
	["crafted", "сделано", ["вещь", "вещи", "вещей"]], ["eaten", "поели", ["раз", "раза", "раз"]],
	["jumps", "прыгнули", ["раз", "раза", "раз"]]]
const SHADE := Color(0.10, 0.02, 0.02, 0.4)
## Directions from the respawn point to the sack, clockwise from north (-z).
const DIRECTIONS := ["к северу", "к северо-востоку", "к востоку", "к юго-востоку", "к югу",
	"к юго-западу", "к западу", "к северо-западу"]

var game
var _panel: PanelContainer
var _title: Label
var _cause: Label
var _when: Label
var _lost: GridContainer
var _sack: Label
var _sack_row: HBoxContainer
var _note: Label
var _respawn: VBoxContainer
var _menu_button: Button
var _new_button: Button
var _stats_panel: PanelContainer
var _stats: GridContainer
var _record: Label
var _fit_for := Rect2()


func _init(g) -> void:
	game = g


func _ready() -> void:
	theme = UiStyle.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel = PanelContainer.new()
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_title = UiStyle.label("", UiStyle.DANGER)
	_title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	_title.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	_title.add_theme_constant_override("outline_size", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_cause = _text(box, UiStyle.INK)
	_cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_when = _text(box, UiStyle.MUTED)
	_when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading(box, "Потеряно")
	_lost = GridContainer.new()
	_lost.columns = COLUMNS
	_lost.add_theme_constant_override("h_separation", 2)
	_lost.add_theme_constant_override("v_separation", 2)
	_lost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_lost)
	_sack_row = HBoxContainer.new()
	_sack_row.add_theme_constant_override("separation", 6)
	box.add_child(_sack_row)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("bag")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(10, 10)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_sack_row.add_child(icon)
	_sack = UiStyle.label("", UiStyle.INK)
	_sack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sack.custom_minimum_size = Vector2(WIDTH - 16, 0)
	_sack_row.add_child(_sack)
	_note = _text(box, UiStyle.MUTED)
	_heading(box, "Остаётся с вами")
	_text(box, UiStyle.INK).text = "Изученные рецепты"
	_gap(box)
	_respawn = VBoxContainer.new()
	_respawn.add_theme_constant_override("separation", 6)
	box.add_child(_respawn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_menu_button = _button(row, "Главное меню", _to_menu)
	_new_button = _button(row, "Новый мир", _new_world)
	for b: Button in [_menu_button, _new_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER

	_stats_panel = PanelContainer.new()
	add_child(_stats_panel)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	_stats_panel.add_child(stats_box)
	_heading(stats_box, "Эта жизнь")
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 8)
	_stats.add_theme_constant_override("v_separation", 6)
	stats_box.add_child(_stats)
	_record = UiStyle.label("", UiStyle.MUTED)
	_record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_record.custom_minimum_size = Vector2(STATS_WIDTH, 0)
	stats_box.add_child(_record)


func _text(parent: Node, color: Color) -> Label:
	var l := UiStyle.label("", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	parent.add_child(l)
	return l


## A section's name in amber with a line to the panel's edge.
func _heading(parent: Node, text: String) -> void:
	_gap(parent)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(UiStyle.label(text, UiStyle.ACCENT))
	var line := ColorRect.new()
	line.color = UiStyle.HIGHLIGHT
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)


func _gap(parent: Node) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, 2)
	parent.add_child(g)


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, BUTTON_H)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Shows the screen while the character is dead and the main menu is closed; run
## every frame once the world is built.
func update() -> void:
	var want: bool = game.character.is_dead() and (game.menu == null or not game.menu.is_open)
	if want and not visible:
		_fill()
		visible = true
		game.hud.visible = false
		print("death screen shown: %s" % _title.text)
	elif not want and visible:
		visible = false
	if visible:
		# The main menu, closing, shows the interface again.
		game.hud.visible = false
		var hud: Control = game.hud
		if Rect2(hud.position, hud.size * hud.scale) != _fit_for or scale != hud.scale:
			_fit()


## Puts the death of the character on the screen.
func _fill() -> void:
	var character = game.character
	var death: Dictionary = character.death
	var cause: Array = CharacterScript.cause_text(str(death.get("cause", "")))
	_title.text = cause[0]
	_cause.text = cause[1]
	_cause.visible = cause[1] != ""
	var t := float(death.get("time", 0.0)) * 24.0
	_when.text = "день %d · %02d:%02d" % [int(death.get("day", 0)), int(t), int(fmod(t * 60.0, 60.0))]
	for c in _lost.get_children():
		c.queue_free()
	var lost: Array = death.get("lost", [])
	for st: Array in lost:
		var s := HotbarSlot.new(SLOT)
		s.texture = ItemIcons.of_item(st[0])
		s.number = str(st[1]) if int(st[1]) > 1 else ""
		s.tooltip_text = Items.title(st[0])
		_lost.add_child(s)
	_lost.visible = not lost.is_empty()
	var points: Array = character.respawn_points()
	_sack_row.visible = not lost.is_empty()
	if lost.is_empty():
		_note.text = "Ничего: сумка была пуста"
	else:
		_sack.text = "Мешок с вещами %s" % _where(death.get("sack"), points[0])
		_note.text = "Он светится и ждёт там, где вы упали, пока его не заберут"
	for c in _respawn.get_children():
		c.queue_free()
		_respawn.remove_child(c)
	var choices := points.duplicate()
	if game.settings.revive_at_death:
		var fell: Array = death.get("at", [])
		choices.append(["На месте смерти", Vector3(fell[0], fell[1], fell[2]) if fell.size() == 3 else points[0][1]])
	for p: Array in choices:
		var at: Vector3 = p[1]
		var b := _button(_respawn, "Возродиться " + (p[0] as String).to_lower(), func() -> void: _revive(at))
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, UiStyle.button(state, true))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, UiStyle.DARK_INK)
	var has_menu: bool = game.menu != null
	_menu_button.disabled = not has_menu
	_new_button.disabled = not has_menu
	_fill_stats(death)
	_fit()


## What the life that ended did, a value over its caption in two columns, and the
## world's deaths under them; nothing for a death saved before lives were counted.
func _fill_stats(death: Dictionary) -> void:
	for c in _stats.get_children():
		c.queue_free()
		_stats.remove_child(c)
	var lived: Variant = death.get("life")
	_stats_panel.visible = lived is Dictionary
	if not (lived is Dictionary):
		return
	for st: Array in STATS:
		var v: float = lived.get(st[0], 0.0)
		if v <= 0.0 and not st[0] in ["days", "walked"]:
			continue
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 2)
		tile.custom_minimum_size = Vector2((STATS_WIDTH - 8) / 2.0, 0)
		var value := UiStyle.label(_value(st[0], v, st[2]), UiStyle.INK)
		tile.add_child(value)
		tile.add_child(UiStyle.label(st[1], UiStyle.MUTED))
		_stats.add_child(tile)
	var n := int(death.get("deaths", 1))
	var best := float(death.get("best", 0.0))
	var days := float(lived.get("days", 0.0))
	if n <= 1:
		_record.text = "Первая смерть в этом мире"
	elif days > best:
		_record.text = "Смерть №%d в этом мире\nНовый рекорд жизни!" % n
	else:
		_record.text = "Смерть №%d в этом мире\nРекорд жизни: %s" % [n, _days(best)]
	_record.add_theme_color_override("font_color", UiStyle.ACCENT if n > 1 and days > best else UiStyle.MUTED)


## A statistic `v` of `name` as it is shown: time lived, a distance, else a count of
## the noun in `forms`.
static func _value(name: String, v: float, forms: Array) -> String:
	match name:
		"days":
			return _days(v)
		"walked":
			return ("%.1f км" % (v / 1000.0)).replace(".", ",") if v >= 1000.0 else "%d м" % roundi(v)
	var n := roundi(v)
	return "%d %s" % [n, _plural(n, forms)]


## The form of a noun in `forms` (one, two, five) that goes with the number `n`.
static func _plural(n: int, forms: Array) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return forms[0]
	if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20):
		return forms[1]
	return forms[2]


## `d` game days as "2 дн 5 ч", "5 ч 20 мин" or "40 мин".
static func _days(d: float) -> String:
	var minutes := roundi(d * 24.0 * 60.0)
	if minutes >= 24 * 60:
		return "%d дн %d ч" % [minutes / (24 * 60), (minutes / 60) % 24]
	if minutes >= 60:
		return "%d ч %d мин" % [minutes / 60, minutes % 60]
	return "%d мин" % minutes


## "в 40 м к северо-востоку от костра старта", from respawn point `point` ([title,
## position]) to the sack at `sack` ([x, y, z] or null).
static func _where(sack: Variant, point: Array) -> String:
	if not (sack is Array) or sack.size() != 3:
		return "там, где вы упали"
	var from: Vector3 = point[1]
	var d := Vector2(float(sack[0]) - from.x, float(sack[2]) - from.z)
	var title := (point[0] as String).trim_prefix("У ").trim_prefix("у ")
	if d.length() < 3.0:
		return "у самого %s" % title
	var sector := posmod(roundi(atan2(d.x, -d.y) / (TAU / 8.0)), 8)
	return "в %d м %s от %s" % [roundi(d.length()), DIRECTIONS[sector], title]


func _revive(at: Vector3) -> void:
	game.net.request(Protocol.REVIVE, [at])
	visible = false
	game.hud.visible = true
	game.hud.toast("Вы снова живы")


func _to_menu() -> void:
	if game.menu != null:
		game.menu.open()


func _new_world() -> void:
	if game.menu != null:
		game.menu.new_world()


## The interface's scale and rect; the panel on the left of a wide screen with the
## statistics on the right, at the bottom of a tall one with the statistics at the top,
## so the place of death in the middle stays in sight.
func _fit() -> void:
	var hud: Control = game.hud
	_fit_for = Rect2(hud.position, hud.size * hud.scale)
	scale = hud.scale
	position = hud.position
	size = hud.size
	_panel.reset_size()
	var p := _panel.size
	_stats_panel.reset_size()
	var q := _stats_panel.size
	if size.x >= size.y * 1.2:
		_panel.position = Vector2(MARGIN, (size.y - p.y) * 0.5).floor()
		_stats_panel.position = Vector2(size.x - q.x - MARGIN, (size.y - q.y) * 0.5).floor()
	else:
		_panel.position = Vector2((size.x - p.x) * 0.5, size.y - p.y - MARGIN).floor()
		_stats_panel.position = Vector2((size.x - q.x) * 0.5, MARGIN).floor()
	queue_redraw()


## The darkened world, over the whole window past the safe rect.
func _draw() -> void:
	var s: float = scale.x
	draw_rect(Rect2(-position / s, get_viewport_rect().size / s).grow(2), SHADE)


## Enter comes back at the first respawn point, Escape opens the main menu; every other
## key stops here, so the game behind gets none.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_revive(game.character.respawn_points()[0][1])
		KEY_ESCAPE:
			_to_menu()
