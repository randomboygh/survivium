extends VFlowContainer
## What a thing is, as small wells with a picture and a few letters in columns of ROWS,
## a tooltip naming each (plan/design/ui.md, section 5): the craft tab's recipe (what it
## needs, have / need, the station and tool, the time) and, for it and the stack chosen
## in the bag, what the thing weighs, feeds, does and how long it lasts (item_wells).
## Short ones read red.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const Workshop := preload("res://src/shared/game/workshop.gd")


## Wells down a column; more go into the next column.
const ROWS := 3
const GAP := 4


func _init() -> void:
	add_theme_constant_override("h_separation", GAP)
	add_theme_constant_override("v_separation", GAP)


## As tall as ROWS wells, shown or not, so the panel keeps its height.
func _ready() -> void:
	var well := _well()
	well.get_child(0).get_child(1).text = "0"
	add_child(well)
	custom_minimum_size.y = ROWS * well.get_combined_minimum_size().y + (ROWS - 1) * GAP
	remove_child(well)
	well.free()


## Shows `wells`: [picture, letters, short, tooltip] each.
func show_wells(wells: Array) -> void:
	while get_child_count() < wells.size():
		add_child(_well())
	for i in get_child_count():
		var well: PanelContainer = get_child(i)
		well.visible = i < wells.size()
		if well.visible:
			var w: Array = wells[i]
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
		box.set_content_margin(side, 4)
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


## The wells every item has, for `count` of item `id` worn by `worn` swings (a stack in
## the bag) or made new (worn -1, a recipe): its weight (`weight` when it holds more,
## a chest with things), what it feeds, a tool's power, the time of its swing and its
## reach, and how many swings it lasts. Quality comes later.
static func item_wells(id: String, count: int, worn := -1, weight := -1.0) -> Array:
	var it := Items.get_item(id)
	var wells := [[ItemIcons.picture("weight"), "%.1f кг" % (weight if weight >= 0.0 else Items.weight(id) * count), false, "Вес"]]
	if Items.food(id) > 0.0:
		wells.append([ItemIcons.picture("food"), "+%d" % roundi(Items.food(id)), false, "Сытость"])
	if it.get("tool", "none") != "none":
		wells.append([UiStyle.icon("power"), str(it.power), false, "Сила"])
		wells.append([UiStyle.icon("hammer"), "%.1f с" % it.swing, false, "Удар"])
		wells.append([UiStyle.icon("target"), str(it.reach), false, "Дальность, клеток"])
	var d: int = it.get("durability", 0)
	if d > 0:
		if worn < 0:
			wells.append([UiStyle.icon("shield"), str(d), false, "Ресурс: ударов до поломки"])
		else:
			var left := maxi(0, d - worn)
			wells.append([UiStyle.icon("shield"), "%d/%d" % [left, d], Workshop.condition(id, worn) < 0.25,
				"Ресурс: ударов до поломки"])
	return wells
