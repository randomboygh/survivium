extends PanelContainer
## The character in the inventory window (plan/design/ui.md, «Инвентарь»): the slots of
## what is worn where it is worn (body, legs, feet down the middle, the head's slot at the
## top left as the bag on the back is at the top right) and of the two hands under them,
## close together, a strip of the bag's load along the bottom of the back's slot; beside
## them the skills (Skills, the character's SkillSet), two columns of bars of a division
## per level in a panel of their own, a thin line along the bottom for the way to the next
## level. The bar shows the skill alone: what the tool in hand does is its own power
## (the item's chips, FactChips), not divisions of the skill, so the two are never mixed
## (docs/balance/GAME_BALANCE_DESIGN.md, «Отображение»); the tooltip tells what the level
## does to the work (faster, cheaper in stamina, one more now and then, a harder blow,
## longer-lasting things) and which held tool the skill paces. A tap on a slot says which
## with `picked`: a slot of Inventory.WEAR_SLOTS, or "hand0" / "hand1".

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Skills := preload("res://src/shared/content/skills.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const Quality := preload("res://src/shared/game/quality.gd")
const Lang := preload("res://src/shared/content/lang.gd")

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
	"head": "[head]", "body": "[body]", "legs": "[legs]", "feet": "[feet]", "back": "[bag_on_the_back]",
	"hand0": "[left_hand]", "hand1": "[right_hand]",
}
## Room between the columns of slots and between the rows.
const GAP_X := 4
const GAP_Y := 4
## The width of the panel of skills (two columns of them).
const SIDE := 132
## The room inside the panel's frame, and between the figure and the column.
const PAD := 4
const SEP := 6
## A skill bar's height, the fill of the skill's own levels, of what the things held and
## worn add, and of the line of the way to the next level.
const BAR := 14
const BAR_FILL := Color("#6b4a2f")
const NEXT_FILL := Color("#d9b45a")
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
## The tool held of each skill's work: role -> the thing's id (named in the tooltip).
var _tool := {}


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
	for sk: Dictionary in Skills.ALL:
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, BAR)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		bar.draw.connect(_draw_bar.bind(bar, sk))
		bars.add_child(bar)
		_bars.append(bar)
	game.character.skills.changed.connect(_on_skills)
	set_slot(slot)


## Skill bar `bar` of skill `sk`: its name inside, a division of its `levels` filled for
## each level learned; along the bottom a line of the way to the next level.
func _draw_bar(bar: Control, sk: Dictionary) -> void:
	var skills = game.character.skills
	var level: int = skills.level(sk.id)
	var segments: int = sk.levels
	var r := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(r, UiStyle.EDGE)
	var inner := r.grow(-1)
	bar.draw_rect(inner, UiStyle.WELL)
	var step := inner.size.x / segments
	for i in mini(level, segments):
		# Each division apart by a pixel of the well.
		var x0 := inner.position.x + roundf(i * step)
		var x1 := inner.position.x + roundf((i + 1) * step) - (1.0 if i < segments - 1 else 0.0)
		bar.draw_rect(Rect2(x0, inner.position.y, x1 - x0, inner.size.y), BAR_FILL)
	if level < segments:
		var w := roundf(inner.size.x * skills.progress(sk.id))
		if w > 0.0:
			bar.draw_rect(Rect2(inner.position.x, inner.end.y - 1.0, w, 1.0), NEXT_FILL)
	var title: String = sk.title
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	var y := floorf((r.size.y - font.get_height(fs)) * 0.5) + font.get_ascent(fs)
	# A name longer than the bar (some languages) is cut with a dot.
	var shown := Lang.t(title)
	var room := r.size.x - 6.0
	if UiStyle.text_width(shown, fs, font) > room:
		while shown.length() > 1 and UiStyle.text_width(shown + ".", fs, font) > room:
			shown = shown.left(-1)
		shown += "."
	bar.draw_string(font, Vector2(4, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.INK)


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
			c.tag = "[l]" if h == 0 else "[r]"
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
	back.tooltip_text = Lang.f("[bag_slots_of_taken_of]", [inv.base,
		(Lang.f("[more]", [Lang.t(Items.title(inv.gear.back)), Items.bag_slots(inv.gear.back)])) if inv.gear.has("back") else "",
		taken, inv.slots.size(), inv.weight(), inv.weight_limit])
	_show_skills(inv)


## The skills changed: the bars drawn again with their tooltips.
func _on_skills() -> void:
	if _figure != null and is_inside_tree():
		_show_skills(game.character.inventory)


## The bars drawn again, each with its level, the way to the next and what the level does
## to the work (SkillSet: pace, effort, extra, blow, quality_most), and the tool in hand
## the skill paces, named.
func _show_skills(inv) -> void:
	_tool.clear()
	for id: String in [game.controls.hands[0], game.controls.hands[1]]:
		if id == "" or FactChips.unarmed(inv, id):
			continue
		var role := Tools.role_of(id)
		if role != "" and not _tool.has(role):
			_tool[role] = id
	var skills = game.character.skills
	for i in mini(_bars.size(), Skills.ALL.size()):
		var sk: Dictionary = Skills.ALL[i]
		var level: int = skills.level(sk.id)
		var text := Lang.f("[level_of_n2]", [sk.title, level, sk.levels])
		if level < sk.levels:
			text += Lang.f("[to_the_next]", [floori(skills.progress(sk.id) * 100.0)])
		var faster := roundi((skills.boost(sk.role) - 1.0) * 100.0)
		if faster > 0:
			text += Lang.f("[by]", ["[swims_faster_n2]" if sk.role == "swim" else "[works_faster_n2]", faster])
		var cheaper := roundi((1.0 - skills.effort(sk.role)) * 100.0)
		if cheaper > 0:
			text += Lang.f("[less_strength_per_swing]", [cheaper])
		var more := roundi(skills.extra_chance(sk.role) * 100.0)
		if more > 0:
			text += Lang.f("[one_more_piece_chance]", [more])
		var harder := roundi(sk.might * level * 100.0 / sk.levels)
		if harder > 0:
			text += Lang.f("[strikes_harder]", [harder])
		var better := roundi(skills.quality_most(sk.role) * skills.share_of(sk.role))
		if sk.role in Quality.GETS and better > 0:
			text += Lang.f("[quality_of_what_you_get]", [better])
		elif sk.role in Quality.MAKES:
			text += Lang.f("[quality_of_what_you_make]", [Quality.skill_cap(skills.share_of(sk.role), skills.quality_most(sk.role))])
		var spared := roundi(skills.care_chance(sk.role) * 100.0)
		if spared > 0:
			text += Lang.f("[the_tool_does_not_wear]", [spared])
		if _tool.has(sk.role):
			text += Lang.f("[in_hand]", [Lang.t(Items.title(_tool[sk.role]))])
		if sk.get("description", "") != "":
			text += "\n" + Lang.t(sk.description)
		_bars[i].tooltip_text = text
		_bars[i].queue_redraw()
