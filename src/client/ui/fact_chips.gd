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
const Quality := preload("res://src/shared/game/quality.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")

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


## The wear item_groups is given for a thing made new (a recipe), not a stack in a bag.
const NEW := -(1 << 30)

## The groups every item has, for `count` of item `id` worn by `worn` swings (a stack in
## the bag; below none for one made by a skilled hand, with swings to spare) or made new
## (worn NEW, a recipe): its weight (`weight` when it holds more,
## a chest with things), what it feeds, how warm clothes keep, what a bag on the back adds, a tool's power, the
## time of its swing and its reach, and how many swings it lasts; how far a light reaches
## and how long one burns (`burn_left` of it when one of them is lit, a share 0..1);
## how long food keeps and how fresh a stack is (`fresh` 0..1, below 0 for one made new).
## What a weapon shoots, with `ammo` of it in the bag (-1: not counted, a recipe).
## The stack's quality `q` (below 0 for a recipe: not shown) and what it does to food,
## warmth, a tool's swing and its swings (Quality).
static func item_groups(id: String, count: int, worn := NEW, weight := -1.0, burn_left := 1.0, fresh := -1.0, ammo := -1, q := -1) -> Array:
	var it := Items.get_item(id)
	var k := Quality.lasts(q) if q >= 0 else 1.0
	var groups := [["Вес", [[ItemIcons.picture("weight"), "%.1f кг" % (weight if weight >= 0.0 else Items.weight(id) * count), false, "Вес"]]]]
	if q >= 0:
		groups.append(["Качество", [[UiStyle.icon("star"), "%d" % q, q < Quality.GRADES[0][0],
			"Качество: %s (%d из %d). Влияет на прочность и скорость инструмента, тепло одежды, сытость еды" % [Quality.grade_name(q), q, Quality.MAX]]]])
	if Items.food(id) > 0.0:
		var food := [[ItemIcons.picture("food"), "+%d" % roundi(Items.food(id) * k), false, "Сытость"]]
		var keeps := Items.spoils(id)
		if keeps > 0.0:
			var days := "%s сут." % str(snappedf(keeps, 0.1))
			food.append([UiStyle.icon("clock"), "%d%%" % roundi(fresh * 100.0) if fresh >= 0.0 else days, fresh >= 0.0 and fresh < 0.25,
				"Свежесть: испортится за %s, в холоде и под крышей дольше" % days])
		if Items.heal(id) > 0.0:
			food.append([ItemIcons.picture("heart"), "+%d" % roundi(Items.heal(id) * k), false, "Здоровье"])
		groups.append(["Еда", food])
	if Items.drink(id) > 0.0:
		groups.append(["Питьё", [[ItemIcons.picture("water"), "+%d" % roundi(Items.drink(id) * k), false, "Вода"]]])
	if it.get("warmth", 0.0) > 0.0:
		groups.append(["Одежда", [[ItemIcons.picture("thermo"), "+%d°" % roundi(it.warmth * k), false,
			"Теплее на столько градусов, надетая; мокрая греет вполовину"]]])
	if Items.bag_slots(id) > 0:
		groups.append(["Сумка", [[UiStyle.icon("bag"), "+%d" % Items.bag_slots(id), false, "Ячеек, надетая за спину"]]])
	if it.get("tool", "none") != "none":
		groups.append(["Инструмент", [[UiStyle.icon("power"), str(it.power), false, power_hint(it)],
			[UiStyle.icon("hammer"), "%.1f с" % (it.swing / (Quality.faster(q) if q >= 0 else 1.0)), false, "Удар, секунд (навык ускоряет)"],
			[UiStyle.icon("target"), str(it.reach), false, "Дальность, клеток"]]])
	var shoots: String = it.get("ammo", "")
	if shoots != "" and it.get("tool", "") == "rod":
		var tip := "Наживка: «%s», по одной на заброс; без неё клюёт редко" % Items.title(shoots)
		var left := "нет" if ammo == 0 else (str(ammo) if ammo > 0 else "")
		groups.append(["Наживка", [[ItemIcons.of_item(shoots), left, ammo == 0, tip]]])
	elif shoots != "":
		var tip := "Стреляет: «%s», по одному на выстрел" % Items.title(shoots)
		if ammo == 0:
			tip += "; в сумке нет — стрелять нечем"
		var left := "нет" if ammo == 0 else (str(ammo) if ammo > 0 else "")
		groups.append(["Заряды", [[ItemIcons.of_item(shoots), left, ammo == 0, tip]]])
	if it.get("light", 0.0) > 0.0:
		var light := [[UiStyle.icon("sun"), str(snappedf(it.light, 0.1)), false, "Свет, клеток"]]
		var burns: float = it.get("burns", 0.0)
		if burns > 0.0:
			var text := _minutes(burns)
			if burn_left < 1.0:
				text = "%s/%s" % [_minutes(burns * burn_left), text]
			light.append([UiStyle.icon("light"), text, burn_left < 0.25, "Горит одна, мин:с"])
		groups.append(["Свет", light])
	var d: int = Quality.durability(it.get("durability", 0), q) if q >= 0 else it.get("durability", 0)
	if d > 0:
		if worn == NEW:
			groups.append(["Ресурс", [[UiStyle.icon("shield"), str(d), false, "Ресурс: ударов до поломки"]]])
		else:
			var left := maxi(0, d - worn)
			var tip := "Ресурс: ударов до поломки"
			if worn < 0:
				tip += "; запас ударов умелой руки: %d" % -worn
			groups.append(["Ресурс", [[UiStyle.icon("shield"), "%d/%d" % [left, d], float(left) / d < 0.25,
				tip]]])
	return groups


## What the power of tool record `it` means, with the thing of its class the player meets
## most as the example (the first broad-leaved tree for an axe, stone for a pickaxe, the
## largest animal that can be hit for a weapon), by the same formulas the rules use
## (Tools.hits_to, Tools.swing_time): the chip tells the player what the number does.
static func power_hint(it: Dictionary) -> String:
	var p: int = it.get("power", 0)
	match it.get("tool", "none"):
		"axe":
			if not Trees.SPECIES.is_empty():
				var s: Dictionary = Trees.SPECIES[Trees.first(Trees.BROAD)]
				return "Сила удара: столько прочности снимает удар. %s (прочность %d): %d ударов" % [s.title, s.hits, Tools.hits_to(s.hits, p)]
		"pickaxe", "shovel":
			var m: int = Mat.STONE if it.tool == "pickaxe" else Mat.DIRT
			var t := Tools.toughness(m)
			var hardest := t
			for i in Mat.COUNT:
				if Tools.can_dig(it, i) and Tools.toughness(i) > hardest:
					hardest = Tools.toughness(i)
			return "Сила: ячейка прочнее силы копается дольше. %s (прочность %d): удар %.1f с; самое твёрдое по силам — прочность %d" % [
				Mat.NAMES[m], roundi(t), Tools.swing_time(it, m), roundi(hardest)]
		"sword", "knife", "spear", "sling", "bow":
			var big := {}
			for kind in AiRules.SPECIES:
				var a: Dictionary = AiRules.SPECIES[kind]
				if a.health > 0 and (big.is_empty() or a.health > big.health):
					big = a
			if not big.is_empty():
				return "Сила удара: столько здоровья снимает удар по зверю. %s (здоровье %d): %d ударов; по игроку — столько же на единицу урона сервера" % [
					big.title, big.health, Tools.hits_to(big.health, p)]
	return "Сила удара"


## Whether weapon `id` shoots something (arrows, sling stones) that bag `inv` has none
## of: it shows inactive then.
static func unarmed(inv, id: String) -> bool:
	var it := Items.get_item(id) if id != "" else {}
	var shoots: String = it.get("ammo", "")
	# A rod casts without bait too (the fish only bite seldom).
	return shoots != "" and it.get("tool", "") != "rod" and inv.count(shoots) == 0


## Seconds `t` as minutes and seconds, "6:00".
static func _minutes(t: float) -> String:
	var s := ceili(t)
	return "%d:%02d" % [s / 60, s % 60]
