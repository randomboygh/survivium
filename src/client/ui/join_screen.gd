extends Control
## «Присоединиться» (plan/architecture/server.md, «Меню и экраны»): the address of a
## server (`wss://…` through a tunnel, `ws://адрес:порт` in the home network; read by
## ServerList.normalize), the name the player goes by there, the password when the
## server asks one, and the servers joined lately (a tap puts the address in the field).
## «Подключиться» says `chosen` with the address, the name and the password; «Назад» (or
## Escape) says `cancelled`. Why the last joining failed shows under the fields. The
## fields go one under the other, the panel as wide as the narrowest phone held upright
## allows; when the keyboard leaves the screen too short, the panel goes to its top so
## the fields stay in sight. It covers the whole screen over a shade of the world
## behind. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ServerList := preload("res://src/client/net/server_list.gd")

const WIDTH := 240
const FIELD_H := 30
const ROW_H := 32
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)
const MARGIN := 8

signal chosen(url: String, name: String, password: String)
signal cancelled

var game
var _panel: PanelContainer
var _url: LineEdit
var _name: LineEdit
var _password: LineEdit
var _error: Label
var _recent: VBoxContainer
var _go: Button
var _back: Button
## The address and the words of the failure the screen opens with.
var _start_url := ""
var _start_error := ""


func _init(g, url := "", error := "") -> void:
	game = g
	_start_url = url
	_start_error = error


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var title := UiStyle.label("Присоединиться", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var recent := ServerList.recent()
	_url = _field(box, "Адрес сервера", "wss://… или ws://адрес:порт")
	_url.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_url.text = _start_url if _start_url != "" else (recent[0].url if not recent.is_empty() else "")
	_name = _field(box, "Имя", "как вас увидят другие")
	_name.max_length = ServerList.NAME_MAX
	_name.text = ServerList.player_name()
	_password = _field(box, "Пароль", "если сервер просит")
	_password.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_error = UiStyle.label("", UiStyle.DANGER)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(_error)
	_say(_start_error)
	_recent = VBoxContainer.new()
	_recent.add_theme_constant_override("separation", 4)
	box.add_child(_recent)
	_fill_recent(recent)
	_go = Button.new()
	_go.text = "Подключиться"
	_go.focus_mode = Control.FOCUS_NONE
	_go.custom_minimum_size = Vector2(WIDTH, ROW_H)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_go.add_theme_stylebox_override(state, UiStyle.button(state, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_go.add_theme_color_override(c, UiStyle.DARK_INK)
	_go.pressed.connect(submit)
	box.add_child(_go)
	_back = Button.new()
	var back := _back
	back.text = "Назад"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(WIDTH, ROW_H)
	back.pressed.connect(cancelled.emit)
	box.add_child(back)
	get_parent().resized.connect(_fit)
	_fit()
	_announce.call_deferred()


## Laid out a frame after it is added: the browser test taps the fields and the
## buttons from this line.
func _announce() -> void:
	await get_tree().process_frame
	print("join screen shown: url %s, name %s, go %s, back %s" % [_url.get_global_rect(), _name.get_global_rect(),
		_go.get_global_rect(), _back.get_global_rect()])


## A field under its name; Enter in it goes to the next one, in the last one joins.
func _field(box: Control, caption: String, hint: String) -> LineEdit:
	box.add_child(UiStyle.label(caption, UiStyle.MUTED))
	var f := LineEdit.new()
	f.placeholder_text = hint
	f.custom_minimum_size = Vector2(WIDTH, FIELD_H)
	f.select_all_on_focus = false
	f.text_submitted.connect(func(_t: String) -> void: _next_after(f))
	box.add_child(f)
	return f


func _next_after(f: LineEdit) -> void:
	var order: Array[LineEdit] = [_url, _name, _password]
	var i := order.find(f)
	if i < order.size() - 1:
		order[i + 1].grab_focus()
	else:
		f.release_focus()
		submit()


## A row for each server joined lately: its name and address; a tap puts the address
## in the field.
func _fill_recent(recent: Array[Dictionary]) -> void:
	for c in _recent.get_children():
		c.queue_free()
		_recent.remove_child(c)
	if recent.is_empty():
		return
	_recent.add_child(UiStyle.label("Недавние", UiStyle.MUTED))
	for r: Dictionary in recent:
		var b := Button.new()
		var title: String = r.title if r.title != "" else "Сервер"
		b.text = "%s\n%s" % [title, _short(r.url)]
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(WIDTH, 40)
		var url: String = r.url
		b.pressed.connect(func() -> void:
			_url.text = url
			_say(""))
		_recent.add_child(b)


## The address without its scheme, as it fits a row.
static func _short(url: String) -> String:
	return url.get_slice("://", 1) if "://" in url else url


## Joins the server in the field, or says what is wrong with the address or the name.
func submit() -> void:
	var url := ServerList.normalize(_url.text)
	var why := ServerList.problem(url, _secure_page())
	var name := _name.text.strip_edges()
	if why == "" and name == "":
		why = "Введите имя"
	if why != "":
		_say(why)
		return
	_url.text = url
	ServerList.set_player_name(name)
	print("joining %s as %s" % [url, name])
	chosen.emit(url, name, _password.text)


## The page was served over https: the browser joins only wss:// servers.
static func _secure_page() -> bool:
	if not OS.has_feature("web"):
		return false
	var v: Variant = JavaScriptBridge.eval("location.protocol", true)
	return v is String and v == "https:"


func _say(text: String) -> void:
	_error.text = text
	_error.visible = text != ""
	if is_inside_tree():
		_fit.call_deferred()


## The panel in the middle; at the top when it is taller than the screen (the keyboard
## is up).
func _fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	_panel.reset_size()
	var s := _panel.size
	_panel.position = Vector2(floorf((screen.x - s.x) * 0.5),
		floorf((screen.y - s.y) * 0.5) if s.y + 2 * MARGIN <= screen.y else MARGIN)
	move_to_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelled.emit()
