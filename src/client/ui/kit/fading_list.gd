extends VBoxContainer
## A list of short lines that come and go as the game's notifications do (UI kit): a
## line comes into its place out of nothing, rising a little while the list opens room
## for it; one sent away (drop) fades up into nothing while the list closes up after it.
## The toasts under the state (Hud.toast), the chat's lines (ChatBox) and the server's
## notices to its host (Hud.server_note) are such lists. A line is any Control, kept in a
## holder of its own (add returns it, its first child is the line) whose height opens
## and closes; the room between two lines is in the holders, so a line going takes its
## share with it. The list grows down from its top; for one that grows up (the chat) its
## owner keeps the list's bottom in place as its size changes.

## Seconds a line takes to come and to go, and how far it rises as it does.
const TIME := 0.35
const RISE := 8.0

## The room under each line, in UI pixels.
var gap := 4


func _init(between := 4) -> void:
	gap = between
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)


## Adds `line`, coming in: at the end, or before the holder `before` (one of this list's).
## Returns its holder.
func add(line: Control, before: Control = null) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.set_meta("open", 0.0)
	holder.modulate.a = 0.0
	holder.add_child(line)
	add_child(holder)
	if before != null and before.get_parent() == self:
		move_child(holder, before.get_index())
	line.minimum_size_changed.connect(_fit.bind(holder))
	if not is_inside_tree():
		# Out of the tree (built before it is shown, the tests) nothing moves: it is there.
		_open(1.0, holder)
		return holder
	_open(0.0, holder)
	var come := holder.create_tween()
	come.tween_method(_open.bind(holder), 0.0, 1.0, TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	holder.set_meta("tween", come)
	return holder


## Sends holder `holder` away: it fades up and the list closes up after it.
func drop(holder: Control) -> void:
	if holder == null or holder.get_parent() != self or holder.has_meta("leaving"):
		return
	holder.set_meta("leaving", true)
	if not is_inside_tree():
		_gone(holder)
		return
	var come: Tween = holder.get_meta("tween", null)
	if come != null and come.is_valid():
		come.kill()
	var go := holder.create_tween()
	go.tween_method(_close.bind(holder), float(holder.get_meta("open")), 0.0, TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	go.tween_callback(_gone.bind(holder))
	holder.set_meta("tween", go)


## The holders shown and not going, the first first.
func shown() -> Array[Control]:
	var out: Array[Control] = []
	for h: Control in get_children():
		if not h.has_meta("leaving"):
			out.append(h)
	return out


## Takes every line away at once.
func clear() -> void:
	for h in get_children():
		remove_child(h)
		h.queue_free()


## A line coming: share `k` of it shown, rising into its place.
func _open(k: float, holder: Control) -> void:
	holder.set_meta("open", k)
	holder.modulate.a = k
	(holder.get_child(0) as Control).position.y = roundf(RISE * (1.0 - k))
	_fit(holder)


## A line going: share `k` of it left, rising out of its place.
func _close(k: float, holder: Control) -> void:
	holder.set_meta("open", k)
	holder.modulate.a = minf(holder.modulate.a, k)
	(holder.get_child(0) as Control).position.y = -roundf(RISE * (1.0 - k))
	_fit(holder)


## The holder as wide as its line and as tall as the share of it shown, the room under it
## included; the line at its size.
func _fit(holder: Control) -> void:
	var line: Control = holder.get_child(0)
	var want := line.get_combined_minimum_size()
	line.size = want
	holder.custom_minimum_size = Vector2(want.x, roundf((want.y + gap) * float(holder.get_meta("open"))))


func _gone(holder: Control) -> void:
	if holder.get_parent() == self:
		remove_child(holder)
	holder.queue_free()
