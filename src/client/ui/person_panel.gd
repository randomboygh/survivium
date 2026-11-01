extends PanelContainer
## The character in the inventory window (plan/design/ui.md, «Инвентарь»): a drawn
## figure with the slots of what is worn round it (head, body, legs, feet, the bag on
## the back) and of the two hands, and beside it the slots of the bag, the weight carried
## at full pace and the skills (examples until skills come). A tap on a slot says which with `picked`:
## a slot of Inventory.WEAR_SLOTS, or "hand0" / "hand1".

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")

signal picked(slot: String)

## Where each slot stands on the figure, in slots across and down (columns 0..2, rows 0..3).
const PLACES := {
	"head": Vector2(1, 0), "body": Vector2(1, 1), "legs": Vector2(1, 2), "feet": Vector2(1, 3),
	"back": Vector2(2, 0), "hand0": Vector2(0, 1.5), "hand1": Vector2(2, 1.5),
}
const TITLES := {
	"head": "Голова", "body": "Тело", "legs": "Ноги", "feet": "Обувь", "back": "Сумка за спиной",
	"hand0": "Левая рука", "hand1": "Правая рука",
}
## Room between the columns of slots (the arms are drawn there) and between the rows.
const GAP_X := 8
const GAP_Y := 4
## The width of the column of the slots, the carrying limit and the skills.
const SIDE := 92
## The room inside the panel's frame, and between the figure and the column.
const PAD := 4
const SEP := 6
## Skills shown until skills are made: [name, level].
const SKILLS := [["Сбор", 3], ["Рубка", 2], ["Копание", 4], ["Стройка", 1], ["Ремесло", 2], ["Охота", 1], ["Плавание", 2]]

var game
var slot := 40
## The slot chosen in the window ("" for none), lit.
var chosen := "":
	set(v):
		chosen = v
		refresh()
var _figure: Control
var _cells := {}
var _limit: Label
var _room: Label


func _init(g) -> void:
	game = g


func _ready() -> void:
	var frame := UiStyle.well()
	frame.set_content_margin_all(PAD)
	add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEP)
	add_child(row)
	_figure = Control.new()
	_figure.draw.connect(_draw_figure)
	row.add_child(_figure)
	for k: String in PLACES:
		var s = HotbarSlot.new(slot)
		s.pressed.connect(func() -> void: picked.emit(k))
		s.tooltip_text = TITLES[k]
		_figure.add_child(s)
		_cells[k] = s
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 1)
	side.custom_minimum_size.x = SIDE
	row.add_child(side)
	_room = _line(side, "Ячейки")
	_limit = _line(side, "Носит")
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	side.add_child(gap)
	side.add_child(UiStyle.label("Навыки", UiStyle.MUTED))
	for sk: Array in SKILLS:
		_line(side, sk[0]).text = str(sk[1])
	var example := UiStyle.label("пока для примера", UiStyle.MUTED)
	example.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	example.custom_minimum_size.x = SIDE
	example.tooltip_text = "Навыков в игре ещё нет: уровни показаны для примера"
	example.mouse_filter = Control.MOUSE_FILTER_PASS
	side.add_child(example)
	set_slot(slot)


## A line of the side column: `title` on the left, the returned label on the right.
func _line(parent: Node, title: String) -> Label:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var name_label := UiStyle.label(title, UiStyle.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The column keeps its width (see width): a long name is cut.
	name_label.clip_text = true
	line.add_child(name_label)
	var value := UiStyle.label("")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value)
	return value


## Lays the figure out for slots `side` UI pixels large.
func set_slot(side: int) -> void:
	slot = side
	if _figure == null:
		return
	_figure.custom_minimum_size = Vector2(3 * slot + 2 * GAP_X, 4 * slot + 3 * GAP_Y)
	for k: String in PLACES:
		var c: Control = _cells[k]
		c.custom_minimum_size = Vector2(slot, slot)
		c.size = c.custom_minimum_size
		c.position = (PLACES[k] * Vector2(slot + GAP_X, slot + GAP_Y)).floor()
	_figure.queue_redraw()


## The width the panel takes with slots `side` UI pixels large.
static func width(side: int) -> int:
	return 3 * side + 2 * GAP_X + SEP + SIDE + 2 * PAD


## What is worn and held now, the chosen slot lit; the load and the slots of the bag.
func refresh() -> void:
	if _figure == null or not is_inside_tree():
		return
	var inv = game.character.inventory
	for k: String in PLACES:
		var c = _cells[k]
		c.selected = k == chosen
		c.number = ""
		c.modulate = Color.WHITE
		if k.begins_with("hand"):
			var h := int(k.right(1))
			var id: String = game.controls.hands[h]
			c.texture = ItemIcons.of_item(id) if id != "" else ItemIcons.picture("hand")
			c.tag = "Л" if h == 0 else "П"
			c.key = "•" if game.controls.active == h else ""
			continue
		var worn: String = inv.gear.get(k, "")
		c.tag = ""
		c.key = ""
		if worn != "":
			c.texture = ItemIcons.of_item(worn)
			if k == "back":
				c.number = "+%d" % Items.bag_slots(worn)
		elif k == "back":
			# The bag the character always has.
			c.texture = UiStyle.icon("bag")
			c.modulate = Color(1, 1, 1, 0.5)
		else:
			c.texture = UiStyle.icon("wear_" + k)
	_limit.text = "%d кг" % inv.weight_limit
	_limit.tooltip_text = "Носит без замедления до %d кг; с силой станет больше" % inv.weight_limit
	_room.text = str(inv.slots.size())
	_room.tooltip_text = "Сумка: %d ячеек%s" % [inv.base,
		(", %s: ещё %d" % [Items.title(inv.gear.back), Items.bag_slots(inv.gear.back)]) if inv.gear.has("back") else ""]


## The figure behind the slots: a neck, arms down to the hands, legs and the bag's strap.
func _draw_figure() -> void:
	var c := UiStyle.EDGE
	var s := float(slot)
	var head: Rect2 = _rect("head")
	var body: Rect2 = _rect("body")
	var legs: Rect2 = _rect("legs")
	var feet: Rect2 = _rect("feet")
	var mid := body.get_center().x
	_figure.draw_rect(Rect2(mid - 3, head.end.y, 6, body.position.y - head.end.y), c)
	_figure.draw_rect(Rect2(mid - 3, body.end.y, 6, legs.position.y - body.end.y), c)
	_figure.draw_rect(Rect2(legs.position.x + s * 0.2, legs.end.y, 4, feet.position.y - legs.end.y), c)
	_figure.draw_rect(Rect2(legs.end.x - s * 0.2 - 4, legs.end.y, 4, feet.position.y - legs.end.y), c)
	for h in 2:
		var hand: Rect2 = _rect("hand%d" % h)
		var from := Vector2(body.position.x if h == 0 else body.end.x, body.position.y + 6)
		var to := Vector2(hand.get_center().x, hand.position.y)
		_figure.draw_line(from, to, c, 4.0)
	var back: Rect2 = _rect("back")
	_figure.draw_line(Vector2(back.position.x, back.get_center().y), Vector2(body.end.x - 4, body.position.y + 2), c, 3.0)


func _rect(k: String) -> Rect2:
	var cell: Control = _cells[k]
	return Rect2(cell.position, cell.size)
