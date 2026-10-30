extends SceneTree
## Writes the reports docs/ keeps of the content, from the data of every mod as the game
## loads it (docs/specifications/BUNDLE_SYSTEM.md, section 13), and checks they are fresh:
##     godot --headless --path . --script res://tools/content_report.gd             writes them
##     godot --headless --path . --script res://tools/content_report.gd -- --check  fails when one is stale
## docs/generated/content-index.md is the register of every record: its kind, category,
## description, the bundle that has it and what replaced or patched it, how many records
## it names and how many name it (by the reference fields and their links, see
## Content.RELATIONS), and what the validator says of it. CI runs --check; run it
## without arguments after changing the data.

const Content := preload("res://src/shared/content/content.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Items := preload("res://src/shared/content/items.gd")

const INDEX := "res://docs/generated/content-index.md"
## The kinds by their names in the register, in its order; a kind not here comes after
## them under its own name.
const KINDS := {"items": "Предметы", "recipes": "Рецепты", "materials": "Материалы ячеек", "trees": "Деревья",
	"bushes": "Кусты", "plants": "Растения", "creatures": "Существа", "biomes": "Биомы", "sounds": "Звуки"}


func _init() -> void:
	# What the validator sees: the full set, a soft reference to nothing a problem too.
	Content.strict = true
	Mods.rescan()
	var wanted := {INDEX: _index()}
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
		"Связи — сколько записей называет эта и сколько называют её (поля-ссылки с типом связи `rel`).",
		"Проверка — что валидатор говорит о записи: «ок», ошибки или предупреждения.", "",
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
		out += ["", "## %s (`%s`, %d)" % [KINDS.get(kind, kind), kind, recs.size()], "",
			"| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |", "|---|---|---|---|---|---|---|"]
		for r: Dictionary in recs:
			var key := "%s/%s" % [kind, r.id]
			var l: Array = links.get(key, [0, 0])
			out.append("| `%s` | %s | %s | %s | %s | %d / %d | %s |" % [r.id, _cell(r.title), _cell(_category(kind, r)),
				_cell(r.description), _origin(kind, r.id), l[0], l[1], _status(r.id)])
	return "\n".join(out) + "\n"


## "kind/id" -> [how many records it names, how many name it], by every reference field.
func _links() -> Dictionary:
	var out := {}
	for kind: String in Content.SCHEMAS:
		for key: String in Content.SCHEMAS[kind]:
			var spec: Dictionary = Content.SCHEMAS[kind][key]
			var target: String = spec.get("of", spec.type) if spec.type in ["list", "amounts", "shares"] else spec.type
			if not target.begins_with("ref:"):
				continue
			for r: Dictionary in Content.records(kind):
				var v: Variant = r[key]
				var named: Array = v if v is Array else (v.keys() if v is Dictionary else [v])
				for id: String in named:
					if id == "":
						continue
					var from := "%s/%s" % [kind, r.id]
					var to := "%s/%s" % [target.substr(4), id]
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
	return ""


func _origin(kind: String, id: String) -> String:
	var o := Content.origin(kind, id)
	var text := "`%s`" % o.bundle
	for b: String in o.replaced:
		text += " → `%s`" % b
	if not o.patched.is_empty():
		text += "; патчи: " + ", ".join(o.patched.map(func(b: String) -> String: return "`%s`" % b))
	return text


## What the validator says of record `id`: "ок", or how many problems and warnings name it.
func _status(id: String) -> String:
	var said := func(lines: PackedStringArray) -> int:
		return Array(lines).filter(func(p: String) -> bool:
			return ("`%s`" % id) in p or (" %s." % id) in p or (" %s:" % id) in p).size()
	var errors: int = said.call(Content.problems)
	var warnings: int = said.call(Content.warnings)
	var parts := []
	if errors > 0:
		parts.append("ошибки: %d" % errors)
	if warnings > 0:
		parts.append("предупреждения: %d" % warnings)
	return "ок" if parts.is_empty() else ", ".join(parts)


## Text for a table cell: one line, no column bar.
func _cell(text: String) -> String:
	return " ".join(text.split("\n")).replace("|", "\\|")
