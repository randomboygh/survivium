extends HFlowContainer
## A row of small tabs under a window's tabs (the kinds of items in the craft tab and
## the bag): «Все» and the kinds given, the chosen one lit; wraps onto more rows when
## narrow. `picked` gives the key of the tab tapped ("" for «Все»).

const UiStyle := preload("res://src/client/ui_style.gd")

signal picked(key: String)

## The key of the tab chosen, "" for «Все».
var chosen := ""
var _keys: Array = []
var _buttons := {}
## The tab lit now ("-" before the first time).
var _lit := "-"


func _init() -> void:
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)


## Shows «Все» and tabs `keys` named by `names` (key -> name); a chosen tab that is gone
## gives way to «Все». True when that changed what is chosen.
func set_tabs(keys: Array, names: Dictionary) -> bool:
	var was := chosen
	if not keys.has(chosen):
		chosen = ""
	var all := [""] + keys
	if all != _keys:
		_keys = all
		for b in get_children():
			b.queue_free()
		_buttons = {}
		_lit = "-"
		for k in all:
			var b := small_button("Все" if k == "" else names.get(k, k), func() -> void: pick(k))
			add_child(b)
			_buttons[k] = b
	_light()
	return chosen != was


func pick(key: String) -> void:
	chosen = key
	_light()
	picked.emit(key)


func _light() -> void:
	if _lit == chosen:
		return
	_lit = chosen
	for k in _buttons:
		light(_buttons[k], k == chosen)


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
		var b: Button
		if p[0] is Texture2D:
			b = icon_button(p[0], p[1], p[2])
		else:
			b = small_button(p[0], p[2])
			b.tooltip_text = p[1]
		row.add_child(b)
	return row


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
