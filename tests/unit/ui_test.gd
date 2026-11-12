extends "res://tests/unit/test_case.gd"
## The interface's own pieces, built headless: the UI kit (src/client/ui/kit/: a button
## that asks first, rows «name ‹ value ›», a window, a strip of cells), and «Витрина интерфейса»
## (ui_gallery.gd), which makes every tab without a script error, its elements answering a tap.

const UiGallery := preload("res://src/client/ui/ui_gallery.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const KitWindow := preload("res://src/client/ui/kit/window.gd")
const SlotStrip := preload("res://src/client/ui/kit/slot_strip.gd")
const VitalsPanel := preload("res://src/client/ui/vitals_panel.gd")


func run() -> void:
	_test_two_tap()
	_test_choice_rows()
	_test_window()
	_test_strip()
	_test_vitals()
	_test_gallery()


func _test_two_tap() -> void:
	var asks := TwoTap.new()
	var a := Kit.button("a")
	var b := Kit.button("b")
	var done := [0]
	asks.guard(a, func() -> void: done[0] += 1)
	asks.guard(b, func() -> void: done[0] += 10)
	a.pressed.emit()
	_check(done[0] == 0 and asks.armed == a, "the first tap only asks")
	b.pressed.emit()
	_check(done[0] == 0 and asks.armed == b, "a tap on another asks with that one instead")
	b.pressed.emit()
	_check(done[0] == 10 and asks.armed == null, "the second tap on the same one does it")
	a.free()
	b.free()


func _test_choice_rows() -> void:
	var rows := ChoiceRows.new()
	var box := VBoxContainer.new()
	var v := {"a": 0, "b": -1, "c": 0, "d": 1}
	rows.add(box, "A", ["x", "y", "z"], func() -> int: return v.a, func(i: int) -> void: v.a = i, {"skip": 2})
	rows.add(box, "B", ["x", "y"], func() -> int: return v.b, func(i: int) -> void: v.b = i, {"other": "своё"})
	rows.add(box, "C", ["off", "on"], func() -> int: return v.c, func(i: int) -> void: v.c = i,
		{"works": func() -> bool: return false})
	rows.add(box, "D", ["off", "on"], func() -> int: return v.d, func(i: int) -> void: v.d = i, {"direct": true})
	rows.refresh()
	_check(rows.rows[1].label.text == "своё", "a row shows its other text when none of its values is chosen")
	_check(rows.rows[2].left.disabled and rows.rows[2].row.modulate.a < 1.0, "a row that cannot change is faded, its arrows off")
	rows.step(0, 1)
	rows.step(0, 1)
	_check(v.a == 0, "the arrows pass over the value to skip, round the ends (%d)" % v.a)
	rows.step(1, -1)
	_check(v.b == 1 and rows.rows[1].label.text == "y", "from none, left picks the last")
	rows.step(2, 1)
	_check(v.c == 0, "a row that cannot change does not")
	rows.step(3, 1)
	_check(v.d == 1, "a direct row goes straight to the last, not round")
	var stepped := [-1]
	rows.stepped.connect(func(i: int) -> void: stepped[0] = i)
	rows.set_focus(-1)
	_check(rows.focus == 3, "the focus goes round the ends")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_LEFT
	_check(rows.key(ev) and v.d == 0 and stepped[0] == 3, "left steps the row in focus and tells it")
	box.free()


func _test_window() -> void:
	for tall in [true, false]:
		var host := Control.new()
		host.size = Vector2(300, 200)
		var w := Control.new()
		w.set_script(KitWindow)
		host.add_child(w)
		var box: VBoxContainer = w.build("Окно")
		var inside := Control.new()
		inside.custom_minimum_size = Vector2(100, 400 if tall else 20)
		box.add_child(inside)
		w.fit()
		_check(w.size == host.size, "a window covers the screen")
		if tall:
			_check(w.panel.position.y == KitWindow.MARGIN, "a panel taller than the screen stands at its top (the keyboard is up)")
		else:
			_check(absf(w.panel.position.y - (host.size.y - w.panel.size.y) * 0.5) <= 1.0, "a short one stands in the middle")
		host.free()


func _test_strip() -> void:
	var strip := SlotStrip.new()
	var moved := [0]
	strip.scrolled.connect(func() -> void: moved[0] += 1)
	strip.set_counts(8, 8)
	_check(not strip.prev.visible, "a strip whose things all fit has no arrows")
	strip.set_counts(8, 3)
	_check(strip.prev.visible and strip.prev.disabled and not strip.next.disabled, "else arrows, the first one off")
	for i in 9:
		strip.next.pressed.emit()
	_check(strip.first == 5 and strip.next.disabled and moved[0] == 5 and strip.is_shown(7) and not strip.is_shown(4),
		"the arrows move a cell at a time and stop at the end (first %d)" % strip.first)
	strip.set_counts(4, 3)
	_check(strip.first == 1, "fewer things keep the first in range")
	_check(SlotStrip.fitting(8 * 44.0, 8, 8) == 8 and SlotStrip.fitting(200.0, 8, 4) == 3,
		"as many cells as fit: all of them, or between the arrows")
	strip.free()


## The state panel: what hinders the body, and the panel widening for its column.
func _test_vitals() -> void:
	var v := Vitals.new()
	_check(VitalsPanel.debuffs_of(v, false).is_empty(), "a rested dry body has nothing hindering it")
	v.wet = 0.5
	v.stamina = 2.0
	_check(VitalsPanel.debuffs_of(v, true) == ["wet", "tired", "heavy"], "wet, out of breath, overloaded, in order")
	var panel := VitalsPanel.new()
	panel._ready()
	var canvas: Control = panel._canvas
	var narrow := canvas.custom_minimum_size.x
	panel.update(v, 0.1, true)
	_check(canvas.custom_minimum_size.x > narrow and panel.visible, "the panel widens for the column and shows")
	panel.update(Vitals.new(), 0.1, false)
	_check(is_equal_approx(canvas.custom_minimum_size.x, narrow), "and shrinks back to the moon")
	panel.free()


func _test_gallery() -> void:
	# The tests run before the tree's first frame: the window is built out of it, its
	# _ready called by hand.
	var host := Control.new()
	host.size = Vector2(400, 860)
	var gallery = UiGallery.new(null)
	host.add_child(gallery)
	gallery._ready()
	for s: Array in UiGallery.SECTIONS:
		gallery.show_section(s[0])
		_check(gallery.section == s[0], "the gallery shows tab %s" % s[0])
		_check(gallery._list.get_child_count() > 1, "tab %s has elements" % s[0])
		_check(gallery.panel.position.x >= 0.0 and gallery.panel.position.y >= 0.0, "tab %s sits on the screen" % s[0])
	# A settings row: its right arrow steps the value and tells it.
	gallery.show_section("rows")
	var row: HBoxContainer = null
	for c in gallery._list.get_children():
		if c is HBoxContainer and c.get_child_count() == 4:
			row = c
			break
	_check(row != null, "the rows tab has a settings row")
	if row != null:
		var before: String = (row.get_child(2) as Label).text
		(row.get_child(3) as Button).pressed.emit()
		_check((row.get_child(2) as Label).text != before, "the right arrow changes the value")
		_check(gallery._said.text.contains((row.get_child(2) as Label).text), "and the line under the page tells it")
	# A slot tapped is chosen.
	gallery.show_section("slots")
	gallery._add_weight(100.0)
	_check(gallery._weight == UiGallery.LIMIT * 2.0, "the weight stops at twice the bag's limit")
	var closed := [false]
	gallery.closed.connect(func() -> void: closed[0] = true)
	gallery.close()
	_check(closed[0], "«Закрыть» tells it closed")
	host.free()
