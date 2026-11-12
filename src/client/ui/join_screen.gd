extends "res://src/client/ui/kit/window.gd"
## «Присоединиться» (plan/architecture/server.md, «Меню и экраны»): the address of a
## server (`wss://…` through a tunnel, `ws://адрес:порт` in the home network; read by
## ServerList.normalize), the name the player goes by there, the password when the
## server asks one, and the servers joined lately (a tap puts the address in the field).
## «Подключиться» says `chosen` with the address, the name and the password; «Назад» (or
## Escape) says `cancelled`. Why the last joining failed shows under the fields. The
## fields go one under the other, the panel as wide as the narrowest phone held upright
## allows; when the keyboard leaves the screen too short, the panel goes to its top so
## the fields stay in sight. It covers the whole screen over a shade of the world
## behind (a window of the UI kit). `game` is the Main node.

const ServerList := preload("res://src/client/net/server_list.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const Lang := preload("res://src/shared/content/lang.gd")

const WIDTH := 240
const FIELD_H := 30
const ROW_H := 32
## A recent server's row and its square trash button.
const FORGET := 40
## Recent servers shown before their list scrolls (as «Загрузить мир», WorldList).
const RECENT_ROWS := 3

signal chosen(url: String, name: String, password: String)
signal cancelled

var game
var _url: LineEdit
var _name: LineEdit
var _password: LineEdit
var _error: Label
var _recent: VBoxContainer
var _recent_scroll: ScrollContainer
var _recent_rows: VBoxContainer
## The trash buttons: two taps each.
var _bins := TwoTap.new()
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
	build("[join]")
	var recent := ServerList.recent()
	_url = _field(box, "[server_address]", "[wss_or_ws_address_port]")
	_url.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_url.text = _start_url if _start_url != "" else (recent[0].url if not recent.is_empty() else "")
	_name = _field(box, "[name]", "[how_others_will_see_you]")
	_name.max_length = ServerList.NAME_MAX
	_name.text = ServerList.player_name()
	_password = _field(box, "[password]", "[if_the_server_asks]")
	_password.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_error = Kit.note("", WIDTH, UiStyle.DANGER)
	box.add_child(_error)
	_say(_start_error)
	_recent = Kit.column(4)
	box.add_child(_recent)
	_recent.add_child(Kit.caption("[recent]"))
	_recent_rows = Kit.column(4)
	# A finger dragged over the server buttons scrolls them too.
	_recent_scroll = Kit.scroll(_recent_rows, false)
	_recent.add_child(_recent_scroll)
	_fill_recent(recent)
	_go = Kit.accent_button("[connect]", submit, WIDTH, ROW_H)
	box.add_child(_go)
	_back = Kit.button("[back]", back, WIDTH, ROW_H)
	box.add_child(_back)
	show_fitted()
	_announce.call_deferred()


func back() -> void:
	cancelled.emit()


## Laid out a frame after it is added: the browser test taps the fields and the
## buttons from this line.
func _announce() -> void:
	await get_tree().process_frame
	print("join screen shown: url %s, name %s, go %s, back %s" % [_url.get_global_rect(), _name.get_global_rect(),
		_go.get_global_rect(), _back.get_global_rect()])


## A field under its name; Enter in it goes to the next one, in the last one joins.
func _field(box: Control, caption: String, hint: String) -> LineEdit:
	box.add_child(Kit.caption(caption))
	var f := Kit.field(hint, WIDTH, 0, FIELD_H)
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
	for c in _recent_rows.get_children():
		c.queue_free()
		_recent_rows.remove_child(c)
	_bins.disarm()
	_recent.visible = not recent.is_empty()
	# As tall as the rows, at most RECENT_ROWS, then scrolled.
	var shown := mini(recent.size(), RECENT_ROWS)
	_recent_scroll.custom_minimum_size = Vector2(WIDTH, maxi(shown * (FORGET + 4) - 4, 0))
	for r: Dictionary in recent:
		var row := Kit.row(4)
		var title: String = r.title if r.title != "" else "[server_name]"
		var url: String = r.url
		var b := Kit.button(Lang.line("%s\n%s", [title, _short(r.url)]), func() -> void:
			_url.text = url
			_say(""), WIDTH - FORGET - 4, FORGET)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		row.add_child(_bins.guard(Kit.icon_button("trash", "[remove_the_server_from_the]", Callable(), FORGET),
			_forget.bind(url)))
		_recent_rows.add_child(row)


## Forgets the server (ServerList.forget) on the trash's second tap, lists the rest and
## fits the panel to them.
func _forget(url: String) -> void:
	ServerList.forget(url)
	print("server forgotten: %s" % url)
	_fill_recent(ServerList.recent())
	# The panel shrinks to the rows left.
	fit.call_deferred()


## The address without its scheme, as it fits a row.
static func _short(url: String) -> String:
	return url.get_slice("://", 1) if "://" in url else url


## Joins the server in the field, or says what is wrong with the address or the name.
func submit() -> void:
	var url := ServerList.normalize(_url.text)
	var why := ServerList.problem(url, _secure_page())
	var name := _name.text.strip_edges()
	if why == "" and name == "":
		why = "[enter_a_name]"
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
	if is_inside_tree() and panel != null:
		fit.call_deferred()
