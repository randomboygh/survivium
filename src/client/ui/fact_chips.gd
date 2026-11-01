extends HFlowContainer
## What a thing is, as small wells with a picture and a few letters in named groups laid
## side by side (a group that does not fit goes on the next line), a tooltip naming each
## well (plan/design/ui.md, section 5): the craft tab's recipe (the materials, have /
## need, the station, the tools, the time, what it makes, by-products) and the stack
## chosen in the bag (item_groups: weight, food, the tool's work, how long it lasts).
## Short ones read red.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const Workshop := preload("res://src/shared/game/workshop.gd")

const GAP := 4
## The space between groups.
const GROUP_GAP := 8
## Lines of groups the panel keeps room for, shown or not, so it keeps its height.
const LINES := 1

var _line_height := 0.0


func _init() -> void:
	add_theme_constant_override("h_separation", GROUP_GAP)
	add_theme_constant_override("v_separation", GAP)


func _ready() -> void:
	var group := _group()
	_fill(group, ["Вес", [[null, "0", false, ""]]])
	add_child(group)
	_line_height = group.get_combined_minimum_size().y
	custom_minimum_size.y = LINES * _line_height + (LINES - 1) * GAP
	remove_child(group)
	group.free()


## Shows `groups`: [caption, wells] each, a well being [picture, letters, short, tooltip];
## a group without wells is left out.
func show_groups(groups: Array) -> void:
	var shown := groups.filter(func(g: Array) -> bool: return not g[1].is_empty())
	while get_child_count() < shown.size():
		add_child(_group())
	for i in get_child_count():
		var group: VBoxContainer = get_child(i)
		group.visible = i < shown.size()
		if group.visible:
			_fill(group, shown[i])


## Group `group` (see _group) showing `g`: [caption, wells].
static func _fill(group: VBoxContainer, g: Array) -> void:
	var caption: Label = group.get_child(0)
	caption.text = g[0]
	caption.visible = g[0] != ""
	var row: HBoxContainer = group.get_child(1)
	var wells: Array = g[1]
	while row.get_child_count() < wells.size():
		row.add_child(_well())
	for j in row.get_child_count():
		var well: PanelContainer = row.get_child(j)
		well.visible = j < wells.size()
		if well.visible:
			var w: Array = wells[j]
			var line := well.get_child(0)
			line.get_child(0).texture = w[0]
			var label: Label = line.get_child(1)
			label.text = w[1]
			label.visible = w[1] != ""
			label.add_theme_color_override("font_color", UiStyle.DANGER if w[2] else UiStyle.INK)
			well.tooltip_text = w[3]


## A group: its caption over a row of wells.
static func _group() -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 1)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(UiStyle.label("", UiStyle.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(row)
	return group


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


## The groups every item has, for `count` of item `id` worn by `worn` swings (a stack in
## the bag) or made new (worn -1, a recipe): its weight (`weight` when it holds more,
## a chest with things), what it feeds, what a bag on the back adds, a tool's power, the
## time of its swing and its reach, and how many swings it lasts; how far a light reaches
## and how long one burns (`burn_left` of it when one of them is lit, a share 0..1);
## how long food keeps and how fresh a stack is (`fresh` 0..1, below 0 for one made new).
## Quality comes later.
static func item_groups(id: String, count: int, worn := -1, weight := -1.0, burn_left := 1.0, fresh := -1.0) -> Array:
	var it := Items.get_item(id)
	var groups := [["Вес", [[ItemIcons.picture("weight"), "%.1f кг" % (weight if weight >= 0.0 else Items.weight(id) * count), false, "Вес"]]]]
	if Items.food(id) > 0.0:
		var food := [[ItemIcons.picture("food"), "+%d" % roundi(Items.food(id)), false, "Сытость"]]
		var keeps := Items.spoils(id)
		if keeps > 0.0:
			var days := "%s сут." % str(snappedf(keeps, 0.1))
			food.append([UiStyle.icon("clock"), "%d%%" % roundi(fresh * 100.0) if fresh >= 0.0 else days, fresh >= 0.0 and fresh < 0.25,
				"Свежесть: испортится за %s, в холоде и под крышей дольше" % days])
		groups.append(["Еда", food])
	if Items.bag_slots(id) > 0:
		groups.append(["Сумка", [[UiStyle.icon("bag"), "+%d" % Items.bag_slots(id), false, "Ячеек, надетая за спину"]]])
	if it.get("tool", "none") != "none":
		groups.append(["Инструмент", [[UiStyle.icon("power"), str(it.power), false, "Сила"],
			[UiStyle.icon("hammer"), "%.1f с" % it.swing, false, "Удар"],
			[UiStyle.icon("target"), str(it.reach), false, "Дальность, клеток"]]])
	if it.get("light", 0.0) > 0.0:
		var light := [[UiStyle.icon("sun"), str(snappedf(it.light, 0.1)), false, "Свет, клеток"]]
		var burns: float = it.get("burns", 0.0)
		if burns > 0.0:
			var text := _minutes(burns)
			if burn_left < 1.0:
				text = "%s/%s" % [_minutes(burns * burn_left), text]
			light.append([UiStyle.icon("light"), text, burn_left < 0.25, "Горит одна, мин:с"])
		groups.append(["Свет", light])
	var d: int = it.get("durability", 0)
	if d > 0:
		if worn < 0:
			groups.append(["Ресурс", [[UiStyle.icon("shield"), str(d), false, "Ресурс: ударов до поломки"]]])
		else:
			var left := maxi(0, d - worn)
			groups.append(["Ресурс", [[UiStyle.icon("shield"), "%d/%d" % [left, d], Workshop.condition(id, worn) < 0.25,
				"Ресурс: ударов до поломки"]]])
	return groups


## Seconds `t` as minutes and seconds, "6:00".
static func _minutes(t: float) -> String:
	var s := ceili(t)
	return "%d:%02d" % [s / 60, s % 60]
