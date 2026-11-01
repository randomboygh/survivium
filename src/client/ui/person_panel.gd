extends PanelContainer
## The character in the inventory window (plan/design/ui.md, «Инвентарь»): the slots of
## what is worn where it is worn (head, body, legs, feet down the middle, the bag on the
## back over the right shoulder) and of the two hands at the sides, joined by faint lines
## of a body, and beside them the bag's load (a bar, the weight and the limit inside) over
## the skills, a bar each in a panel of their own (examples until skills come). A tap on a slot says which with `picked`: a slot of
## Inventory.WEAR_SLOTS, or "hand0" / "hand1".

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
const GAP_X := 12
const GAP_Y := 4
## The width of the panel of skills.
const SIDE := 86
## The room inside the panel's frame, and between the figure and the column.
const PAD := 4
const SEP := 6
## A skill bar's height, the share of it the highest skill fills, and its fill.
const BAR := 14
const BAR_TOP := 0.9
const BAR_FILL := Color("#6b4a2f")
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
## The bag's load by the bag's slot.
var _load: Control
var _cells := {}


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
	# By the bag on the back, its load: a bar of the weight against the limit, the
	# numbers inside; under it the skills in a panel of their own, a bar each.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.custom_minimum_size.x = SIDE
	row.add_child(side)
	_load = Control.new()
	_load.custom_minimum_size = Vector2(0, BAR + 4)
	_load.draw.connect(_draw_load)
	side.add_child(_load)
	var skills := PanelContainer.new()
	var well := UiStyle.well()
	well.set_content_margin_all(3)
	skills.add_theme_stylebox_override("panel", well)
	skills.tooltip_text = "Навыки (пока для примера: навыков в игре ещё нет)"
	skills.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(skills)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skills.add_child(bars)
	var top := 0
	for sk: Array in SKILLS:
		top = maxi(top, sk[1])
	for sk: Array in SKILLS:
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, BAR)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_draw_bar.bind(bar, sk[0], sk[1], top))
		bars.add_child(bar)
	set_slot(slot)


## Skill bar `bar`: its name `title` inside, filled by its level `level` against the
## highest one `top` (which fills BAR_TOP of the bar).
func _draw_bar(bar: Control, title: String, level: int, top: int) -> void:
	var r := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(r, UiStyle.EDGE)
	var inner := r.grow(-1)
	bar.draw_rect(inner, UiStyle.WELL)
	var share := BAR_TOP * level / float(maxi(top, 1))
	bar.draw_rect(Rect2(inner.position, Vector2(roundf(inner.size.x * share), inner.size.y)), BAR_FILL)
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	var y := floorf((r.size.y - font.get_height(fs)) * 0.5) + font.get_ascent(fs)
	bar.draw_string(font, Vector2(4, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.INK)


## The load bar: the weight carried against the limit, amber near it, red past it.
func _draw_load() -> void:
	var inv = game.character.inventory
	var r := Rect2(Vector2.ZERO, _load.size)
	_load.draw_rect(r, UiStyle.EDGE)
	var inner := r.grow(-1)
	_load.draw_rect(inner, UiStyle.WELL)
	var share: float = inv.load_share()
	_load.draw_rect(Rect2(inner.position, Vector2(roundf(inner.size.x * clampf(share, 0.0, 1.0)), inner.size.y)),
		Color(UiStyle.DANGER, 0.6) if share > 1.0 else (Color(UiStyle.ACCENT, 0.5) if share > 0.9 else BAR_FILL))
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	var y := floorf((r.size.y - font.get_height(fs)) * 0.5) + font.get_ascent(fs)
	var icon := ItemIcons.picture("weight")
	var x := 3.0
	if icon != null:
		_load.draw_texture(icon, Vector2(x, floorf((r.size.y - icon.get_height()) * 0.5)))
		x += icon.get_width() + 3
	_load.draw_string(font, Vector2(x, y), "%d/%d кг" % [roundi(inv.weight()), inv.weight_limit],
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.INK)
	_load.tooltip_text = "Вес: %.1f из %d кг%s" % [inv.weight(), inv.weight_limit, " — перегруз" if share > 1.0 else ""]


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


## What is worn and held now, the chosen slot lit; the bag's slots on its tooltip.
func refresh() -> void:
	if _figure == null or not is_inside_tree():
		return
	var inv = game.character.inventory
	for k: String in PLACES:
		var c = _cells[k]
		c.selected = k == chosen
		c.icon_size = Vector2(24, 24)
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
			c.icon_size = c.texture.get_size() * 2
			c.modulate = Color(1, 1, 1, 0.6)
		else:
			# The picture of what goes there, faint, at a whole scale (it is not square).
			c.texture = UiStyle.icon("wear_" + k)
			c.icon_size = c.texture.get_size() * 2
			c.modulate = Color(1, 1, 1, 0.6)
	_cells.back.tooltip_text = "Сумка: %d ячеек%s" % [inv.base,
		(", %s: ещё %d" % [Items.title(inv.gear.back), Items.bag_slots(inv.gear.back)]) if inv.gear.has("back") else ""]
	_figure.queue_redraw()
	_load.queue_redraw()


## The faint body joining the slots: a neck, arms down to the hands, legs and the
## bag's strap.
func _draw_figure() -> void:
	var c := Color(UiStyle.MUTED, 0.18)
	var s := float(slot)
	var head: Rect2 = _rect("head")
	var body: Rect2 = _rect("body")
	var legs: Rect2 = _rect("legs")
	var feet: Rect2 = _rect("feet")
	var mid := floorf(body.get_center().x)
	_figure.draw_rect(Rect2(mid - 4, head.end.y, 8, body.position.y - head.end.y), c)
	_figure.draw_rect(Rect2(mid - 6, body.end.y, 12, legs.position.y - body.end.y), c)
	_figure.draw_rect(Rect2(legs.position.x + s * 0.2, legs.end.y, 5, feet.position.y - legs.end.y), c)
	_figure.draw_rect(Rect2(legs.end.x - s * 0.2 - 5, legs.end.y, 5, feet.position.y - legs.end.y), c)
	for h in 2:
		var hand: Rect2 = _rect("hand%d" % h)
		var from := Vector2(body.position.x if h == 0 else body.end.x, body.position.y + 6)
		var to := Vector2(hand.get_center().x, hand.position.y)
		_figure.draw_line(from, to, c, 5.0)
	var back: Rect2 = _rect("back")
	_figure.draw_line(Vector2(back.position.x, back.get_center().y), Vector2(body.end.x - 4, body.position.y + 2), c, 3.0)


func _rect(k: String) -> Rect2:
	var cell: Control = _cells[k]
	return Rect2(cell.position, cell.size)
