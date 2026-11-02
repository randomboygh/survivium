extends PanelContainer
## The character in the inventory window (plan/design/ui.md, «Инвентарь»): the slots of
## what is worn where it is worn (body, legs, feet down the middle, the head's slot at the
## top left as the bag on the back is at the top right) and of the two hands under them,
## close together, a strip of the bag's load along the bottom of the back's slot; beside
## them the skills, two columns of bars of SEGMENTS divisions in a panel of their own
## (examples until skills come), what the things held and worn add to a skill (a tool's
## power, SKILL_OF) as more divisions in another colour. A tap on a slot says which with
## `picked`: a slot of Inventory.WEAR_SLOTS, or "hand0" / "hand1".

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")

signal picked(slot: String)

## Where each slot stands on the figure, in slots across and down (columns 0..2, rows
## 0..2): the body, legs and feet down the middle, the head's slot at the top left as
## the bag on the back is at the top right, the hands under them.
const PLACES := {
	"head": Vector2(0, 0), "body": Vector2(1, 0), "legs": Vector2(1, 1), "feet": Vector2(1, 2),
	"back": Vector2(2, 0), "hand0": Vector2(0, 1.5), "hand1": Vector2(2, 1.5),
}
const ROWS := 3
const TITLES := {
	"head": "Голова", "body": "Тело", "legs": "Ноги", "feet": "Обувь", "back": "Сумка за спиной",
	"hand0": "Левая рука", "hand1": "Правая рука",
}
## Room between the columns of slots and between the rows.
const GAP_X := 4
const GAP_Y := 4
## The width of the panel of skills (two columns of them).
const SIDE := 132
## The room inside the panel's frame, and between the figure and the column.
const PAD := 4
const SEP := 6
## A skill bar's height, its divisions, the fill of the skill's own and of what the
## things held and worn add.
const BAR := 14
const SEGMENTS := 10
const BAR_FILL := Color("#6b4a2f")
const BONUS_FILL := Color("#4f7a37")
## Skills shown until skills are made: [name, level in divisions].
const SKILLS := [["Сбор", 4], ["Рубка", 3], ["Копание", 5], ["Стройка", 2], ["Ремесло", 3], ["Охота", 2], ["Плавание", 3]]
## The skill a tool of each class helps (until skills are made): it adds its power.
const SKILL_OF := {
	"axe": "Рубка", "pickaxe": "Копание", "shovel": "Копание", "scythe": "Сбор", "knife": "Ремесло",
	"needle": "Ремесло", "sword": "Охота", "spear": "Охота", "bow": "Охота", "sling": "Охота", "rod": "Охота",
}

var game
var slot := 40
## The slot chosen in the window ("" for none), lit.
var chosen := "":
	set(v):
		chosen = v
		refresh()
var _figure: Control
var _cells := {}
var _bars := []
## What the things held and worn add to each skill: name -> [divisions, the thing's id].
var _bonus := {}


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
	row.add_child(_figure)
	for k: String in PLACES:
		var s = HotbarSlot.new(slot)
		s.pressed.connect(func() -> void: picked.emit(k))
		s.tooltip_text = TITLES[k]
		_figure.add_child(s)
		_cells[k] = s
	# The skills in a panel of their own, two columns of bars.
	var skills := PanelContainer.new()
	var well := UiStyle.well()
	well.set_content_margin_all(3)
	skills.add_theme_stylebox_override("panel", well)
	skills.custom_minimum_size.x = SIDE
	row.add_child(skills)
	var bars := GridContainer.new()
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bars.columns = 2
	bars.add_theme_constant_override("h_separation", 2)
	bars.add_theme_constant_override("v_separation", 2)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skills.add_child(bars)
	for sk: Array in SKILLS:
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, BAR)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		bar.draw.connect(_draw_bar.bind(bar, sk[0], sk[1]))
		bars.add_child(bar)
		_bars.append(bar)
	set_slot(slot)


## Skill bar `bar`: its name `title` inside, `level` of its SEGMENTS divisions filled and
## after them, in another colour, what the things held and worn add (see _bonus).
func _draw_bar(bar: Control, title: String, level: int) -> void:
	var r := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(r, UiStyle.EDGE)
	var inner := r.grow(-1)
	bar.draw_rect(inner, UiStyle.WELL)
	var add: int = _bonus.get(title, [0])[0]
	var step := inner.size.x / SEGMENTS
	for i in mini(level + add, SEGMENTS):
		# Each division apart by a pixel of the well.
		var x0 := inner.position.x + roundf(i * step)
		var x1 := inner.position.x + roundf((i + 1) * step) - (1.0 if i < SEGMENTS - 1 else 0.0)
		bar.draw_rect(Rect2(x0, inner.position.y, x1 - x0, inner.size.y), BAR_FILL if i < level else BONUS_FILL)
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	var y := floorf((r.size.y - font.get_height(fs)) * 0.5) + font.get_ascent(fs)
	bar.draw_string(font, Vector2(4, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.INK)


## Lays the figure out for slots `side` UI pixels large.
func set_slot(side: int) -> void:
	slot = side
	if _figure == null:
		return
	_figure.custom_minimum_size = Vector2(3 * slot + 2 * GAP_X, ROWS * slot + (ROWS - 1) * GAP_Y)
	for k: String in PLACES:
		var c: Control = _cells[k]
		c.custom_minimum_size = Vector2(slot, slot)
		c.size = c.custom_minimum_size
		c.position = (PLACES[k] * Vector2(slot + GAP_X, slot + GAP_Y)).floor()


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
			c.inactive = FactChips.unarmed(inv, id)
			c.tag = "Л" if h == 0 else "П"
			c.key = "•" if game.controls.active == h else ""
			continue
		var worn: String = inv.gear.get(k, "")
		c.inactive = false
		c.tag = ""
		c.key = ""
		if worn != "":
			c.texture = ItemIcons.of_item(worn)
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
	# Under the bag, a strip of its load, as a light's in a slot: green, amber near the
	# limit, red past it.
	var share: float = inv.load_share()
	var back = _cells.back
	back.fill = clampf(share, 0.0, 1.0)
	back.fill_color = UiStyle.DANGER if share > 1.0 else (UiStyle.ACCENT if share > 0.9 else UiStyle.GOOD)
	var taken := 0
	for s in inv.slots:
		if s != null:
			taken += 1
	back.tooltip_text = "Сумка: %d ячеек%s; занято %d из %d, %.1f из %d кг" % [inv.base,
		(", %s: ещё %d" % [Items.title(inv.gear.back), Items.bag_slots(inv.gear.back)]) if inv.gear.has("back") else "",
		taken, inv.slots.size(), inv.weight(), inv.weight_limit]
	_show_skills(inv)


## What the things in the hands and worn add to the skills: the most of each skill, a
## tool's power (a weapon with nothing to shoot adds nothing); the bars drawn again.
func _show_skills(inv) -> void:
	_bonus.clear()
	var things: Array = [game.controls.hands[0], game.controls.hands[1]] + inv.gear.values()
	for id: String in things:
		if id == "" or FactChips.unarmed(inv, id):
			continue
		var it := Items.get_item(id)
		var skill: String = SKILL_OF.get(it.get("tool", "none"), "")
		var add: int = it.get("power", 0)
		if skill != "" and add > _bonus.get(skill, [0])[0]:
			_bonus[skill] = [add, id]
	for i in _bars.size():
		var sk: Array = SKILLS[i]
		var b: Array = _bonus.get(sk[0], [0, ""])
		_bars[i].tooltip_text = "%s: %d%s (пока для примера: навыков в игре ещё нет)" % [sk[0], sk[1],
			" + %d от «%s»" % [b[0], Items.title(b[1])] if b[0] > 0 else ""]
		_bars[i].queue_redraw()
