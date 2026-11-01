extends PanelContainer
## The character in the inventory window (plan/design/ui.md, «Инвентарь»): the player's
## own figure (its sprite, facing the viewer) between the slots of what is worn (head,
## body, legs, feet) on the left and of the bag on the back and the two hands on the
## right, and beside it the slots of the bag, the weight carried
## at full pace and the skills (examples until skills come). A tap on a slot says which with `picked`:
## a slot of Inventory.WEAR_SLOTS, or "hand0" / "hand1".

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")

signal picked(slot: String)

## Where each slot stands on the figure, in slots across and down (columns 0..2, rows 0..3).
## What is worn down the left, the bag and the hands down the right, the player's own
## figure between them.
const PLACES := {
	"head": Vector2(0, 0), "body": Vector2(0, 1), "legs": Vector2(0, 2), "feet": Vector2(0, 3),
	"back": Vector2(2, 0), "hand0": Vector2(2, 1), "hand1": Vector2(2, 2),
}
## The player's figure: the layers of the first frame of the sheet facing the viewer
## (content/core/sprites/player.yaml: idle, looking south), outlined.
const SPRITES := "res://content/core/sprites/player/"
const LAYERS := ["body", "shirt", "trousers", "boots", "hair", "fists"]
const FRAME := 32
const TITLES := {
	"head": "Голова", "body": "Тело", "legs": "Ноги", "feet": "Обувь", "back": "Сумка за спиной",
	"hand0": "Левая рука", "hand1": "Правая рука",
}
## Room round the middle column (where the figure stands, a slot wide and this on each side) and between the rows.
const GAP_X := 12
const GAP_Y := 4
## The width of the column of the slots, the carrying limit and the skills.
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
	# The skills in a panel of their own: a bar each, its name inside.
	var skills := PanelContainer.new()
	var well := UiStyle.well()
	well.set_content_margin_all(3)
	skills.add_theme_stylebox_override("panel", well)
	skills.tooltip_text = "Навыков в игре ещё нет: уровни показаны для примера"
	skills.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(skills)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skills.add_child(bars)
	var head := UiStyle.label("Навыки", UiStyle.MUTED)
	head.clip_text = true
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(head)
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
	_limit.text = "%d кг" % inv.weight_limit
	_limit.tooltip_text = "Носит без замедления до %d кг; с силой станет больше" % inv.weight_limit
	_room.text = str(inv.slots.size())
	_room.tooltip_text = "Сумка: %d ячеек%s" % [inv.base,
		(", %s: ещё %d" % [Items.title(inv.gear.back), Items.bag_slots(inv.gear.back)]) if inv.gear.has("back") else ""]


static var _portrait: ImageTexture


## The player's figure between the slots, as large as whole pixels let it be, in the
## middle, standing on a faint shadow.
func _draw_figure() -> void:
	var tex := portrait()
	var room := Vector2(slot + 2 * GAP_X, 4 * slot + 3 * GAP_Y - 6)
	var scale := maxf(1.0, floorf(minf(room.x / tex.get_width(), room.y / tex.get_height())))
	var size := tex.get_size() * scale
	var at := ((_figure.custom_minimum_size - size) * 0.5).floor()
	var shadow := Rect2(at.x - scale, at.y + size.y - scale * 2, size.x + scale * 2, scale * 2)
	_figure.draw_rect(shadow, Color(0, 0, 0, 0.35))
	_figure.draw_texture_rect(tex, Rect2(at, size), false)


## The player's figure as a picture, cut to what is drawn with a one-pixel outline.
static func portrait() -> ImageTexture:
	if _portrait != null:
		return _portrait
	var img := Image.create_empty(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for name: String in LAYERS:
		var tex: Texture2D = load(SPRITES + name + ".png")
		if tex == null:
			continue
		var layer := tex.get_image()
		layer.convert(Image.FORMAT_RGBA8)
		img.blend_rect(layer, Rect2i(0, 0, FRAME, FRAME), Vector2i.ZERO)
	var used := img.get_used_rect().grow(1).intersection(Rect2i(0, 0, FRAME, FRAME))
	var cut := img.get_region(used)
	var out := cut.duplicate()
	for y in cut.get_height():
		for x in cut.get_width():
			if cut.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < cut.get_width() and p.y < cut.get_height() and cut.get_pixelv(p).a > 0.0:
					out.set_pixel(x, y, UiStyle.EDGE)
					break
	_portrait = ImageTexture.create_from_image(out)
	return _portrait


func _rect(k: String) -> Rect2:
	var cell: Control = _cells[k]
	return Rect2(cell.position, cell.size)
