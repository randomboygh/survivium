extends RefCounted
## Small buttons for the windows' rows of tabs and choices: a small button, one with a
## picture, buttons joined side by side (`split`), a block of them at a panel's corner,
## and lighting one amber (`light`). All static; the kinds row itself is IconTabs.

const UiStyle := preload("res://src/client/ui/ui_style.gd")


## A small square button with a picture (`texture`, an icon) and a tooltip.
static func icon_button(texture: Texture2D, tip: String, action: Callable) -> Button:
	var b := small_button("", action)
	b.icon = UiStyle.centred(texture)
	b.tooltip_text = tip
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.custom_minimum_size = Vector2(26, 24)
	return b


## Buttons side by side as one, their frames overlapping: `parts` are [picture or
## text, tooltip, action] each. The buttons are the row's children, in order.
static func split(parts: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", -2)
	for p in parts:
		row.add_child(_part(p))
	return row


## A block of buttons at the bottom right of a panel: a wide one (`wide`: [picture or
## text, tooltip, action], `width` across, as wide as the row) under the row `top`,
## joined to it (`joined`) or apart. The row is the first child, the wide one the second.
static func block(top: Control, wide: Array, width: int, joined := true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_theme_constant_override("separation", -2 if joined else 4)
	box.add_child(top)
	var b := _part(wide)
	b.custom_minimum_size = Vector2(width, 30)
	box.add_child(b)
	return box


## A button of `p`: [picture or text, tooltip, action].
static func _part(p: Array) -> Button:
	var b: Button
	if p[0] is Texture2D:
		b = icon_button(p[0], p[1], p[2])
	else:
		b = small_button(p[0], p[2])
		b.tooltip_text = p[1]
	return b


## Lights button `b` amber (a chosen tab, a button waiting for its second tap) or not.
static func light(b: Button, on: bool, danger := false) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, _box(state, on, danger))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UiStyle.DARK_INK if on else UiStyle.INK)


## A button smaller than the window's: a short row of tabs or a choice.
static func small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 24)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, _box(state, false))
	b.pressed.connect(action)
	return b


## The frames of the small buttons, made once (a frame is drawn pixel by pixel).
static var _boxes := {}


static func _box(state: String, on: bool, danger := false) -> StyleBox:
	var key := "%s:%s:%s" % [state, on, danger]
	if not _boxes.has(key):
		var box := UiStyle.button(state, on and not danger, danger)
		box.content_margin_left = 6
		box.content_margin_right = 6
		box.content_margin_top = 4
		box.content_margin_bottom = 6
		_boxes[key] = box
	return _boxes[key]
