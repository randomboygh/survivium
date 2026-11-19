extends PanelContainer
## The tab «Персонаж» of the inventory window (plan/mvp.md stage 3, «Решения по
## персонажу»; plan/design/ui.md, «Инвентарь»): the character drawn big in the middle
## (FigurePreview on its stand, in what it wears and its looks, Figure.dressed, with what
## its hands hold, Hands.look, its short shadow to the north-west), turned through the
## eight directions by a finger or the mouse dragged across it, a tap on a half of it or
## the arrows by the stand, as big as on the «Персонаж» tab of a new game (FigureStage);
## round it the slots of what is worn (the head, body, legs and feet down the left, as
## high as they are on the figure) and of the bag on the back and the two hands down the
## right, a strip of the bag's load along the bottom of the back's slot. Under it the
## skills (Skills, the character's SkillSet), in three columns; on a wide screen
## (`set_wide`) beside it in one, the figure a little smaller (the window's height is
## short there): bars of a division per level in a panel of their own, a thin line along
## the bottom for the way to the next level. The bar shows the skill alone: what the tool
## in hand does is its own power (the item's chips, FactChips), not divisions of the
## skill, so the two are never mixed (docs/balance/GAME_BALANCE_DESIGN.md,
## «Отображение»); the tooltip tells what the level does to the work (faster, cheaper in
## stamina, one more now and then, a harder blow, longer-lasting things) and which held
## tool the skill paces. A tap on a slot says which with `picked` as the finger lifts
## (the tab may scroll, InventoryWindow): a slot of Inventory.WEAR_SLOTS, or "hand0" /
## "hand1".

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const FigurePreview := preload("res://src/client/ui/figure_preview.gd")
const FigureStage := preload("res://src/client/ui/figure_stage.gd")
const Figure := preload("res://src/client/view/figure.gd")
const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Skills := preload("res://src/shared/content/skills.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const Quality := preload("res://src/shared/game/quality.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Vitals := preload("res://src/shared/game/vitals.gd")

signal picked(slot: String)

## The slots left of the figure, from the top (as high as they are on it), and right of it.
const LEFT := ["head", "body", "legs", "feet"]
const RIGHT := ["back", "hand0", "hand1"]
const TITLES := {
	"head": "[head]", "body": "[body]", "legs": "[legs]", "feet": "[feet]", "back": "[bag_on_the_back]",
	"hand0": "[left_hand]", "hand1": "[right_hand]",
}
## Room between the slots of a column (the column fits the window of a phone on its side,
## TARGET_SIDE tall), and between the columns and the figure.
const GAP_Y := 3
const GAP_X := 6
## The columns of skills under the figure and beside it.
const COLUMNS_UNDER := 3
const COLUMNS_BESIDE := 1
## The room inside the panel's frame, and between the figure and the skills.
const PAD := 4
const SEP := 6
## A skill bar's height (under the figure, and lower beside it: the column as tall as the
## figure's), the fill of the skill's own levels, of what the things held and
## worn add, and of the line of the way to the next level.
const BAR := 14
const BAR_BESIDE := 12
const BAR_FILL := Color("#6b4a2f")
const NEXT_FILL := Color("#d9b45a")
var game
var slot := 40
## The slot chosen in the window ("" for none), lit.
var chosen := "":
	set(v):
		chosen = v
		refresh()
var preview: FigurePreview
var _stage: FigureStage
var _layout: BoxContainer
var _columns: Array[VBoxContainer] = []
var _cells := {}
var _skills: PanelContainer
var _grid: GridContainer
var _bars := []
## The tool held of each skill's work: role -> the thing's id (named in the tooltip).
var _tool := {}
## The hands the figure was last given, "left|right|hand in use" (see _hold).
var _held := ""


func _init(g) -> void:
	game = g


func _ready() -> void:
	var frame := UiStyle.well()
	add_theme_stylebox_override("panel", _padded(frame, PAD))
	_layout = BoxContainer.new()
	_layout.vertical = true
	_layout.add_theme_constant_override("separation", SEP)
	add_child(_layout)
	# The figure in the middle, the slots in a column on each side of it.
	var figure := HBoxContainer.new()
	figure.alignment = BoxContainer.ALIGNMENT_CENTER
	figure.add_theme_constant_override("separation", GAP_X)
	_layout.add_child(figure)
	var left := _column(LEFT)
	figure.add_child(left)
	# The figure as big as on the «Персонаж» tab of a new game (FigureStage).
	_stage = FigureStage.new()
	figure.add_child(_stage)
	preview = _stage.preview
	figure.add_child(_column(RIGHT))
	# The skills in a panel of their own, columns of bars.
	_skills = PanelContainer.new()
	var well := UiStyle.well()
	_skills.add_theme_stylebox_override("panel", _padded(well, 3))
	_layout.add_child(_skills)
	_grid = GridContainer.new()
	_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skills.add_child(_grid)
	for sk: Dictionary in Skills.ALL:
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, BAR)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		bar.draw.connect(_draw_bar.bind(bar, sk))
		_grid.add_child(bar)
		_bars.append(bar)
	game.character.skills.changed.connect(_on_skills)
	set_wide(false)
	set_slot(slot)


## A copy of `box` (shared, UiStyle.well) with `pad` inside.
static func _padded(box: StyleBox, pad: int) -> StyleBox:
	var b: StyleBox = box.duplicate()
	b.set_content_margin_all(pad)
	return b


## A column of the slots `keys`, top down.
func _column(keys: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP_Y)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k: String in keys:
		var s = HotbarSlot.new(slot)
		s.on_release = true
		s.pressed.connect(func() -> void: picked.emit(k))
		s.tooltip_text = TITLES[k]
		col.add_child(s)
		_cells[k] = s
	_columns.append(col)
	return col


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
	for c: Control in _cells.values():
		c.custom_minimum_size = Vector2(slot, slot)


## The skills beside the figure (`wide`, a screen wider than tall), or under it; the
## figure as large as it is drawn there.
func set_wide(wide: bool) -> void:
	if _layout == null:
		return
	_layout.vertical = not wide
	_grid.columns = COLUMNS_BESIDE if wide else COLUMNS_UNDER
	_grid.add_theme_constant_override("v_separation", 1 if wide else 2)
	for bar: Control in _bars:
		bar.custom_minimum_size.y = BAR_BESIDE if wide else BAR
	_skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills.size_flags_vertical = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
	_stage.set_wide(wide)


## The figure drawn a step smaller, the window having no room for it; whether it could be
## (not when the slots beside it are as tall: a smaller figure saves no room then).
func shrink() -> bool:
	if _stage == null or _stage.get_combined_minimum_size().y <= _columns[0].get_combined_minimum_size().y:
		return false
	return _stage.shrink()


## The hands followed while the tab shows, as Hands.update follows them for the world's
## figure: the hand in use changed, or a hand emptied as its last thing is used up,
## refreshes no bag.
func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_hold()


## The figure given what the hands hold (Controls.hands, Hands.look) when they change.
func _hold() -> void:
	var c = game.controls
	var key := "%s|%s|%d" % [c.hands[0], c.hands[1], c.active]
	if key == _held:
		return
	_held = key
	preview.hold(game.hands.look(c.hands[0]), game.hands.look(c.hands[1]), "left" if c.active == 0 else "right")


## What is worn and held now, the chosen slot lit; the bag's slots on its tooltip.
func refresh() -> void:
	if _layout == null or not is_inside_tree():
		return
	var inv = game.character.inventory
	# The figure in what it wears and its looks, with what its hands hold, as in the world
	# (Hands.update).
	var looks: Dictionary = game.character.looks
	preview.dress(Figure.dressed(inv.gear, looks))
	_hold()
	preview.paint(looks)
	for k: String in TITLES:
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
	if _layout != null and is_inside_tree():
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
		var hardier := floori(sk.get("health", 0.0) * level / sk.levels / Vitals.CELL + 0.0001) * roundi(Vitals.CELL)
		if hardier > 0:
			text += Lang.f("[more_health]", [hardier])
		var stronger: float = snappedf(sk.get("carry", 0.0) * level / sk.levels, 0.1)
		if stronger > 0.0:
			text += Lang.f("[carries_more_kg]", [stronger])
		if _tool.has(sk.role):
			text += Lang.f("[in_hand]", [Lang.t(Items.title(_tool[sk.role]))])
		if sk.get("description", "") != "":
			text += "\n" + Lang.t(sk.description)
		_bars[i].tooltip_text = text
		_bars[i].queue_redraw()
