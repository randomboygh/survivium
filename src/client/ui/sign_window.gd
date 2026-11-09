extends Control
## The window a tap on a sign opens (decision 183): its name and its text, a field for
## each of its lines (its item's `sign_lines`, `sign_width` letters each) when the
## player may build where it stands (Territory "build", the client's copy of the land),
## else the text to read and who may write it. «Сохранить» writes the lines through the
## server (Protocol.SIGN_WRITE, Placed.write), «Повернуть» turns a sign that is not on a
## wall a quarter (SIGN_TURN), «Закрыть» or Escape closes it. It covers the whole screen
## over a shade of the world behind; when the keyboard leaves the screen too short, the
## panel goes to its top. `game` is the Main node. While a field has the keys, they do
## not walk the player (Controls._typing).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Items := preload("res://src/shared/content/items.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Lang := preload("res://src/shared/content/lang.gd")

const WIDTH := 240
const FIELD_H := 26
const ROW_H := 30
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)
const MARGIN := 8

signal closed

var game
## The north-west cell of the sign shown (Placed.at finds it again once it is written or
## turned: the record is set down anew).
var cell: Vector3i
var item: String
var _panel: PanelContainer
var _fields: Array[LineEdit] = []
var _note: Label


func _init(g, e: Dictionary) -> void:
	game = g
	cell = e.cell
	item = e.item


## True when the player may write on the sign (build where it stands).
func may_write() -> bool:
	var land = game.land
	if land == null:
		return true
	return land.copy.allowed(land.copy.claim_at(cell), land.me(), "build")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rec := Items.get_item(item)
	var text: String = game.placed.at(cell).get("text", "")
	var lines := text.split("\n")
	_panel = PanelContainer.new()
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var title := UiStyle.label(Lang.t(Items.title(item)), UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(title)
	var writes := may_write()
	if writes:
		for i in int(rec.get("sign_lines", 0)):
			var f := LineEdit.new()
			f.max_length = int(rec.get("sign_width", 20))
			f.placeholder_text = Lang.f("Строка %d", [(i + 1)])
			f.custom_minimum_size = Vector2(WIDTH, FIELD_H)
			f.select_all_on_focus = false
			f.text = lines[i] if i < lines.size() else ""
			f.text_submitted.connect(func(_t: String) -> void: _next_after(f))
			# The caret goes after the text written: a phone's keyboard is shown it as the
			# field takes the keys, before the tap's own place.
			f.focus_entered.connect(func() -> void: f.caret_column = f.text.length())
			box.add_child(f)
			_fields.append(f)
	else:
		var read := UiStyle.label(text if text != "" else "Здесь ничего не написано", UiStyle.INK if text != "" else UiStyle.MUTED)
		read.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if text != "":
			read.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		read.custom_minimum_size = Vector2(WIDTH, 0)
		box.add_child(read)
	_note = UiStyle.label("" if writes else "Писать может тот, кто строит на этой земле", UiStyle.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH, 0)
	_note.visible = _note.text != ""
	box.add_child(_note)
	if writes:
		box.add_child(_button("Сохранить", save, true))
		if not rec.get("wall", false):
			box.add_child(_button("Повернуть", turn))
	box.add_child(_button("Закрыть", close))
	get_parent().resized.connect(_fit)
	_fit()
	if not _fields.is_empty() and not game.controls.touch:
		_fields[0].grab_focus()


func _button(text: String, call: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(WIDTH, ROW_H)
	if accent:
		UiStyle.accent(b)
	b.pressed.connect(call)
	return b


## Enter in a field goes to the next one, in the last one saves.
func _next_after(f: LineEdit) -> void:
	var i := _fields.find(f)
	if i < _fields.size() - 1:
		_fields[i + 1].grab_focus()
	else:
		f.release_focus()
		save()


## True while one of the fields has the keys.
func typing() -> bool:
	for f in _fields:
		if f.has_focus():
			return true
	return false


## Writes the lines on the sign through the server and closes the window.
func save() -> void:
	var lines: Array[String] = []
	for f in _fields:
		lines.append(f.text)
	game.net.request(Protocol.SIGN_WRITE, [cell, "\n".join(lines)])
	close()


## Turns the sign a quarter (a signpost's arrow points another way); the window stays.
func turn() -> void:
	game.net.request(Protocol.SIGN_TURN, [cell])


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


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
