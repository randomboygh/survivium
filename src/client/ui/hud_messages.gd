extends "res://src/client/ui/hud_parts.gd"
## The game screen's interface, part two (hud.gd): the loading line, the short
## messages under the state (toast, notice) and the server's notices to its host
## (server_note) that come, rise and fade (the UI kit's FadingList), and the hint by the
## mouse pointer.

## The room round the buttons and panels on the screen, in UI pixels, where a tap
## that just misses one does not reach the world (see covers).
const SAFE_ZONE := 8
const TOAST_TIME := 4.0
const MAX_TOASTS := 3
## How long a toast takes to come and to go (the UI kit's FadingList).
const TOAST_FADE := FadingList.TIME
## Seconds a server's notice to its host shows, how many show, the room after its mark.
const SERVER_NOTE_TIME := 6.0
const MAX_SERVER_NOTES := 3
const SERVER_MARK_GAP := 4
const KEYS := "[wasd_walk_space_jump_lmb]"


func set_loading(text: String) -> void:
	Lang.seen(text)
	_loading.visible = text != ""
	_loading_label.text = text
	_loading.reset_size()
	_loading.position = ((size - _loading.size) * 0.5).floor()


## A short message under the state, in a list of the last MAX_TOASTS: it comes into the
## end of the list out of nothing, rising a little; after TOAST_TIME, or when a newer one
## would make the list too long, the oldest fades up and away and the rest move up.
func toast(text: String) -> void:
	Lang.seen(text)
	_toast(text)


func _toast(text: String) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiStyle.label(text))
	var holder := _toasts.add(p)
	_fit_toast(p)
	var life := holder.create_tween()
	life.tween_interval(TOAST_FADE + TOAST_TIME)
	life.tween_callback(_toasts.drop.bind(holder))
	var shown := _toasts.shown()
	while shown.size() > MAX_TOASTS:
		_toasts.drop(shown.pop_front())
	return holder


## A notice in the list of toasts (see toast) that stands out: a gold star by `title`
## and a line `sub` under it, the panel warmed gold (a skill's new level, LevelUp).
func notice(title: String, sub: String) -> void:
	Lang.seen(title)
	Lang.seen(sub)
	var holder := _toast("★ " + Lang.t(title) + "\n" + Lang.t(sub))
	var p: Control = holder.get_child(0)
	p.self_modulate = NOTICE_TINT
	var label := p.get_child(0) as Label
	if label != null:
		label.add_theme_color_override("font_color", UiStyle.ACCENT)


## A notice of the server to its host (Protocol.NOTED: a player came or went, was not let
## in), `line` a phrase put together (Lang.line): in a list of its own under the toasts,
## cool-tinted with the server's mark, coming and going as they do, the last
## MAX_SERVER_NOTES kept for SERVER_NOTE_TIME each.
func server_note(line: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.self_modulate = SERVER_TINT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SERVER_MARK_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var mark := TextureRect.new()
	mark.texture = UiStyle.icon("server")
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	# The names in it are the players' own: the line is put into the language here.
	var label := UiStyle.label(Lang.t(line), UiStyle.COLD)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	print("server note: %s" % label.text)
	var holder := _server_notes.add(p)
	_fit_toast(p)
	var life := holder.create_tween()
	life.tween_interval(FadingList.TIME + SERVER_NOTE_TIME)
	life.tween_callback(_server_notes.drop.bind(holder))
	var shown := _server_notes.shown()
	while shown.size() > MAX_SERVER_NOTES:
		_server_notes.drop(shown.pop_front())


## Wraps toast `p`'s text when it is wider than the room left of the buttons.
func _fit_toast(p: PanelContainer) -> void:
	var l: Label = p.get_child(0) as Label
	var frame := p.get_theme_stylebox("panel").get_minimum_size().x
	if l == null:
		# A server's notice: its mark before the line.
		var row: Control = p.get_child(0)
		l = row.get_child(1)
		frame += (row.get_child(0) as Control).get_combined_minimum_size().x + SERVER_MARK_GAP
	var room := floorf(_toast_room - frame)
	var font := l.get_theme_font("font")
	var wide := 0.0
	for line: String in l.text.split("\n"):
		wide = maxf(wide, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)
	var wrap := wide + 1.0 > room
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = room if wrap else 0.0


## Hint next to the mouse pointer (`screen_pos` in screen pixels); empty text hides it.
func show_tip(screen_pos: Vector2, text: String, on_touch := false) -> void:
	_tip.visible = text != "" and (on_touch or not touch)
	if not _tip.visible:
		return
	_tip_label.text = text
	_tip.reset_size()
	var p := ((screen_pos - position) / scale.x + Vector2(12, 8)).floor()
	p.x = minf(p.x, size.x - _tip.size.x - 2)
	p.y = minf(p.y, size.y - _tip.size.y - 2)
	_tip.position = p
