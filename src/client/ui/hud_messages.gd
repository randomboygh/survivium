extends "res://src/client/ui/hud_parts.gd"
## The game screen's interface, part two (hud.gd): the loading line, the short
## messages under the state (toast, notice) that come, rise and fade, and the hint by the
## mouse pointer.

## The room round the buttons and panels on the screen, in UI pixels, where a tap
## that just misses one does not reach the world (see covers).
const SAFE_ZONE := 8
const TOAST_TIME := 4.0
const MAX_TOASTS := 3
## How long a toast takes to come and to go, and how far it rises as it comes.
const TOAST_FADE := 0.35
const TOAST_RISE := 8.0
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


func _toast(text: String) -> void:
	# Each in a holder of its size, inside which it rises into place.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toasts.add_child(holder)
	var p := _panel(holder)
	p.add_child(UiStyle.label(text))
	p.minimum_size_changed.connect(func() -> void:
		p.reset_size()
		holder.custom_minimum_size = p.get_combined_minimum_size())
	_fit_toast(p)
	p.reset_size()
	holder.custom_minimum_size = p.get_combined_minimum_size()
	holder.modulate.a = 0.0
	p.position.y = TOAST_RISE
	var come := holder.create_tween().set_parallel()
	come.tween_property(holder, "modulate:a", 1.0, TOAST_FADE)
	come.tween_property(p, "position:y", 0.0, TOAST_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	holder.set_meta("tween", come)
	var life := holder.create_tween()
	life.tween_interval(TOAST_FADE + TOAST_TIME)
	life.tween_callback(_toast_leave.bind(holder))
	var shown := _toasts.get_children().filter(func(h: Node) -> bool: return not h.has_meta("leaving"))
	while shown.size() > MAX_TOASTS:
		_toast_leave(shown.pop_front())


## A notice in the list of toasts (see toast) that stands out: a gold star by `title`
## and a line `sub` under it, the panel warmed gold (a skill's new level, LevelUp).
func notice(title: String, sub: String) -> void:
	Lang.seen(title)
	Lang.seen(sub)
	_toast("★ " + Lang.t(title) + "\n" + Lang.t(sub))
	var holder: Control = _toasts.get_child(_toasts.get_child_count() - 1)
	if holder.get_child_count() > 0:
		var p: Control = holder.get_child(0)
		p.self_modulate = NOTICE_TINT
		var label := p.get_child(0) as Label
		if label != null:
			label.add_theme_color_override("font_color", UiStyle.ACCENT)


## Toast `holder` (see toast) fades away, the list sliding up by it as it goes.
func _toast_leave(holder: Control) -> void:
	if holder.has_meta("leaving"):
		return
	holder.set_meta("leaving", true)
	var come: Tween = holder.get_meta("tween")
	if come.is_valid():
		come.kill()
	var go := holder.create_tween()
	go.tween_method(func(a: float) -> void:
		holder.modulate.a = a
		_scroll_toasts(), holder.modulate.a, 0.0, TOAST_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	go.tween_callback(func() -> void:
		_toasts.remove_child(holder)
		holder.queue_free()
		_scroll_toasts())


## Moves the list of toasts up by the share of each toast leaving that has faded: the
## whole of it as it is gone, when the list closes up under it.
func _scroll_toasts() -> void:
	var off := 0.0
	var sep := _toasts.get_theme_constant("separation")
	for h: Control in _toasts.get_children():
		if h.has_meta("leaving"):
			off += (h.size.y + sep) * (1.0 - h.modulate.a)
	_toasts.position.y = -roundf(off)


## Wraps toast `p`'s text when it is wider than the room left of the buttons.
func _fit_toast(p: PanelContainer) -> void:
	var l: Label = p.get_child(0)
	var frame := p.get_theme_stylebox("panel").get_minimum_size().x
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
