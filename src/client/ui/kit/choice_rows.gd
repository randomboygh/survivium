extends RefCounted
## Rows «name ‹ value ›» of the UI kit (kit.gd): the settings, «Тестирование», «Новый
## мир» and its mods. Each row shows one of its `values`, read by its getter; its
## arrows set the previous or the next through its setter, round the ends. The rows go
## where the owner puts them (`add` takes the parent); the owner keeps one ChoiceRows
## per page and `clear`s it when the page is made anew. The row in focus has its name
## lit amber: up and down move it, left and right step it (`key`). `stepped` tells the
## owner a row was stepped, after its values are shown again.
## A row's options: "other" — the text when the getter gives -1 (none of the values);
## "works" — a Callable telling whether it can change now (else faded, arrows off);
## "show" — a text standing in for the value; "direct" — the arrows go straight to the
## first and the last value; "stop" — the arrows stop at the ends, not going round;
## "skip" — a value the arrows pass over; "open" — what an
## extra button after the arrows does (its icon "open_icon", tooltip "open_tip"); "name_width";
## "wrap" — the name wraps (else it is cut with an ellipsis); "switch" — false keeps
## the arrows on a row of «выкл | вкл».
## A row whose values are only off and on (SWITCHES) is a switch (switch.gd) in place of
## the arrows and the value: a tap turns it, left turns it off and right on.
## The arrows of a row that stops at its ends ("stop", "direct") are off at that end.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const Switch := preload("res://src/client/ui/kit/switch.gd")

## The pairs of values that make a row a switch: [off, on].
const SWITCHES := [["[off]", "[on]"], ["[hidden]", "[shown]"]]

## Row `index` was stepped by the player.
signal stepped(index: int)

## The rows, in order: name (Label), values, get, set, label (the value's Label or null),
## left and right (the arrows or null), row (the box), and the options above.
var rows: Array[Dictionary] = []
## The row in focus, -1 for none.
var focus := -1
var name_width := 112.0
var value_width := 84.0
var arrow := Kit.SQUARE
## The list the rows scroll in, kept in sight as the focus moves (none: not scrolled).
var scroll: ScrollContainer = null


func _init(name_w := 112.0, value_w := 84.0, arrow_side := Kit.SQUARE) -> void:
	name_width = name_w
	value_width = value_w
	arrow = arrow_side


## The width of a whole row: name, arrows and value.
func width() -> float:
	return name_width + value_width + 2 * arrow + 3 * 2


## Adds a row to `parent` (see the options above) and returns its box.
func add(parent: Node, name: String, values: Array, getter: Callable, setter: Callable, opts := {}) -> HBoxContainer:
	var row := Kit.row(2)
	parent.add_child(row)
	var label := _name(name, opts)
	row.add_child(label)
	var index := rows.size()
	var on := switch_on(values) if opts.get("switch", true) else -1
	if on >= 0:
		# In the room of the arrows and the value, its track at the right end; "show"
		# stands left of it (a mod's «3 из 5»), "open" after it.
		var sw := Switch.new(opts.get("show", ""))
		sw.alignment = HORIZONTAL_ALIGNMENT_CENTER
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			sw.add_theme_color_override(c, UiStyle.MUTED)
		var room := value_width + 2 * arrow + 2 * 2
		if opts.has("open"):
			room -= arrow + 2
		sw.custom_minimum_size = Vector2(room, arrow)
		sw.toggled.connect(_switched.bind(index))
		row.add_child(sw)
		if opts.has("open"):
			row.add_child(Kit.icon_button(opts.get("open_icon", "menu"), opts.get("open_tip", "[whats_included]"), opts.open, arrow))
		var r := {"name": label, "values": values, "get": getter, "set": setter, "label": null, "left": null,
			"right": null, "row": row, "switch": sw, "on": on}
		r.merge(opts)
		rows.append(r)
		return row
	var left := _arrow(row, "prev", index, -1)
	var value := UiStyle.label()
	value.custom_minimum_size = Vector2(value_width, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)
	var right := _arrow(row, "next", index, 1)
	if opts.has("open"):
		row.add_child(Kit.icon_button(opts.get("open_icon", "menu"), opts.get("open_tip", "[whats_included]"), opts.open, arrow))
	var r := {"name": label, "values": values, "get": getter, "set": setter, "label": value, "left": left,
		"right": right, "row": row}
	r.merge(opts)
	rows.append(r)
	return row


## A row of the owner's own making (a field, a count with a button) that takes the
## focus like the others: its name `label`; right (or Enter) on it does `open`.
func add_custom(label: Label, open := Callable()) -> int:
	rows.append({"name": label, "values": [], "get": Callable(), "set": Callable(), "label": null,
		"left": null, "right": null, "row": label.get_parent(), "open": open})
	return rows.size() - 1


## A name label as the rows have it, for a custom row.
func name_label(name: String, opts := {}) -> Label:
	return _name(name, opts)


## Where «on» is in `values` when they are only off and on (SWITCHES), else -1.
static func switch_on(values: Array) -> int:
	if values.size() != 2:
		return -1
	for pair: Array in SWITCHES:
		if values.has(pair[0]) and values.has(pair[1]):
			return values.find(pair[1])
	return -1


## The text of row `i`'s value now (a switch's too).
func text_of(i: int) -> String:
	var r: Dictionary = rows[i]
	if r.label != null:
		return r.label.text
	var v: int = r.get.call()
	return r.values[clampi(v, 0, r.values.size() - 1)] if v >= 0 else r.get("other", "")


## Forgets the rows (the owner frees their boxes).
func clear() -> void:
	rows.clear()
	focus = -1


## Shows every row's value from its getter, fades the rows that cannot change now;
## whether a value's text changed.
func refresh() -> bool:
	var changed := false
	for r in rows:
		if r.has("switch"):
			var sw: Switch = r.switch
			var lit: bool = r.get.call() == r.on
			if sw.button_pressed != lit:
				sw.show_value(lit)
				changed = true
			sw.disabled = not works(r)
			r.row.modulate.a = 1.0 if not sw.disabled else 0.4
			continue
		if r.label == null:
			continue
		var text: String = r.get("show", "")
		if text == "":
			var i: int = r.get.call()
			var other: String = r.get("other", "")
			text = other if i < 0 and other != "" else r.values[clampi(i, 0, r.values.size() - 1)]
		if r.label.text != text:
			r.label.text = text
			changed = true
		var on := works(r)
		# A row that stops at its ends has the arrow towards an end off there.
		var ends: bool = r.get("stop", false) or r.get("direct", false)
		var at: int = r.get.call()
		r.left.disabled = not on or (ends and at == 0)
		r.right.disabled = not on or (ends and at == r.values.size() - 1)
		r.row.modulate.a = 1.0 if on else 0.4
	return changed


## Whether row `r` can change now.
static func works(r: Dictionary) -> bool:
	var w: Callable = r.get("works", Callable())
	return not w.is_valid() or w.call()


## Picks the next (`dir` 1) or the previous value of row `i`, round the ends; from none
## of them (-1) the first or the last. A custom row opens on a step right.
func step(i: int, dir: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var r: Dictionary = rows[i]
	var n: int = r.values.size()
	if n == 0:
		var open: Callable = r.get("open", Callable())
		if dir > 0 and open.is_valid():
			open.call()
		return
	if not works(r):
		return
	var cur: int = r.get.call()
	var next: int
	if r.has("switch"):
		next = r.on if dir > 0 else 1 - r.on
		if next == cur:
			return
	elif r.get("direct", false):
		next = 0 if dir < 0 else n - 1
	elif cur < 0:
		next = 0 if dir > 0 else n - 1
	elif r.get("stop", false):
		next = clampi(cur + dir, 0, n - 1)
	else:
		next = posmod(mini(cur, n - 1) + dir, n)
		if next == r.get("skip", -1):
			next = posmod(next + dir, n)
	r.set.call(next)
	refresh()
	stepped.emit(i)


## Puts the focus on row `i` (round the ends) and lights its name.
func set_focus(i: int) -> void:
	if rows.is_empty():
		focus = -1
		return
	focus = posmod(i, rows.size())
	for j in rows.size():
		rows[j].name.add_theme_color_override("font_color", UiStyle.ACCENT if j == focus else UiStyle.INK)
	if scroll != null and scroll.is_inside_tree():
		scroll.ensure_control_visible(rows[focus].name)


## Up and down move the focus, left and right step its row; whether `event` was one.
func key(event: InputEvent) -> bool:
	if rows.is_empty() or not (event is InputEventKey and event.pressed):
		return false
	match event.physical_keycode:
		KEY_UP, KEY_W:
			set_focus(focus - 1)
		KEY_DOWN, KEY_S:
			set_focus(focus + 1)
		KEY_LEFT, KEY_A:
			step(focus, -1)
		KEY_RIGHT, KEY_D:
			step(focus, 1)
		_:
			return false
	return true


func _name(name: String, opts: Dictionary) -> Label:
	var label := UiStyle.label(name)
	label.custom_minimum_size = Vector2(opts.get("name_width", name_width), 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if opts.get("wrap", false):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _arrow(row: Node, icon: String, index: int, dir: int) -> Button:
	var b := Kit.icon_button(icon, "", _pressed.bind(index, dir), arrow)
	row.add_child(b)
	return b


## Switch `index` was turned by a tap: its value follows.
func _switched(on: bool, index: int) -> void:
	set_focus(index)
	var r: Dictionary = rows[index]
	if not works(r):
		refresh()
		return
	r.set.call(r.on if on else 1 - r.on)
	refresh()
	stepped.emit(index)


func _pressed(index: int, dir: int) -> void:
	set_focus(index)
	step(index, dir)
