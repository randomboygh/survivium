extends VBoxContainer
## The chat on a server (plan/architecture/server.md, С6; plan/design/ui.md «Сообщения»):
## the last lines heard (Protocol.HEARD: the players within the chat's reach, the
## server's answers) in the bottom left corner, each coming up and going after FADE
## seconds as the notifications do (the UI kit's FadingList), and the
## field to say a line, opened by Enter or the chat button and closed by sending,
## Escape or the button again. While it is open all the recent lines show, the newest
## at the bottom. One in a team chooses whom a line goes to by the button before the
## field («Рядом» / «Команде»; Protocol.TEAM_CHAT). A line that begins with "/" is a host's command; the server answers
## it in the chat. Sending a line shows the recent lines again for FADE seconds, the
## line said among them (in single player, with no server to hear it, it is put in the
## chat here). `typing` keeps the keys from walking the character. `game` is the
## Main node; the HUD places the box (place). Its buttons and field are the UI kit's.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const FadingList := preload("res://src/client/ui/kit/fading_list.gd")

## Lines kept, lines shown while closed and while open, seconds a line shows.
const KEPT := 30
const SHOWN := 5
const OPEN_SHOWN := 10
const FADE := 12.0
const WIDTH := 220
## Letters a line may have (Requests.CHAT_MAX on the server cuts it there too).
const MAX := 160

var game
## The lines heard: {"text", "color", "at" (seconds), "n" (its number)}, the newest last.
var lines: Array[Dictionary] = []
var _list: FadingList
## The holders of the lines shown (FadingList.add), by the line's number.
var _shown := {}
## Where the box's bottom stays (place): the list grows up from it.
var _bottom := 0.0
var _row: PanelContainer
var _field: LineEdit
## Whom a line goes to: those near, or the team (shown only to one in a team).
var _to_team := false
var _whom: Button
## Lines heard in all: the next line's number.
var _heard := 0
## When a line was last sent (seconds): the lines heard before it fade from then on.
var _sent := -INF


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Runs only while lines show with the field closed (hear and close start it, _refresh
	# stops it).
	set_process(false)
	add_theme_constant_override("separation", 2)
	_list = FadingList.new(2)
	add_child(_list)
	minimum_size_changed.connect(_keep_bottom)
	_row = PanelContainer.new()
	_row.add_theme_stylebox_override("panel", UiStyle.panel(Vector4(4, 3, 4, 3)))
	_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_row.visible = false
	add_child(_row)
	var h := Kit.row(4)
	_row.add_child(h)
	_whom = Kit.button("", _switch_whom, 0, Kit.FIELD_H)
	_whom.tooltip_text = "[who_hears_it_those_nearby]"
	h.add_child(_whom)
	_field = Kit.field("[say_to_those_nearby]", WIDTH - 40, MAX)
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.text_submitted.connect(func(_t: String) -> void: submit())
	h.add_child(_field)
	var send := Kit.button("›", submit, Kit.FIELD_H, Kit.FIELD_H)
	send.tooltip_text = "[say]"
	h.add_child(send)


## The button of whom a line goes to: the other ones; the field keeps the keys.
func _switch_whom() -> void:
	_to_team = not _to_team
	_show_whom()
	_field.grab_focus()


## The field is open and has the keys.
var typing: bool:
	get:
		return _row != null and _row.visible and _field.has_focus()


func is_open() -> bool:
	return _row.visible


## Opens the field (its keyboard on a phone), or closes it when open.
func toggle() -> void:
	if _row.visible:
		close()
	else:
		open()


func open() -> void:
	_show_whom()
	_row.visible = true
	_field.grab_focus()
	# Editing at once: the phone's keyboard comes up with the field, not at a tap on it.
	_field.edit()
	_refresh()


func close() -> void:
	_field.release_focus()
	_row.visible = false
	_refresh()


## Says the line in the field (a command when it begins with "/") and closes it.
func submit() -> void:
	var text := _field.text.strip_edges()
	_field.text = ""
	if text != "":
		_sent = _now()
	close()
	if text == "":
		return
	if game.join_url == "":
		# Single player: no one hears but the player, and there are no commands.
		if text.begins_with("/"):
			hear(0, "", "[commands_with_work_only_on]")
		else:
			hear(-1, game.player_name, text.left(MAX))
		return
	if game.net != null:
		print("chat: say %s" % text)
		if _to_team and game.team.has_team() and not text.begins_with("/"):
			game.team.say(text)
		else:
			game.net.request(Protocol.CHAT, [text])


## The button of whom a line goes to, shown in a team only.
func _show_whom() -> void:
	var team: bool = game.team.has_team()
	_to_team = _to_team and team
	_whom.visible = team
	_whom.text = "[to_team]" if _to_team else "[nearby]"
	_whom.add_theme_color_override("font_color", UiStyle.TEAM if _to_team else UiStyle.INK)
	_field.placeholder_text = "[say_to_the_team]" if _to_team else "[say_to_those_nearby]"


## A line heard: said by player `id` named `who` (0 the server, "" for its answer; -1
## the player in single player), to the team when `team` (marked and coloured).
func hear(id: int, who: String, text: String, team := false) -> void:
	var own: bool = id == -1 or id != 0 and id == int(game.welcome.get("id", -1))
	# The server's own lines are phrases of the game; the players' are as they wrote them.
	if id == 0:
		text = Lang.t(text)
		who = Lang.t(who)
	else:
		text = Lang.written(text)
	var line := text if who == "" else "%s: %s" % [who, text]
	if team:
		line = tr("[team_n2]") + line
	var color := UiStyle.MUTED if id == 0 else (UiStyle.TEAM if team else (UiStyle.ACCENT if own else UiStyle.INK))
	lines.append({"text": line, "color": color, "at": _now(), "n": _heard})
	_heard += 1
	while lines.size() > KEPT:
		lines.pop_front()
	print("chat: %s" % line)
	_refresh()


## Puts the box's bottom left corner at `corner` (HUD units), `room` wide at most.
func place(corner: Vector2, room: float) -> void:
	custom_minimum_size.x = minf(WIDTH, room)
	for h: Control in _list.get_children():
		(h.get_child(0) as Control).custom_minimum_size.x = custom_minimum_size.x
	position.x = floorf(corner.x)
	_bottom = floorf(corner.y)
	_keep_bottom()


## The box as tall as what it shows, its bottom where it was put (place): the lines
## coming and going move its top.
func _keep_bottom() -> void:
	reset_size()
	position.y = floorf(_bottom - size.y)


func _process(_delta: float) -> void:
	_refresh()


## Shows the lines that are still fresh (all recent ones while open): a line new to the
## list comes up into it, one no longer fresh (or pushed out by newer ones) goes.
func _refresh() -> void:
	var now := _now()
	var open := _row.visible
	var shown: Array[Dictionary] = []
	for i in range(lines.size() - 1, -1, -1):
		var l: Dictionary = lines[i]
		if shown.size() >= (OPEN_SHOWN if open else SHOWN) or (not open and now - _since(l) > FADE):
			break
		shown.push_front(l)
	var keep := {}
	for l: Dictionary in shown:
		keep[l.n] = true
	for n: int in _shown.keys():
		if not keep.has(n):
			_list.drop(_shown[n])
			_shown.erase(n)
	# From the newest up: a line older than those shown comes in above them, before the
	# newer one.
	var newer: Control = null
	for i in range(shown.size() - 1, -1, -1):
		var l: Dictionary = shown[i]
		if not _shown.has(l.n):
			_shown[l.n] = _list.add(_label(l), newer)
		newer = _shown[l.n]
	set_process(not shown.is_empty() and not open)


## The label of line `l`, as wide as the box, wrapped, outlined over the world.
func _label(l: Dictionary) -> Label:
	var label := UiStyle.label(l.text, l.color)
	# Players' words as written (the server's are put into the language as heard).
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = custom_minimum_size.x
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label


func _input(event: InputEvent) -> void:
	if typing and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


## When line `l` began to fade: when it was heard, or when a line was sent after it.
func _since(l: Dictionary) -> float:
	return maxf(l.at, _sent)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
