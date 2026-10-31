extends VBoxContainer
## The chat on a server (plan/architecture/server.md, С6; plan/design/ui.md «Сообщения»):
## the last lines heard (Protocol.HEARD: the players within the chat's reach, the
## server's answers) in the bottom left corner, each fading after FADE seconds, and the
## field to say a line, opened by Enter or the chat button and closed by sending,
## Escape or the button again. While it is open all the recent lines show, the newest
## at the bottom. A line that begins with "/" is a host's command; the server answers
## it in the chat. `typing` keeps the keys from walking the character. `game` is the
## Main node; the HUD places the box (place).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

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
## What the labels show (open, how many, of how many heard): they are made again when it changes.
var _shown_key := ""


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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	_row.add_child(h)
	_field = LineEdit.new()
	_field.placeholder_text = "Сказать рядом…"
	_field.max_length = MAX
	_field.custom_minimum_size = Vector2(WIDTH - 40, 26)
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.select_all_on_focus = false
	_field.text_submitted.connect(func(_t: String) -> void: submit())
	h.add_child(_field)
	var send := Button.new()
	send.text = "›"
	send.tooltip_text = "Сказать"
	send.focus_mode = Control.FOCUS_NONE
	send.custom_minimum_size = Vector2(26, 26)
	send.pressed.connect(submit)
	h.add_child(send)


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
	_row.visible = true
	_field.grab_focus()
	_refresh()


func close() -> void:
	_field.release_focus()
	_row.visible = false
	_refresh()


## Says the line in the field (a command when it begins with "/") and closes it.
func submit() -> void:
	var text := _field.text.strip_edges()
	_field.text = ""
	close()
	if text != "" and game.net != null:
		print("chat: say %s" % text)
		game.net.request(Protocol.CHAT, [text])


## A line heard: said by player `id` named `who` (0 the server, "" for its answer).
func hear(id: int, who: String, text: String) -> void:
	var own: bool = id != 0 and id == int(game.welcome.get("id", -1))
	var line := text if who == "" else "%s: %s" % [who, text]
	var color := UiStyle.MUTED if id == 0 else (UiStyle.ACCENT if own else UiStyle.INK)
	lines.append({"text": line, "color": color, "at": _now()})
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
		if shown.size() >= (OPEN_SHOWN if open else SHOWN) or (not open and now - l.at > FADE):
			break
		shown.push_front(l)
	var key := "%s|%d|%d" % [open, shown.size(), lines.size()]
	if key != _shown_key:
		_shown_key = key
		for c in _list.get_children():
			_list.remove_child(c)
			c.queue_free()
		for l: Dictionary in shown:
			var label := UiStyle.label(l.text, l.color)
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
		var age: float = now - shown[i].at
		labels[i].modulate.a = 1.0 if open else clampf((FADE - age) / FADE_OUT, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if typing and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
