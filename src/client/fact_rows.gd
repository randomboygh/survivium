extends GridContainer
## What a thing is, in rows of «name: value» (plan/design/ui.md, section 5): the
## recipe chosen in the craft tab (what it needs, where, how long, then what it makes)
## and the stack chosen in the bag. A value is words or small wells with a picture and
## a few letters (have / need, «нет»), short ones in red. See item_rows for the rows
## every item has.

const UiStyle := preload("res://src/client/ui_style.gd")
const Items := preload("res://src/shared/items.gd")
const Workshop := preload("res://src/client/workshop.gd")

## The width of the names, in UI pixels.
const NAME_WIDTH := 60

var _names := []
var _values := []


func _init() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 4)


## Shows `rows`: [name, value] each, a value being words or an Array of wells
## [picture, letters, short, tooltip].
func show_rows(rows: Array) -> void:
	while _names.size() < rows.size():
		var name := UiStyle.label("", UiStyle.MUTED)
		name.custom_minimum_size.x = NAME_WIDTH
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(name)
		_names.append(name)
		var value := HFlowContainer.new()
		value.add_theme_constant_override("h_separation", 4)
		value.add_theme_constant_override("v_separation", 4)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.add_child(UiStyle.label())
		add_child(value)
		_values.append(value)
	for i in _names.size():
		var shown := i < rows.size()
		_names[i].visible = shown
		_values[i].visible = shown
		if shown:
			_names[i].text = rows[i][0]
			_show_value(_values[i], rows[i][1])


## The rows of `value` laid out at `w` UI pixels across (a flow is measured at its
## least width).
func fit_width(w: int) -> void:
	for v in _values:
		v.custom_minimum_size.x = w - NAME_WIDTH - 6


func _show_value(box: HFlowContainer, value) -> void:
	var words: Label = box.get_child(0)
	words.visible = value is String
	if value is String:
		words.text = value
	var wells: Array = value if value is Array else []
	while box.get_child_count() - 1 < wells.size():
		box.add_child(_well())
	for i in range(1, box.get_child_count()):
		var well: PanelContainer = box.get_child(i)
		well.visible = i - 1 < wells.size()
		if well.visible:
			var w: Array = wells[i - 1]
			var row := well.get_child(0)
			row.get_child(0).texture = w[0]
			var label: Label = row.get_child(1)
			label.text = w[1]
			label.visible = w[1] != ""
			label.add_theme_color_override("font_color", UiStyle.DANGER if w[2] else UiStyle.INK)
			well.tooltip_text = w[3]


## A small well with a picture and a few letters.
static func _well() -> PanelContainer:
	var p := PanelContainer.new()
	var box := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, 3)
	p.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(12, 12)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := UiStyle.label()
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return p


## The rows every item has, for `count` of item `id` worn by `worn` swings (a stack in
## the bag) or made new (worn -1, a recipe): its weight (`weight` when it holds more,
## a chest with things), what it feeds, how a tool works
## (its power, the time of a swing, how far it reaches) and how long it lasts.
## Quality comes later.
static func item_rows(id: String, count: int, worn := -1, weight := -1.0) -> Array:
	var it := Items.get_item(id)
	var rows := [["Вес", "%.1f кг" % (weight if weight >= 0.0 else Items.weight(id) * count)]]
	if Items.food(id) > 0.0:
		rows.append(["Сытость", "+%d" % roundi(Items.food(id))])
	if it.get("tool", "none") != "none":
		rows.append(["Работа", "сила %d, удар %.1f с, %d кл" % [it.power, it.swing, it.reach]])
	var d: int = it.get("durability", 0)
	if d > 0:
		if worn < 0:
			rows.append(["Ресурс", "%d ударов" % d])
		else:
			rows.append(["Ресурс", "%d из %d (%d%%)" % [maxi(0, d - worn), d, roundi(Workshop.condition(id, worn) * 100.0)]])
	return rows
