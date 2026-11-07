extends SceneTree
## Writes docs/balance/GAME_BALANCE_TABLES.md, the tables of the game's balance, from the data
## of every mod as the game loads it and by the same formulas the rules use (Tools.swing_time,
## Tools.hits_to, SkillSet.pace / effort / blow, Vitals.COSTS), so the tables say what the
## game does (docs/balance/GAME_BALANCE_DESIGN.md), and checks they are fresh:
##     godot --headless --path . --script res://tools/balance_report.gd             writes it
##     godot --headless --path . --script res://tools/balance_report.gd -- --check  fails when it is stale
## The tables: the tools by class and tier; the tree × axe × skill matrix (hits, seconds,
## stamina); the cell × pickaxe and × shovel matrices; the beast × weapon matrix at no skill
## and at the last level; players fighting; the skills' levels (points, hours of work, what
## each level does); the stamina of sustained work; what a tool costs to make against how
## long it lasts; the food against a day's hunger. Run it after changing tools, trees,
## materials, creatures, skills or the rules' numbers; tests/unit/balance_test.gd holds the
## limits the tables must keep within.

const Content := preload("res://src/shared/content/content.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Skills := preload("res://src/shared/content/skills.gd")
const SkillSet := preload("res://src/shared/game/skill_set.gd")
const Vitals := preload("res://src/shared/game/vitals.gd")
const Rules := preload("res://src/shared/game/rules.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Clock := preload("res://src/shared/game/clock.gd")
const ContentGraph := preload("res://src/shared/content/content_graph.gd")

const OUT := "res://docs/balance/GAME_BALANCE_TABLES.md"
## The classes of tools the tables go through, in this order, and what they are called.
const CLASSES := {"axe": "Топоры", "pickaxe": "Кирки", "shovel": "Лопаты", "scythe": "Косы", "sickle": "Серпы",
	"hoe": "Тяпки", "sword": "Мечи", "knife": "Ножи", "spear": "Копья", "sling": "Пращи", "bow": "Луки", "rod": "Удочки"}
## What the hands do at each stamina cost (Vitals.COSTS) in the tables of stamina.
const WORK_OF := {"chop": ["chop", "axe"], "dig": ["dig", "pickaxe"], "swing": ["hunt", "sword"]}

var graph: ContentGraph


func _init() -> void:
	var check := "--check" in OS.get_cmdline_user_args()
	graph = ContentGraph.new()
	var text := _report()
	if check:
		if FileAccess.get_file_as_string(OUT) != text:
			printerr("stale: %s (run tools/balance_report.gd)" % OUT)
			quit(1)
			return
		print("fresh: %s" % OUT)
	else:
		DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
		var f := FileAccess.open(OUT, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("wrote %s" % OUT)
	quit(0)


func _report() -> String:
	var out: Array = []
	out.append("# Таблицы баланса")
	out.append("")
	out.append("Создаёт `tools/balance_report.gd` из данных всех модов теми же формулами, что и правила игры; руками не")
	out.append("править (`-- --check` проверяет свежесть). Формулы и их смысл — [GAME_BALANCE_DESIGN.md](GAME_BALANCE_DESIGN.md),")
	out.append("пределы, в которых таблицы должны держаться, — `tests/unit/balance_test.gd`. Время — секунды реального времени,")
	out.append("«Н0» — без навыка, «Н5» и «Н10» — на пятом и последнем уровне навыка этой работы; выносливость — из %d." % roundi(Vitals.MAX))
	out.append("")
	out.append_array(_tools())
	out.append_array(_chopping())
	out.append_array(_digging())
	out.append_array(_hunting())
	out.append_array(_pvp())
	out.append_array(_skills())
	out.append_array(_stamina())
	out.append_array(_economy())
	out.append_array(_food())
	return "\n".join(out) + "\n"


## The tool items of class `kind`, weakest first (by power, then by swing the slower first).
func _of_class(kind: String) -> Array:
	var out: Array = []
	for id in Items.IDS:
		var it := Items.get_item(id)
		if it.get("tool", "none") == kind:
			out.append(it)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.power != b.power:
			return a.power < b.power
		return a.swing > b.swing)
	return out


func _era(id: String) -> String:
	var n: Variant = graph.era.get("items/" + id)
	return "—" if n == null else str(n)


func _f(x: float, digits := 1) -> String:
	return ("%." + str(digits) + "f") % x


## A skill set at level `n` of every skill.
func _at(n: int) -> SkillSet:
	var s := SkillSet.new()
	for sk: Dictionary in Skills.ALL:
		if n > 0:
			s.gain(sk.role, Skills.need(sk, n))
	return s


# --- Tools ---------------------------------------------------------------------------


func _tools() -> Array:
	var out: Array = ["## Инструменты по классам", "",
		"Сила — сколько прочности снимает удар (дерево, камень, зверь); у копающих удар по ячейке прочнее силы длится",
		"в прочность/сила раз дольше. Эпоха — ступень прогресса по графу контента (0 — руки, 1 — камень, 3 — медь, 4 — бронза, 5 — железо, 6 — сталь).", ""]
	out.append("| Класс | Предмет | Сила | Удар, с | Клеток | Дальность | Прочность, ударов | Эпоха | Вес |")
	out.append("|---|---|---|---|---|---|---|---|---|")
	var hand: Dictionary = Tools.HAND
	out.append("| руки | %s | %d | %s | %d | %d | — | 0 | — |" % [hand.title, hand.power, _f(hand.swing, 2), hand.area, hand.reach])
	for kind: String in CLASSES:
		for it: Dictionary in _of_class(kind):
			var extra := ""
			if it.get("range", 0) > 0:
				extra = " (бросок %d)" % it.range
			out.append("| %s | %s | %d | %s | %d | %d%s | %s | %s | %s |" % [CLASSES[kind], it.title, it.power, _f(it.swing, 2),
				it.area, it.reach, extra, str(it.durability) if it.durability > 0 else "—", _era(it.id), _f(it.weight, 1)])
	out.append("")
	return out


# --- Chopping -------------------------------------------------------------------------


func _chopping() -> Array:
	var out: Array = ["## Рубка: дерево × топор × навык", "",
		"Ударов = ⌈прочность дерева / сила топора⌉; время = ударов × удар топора × темп навыка (Н10 — вдвое быстрее);",
		"силы = ударов × цена взмаха (%d) × доля навыка (Н10 — на %d%% дешевле). Навык Рубки не меняет число ударов:" % [roundi(Vitals.COSTS.chop), roundi(Skills.of_role("chop").effort * 100.0)],
		"разница топоров держится на любом уровне, а разница навыка — с любым топором.", ""]
	var axes := _of_class("axe")
	var s0 := _at(0)
	var s10 := _at(Skills.of_role("chop").levels)
	var head := "| Дерево | Прочность |"
	var line := "|---|---|"
	for a: Dictionary in axes:
		head += " %s: ударов / с Н0 / с Н10 / силы Н0 / силы Н10 |" % a.title.replace(" топор", "")
		line += "---|"
	out.append(head)
	out.append(line)
	var species: Array = Trees.SPECIES.duplicate()
	species.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.hits < b.hits or (a.hits == b.hits and a.id < b.id))
	for sp: Dictionary in species:
		var row := "| %s | %d |" % [sp.title, sp.hits]
		for a: Dictionary in axes:
			var hits := Tools.hits_to(sp.hits, a.power)
			row += " %d / %s / %s / %s / %s |" % [hits, _f(hits * a.swing * s0.pace("chop")), _f(hits * a.swing * s10.pace("chop")),
				_f(hits * Vitals.cost_of("chop", s0.effort("chop")), 0), _f(hits * Vitals.cost_of("chop", s10.effort("chop")), 0)]
		out.append(row)
	out.append("")
	# The matrix the task asks for (section 14): one tree, every axe, every level.
	var oak: Dictionary = Trees.SPECIES[Trees.first(Trees.BROAD)]
	out.append("### Контрольная таблица: %s (прочность %d), каждый топор на каждом уровне Рубки" % [oak.title, oak.hits])
	out.append("")
	out.append("Секунд на дерево (ударов). Условная проверка ТЗ — дерево прочности 8 с топорами 2/4/6 — дала бы 4/2/2 удара:")
	out.append("прочность в 8 слишком мала против лучшего топора, поэтому у деревьев она от %d до %d." % [species[0].hits, species[-1].hits])
	out.append("")
	var chop := Skills.of_role("chop")
	head = "| Уровень | Темп |"
	line = "|---|---|"
	for a: Dictionary in axes:
		head += " %s (сила %d) |" % [a.title.replace(" топор", ""), a.power]
		line += "---|"
	out.append(head)
	out.append(line)
	for n in chop.levels + 1:
		var s := _at(n)
		var row := "| %d | ×%s |" % [n, _f(s.boost("chop"), 2)]
		for a: Dictionary in axes:
			var hits := Tools.hits_to(oak.hits, a.power)
			row += " %s (%d) |" % [_f(hits * a.swing * s.pace("chop")), hits]
		out.append(row)
	out.append("")
	return out


# --- Digging --------------------------------------------------------------------------


func _digging() -> Array:
	var out: Array = ["## Копание: ячейка × инструмент × навык", "",
		"Секунд на ячейку = удар × max(1, прочность / сила) × темп навыка; «—» — инструмент её не берёт (твёрдость выше",
		"силы или не тот класс). Руки копают мягкий грунт в %s раза медленнее своего взмаха." % _f(Tools.HAND.slow, 1), ""]
	for kind in ["pickaxe", "shovel"]:
		var tools: Array = _of_class(kind)
		if kind == "shovel":
			tools.push_front(Tools.HAND)
		var s0 := _at(0)
		var s10 := _at(Skills.of_role("dig").levels)
		var head := "| Ячейка | Твёрдость | Прочность |"
		var line := "|---|---|---|"
		for t: Dictionary in tools:
			head += " %s: с Н0 / с Н10 |" % t.title
			line += "---|"
		out.append("### %s" % ("Киркой" if kind == "pickaxe" else "Лопатой и руками"))
		out.append("")
		out.append(head)
		out.append(line)
		for m in Mat.COUNT:
			var rec: Dictionary = Mat.RECORDS[m]
			if rec.dig != kind:
				continue
			var row := "| %s | %d | %s |" % [rec.title, rec.hardness, _f(Tools.toughness(m), 0)]
			for t: Dictionary in tools:
				if Tools.can_dig(t, m):
					row += " %s / %s |" % [_f(Tools.swing_time(t, m) * s0.pace("dig"), 2), _f(Tools.swing_time(t, m) * s10.pace("dig"), 2)]
				else:
					row += " — |"
			out.append(row)
		out.append("")
	return out


# --- Hunting --------------------------------------------------------------------------


func _hunting() -> Array:
	var hunt := Skills.of_role("hunt")
	var out: Array = ["## Охота: зверь × оружие × навык", "",
		"Удар = сила оружия, с навыком Охоты × (1 + %s × доля уровней), округлённый; ударов = ⌈здоровье / удар⌉; время — удары" % _f(hunt.might, 2),
		"подряд × взмах × темп (без погони: раненый зверь убегает %s с). Звери игрока не бьют: бой с ними — время и погоня." % _f(8.0, 0), ""]
	var weapons: Array = []
	for kind in ["sword", "knife", "spear", "sling", "bow"]:
		weapons.append_array(_of_class(kind))
	weapons.push_front(Tools.HAND)
	var s0 := _at(0)
	var s10 := _at(hunt.levels)
	var head := "| Зверь | Здоровье |"
	var line := "|---|---|"
	for w: Dictionary in weapons:
		head += " %s: ударов Н0 (с) / ударов Н10 (с) |" % w.title
		line += "---|"
	out.append(head)
	out.append(line)
	var kinds: Array = AiRules.SPECIES.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return AiRules.SPECIES[a].health < AiRules.SPECIES[b].health)
	for kind: String in kinds:
		var a: Dictionary = AiRules.SPECIES[kind]
		if a.health <= 0:
			continue
		var row := "| %s | %d |" % [a.title, a.health]
		for w: Dictionary in weapons:
			var h0 := Tools.hits_to(a.health, s0.blow("hunt", w.power))
			var h10 := Tools.hits_to(a.health, s10.blow("hunt", w.power))
			row += " %d (%s) / %d (%s) |" % [h0, _f(h0 * w.swing * s0.pace("hunt")), h10, _f(h10 * w.swing * s10.pace("hunt"))]
		out.append(row)
	out.append("")
	return out


# --- PvP ------------------------------------------------------------------------------


func _pvp() -> Array:
	var rules := Rules.new()
	var out: Array = ["## Игрок против игрока", "",
		"Урон = сила оружия × `pvp_damage` (%d) из %d здоровья; навыки удар по игроку не меняют, брони нет. Ударов до смерти и" % [rules.pvp_damage, roundi(Vitals.MAX)],
		"секунд ударов подряд (каждый попал).", ""]
	out.append("| Оружие | Сила | Урон | Ударов | Секунд |")
	out.append("|---|---|---|---|---|")
	var weapons: Array = [Tools.HAND]
	for kind in ["sword", "knife", "spear", "sling", "bow"]:
		weapons.append_array(_of_class(kind))
	for w: Dictionary in weapons:
		var dmg := maxi(1, w.power) * rules.pvp_damage
		var hits := ceili(Vitals.MAX / dmg)
		out.append("| %s | %d | %d | %d | %s |" % [w.title, w.power, dmg, hits, _f(hits * w.swing)])
	out.append("")
	return out


# --- Skills ---------------------------------------------------------------------------


func _skills() -> Array:
	var out: Array = ["## Навыки: уровни и их цена", "",
		"Очки — секунды полезной работы без навыка (взмах, который что-то сделал; время рецепта, тот же подряд — меньше;",
		"целая вещь — `each`). Первый уровень — `first` очков, каждый следующий в `growth` раза дороже. Что даёт уровень — доля",
		"уровней от предела навыка: темп (×), дешевле по силам, шанс лишней штуки, удар сильнее, вещи прочнее, бережность к инструменту.", ""]
	out.append("| Навык | Работа | Уровней | first | growth | Очков до 1 / 5 / 10 | Часов работы до 5 / 10 | На последнем: темп | силы | лишняя | удар | прочнее | бережность |")
	out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for sk: Dictionary in Skills.ALL:
		out.append("| %s | %s | %d | %d | %s | %d / %d / %d | %s / %s | ×%s | −%d%% | %d%% | +%d%% | +%d%% | %d%% |" % [sk.title, sk.role, sk.levels,
			roundi(sk.first), _f(sk.growth, 2), roundi(Skills.need(sk, 1)), roundi(Skills.need(sk, 5)), roundi(Skills.need(sk, sk.levels)),
			_f(Skills.need(sk, 5) / 3600.0, 2), _f(Skills.need(sk, sk.levels) / 3600.0, 2), _f(1.0 + sk.speed, 2), roundi(sk.effort * 100.0),
			roundi(sk.yield * 100.0), roundi(sk.might * 100.0), roundi(sk.quality * 100.0), roundi(sk.care * 100.0)])
	out.append("")
	var chop := Skills.of_role("chop")
	out.append("### Кривая одного навыка (%s)" % chop.title)
	out.append("")
	out.append("| Уровень | Очков всего | Минут работы | Темп | Сил на взмах | Шанс лишней | Бережность |")
	out.append("|---|---|---|---|---|---|---|")
	for n in chop.levels + 1:
		var s := _at(n)
		out.append("| %d | %d | %s | ×%s | %d%% | %d%% | %d%% |" % [n, roundi(Skills.need(chop, n)), _f(Skills.need(chop, n) / 60.0, 0),
			_f(s.boost("chop"), 2), roundi(s.effort("chop") * 100.0), roundi(s.extra_chance("chop") * 100.0), roundi(s.care_chance("chop") * 100.0)])
	out.append("")
	return out


# --- Stamina --------------------------------------------------------------------------


func _stamina() -> Array:
	var out: Array = ["## Выносливость непрерывной работы", "",
		"Отдых %s/с, во время работы (%s с после оплаченного взмаха) — %s/с. Расход в секунду = цена взмаха × доля навыка /" % [_f(Vitals.REST, 0), _f(Vitals.BUSY, 1), _f(Vitals.REST * Vitals.WORK_REST, 0)],
		"время взмаха; работа, что тратит меньше отдыха, не утомляет вовсе («∞»). Секунд до нуля — с полных %d сил. Инструмент" % roundi(Vitals.MAX),
		"лучше делает больше за взмах, а не тратит меньше: цена одного дерева или ячейки падает с инструментом (меньше ударов) и с навыком (дешевле взмах).", ""]
	out.append("| Работа | Инструмент | Цена взмаха Н0 / Н10 | Удар, с | Расход в с Н0 / Н10 | Секунд до нуля Н0 / Н10 |")
	out.append("|---|---|---|---|---|---|")
	for action: String in WORK_OF:
		var role: String = WORK_OF[action][0]
		var tools: Array = _of_class(WORK_OF[action][1])
		if action != "chop":
			tools.push_front(Tools.HAND)
		var s0 := _at(0)
		var s10 := _at(Skills.of_role(role).levels)
		for t: Dictionary in tools:
			var swing: float = t.swing
			if action == "dig":
				swing = Tools.swing_time(t, Mat.STONE if t.tool == "pickaxe" else Mat.DIRT)
			var c0 := Vitals.cost_of(action, s0.effort(role))
			var c10 := Vitals.cost_of(action, s10.effort(role))
			var d0 := c0 / (swing * s0.pace(role)) - Vitals.REST * Vitals.WORK_REST
			var d10 := c10 / (swing * s10.pace(role)) - Vitals.REST * Vitals.WORK_REST
			out.append("| %s | %s | %s / %s | %s | %s / %s | %s / %s |" % [action, t.title, _f(c0), _f(c10), _f(swing, 2),
				_f(d0), _f(d10), _f(Vitals.MAX / d0, 0) if d0 > 0.0 else "∞", _f(Vitals.MAX / d10, 0) if d10 > 0.0 else "∞"])
	out.append("")
	return out


# --- Economy --------------------------------------------------------------------------


func _economy() -> Array:
	var out: Array = ["## Цена инструмента против его срока", "",
		"Первый рецепт каждого инструмента: что берёт, где и сколько секунд; глубина — шагов изготовления от старта (граф);",
		"ударов на единицу материала — прочность / число взятых вещей (сколько работы покупает каждая вещь рецепта).", ""]
	out.append("| Предмет | Рецепт берёт | Станок | Время, с | Глубина | Прочность | Ударов на вещь рецепта | Чинят |")
	out.append("|---|---|---|---|---|---|---|---|")
	for kind: String in CLASSES:
		for it: Dictionary in _of_class(kind):
			var r := {}
			for rec: Dictionary in Crafting.RECIPES:
				if rec.makes == it.id:
					r = rec
					break
			if r.is_empty():
				continue
			var needs: Array = []
			var n := 0
			for id: String in r.needs:
				needs.append("%s ×%d" % [Items.title(id), r.needs[id]])
				n += int(r.needs[id])
			var repair: Array = []
			for id: String in it.repair:
				repair.append("%s ×%d" % [Items.title(id), it.repair[id]])
			var depth: Variant = graph.reached.get("items/" + it.id)
			out.append("| %s | %s | %s | %s | %s | %d | %d | %s |" % [it.title, ", ".join(needs), Items.title(r.at) if r.at != "" else "руки",
				_f(r.time, 0), str(depth) if depth != null else "—", it.durability, it.durability / maxi(1, n), ", ".join(repair) if not repair.is_empty() else "—"])
	out.append("")
	return out


# --- Food -----------------------------------------------------------------------------


func _food() -> Array:
	var out: Array = ["## Еда против голода", "",
		"Сытость уходит на %d в игровые сутки (%d мин реального времени при обычном ходе часов, 10 раз медленнее 4-минутных)," % [roundi(Vitals.HUNGER_PER_DAY), roundi(Clock.DAY_LENGTH * 10.0 / 60.0)],
		"вода — на %d, лечение — %d в сутки при сытости выше %d. Штук в сутки — сколько съесть за игровые сутки, чтобы не голодать." % [roundi(Vitals.THIRST_PER_DAY), roundi(Vitals.HEAL_PER_DAY), roundi(Vitals.WELL_FED)], ""]
	out.append("| Еда | Сытость | Лечит | Поит | Вес | Портится, суток | Штук в сутки | Сытости на кг |")
	out.append("|---|---|---|---|---|---|---|---|")
	var foods: Array = []
	for id in Items.IDS:
		var it := Items.get_item(id)
		if it.food > 0.0:
			foods.append(it)
	foods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.food > b.food)
	for it: Dictionary in foods:
		var spoils: float = it.get("spoils", 0.0)
		out.append("| %s | %d | %d | %d | %s | %s | %s | %d |" % [it.title, roundi(it.food), roundi(it.heal), roundi(it.get("drink", 0.0)),
			_f(it.weight, 2), _f(spoils, 1) if spoils > 0.0 else "не портится", _f(Vitals.HUNGER_PER_DAY / it.food, 1), roundi(it.food / maxf(0.01, it.weight))])
	out.append("")
	return out
