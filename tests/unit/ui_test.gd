extends "res://tests/unit/test_case.gd"
## The interface's own pieces, built headless: «Витрина интерфейса» (ui_gallery.gd) makes
## every tab without a script error, and its elements answer a tap.

const UiGallery := preload("res://src/client/ui/ui_gallery.gd")


func run() -> void:
	_test_gallery()


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
		_check(gallery._panel.position.x >= 0.0 and gallery._panel.position.y >= 0.0, "tab %s sits on the screen" % s[0])
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
