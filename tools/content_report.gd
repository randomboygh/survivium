extends SceneTree
## Writes the reports docs/ keeps of the content, from the data of every mod as the game
## loads it (docs/specifications/BUNDLE_SYSTEM.md, section 13), and checks they are fresh:
##     godot --headless --path . --script res://tools/content_report.gd             writes them
##     godot --headless --path . --script res://tools/content_report.gd -- --check  fails when one is stale
## docs/generated/content-index.md is the register of every record: its kind, category,
## description, the bundle that has it and what replaced or patched it, the era of an item
## and a recipe, how many records it names and how many name it (by the reference fields
## and their links, see Content.RELATIONS), and what the checks say of it.
## docs/generated/content-graph.md is the content graph (ContentGraph): the start, the items
## by depth, where each comes from and where it goes, the shared resources, what the hands
## and each tool get out of the world, the stations, the chain of each thing made, the map
## of the eras with the branches of progress and a diagram of the recipes.
## docs/generated/content-recipes.md is the register of recipes: by kind of work, what
## each makes and gives besides, uses up and keeps, its station, tools, time, depth, era
## and the other recipes of its thing. docs/generated/content-checks.md is what the checks
## found, each check with what it means and how to fix what it finds. CI runs --check;
## run it without arguments after changing the data.

const Content := preload("res://src/shared/content/content.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Items := preload("res://src/shared/content/items.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const Eras := preload("res://src/shared/content/eras.gd")
const ContentGraph := preload("res://src/shared/content/content_graph.gd")

const INDEX := "res://docs/generated/content-index.md"
const GRAPH := "res://docs/generated/content-graph.md"
const RECIPES := "res://docs/generated/content-recipes.md"
const CHECKS := "res://docs/generated/content-checks.md"
## The kinds by their names in the register, in its order; a kind not here comes after
## them under its own name.
const KINDS := {"items": "Предметы", "recipes": "Рецепты", "materials": "Материалы ячеек", "trees": "Деревья",
	"bushes": "Кусты", "plants": "Растения", "creatures": "Существа", "biomes": "Биомы", "starts": "Старт", "eras": "Эпохи",
	"sounds": "Звуки"}
## How the ways of the graph are said (ContentGraph.ways: the `via` of each).
const VIA := {"world": "мир", "start": "старт", "special": "особый источник", "recipe": "рецепт", "also": "побочно", "craft": "сделать",
	"spawns": "растёт в биоме", "lives": "живёт в биоме", "is": "это", "place": "поставить", "plant": "посадить",
	"sow": "посеять", "dig": "копать", "mow": "косить", "fell": "рубить", "gather": "собирать", "dig_out": "выкопать"}
## The kinds of work of recipes (`process`), in the order of the register of recipes.
const PROCESS := {"craft": "Изготовление", "refine": "Переработка", "smelt": "Плавка и обжиг", "cook": "Готовка"}
## The checks of the graph (ContentGraph.CHECKS): name, what they find, how to fix it.
const CHECK_TEXT := {
	"no_source": ["Нет источника", "предмет не делает ни один рецепт, его не даёт мир и его нет в старте",
		"рецепт или источник в мире (`item` клетки, `log`, `seed`, `fruit` дерева или куста, `gives` растения); то, что дают квест или торговля, помечается `source: special`"],
	"never_had": ["Не достать", "пути к предмету есть, но каждый требует того, чего не достать",
		"по причине в сообщении: дать недостающее раньше, другой станок или инструмент, ещё один путь"],
	"no_tool_item": ["Нет инструмента", "рецепт требует класс инструмента, которым не является ни один предмет",
		"предмет этого класса или другой класс в рецепте"],
	"never_made": ["Рецепт не сделать", "не достать материала, станка или инструмента рецепта",
		"по причине в сообщении, как для «Не достать»"],
	"never_grows": ["Не растёт", "растение, куст или дерево не растёт ни в одном биоме, и его не сажают и не сеют",
		"вписать в биом (`trees`, `bushes`) или дать предмет, который его сажает или сеет, и путь к этому предмету"],
	"no_food": ["Нет корма", "ничто из того, что ест животное (`likes`), в мире не растёт",
		"дать растению место в мире или поправить `likes`"],
	"cycle": ["Замкнутый круг", "каждая вещь круга требует следующую, и войти в круг извне нельзя",
		"путь к одной из вещей круга без остальных: другой рецепт, источник в мире, инструмент раньше"],
	"early_era": ["Эпоха раньше пути", "у предмета записана эпоха (`era`) раньше той, в которой его можно получить: рецепт требует вещь более поздней эпохи, или добыть его может только инструмент более поздней эпохи",
		"поднять `era` предмета, дать ему путь раньше или поправить эпоху того, что он требует"],
	"dead_end": ["Тупик", "вещь достаётся, но её не тратит ни один рецепт, ею ничего не чинят, и сама она ни для чего: не инструмент, не станок, не блок, не семя, не еда, не лекарство, не топливо, не свет",
		"рецепт, который её тратит, или назначение; или убрать её из источника"],
	"station": ["Станок одного рецепта", "на станке делают один рецепт или ни одного",
		"ещё рецепты на этом станке или перенести рецепт на другой"],
	"twins": ["Двойники", "вещи одинаковы во всём, что делают, и в том, кому нужны",
		"развести свойства или назначение, или оставить одну"],
	"loop": ["Прибыльный круг", "круг рецептов возвращает вещи больше, чем взял (прочие материалы рецептов круга не считаются): бесконечный источник",
		"уравнять количества в рецептах круга"],
	"never_appears": ["Материал не встречается", "генератор не кладёт его ни для одной роли, и его не ставит ни один предмет",
		"роль в биоме или предмет с `place`"],
	"long_chain": ["Длинная цепочка", "вещь дальше от старта, чем ждёт её эпоха (`depth` эпохи): длинная цепочка для ранней ступени",
		"короче цепочка, позже эпоха у вещи (`era`) или больше `depth` у эпохи"],
}

## The graph of the full set, and the problems of the loader and the registries in it.
var graph: ContentGraph
var loader_errors: PackedStringArray = []


func _init() -> void:
	# What the validator sees: the full set, a soft reference to nothing a problem too.
	Content.strict = true
	Mods.rescan()
	graph = ContentGraph.new()
	loader_errors = Content.problems + Crafting.check() + Starts.check() + Eras.check()
	var wanted := {INDEX: _index(), GRAPH: _graph(), RECIPES: _recipes(), CHECKS: _checks()}
	Content.strict = false
	var stale := []
	var check := "--check" in OS.get_cmdline_user_args()
	for path: String in wanted:
		if check:
			if FileAccess.get_file_as_string(path) != wanted[path]:
				stale.append(path)
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(wanted[path])
		f.close()
		print("wrote " + path.trim_prefix("res://"))
	for path: String in stale:
		printerr("%s is stale: run godot --headless --path . --script res://tools/content_report.gd" % path.trim_prefix("res://"))
	if check and stale.is_empty():
		print("content reports OK")
	quit(1 if not stale.is_empty() else 0)


## The register of records (result 2 of the spec): the mods and their bundles, then a
## table per kind.
func _index() -> String:
	var out := ["# Реестр сущностей", "",
		"Создаёт `tools/content_report.gd` из данных всех модов, как их грузит игра; руками не править. После",
		"правки данных: `godot --headless --path . --script res://tools/content_report.gd`; CI проверяет, что",
		"реестр свежий. Правила системы — [BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md).", "",
		"Категория — у предметов та, что выводит игра (у рецепта — его предмета), у остальных их роль или вид.",
		"Бандл — где запись определена; «→» — кто её заменил (`replaces`), «патчи» — кто поправил.",
		"Эпоха — у предметов и рецептов та, что выводит граф (карта эпох — в [content-graph.md](content-graph.md)).",
		"Связи — сколько записей называет эта и сколько называют её (поля-ссылки с типом связи `rel`).",
		"Проверка — что говорят о записи проверки загрузки и графа: «ок», ошибки или предупреждения. Граф —",
		"[content-graph.md](content-graph.md), что нашли проверки — [content-checks.md](content-checks.md).", "",
		"## Моды и бандлы", ""]
	for mod: String in Content.available():
		var bundles := Content.bundles_of(mod)
		var line := "- `%s` %s" % [mod, Mods.mod_title(mod)]
		if bundles != [mod]:
			var parts := []
			for b: String in bundles:
				parts.append("`%s` %s" % [b, Mods.title(b)])
			line += ": " + ", ".join(parts)
		out.append(line)
	var links := _links()
	var kinds := KINDS.keys().filter(func(k: String) -> bool: return Content.SCHEMAS.has(k))
	for kind: String in Content.SCHEMAS:
		if not kind in kinds:
			kinds.append(kind)
	for kind: String in kinds:
		var recs := Content.records(kind)
		var dated: bool = kind in ["items", "recipes"]
		out += ["", "## %s (`%s`, %d)" % [KINDS.get(kind, kind), kind, recs.size()], "",
			"| Id | Название | Категория | Описание | Бандл |%s Связи из / в | Проверка |" % (" Эпоха |" if dated else ""),
			"|---|---|---|---|---|%s---|---|" % ("---|" if dated else "")]
		for r: Dictionary in recs:
			var key := "%s/%s" % [kind, r.id]
			var l: Array = links.get(key, [0, 0])
			out.append("| `%s` | %s | %s | %s | %s |%s %d / %d | %s |" % [r.id, _cell(r.title), _cell(_category(kind, r)),
				_cell(r.description), _origin(kind, r.id), " %s |" % _era(key) if dated else "", l[0], l[1], _status(kind, r.id)])
	return "\n".join(out) + "\n"


## "kind/id" -> [how many records it names, how many name it], by every reference field
## (Content.refs, the entries of a field too).
func _links() -> Dictionary:
	var out := {}
	for kind: String in Content.SCHEMAS:
		for ref: Array in Content.refs(kind):
			for r: Dictionary in Content.records(kind):
				for id: String in Content.named(r, ref[0]):
					var from := "%s/%s" % [kind, r.id]
					var to := "%s/%s" % [Content.target(ref[1]), id]
					out[from] = [out.get(from, [0, 0])[0] + 1, out.get(from, [0, 0])[1]]
					out[to] = [out.get(to, [0, 0])[0], out.get(to, [0, 0])[1] + 1]
	return out


func _category(kind: String, r: Dictionary) -> String:
	match kind:
		"items":
			return Items.CATEGORIES[Items.category(r.id)]
		"recipes":
			return Items.CATEGORIES[Items.category(r.makes)]
		"materials":
			return r.role if r.role != "none" else ""
		"plants":
			return r.kind
		"biomes":
			return r.where
		"trees":
			return r.leaves
		"eras":
			return "порядок %d" % r.order
	return ""


func _origin(kind: String, id: String) -> String:
	var o := Content.origin(kind, id)
	var text := "`%s`" % o.bundle
	for b: String in o.replaced:
		text += " → `%s`" % b
	if not o.patched.is_empty():
		text += "; патчи: " + ", ".join(o.patched.map(func(b: String) -> String: return "`%s`" % b))
	return text


## What the checks say of record `id` of `kind`: "ок", or how many errors and warnings
## name it (the loader's by the id in their text, the graph's by the records they are about).
func _status(kind: String, id: String) -> String:
	var said := func(lines: PackedStringArray) -> int:
		return Array(lines).filter(func(p: String) -> bool:
			return ("`%s`" % id) in p or (" %s." % id) in p or (" %s:" % id) in p).size()
	var errors: int = said.call(loader_errors)
	var warnings: int = said.call(Content.warnings)
	for f: Dictionary in graph.findings:
		if f.keys.has("%s/%s" % [kind, id]):
			if ContentGraph.CHECKS[f.check]:
				errors += 1
			else:
				warnings += 1
	var parts := []
	if errors > 0:
		parts.append("ошибки: %d" % errors)
	if warnings > 0:
		parts.append("предупреждения: %d" % warnings)
	return "ок" if parts.is_empty() else ", ".join(parts)


## Text for a table cell: one line, no column bar.
func _cell(text: String) -> String:
	return " ".join(text.split("\n")).replace("|", "\\|")


# --- The content graph --------------------------------------------------------------------

## The content graph (results 4–8 of the spec, section 13 of BUNDLE_SYSTEM.md).
func _graph() -> String:
	var out := ["# Граф контента", "",
		"Создаёт `tools/content_report.gd` из данных всех модов по графу `src/shared/content/content_graph.gd`;",
		"руками не править, CI проверяет, что граф свежий. Правила — раздел 11",
		"[BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md), что нашли проверки — [content-checks.md](content-checks.md),",
		"все записи — [content-index.md](content-index.md).", "",
		"Граф идёт от старта по правилам рук (`Tools`, тем же, что в игре): мир даёт биомы, клетки, растения, деревья",
		"и кусты; действие над ними инструментом, что уже есть, даёт вещи; рецепты делают из них новые на",
		"поставленных станках; поставленное, посаженное и посеянное даёт своё, пока не перестаёт прибавляться новое.",
		"Глубина — сколько шагов изготовления отделяет вещь от старта: что мир и старт дают голыми руками — 0,",
		"добытое инструментом — глубина самого раннего инструмента, который это может, изделие — на 1 больше",
		"самого глубокого из материалов, станка и инструмента своего рецепта."]
	out += _start()
	out += _depths()
	out += _items()
	out += _shared()
	out += _harvest()
	out += _stations()
	out += _chains()
	out += _era_map()
	out += _diagram()
	return "\n".join(out) + "\n"


func _start() -> Array:
	var s := Starts.START
	var bag := []
	for id: String in s.bag:
		bag.append("%s ×%d" % [_title("items/" + id), s.bag[id]])
	var out := ["", "## Старт", "", "Новый мир начинается по записи `%s` «%s»." % [s.id, s.title], "",
		"- Сумка: %s." % (", ".join(bag) if not bag.is_empty() else "пусто")]
	for e: Dictionary in s.camp:
		out.append("- У точки появления: %s, %s." % [_title("items/" + e.item), _offset(e.at)])
	return out


## Where a thing of the camp stands from the spawn: "на 4 клетки к западу и на 4 к югу".
static func _offset(at: Array) -> String:
	var parts := []
	if at[0] != 0:
		parts.append("%s к %s" % [_cells(absi(at[0]), true), "востоку" if at[0] > 0 else "западу"])
	if at[1] != 0:
		parts.append("%s к %s" % [_cells(absi(at[1]), parts.is_empty()), "югу" if at[1] > 0 else "северу"])
	return "на " + " и на ".join(parts) if not parts.is_empty() else "на ней самой"


## `n` cells after «на»: "1 клетку", "3 клетки", "5 клеток"; the number alone without `noun`.
static func _cells(n: int, noun: bool) -> String:
	if not noun:
		return str(n)
	var form := "клеток"
	if n % 10 == 1 and n % 100 != 11:
		form = "клетку"
	elif n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]:
		form = "клетки"
	return "%d %s" % [n, form]


## The items by depth, the branches of progress side by side (result 8, until the eras).
func _depths() -> Array:
	var by := {}
	for id: String in Items.IDS:
		var d: int = graph.reached.get("items/" + id, -1)
		if not by.has(d):
			by[d] = []
		by[d].append(_title("items/" + id))
	var depths := by.keys()
	depths.sort()
	if depths.has(-1):
		depths.erase(-1)
		depths.append(-1)
	var out := ["", "## Предметы по глубине", "", "| Глубина | Предметы |", "|---|---|"]
	for d: int in depths:
		out.append("| %s | %s |" % [str(d) if d >= 0 else "не достать", ", ".join(by[d])])
	return out


## Where each item comes from and where it goes (result 4).
func _items() -> Array:
	var out := ["", "## Откуда и куда", "",
		"Откуда — все пути к предмету, первым тот, что даёт ему глубину. Куда — рецепты, которые его тратят,",
		"рецепты на нём как на станке, что им чинят, и для чего он сам.", "",
		"| Предмет | Глубина | Откуда | Куда |", "|---|---|---|---|"]
	for id: String in Items.IDS:
		var key := "items/" + id
		out.append("| %s | %s | %s | %s |" % [_named(key), _depth(key), _from(key), _to(id)])
	return out


## The ways to `key` by how they go ("рубить: Дуб, Сосна; рецепт: Доски"), the one of its
## depth first.
func _from(key: String) -> String:
	var ways: Array = graph.sources.get(key, []).duplicate()
	if graph.how.has(key):
		ways.erase(graph.how[key])
		ways.push_front(graph.how[key])
	var by := {}
	for w: Dictionary in ways:
		var via: String = VIA.get(w.via, w.via)
		if not by.has(via):
			by[via] = []
		if w.from != "" and w.via != "start" and not _title(w.from) in by[via]:
			by[via].append(_title(w.from))
	var parts := []
	for via: String in by:
		parts.append(via + (": " + ", ".join(by[via]) if not by[via].is_empty() else ""))
	return "; ".join(parts) if not parts.is_empty() else "—"


## Where item `id` goes: the recipes that use it up, those made at it, what is mended with
## it, and what it is for itself.
func _to(id: String) -> String:
	var item := Items.get_item(id)
	var by := {}
	for u: Array in graph.uses.get("items/" + id, []):
		var what: String = {"consumes": "в рецепты", "requires": "нужен в сумке рецептам", "requires_station": "станок рецептов",
			"repaired_with": "чинит"}.get(u[0], u[0])
		if not by.has(what):
			by[what] = []
		by[what].append(_title(u[1]))
	var parts := []
	for what: String in by:
		parts.append("%s: %s" % [what, ", ".join(by[what])])
	if item.tool != "none":
		parts.append("инструмент: %s" % Items.tool_title(item.tool))
	if item.storage > 0:
		parts.append("хранит вещи: %d мест" % item.storage)
	elif item.prop != "none" and not by.has("станок рецептов"):
		parts.append("станок")
	parts += _flags(item)
	for f: String in ["place", "plant", "sow", "crop"]:
		if item[f] != "":
			var of := {"place": "materials", "plant": "bushes", "sow": "materials", "crop": "plants"}[f] as String
			parts.append("%s: %s" % [{"place": "блок", "plant": "сажает", "sow": "засевает", "crop": "растит"}[f], _title("%s/%s" % [of, item[f]])])
	for f: String in ["food", "heal", "fuel", "light"]:
		var v: Variant = item[f]
		if v is bool and v or (v is float or v is int) and v > 0:
			parts.append({"food": "еда", "heal": "лечит", "fuel": "топливо", "light": "свет"}[f])
	return "; ".join(parts) if not parts.is_empty() else "—"


## The items two recipes or more use up, and what stands on each (result 6): what is made
## of it, then of that, along the ways of the depths, stations and tools too.
func _shared() -> Array:
	var on := {}
	for key: String in graph.reached:
		for b: String in graph.basis(key):
			if not on.has(b):
				on[b] = []
			on[b].append(key)
	var out := ["", "## Общие ресурсы", "",
		"Предметы, которые тратят два рецепта и больше. На нём держится — всё, что делается из него прямо или",
		"дальше по цепочкам (по путям, которые дают глубину), через станки и инструменты тоже.", "",
		"| Ресурс | Тратят рецепты | На нём держится |", "|---|---|---|"]
	for id: String in Items.IDS:
		var key := "items/" + id
		var users := Array(graph.uses.get(key, [])).filter(func(u: Array) -> bool: return u[0] == "consumes")
		if users.size() < 2:
			continue
		var held := _closure(key, on).filter(func(k: String) -> bool: return k.begins_with("items/") and k != key)
		out.append("| %s | %s | %s |" % [_named(key), ", ".join(users.map(func(u: Array) -> String: return _title(u[1]))),
			", ".join(held.map(_title)) if not held.is_empty() else "—"])
	return out


## What the hands and the tools get out of the world (result 7): for the cells, trees,
## bushes and plants, each action, what it gives and what does it, by the rules of the
## hands; things alike in all that share a line.
func _harvest() -> Array:
	var rows := {}
	for w: Dictionary in graph.ways:
		if w.act == "" or w.from == "":
			continue
		var k: String = w.from + " " + w.act
		if not rows.has(k):
			rows[k] = {"from": w.from, "act": w.act, "gives": [], "way": w}
		if not _title(w.to) in rows[k].gives:
			rows[k].gives.append(_title(w.to))
	var keys := rows.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ta := _title(rows[a].from)
		var tb := _title(rows[b].from)
		return ta < tb if ta != tb else a < b)
	var lines := {}
	for k: String in keys:
		var r: Dictionary = rows[k]
		var by := ["руки"] if graph.by_hand(r.way) else []
		by += graph.able(r.way).map(func(id: String) -> String: return _title("items/" + id))
		var line := [r.from.get_slice("/", 0), VIA.get(r.act, r.act), ", ".join(r.gives), ", ".join(by) if not by.is_empty() else "ничем"]
		if not lines.has(line):
			lines[line] = []
		lines[line].append(_title(r.from))
	var out := ["", "## Инструменты и добыча", "",
		"Что даёт мир каждым действием и чем это сделать: руками или предметом-инструментом (по правилам `Tools`,",
		"тем же, что в игре). Одинаковое у нескольких записей — одной строкой."]
	for kind: String in ["materials", "trees", "bushes", "plants"]:
		out += ["", "### %s" % {"materials": "Клетки", "trees": "Деревья", "bushes": "Кусты", "plants": "Растения"}[kind], "",
			"| Что | Действие | Даёт | Чем |", "|---|---|---|---|"]
		for line: Array in lines:
			if line[0] == kind:
				out.append("| %s | %s | %s | %s |" % [", ".join(lines[line]), line[1], line[2], line[3]])
	return out


## The stations, the recipes made at each and what else each does, the hands' first.
func _stations() -> Array:
	var out := ["", "## Станки", "", "| Станок | Класс | Глубина | Рецепты | Ещё |", "|---|---|---|---|---|"]
	var of := func(at: String) -> String:
		return ", ".join(Array(Crafting.RECIPES).filter(func(r: Dictionary) -> bool: return r.at == at)
			.map(func(r: Dictionary) -> String: return _title("recipes/" + r.id)))
	out.append("| Руки, без станка | — | 0 | %s | — |" % of.call(""))
	for id: String in Items.IDS:
		if Items.is_station(id):
			var item := Items.get_item(id)
			var made: String = of.call(id)
			var more := _flags(item)
			out.append("| %s | `%s` | %s | %s | %s |" % [_named("items/" + id), item.prop, _depth("placed/" + id),
				made if made != "" else "—", "; ".join(more) if not more.is_empty() else "—"])
	return out


## What the flags of a thing set down make it do besides (Placed): it burns, tools are
## mended at it, it stands in for other stations, it is set down with a tool.
func _flags(item: Dictionary) -> Array:
	var out := []
	if item.fire:
		out.append("горит: тушится и разжигается топливом")
	if item.repairs:
		out.append("здесь чинят инструменты")
	if not item.serves.is_empty():
		out.append("заменяет: " + ", ".join(item.serves.map(func(id: String) -> String: return _title("items/" + id))))
	if item.place_tool != "none":
		out.append("ставится, если в сумке есть: %s" % Items.tool_title(item.place_tool))
	return out


## The chain of each thing made (result 5): what it comes of, down to what the world gives,
## along the ways of the depths.
func _chains() -> Array:
	var back := {}
	for key: String in graph.reached:
		back[key] = graph.basis(key)
	var made := Array(Items.IDS).filter(func(id: String) -> bool:
		return graph.how.get("items/" + id, {}).get("via", "") in ["recipe", "also"])
	made.sort_custom(func(a: String, b: String) -> bool:
		var da: int = graph.reached["items/" + a]
		var db: int = graph.reached["items/" + b]
		return da < db if da != db else a < b)
	var out := ["", "## Цепочки", "",
		"Из чего складывается каждое изделие по путям, которые дают ему глубину: сырьё — что даёт мир и старт,",
		"промежуточное — изделия по дороге, станки и инструменты — те, без которых на этом пути не обойтись.", "",
		"| Изделие | Глубина | Сырьё | Промежуточное | Станки | Инструменты |", "|---|---|---|---|---|---|"]
	for id: String in made:
		var parts := [[], [], [], []]
		for k: String in _closure("items/" + id, back):
			if not k.begins_with("items/") or k == "items/" + id:
				continue
			var item := Items.get_item(k.substr(6))
			var i := 3 if item.tool != "none" else 2 if item.prop != "none" else 1 if graph.how[k].via in ["recipe", "also"] else 0
			parts[i].append(_title(k))
		var cells := parts.map(func(p: Array) -> String: return ", ".join(p) if not p.is_empty() else "—")
		out.append("| %s | %s | %s | %s | %s | %s |" % ([_named("items/" + id), _depth("items/" + id)] + cells))
	return out


## The recipes as a mermaid diagram: an arrow from each material to what is made of it and
## its by-products, a dotted one from the station, the tools and what is kept; what no
## recipe makes is rounded, stations are framed, a tool of a kind is a hexagon.
func _diagram() -> Array:
	var out := ["", "## Схема рецептов", "",
		"Сплошная стрелка — материал рецепта (к изделию и побочному), пунктир — то, что не тратится: станок,",
		"инструмент, вещь в сумке. Скруглено то, что не делает ни один рецепт (его даёт мир или старт), в рамке —",
		"станки, в шестиугольнике — инструмент любого вида.", "", "```mermaid", "flowchart LR"]
	var nodes := {}
	var node := func(key: String) -> String:
		if not nodes.has(key):
			nodes[key] = "n%d" % nodes.size()
			var title := _title(key).replace("\"", "#quot;")
			var item := Items.get_item(key.substr(6)) if key.begins_with("items/") else {}
			var shape := "[\"%s\"]"
			if key.begins_with("tool/"):
				shape = "{{\"%s\"}}"
			elif not item.is_empty() and item.prop != "none":
				shape = "[[\"%s\"]]"
			elif not Array(Crafting.RECIPES).any(func(r: Dictionary) -> bool: return key.substr(6) in _made_by(r)):
				shape = "([\"%s\"])"
			out.append("  %s%s" % [nodes[key], shape % title])
		return nodes[key]
	for r: Dictionary in Crafting.RECIPES:
		var to: String = node.call("items/" + r.makes)
		for made: String in _made_by(r):
			for id: String in r.needs:
				out.append("  %s --> %s" % [node.call("items/" + id), node.call("items/" + made)])
		var kept := ["items/" + r.at] if r.at != "" else []
		kept += r.tools.map(func(kind: String) -> String: return "tool/" + kind)
		kept += r.keeps.keys().map(func(id: String) -> String: return "items/" + id)
		for k: String in kept:
			out.append("  %s -.-> %s" % [node.call(k), to])
	out.append("```")
	return out


## The map of the eras (result 8 of the spec, in place of a tree of technologies): for each
## era what it opens (the items that name it, `era`) and what comes in it by the kinds of
## items, then the branches of progress (see _branches).
func _era_map() -> Array:
	var out := ["", "## Карта эпох", "",
		"Эпоха — ступень прогресса (`core/data/eras.yaml`, раздел 9 [BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md));",
		"в игре она ничего не запрещает. Эпоха вещи — самая ранняя, в которой её можно получить: изделие — самая",
		"поздняя эпоха того, что требует рецепт (материалы, вещь в сумке, станок, инструменты), добытое — эпоха",
		"самого раннего инструмента, который это может, поставленное по старту — первая; но не раньше эпохи,",
		"записанной у предмета (`era`). Жирным — предметы, у которых эпоха записана: они открывают ступень. В",
		"каждой эпохе вещи по видам, от меньшей глубины к большей."]
	if Eras.ERAS.is_empty():
		return out + ["", "Эпох нет: ни один мод их не задаёт."]
	var by := {}
	var ids := Array(Items.IDS).filter(func(id: String) -> bool: return graph.era.has("items/" + id))
	var order := {}
	for i in ids.size():
		order[ids[i]] = i
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: int = graph.reached["items/" + a]
		var db: int = graph.reached["items/" + b]
		return da < db or (da == db and order[a] < order[b]))
	for id: String in ids:
		var n: int = graph.era["items/" + id]
		if not by.has(n):
			by[n] = {}
		var kind := Items.category(id)
		by[n][kind] = by[n].get(kind, []) + ["**%s**" % _title("items/" + id) if Items.get_item(id).era != "" else _title("items/" + id)]
	for n in Eras.ERAS.size():
		var e: Dictionary = Eras.ERAS[n]
		out += ["", "### %s `%s`" % [Eras.title(n), e.id], ""]
		var about: String = e.description
		if e.depth > 0:
			about += (" " if about != "" else "") + "Цепочки — до %d шагов от старта." % e.depth
		if about != "":
			out += [about, ""]
		if not by.has(n):
			out.append("Вещей этой эпохи пока нет.")
			continue
		for kind: String in Items.CATEGORIES:
			if by[n].has(kind):
				out.append("- %s: %s." % [Items.CATEGORIES[kind], ", ".join(by[n][kind])])
	out += _branches()
	return out


## The branches of progress as a mermaid diagram, an era to a box: the tools, the stations
## and the items that open an era, an arrow to each from those it comes of directly, by the
## ways that give them their eras (through things that are none of these).
func _branches() -> Array:
	var nodes := Array(Items.IDS).filter(func(id: String) -> bool:
		var item := Items.get_item(id)
		return graph.era.has("items/" + id) and (item.tool != "none" or Items.is_station(id) or item.era != ""))
	var back := {}
	for key: String in graph.era:
		back[key] = graph.basis(key, true)
	var under := {}
	for id: String in nodes:
		var seen := _closure("items/" + id, back)
		under[id] = nodes.filter(func(o: String) -> bool: return o != id and seen.has("items/" + o))
	var out := ["", "### Ветки", "",
		"Инструменты, станки и то, что открывает эпоху, по эпохам; стрелка — из чего вещь выходит прямо (через",
		"материалы и прочее, что не показано). Ветки, что идут рядом, не зависят друг от друга.", "", "```mermaid",
		"flowchart LR"]
	for n in Eras.ERAS.size():
		var here := nodes.filter(func(id: String) -> bool: return graph.era["items/" + id] == n)
		if here.is_empty():
			continue
		out.append("  subgraph e%d[\"%s\"]" % [n, Eras.title(n)])
		for id: String in here:
			out.append("    b%d[\"%s\"]" % [nodes.find(id), _title("items/" + id)])
		out.append("  end")
	for id: String in nodes:
		var from: Array = under[id]
		for o: String in from:
			if not from.any(func(m: String) -> bool: return m != o and under[m].has(o)):
				out.append("  b%d --> b%d" % [nodes.find(o), nodes.find(id)])
	out.append("```")
	return out


## The items recipe `r` makes: its own, then its by-products.
static func _made_by(r: Dictionary) -> Array:
	var out := [r.makes]
	for e: Dictionary in r.also:
		if not out.has(e.item):
			out.append(e.item)
	return out


## Every key reached from `start` along `edges` (key -> keys), `start` first.
static func _closure(start: String, edges: Dictionary) -> Array:
	var seen := {start: true}
	var queue := [start]
	var i := 0
	while i < queue.size():
		for k: String in edges.get(queue[i], []):
			if not seen.has(k):
				seen[k] = true
				queue.append(k)
		i += 1
	return queue


## The title of the record of `key` ("items/x"; "placed/x", a thing set down; "tool/k", a
## tool of a kind), its id when it has none.
func _title(key: String) -> String:
	var kind := key.get_slice("/", 0)
	var id := key.substr(kind.length() + 1)
	if kind == "placed":
		return _title("items/" + id)
	if kind == "tool":
		return "%s (любой)" % Items.tool_title(id)
	return graph.records.get(key, {}).get("title", id)


## The title of the record of `key` with its id: "Бревно `resources:log`".
func _named(key: String) -> String:
	return "%s `%s`" % [_title(key), key.substr(key.find("/") + 1)]


func _depth(key: String) -> String:
	return str(graph.reached[key]) if graph.reached.has(key) else "не достать"


## The era of `key` by the graph ("1. Примитивные инструменты"), "—" for what is never reached.
func _era(key: String) -> String:
	return Eras.title(graph.era[key]) if graph.era.has(key) else "—"


# --- The register of recipes -------------------------------------------------------------

## The register of recipes (result 3 of the spec): by kind of work, each recipe with what
## it makes and gives besides, uses up and keeps, its station and those that serve it, its
## tools and their wear, its time, the depth and the era of its thing by it and the other
## recipes of it.
func _recipes() -> String:
	var out := ["# Реестр рецептов", "",
		"Создаёт `tools/content_report.gd` из данных всех модов; руками не править, CI проверяет, что реестр свежий.",
		"Поля рецепта — [DATA_MODEL.md](../DATA_MODEL.md), правила — раздел 6",
		"[BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md), что из чего по цепочкам — [content-graph.md](content-graph.md).", "",
		"Рецепт узнаётся, когда в сумке побывало всё, что он тратит. Тратит — забирается из сумки, когда работа",
		"встаёт в очередь (отмена возвращает); в сумке — нужно, пока идёт работа, и не тратится. Станок — где",
		"делают; годится и тот, что его заменяет (`serves`). Инструменты — классы, по одному каждого в сумке;",
		"износ — сколько ударов снимает с инструмента каждое изделие, когда износ включён. Побочно — что выходит",
		"вместе с изделием, с шансом, который решает номер работы, а не случай. Глубина — шагов изготовления",
		"от старта до изделия по этому рецепту, эпоха — самая поздняя эпоха того, что рецепт требует (карта эпох —",
		"в [content-graph.md](content-graph.md)). Альтернативы — другие рецепты той же вещи.", "",
		"## Сводка", "", "| Процесс | Рецептов | Где делают |", "|---|---|---|"]
	var by := {}
	for r: Dictionary in Crafting.RECIPES:
		by[r.process] = by.get(r.process, []) + [r]
	for p: String in PROCESS:
		if by.has(p):
			var at := []
			for r: Dictionary in by[p]:
				var where := _title("items/" + r.at) if r.at != "" else "руки"
				if not where in at:
					at.append(where)
			out.append("| %s (`%s`) | %d | %s |" % [PROCESS[p], p, by[p].size(), ", ".join(at)])
	for p: String in PROCESS:
		if not by.has(p):
			continue
		out += ["", "## %s (`%s`)" % [PROCESS[p], p], "",
			"| Рецепт | Делает | Тратит | В сумке | Станок | Инструменты | Время | Глубина | Эпоха | Альтернативы |",
			"|---|---|---|---|---|---|---|---|---|---|"]
		for r: Dictionary in by[p]:
			var key: String = "recipes/" + r.id
			var makes := "%s ×%d" % [_title("items/" + r.makes), r.count]
			for e: Dictionary in r.also:
				makes += "; побочно: %s ×%d%s" % [_title("items/" + e.item), e.count,
					" (%d%%)" % roundi(e.chance * 100.0) if e.chance < 1.0 else ""]
			var tools: Array = r.tools.map(func(kind: String) -> String: return Items.tool_title(kind))
			var others := Array(Crafting.RECIPES).filter(func(o: Dictionary) -> bool: return o.makes == r.makes and o.id != r.id)
			out.append("| %s | %s | %s | %s | %s | %s | %d с | %s | %s | %s |" % [_named(key), makes, _amounts(r.needs), _amounts(r.keeps),
				_station(r.at), (", ".join(tools) + (" (износ %d)" % r.wear if r.wear > 0 else "")) if not tools.is_empty() else "—",
				roundi(r.time), str(graph.reached[key] + 1) if graph.reached.has(key) else "не сделать", _era(key),
				", ".join(others.map(func(o: Dictionary) -> String: return _named("recipes/" + o.id))) if not others.is_empty() else "—"])
	return "\n".join(out) + "\n"


## "Бревно ×1, Ветка ×2" for a mapping of item ids to how many, "—" for none.
func _amounts(amounts: Dictionary) -> String:
	var parts := []
	for id: String in amounts:
		parts.append("%s ×%d" % [_title("items/" + id), amounts[id]])
	return ", ".join(parts) if not parts.is_empty() else "—"


## Station `at` of a recipe with those that serve it: "Верстак (или Стойка)"; "руки" for none.
func _station(at: String) -> String:
	if at == "":
		return "руки"
	var servers := Array(Items.IDS).filter(func(id: String) -> bool: return Items.get_item(id).serves.has(at))
	return _title("items/" + at) + (" (или %s)" % ", ".join(servers.map(func(id: String) -> String: return _title("items/" + id)))
		if not servers.is_empty() else "")


# --- What the checks found ----------------------------------------------------------------

## What the checks found (result 9): every check with what it means, how to fix what it
## finds and how many it found, then each finding.
func _checks() -> String:
	var found := {}
	for f: Dictionary in graph.findings:
		if not found.has(f.check):
			found[f.check] = []
		found[f.check].append(f)
	var out := ["# Проверки контента", "",
		"Создаёт `tools/content_report.gd` из данных всех модов; руками не править, CI проверяет, что отчёт свежий.",
		"Ошибки валят CI: их же находит валидатор `tools/validate.gd`, который проверяет ещё картинки, звуки, модели",
		"и каждый бандл отдельно. Предупреждения CI не валят. Правила — раздел 11",
		"[BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md), граф — [content-graph.md](content-graph.md).", "",
		"## Сводка", "", "| Проверка | Вид | Найдено | Что находит | Как исправить |", "|---|---|---|---|---|",
		"| Загрузка и схемы | ошибка | %d | битые ссылки, поля не по схеме, повтор id, станок рецепта не станок, износ без инструмента, лагерь старта, две эпохи одного порядка | по сообщению |" % loader_errors.size()]
	for check: String in ContentGraph.CHECKS:
		var t: Array = CHECK_TEXT[check]
		out.append("| %s | %s | %d | %s | %s |" % [t[0], "ошибка" if ContentGraph.CHECKS[check] else "предупреждение",
			found.get(check, []).size(), t[1], t[2]])
	out.append("| Имена | предупреждение | %d | имя рецепта, инструмента, руды или метки не по правилам (раздел 3) | переименовать, старое имя — в `was` |" % Content.warnings.size())
	out += ["", "## Найдено", ""]
	var any := false
	if not loader_errors.is_empty():
		any = true
		out += ["### Загрузка и схемы (%d)" % loader_errors.size(), ""]
		for e: String in loader_errors:
			out.append("- " + _cell(e))
		out.append("")
	for check: String in ContentGraph.CHECKS:
		if not found.has(check):
			continue
		any = true
		out += ["### %s (%d)" % [CHECK_TEXT[check][0], found[check].size()], ""]
		for f: Dictionary in found[check]:
			out.append("- " + _finding(f))
		out.append("")
	if not Content.warnings.is_empty():
		any = true
		out += ["### Имена (%d)" % Content.warnings.size(), ""]
		for w: String in Content.warnings:
			out.append("- " + _cell(w))
		out.append("")
	if not any:
		out += ["Ничего.", ""]
	return "\n".join(out)


## A finding of the graph in a line: the records it is about, and for an error the
## validator's message with what is lacking.
func _finding(f: Dictionary) -> String:
	var names := ", ".join(f.keys.map(_named))
	match f.check:
		"station":
			return "%s: %s" % [names, ", ".join(f.of.map(func(id: String) -> String: return _title("recipes/" + id)))
				if not f.of.is_empty() else "ни одного рецепта"]
		"loop":
			return "%s: ×%.2f" % [names, f.of]
		"long_chain":
			var n: int = graph.era[f.keys[0]]
			return "%s: глубина %d, эпоха «%s» ждёт до %d" % [names, f.of, Eras.ERAS[n].title, Eras.ERAS[n].depth]
	if ContentGraph.CHECKS[f.check]:
		return "%s: %s" % [names, _cell(f.text)]
	return names
