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
const FadingList := preload("res://src/client/ui/kit/fading_list.gd")
const ChatBox := preload("res://src/client/ui/chat_box.gd")
const VitalsPanel := preload("res://src/client/ui/vitals_panel.gd")
const Hud := preload("res://src/client/ui/hud.gd")
const MapView := preload("res://src/client/ui/map_view.gd")
const Minimap := preload("res://src/client/ui/minimap.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const MenuBackdrop := preload("res://src/client/ui/menu_backdrop.gd")


func run() -> void:
	_test_two_tap()
	_test_choice_rows()
	_test_window()
	_test_strip()
	_test_vitals()
	_test_gallery()
	_test_fading_list()
	_test_chat_lines()
	_test_pc_scales()
	_test_menu_sparrow()
	_test_map_fit()


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
	_test_switch_rows()


## A row of only off and on is a switch; a row that stops at its ends has the arrow
## towards the end it is at off.
func _test_switch_rows() -> void:
	var rows := ChoiceRows.new()
	var box := VBoxContainer.new()
	var v := {"on": 1, "flip": 0, "vol": 0, "dead": 1}
	rows.add(box, "On", ["[off]", "[on]"], func() -> int: return v.on, func(i: int) -> void: v.on = i)
	rows.add(box, "Flip", ["[on]", "[off]"], func() -> int: return v.flip, func(i: int) -> void: v.flip = i)
	rows.add(box, "Vol", ["[off]", "50%", "100%"], func() -> int: return v.vol, func(i: int) -> void: v.vol = i, {"stop": true})
	rows.add(box, "Dead", ["[off]", "[on]"], func() -> int: return v.dead, func(i: int) -> void: v.dead = i,
		{"works": func() -> bool: return false})
	rows.refresh()
	_check(rows.rows[0].has("switch") and rows.rows[0].left == null and rows.rows[0].switch.button_pressed,
		"a row of off and on is a switch, lit when on")
	_check(rows.rows[1].switch.button_pressed and rows.rows[1].on == 0, "on first in the values is lit too")
	_check(not rows.rows[2].has("switch"), "a row of more values keeps its arrows")
	var told := [-1]
	rows.stepped.connect(func(i: int) -> void: told[0] = i)
	rows.rows[0].switch.button_pressed = false
	_check(v.on == 0 and told[0] == 0 and rows.text_of(0) == "[off]", "a tap on the switch turns the value and tells it")
	rows.step(1, 1)
	_check(v.flip == 0, "right on a switch that is on leaves it on")
	rows.step(1, -1)
	_check(v.flip == 1 and not rows.rows[1].switch.button_pressed, "left turns it off")
	rows.rows[3].switch.button_pressed = false
	_check(v.dead == 1 and rows.rows[3].switch.button_pressed and rows.rows[3].switch.disabled,
		"a switch that cannot change stays and is off for taps")
	_check(rows.rows[2].left.disabled and not rows.rows[2].right.disabled, "at the first value the left arrow of a stopping row is off")
	rows.step(2, 1)
	rows.step(2, 1)
	_check(v.vol == 2 and rows.rows[2].right.disabled and not rows.rows[2].left.disabled, "at the last the right one")
	# A tap on a switch row's name turns it too; a finger that moved (scrolled) does not.
	var name: Label = rows.rows[0].name
	name.size = Vector2(100, 20)
	_tap_name(name, Vector2(10, 10), Vector2(12, 10))
	_check(v.on == 1 and rows.rows[0].switch.button_pressed, "a tap on the name of a switch's row turns it")
	_tap_name(name, Vector2(10, 10), Vector2(10, 40))
	_check(v.on == 1, "a finger dragged from the name turns nothing")
	rows.rows[3].name.size = Vector2(100, 20)
	_tap_name(rows.rows[3].name, Vector2(10, 10), Vector2(10, 10))
	_check(v.dead == 1, "nor does a tap on the name of a switch that cannot change")
	var sw := Kit.check("A", true)
	_check(sw.button_pressed and sw.text == "A", "the kit's switch carries its name and value")
	sw.free()
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
	# A window of a set width keeps it whatever it shows (a long note, a list's bar),
	# and a text straight in its column keeps the rows' room from the frame.
	var screen := Control.new()
	screen.size = Vector2(400, 600)
	var win := Control.new()
	win.set_script(KitWindow)
	screen.add_child(win)
	var column: VBoxContainer = win.build("Окно", 6, 200.0)
	var note := Kit.note("")
	column.add_child(note)
	var rows := Kit.column(4)
	var row := Kit.button("ряд", Callable(), 150, 30)
	rows.add_child(row)
	var list := Kit.scroll(rows, false)
	column.add_child(list)
	win.fit()
	var wide: float = win.panel.size.x
	note.text = "Очень длинная надпись, которая не помещается в одну строку окна и переносится"
	win.fit()
	_check(win.panel.size.x == wide, "a long note wraps: the window keeps its width")
	_check(note.get_theme_stylebox("normal").content_margin_left == UiStyle.BAR_GAP,
		"a text in a window's column keeps the rows' room from the frame")
	var room: MarginContainer = list.get_child(0)
	var before := list.get_combined_minimum_size().x
	UiStyle.bar_room(room, true, list)
	_check(list.get_combined_minimum_size().x == before, "a list is as wide with its bar shown as without")
	UiStyle.bar_room(room, false, list)
	screen.free()


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
	_check(is_equal_approx(canvas.custom_minimum_size.x, narrow) and panel.columns.is_empty(),
		"and shrinks back to the health bar: nothing low shows no standing bar")
	var thirsty := Vitals.new()
	thirsty.water = 10.0
	panel.update(thirsty, 0.1, false)
	_check(panel.columns == ["water"], "a low one shows alone")
	panel.pinned = true
	panel.update(thirsty, 0.1, false)
	_check(panel.columns.size() == 4, "all of them with the bag open")
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


## A list of lines that come and go (FadingList), built out of the tree as the tests
## are: there nothing moves, a line is there at once and one dropped is gone.
func _test_fading_list() -> void:
	var list := FadingList.new()
	var first := list.add(Label.new())
	var second := list.add(Label.new())
	var top := list.add(Label.new(), first)
	_check(list.get_child(0) == top and list.get_child(1) == first and list.get_child(2) == second,
		"a line put before another comes in above it")
	_check(first.get_child(0) is Label and first.modulate.a == 1.0 and first.custom_minimum_size.y == (first.get_child(0) as Control).get_combined_minimum_size().y + list.gap
		and first.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN, "a line is in a holder as tall as it and the room under it")
	list.drop(first)
	_check(list.shown() == [top, second] and list.get_child_count() == 2, "a line dropped is gone")
	list.clear()
	_check(list.get_child_count() == 0, "clear takes every line at once")
	list.free()


## The chat's lines in its list: the last SHOWN heard show, the newest at the bottom.
func _test_chat_lines() -> void:
	var chat = ChatBox.new({"link": {"welcome": {"id": 1}, "join_url": "ws://x"}})
	chat._ready()
	chat.place(Vector2(8, 300), 400)
	var watching := Lang.watching
	Lang.watching = false
	for i in ChatBox.SHOWN + 2:
		chat.hear(2, "Боря", "строка %d" % i)
	Lang.watching = watching
	var shown: Array = chat._list.shown()
	_check(shown.size() == ChatBox.SHOWN and chat._shown.size() == ChatBox.SHOWN,
		"the chat shows its last %d lines: %d" % [ChatBox.SHOWN, shown.size()])
	_check(not shown.is_empty() and (shown.back().get_child(0) as Label).text == "Боря: строка %d" % (ChatBox.SHOWN + 1)
		and (shown.front().get_child(0) as Label).text == "Боря: строка 2", "the newest at the bottom, the older ones gone")
	chat.free()


## The interface's scale on a computer (Hud.pc_scale): smaller than on a phone, ×2 on a
## 1080 px screen, and each of the five sizes differs from the next there and on larger ones.
func _test_pc_scales() -> void:
	_check(Hud.pc_scale(1080, 2) == 2.0, "a 1080 px screen gets x2 at the normal size")
	_check(Hud.pc_scale(1440, 2) == 3.0, "a 1440 px screen gets x3")
	_check(Hud.pc_scale(768, 2) == 1.5, "a 768 px laptop gets x1.5")
	for side in [950, 1080, 1440, 2160]:
		var last := 0.0
		for size in 5:
			var s := Hud.pc_scale(side, size)
			_check(s > last, "size %d is larger than the one before on %d px" % [size, side])
			last = s
	_check(Hud.pc_scale(300, 0) == 1.0, "never under a screen pixel per UI pixel")


## The whole map fills a phone held upright, whatever size it was laid out at before,
## and its hint, in the player's language, stays inside the panel.
func _test_map_fit() -> void:
	var map := MapView.new()
	map.minimap = Minimap.new()
	map._ready()
	var phone := Vector2(400, 820)
	for before: Vector2 in [Vector2(90, 400), Vector2(820, 400), phone]:
		map.fit(before, true)
		map.fit(phone, true)
		_check(map.well.size.y > phone.y * 0.7, "the map fills the screen after %s: %s" % [before, map.well])
		var text := Lang.t(map._hint.text)
		var widest := UiStyle.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE).x
		var wraps: bool = map._hint.autowrap_mode != TextServer.AUTOWRAP_OFF
		var inside: bool = map._hint.position.x >= MapView.MARGIN and map._hint.position.x \
				+ (map._hint.size.x if wraps else widest) <= phone.x - MapView.MARGIN
		_check(inside and map._hint.position.y > map.well.end.y, "the hint stays inside, under the map")
	# A pinch, then the fingers lifted one after the other: the one left a moment
	# longer does not drag the map.
	var a := Vector2(150, 400)
	var b := Vector2(250, 400)
	_touch(map, 0, a, true)
	_touch(map, 1, b, true)
	_drag(map, 0, a + Vector2(-40, 0))
	_drag(map, 1, b + Vector2(40, 0))
	_touch(map, 1, b + Vector2(40, 0), false)
	var held := map.centre
	_drag(map, 0, a + Vector2(-40, 60))
	_touch(map, 0, a + Vector2(-40, 60), false)
	_check(map.centre == held, "the finger left after a pinch does not move the map")
	# One finger alone drags it by as far as it moved.
	_touch(map, 0, a, true)
	_drag(map, 0, a + Vector2(20, 0))
	_drag(map, 0, a + Vector2(40, 0))
	_touch(map, 0, a + Vector2(40, 0), false)
	_check(map.centre.x < held.x and is_equal_approx(map.centre.y, held.y), "one finger drags the map")
	map.minimap.free()
	map.free()
	# A key is measured as its words in the player's language.
	_check(UiStyle.text_width("[a_tap_places_a_marker]") == UiStyle.text_width(Lang.t("[a_tap_places_a_marker]")),
		"a key measures as its words")


## Where each test finger is, so a drag carries its `relative` as the engine's do.
var _at := {}


## A left click on `label` pressed at `from` and let go at `to` (its own pixels).
func _tap_name(label: Label, from: Vector2, to: Vector2) -> void:
	for at: Vector2 in [from, to]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = at == from and not label.has_meta("tap_at")
		e.position = at
		e.global_position = at
		label.gui_input.emit(e)


func _touch(c: Control, index: int, at: Vector2, down: bool) -> void:
	_at[index] = at
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = down
	c._input(e)
	c._gui_input(e)


func _drag(c: Control, index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	e.relative = at - (_at.get(index, at) as Vector2)
	_at[index] = at
	c._gui_input(e)


## The sparrow on the menu's name (the way into the playtest switches) stays when the world
## chosen was played without the sparrow's bundle: the menu then finds no such creature
## loaded, at the start too (the record is read from the bundle on disk), and after.
func _test_menu_sparrow() -> void:
	var id := "animals:sparrow"
	MenuBackdrop._sparrow_kept = []
	var cold = MenuBackdrop.new()
	cold._take_sparrow({}, id)
	_check(cold._sparrow_picture != null and cold._sparrow_frames > 1 and cold._sparrow_views == 3,
		"the menu's sparrow comes from the bundle on disk with no sparrow loaded")
	MenuBackdrop._sparrow_kept = []
	var first = MenuBackdrop.new()
	first._take_sparrow(AiRules.SPECIES.get(id, {}), id)
	_check(first._sparrow_picture != null and first._sparrow_frames == cold._sparrow_frames
		and first._sparrow_walk == cold._sparrow_walk, "the menu's sparrow from the creatures loaded is the one on disk")
	var again = MenuBackdrop.new()
	again._take_sparrow({}, id)
	_check(again._sparrow_picture == first._sparrow_picture and again._sparrow_views == first._sparrow_views,
		"the menu's sparrow stays with no sparrow in the creatures loaded")
	for m in [cold, first, again]:
		m.free()
