extends VBoxContainer
## The chat on a server (plan/architecture/server.md, С6; plan/design/ui.md «Сообщения»):
## the last lines heard (Protocol.HEARD: the players within the chat's reach, the
## server's answers) in the bottom left corner, each fading after FADE seconds, and the
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

## Lines kept, lines shown while closed, seconds a line shows, and its fading at the end.
const KEPT := 30
const SHOWN := 5
const OPEN_SHOWN := 10
const FADE := 12.0
const FADE_OUT := 2.0
const WIDTH := 220
## Letters a line may have (Requests.CHAT_MAX on the server cuts it there too).
const MAX := 160

var game
## The lines heard: {"text", "color", "at" (seconds)}, the newest last.
var lines: Array[Dictionary] = []
var _list: VBoxContainer
var _row: PanelContainer
var _field: LineEdit
## Whom a line goes to: those near, or the team (shown only to one in a team).
var _to_team := false
var _whom: Button
## What the labels show (open, how many, of how many heard): they are made again when it changes.
var _shown_key := ""
## Lines heard in all: the shown lines change with it even once KEPT are kept.
var _heard := 0
## When a line was last sent (seconds): the lines heard before it fade from then on.
var _sent := -INF


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Runs only while lines fade (hear and open start it, _refresh stops it).
	set_process(false)
	add_theme_constant_override("separation", 4)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
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
	var line := text if who == "" else "%s: %s" % [who, text]
	if team:
		line = tr("[team_n2]") + line
	var color := UiStyle.MUTED if id == 0 else (UiStyle.TEAM if team else (UiStyle.ACCENT if own else UiStyle.INK))
	lines.append({"text": line, "color": color, "at": _now()})
	_heard += 1
	while lines.size() > KEPT:
		lines.pop_front()
	print("chat: %s" % line)
	_refresh()


## Puts the box's bottom left corner at `corner` (HUD units), `room` wide at most.
func place(corner: Vector2, room: float) -> void:
	custom_minimum_size.x = minf(WIDTH, room)
	for l: Label in _list.get_children():
		l.custom_minimum_size.x = custom_minimum_size.x
	reset_size()
	position = Vector2(corner.x, corner.y - size.y).floor()


func _process(_delta: float) -> void:
	_refresh()


## Shows the lines that are still fresh (all recent ones while open), fading the old.
func _refresh() -> void:
	var now := _now()
	var open := _row.visible
	var shown: Array[Dictionary] = []
	for i in range(lines.size() - 1, -1, -1):
		var l: Dictionary = lines[i]
		if shown.size() >= (OPEN_SHOWN if open else SHOWN) or (not open and now - _since(l) > FADE):
			break
		shown.push_front(l)
	var key := "%s|%d|%d" % [open, shown.size(), _heard]
	if key != _shown_key:
		_shown_key = key
		for c in _list.get_children():
			_list.remove_child(c)
			c.queue_free()
		for l: Dictionary in shown:
			var label := UiStyle.label(l.text, l.color)
			# Players' words as written (the server's are put into the language as heard).
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = custom_minimum_size.x
			label.add_theme_constant_override("outline_size", 4)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			_list.add_child(label)
		var bottom := position.y + size.y
		reset_size()
		position.y = floorf(bottom - size.y)
	set_process(not shown.is_empty() and not open)
	var labels := _list.get_children()
	for i in labels.size():
		var age: float = now - _since(shown[i])
		labels[i].modulate.a = 1.0 if open else clampf((FADE - age) / FADE_OUT, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if typing and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


## When line `l` began to fade: when it was heard, or when a line was sent after it.
func _since(l: Dictionary) -> float:
	return maxf(l.at, _sent)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
