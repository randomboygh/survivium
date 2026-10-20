extends RefCounted
## Mods and their data files. A mod is a folder under `content/` with `mod.yaml` and
## `data/<kind>.yaml`, one file per kind of record (materials, items, creatures,
## trees, bushes), each a list of records with an `id`. Ids carry the mod's namespace:
## `grass` in the core mod is `core:grass`, and a reference without a namespace
## means the same mod. A later mod may redefine a record of an earlier one by id.
##
## Records are checked against SCHEMAS on load: wrong types, values out of range,
## unknown fields, missing fields without a default and broken references are
## reported with the file and the id. The game loads what it can and reports the
## problems; `tools/validate.gd` runs the same checks in CI and fails on any.
## The registries (materials.gd, items.gd, ai_rules.gd, trees.gd, bushes.gd) read their kind
## with `records(kind)` when their class loads, so the rest of the code keeps using
## `Mat.GRASS`, `Trees.OAK` or `AiRules.SPECIES` as before.

const Yaml := preload("res://src/shared/yaml.gd")

const ROOT := "res://content"
## Mods in load order, until mod.yaml dependencies order them.
static var MODS: Array = ["core"]

## Field types: bool, int, float, string, color ("#rrggbb"), vec3 ([x, y, z]),
## enum (one of `values`), list (of `of`, with `len` or at `least` so many items),
## ref:<kind> (an id of a record of that kind; an empty default means none). `min`/`max`
## bound numbers, in a list each item. A field without `default` is required. `id` and
## `title` are implied for every kind.
const SCHEMAS := {
	"materials": {
		"solid": {"type": "bool", "default": true},
		"roof": {"type": "bool", "default": true},
		"slope": {"type": "bool", "default": false},
		"hotbar": {"type": "int", "min": 0, "default": 0},
		"corners": {"type": "enum", "values": ["sharp", "soft", "round"], "default": "sharp"},
		"item": {"type": "ref:items", "default": ""},
		"dig": {"type": "enum", "values": ["hand", "shovel", "pickaxe", "axe", "none"], "default": "pickaxe"},
		"hardness": {"type": "int", "min": 0, "default": 1},
	},
	"items": {
		"weight": {"type": "float", "min": 0.0},
		"stack": {"type": "int", "min": 1},
		"food": {"type": "float", "min": 0.0, "default": 0.0},
		"place": {"type": "ref:materials", "default": ""},
		"model": {"type": "string", "default": ""},
		"icon": {"type": "string", "default": ""},
		"tool": {"type": "enum", "values": ["none", "axe", "pickaxe", "shovel", "sword"], "default": "none"},
		"power": {"type": "int", "min": 0, "default": 0},
		"area": {"type": "int", "min": 1, "default": 1},
		"swing": {"type": "float", "min": 0.05, "default": 0.5},
		"plant": {"type": "ref:bushes", "default": ""},
	},
	"creatures": {
		"mass": {"type": "float", "min": 0.01},
		"diet": {"type": "list", "of": "enum", "values": ["plants", "meat"], "least": 1},
		"speed": {"type": "float", "min": 0.0},
		"sight": {"type": "float", "min": 0.0},
		"human_wariness": {"type": "float", "min": 0.0, "max": 1.0},
		"active": {"type": "enum", "values": ["day", "night", "any"]},
		"count": {"type": "int", "min": 0, "default": 0},
		"sprite": {"type": "string", "default": ""},
	},
	"trees": {
		"leaves": {"type": "enum", "values": ["broad", "needles"]},
		"trunk": {"type": "list", "of": "int", "len": 2, "min": 0},
		"crown": {"type": "list", "of": "float", "len": 3, "min": 0.0},
		"tints": {"type": "list", "of": "color", "least": 1},
		"bare": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"seed": {"type": "ref:items", "default": ""},
		"hits": {"type": "int", "min": 1, "default": 4},
	},
	"bushes": {
		"tint": {"type": "color"},
		"berries": {"type": "color", "default": null},
		"berry_cards": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"cards": {"type": "int", "min": 1},
		"rise": {"type": "float", "min": 0.0},
		"spread": {"type": "vec3"},
		"small": {"type": "bool", "default": false},
		"fruit": {"type": "ref:items", "default": ""},
		"fruit_count": {"type": "list", "of": "int", "len": 2, "min": 0, "default": [0, 0]},
		"twigs": {"type": "int", "min": 0, "default": 0},
		"item": {"type": "ref:items", "default": ""},
	},
}
const MOD_SCHEMA := {
	"title": {"type": "string"},
	"version": {"type": "string"},
	"api": {"type": "int", "min": 1, "max": 1},
}

## Problems found by the last load, "file: id.field: what".
static var problems: PackedStringArray = []
## kind -> Array of records in load order; a record's `mod` names its mod.
static var _kinds := {}
static var _loaded := false


## Records of `kind` from every mod, checked and with defaults filled in.
static func records(kind: String) -> Array:
	if not _loaded:
		load_all()
	return _kinds.get(kind, [])


## The record with `id` of `kind`, or an empty Dictionary.
static func find(kind: String, id: String) -> Dictionary:
	for r in records(kind):
		if r.id == id:
			return r
	return {}


## Reads every mod again; the registries call their own `reload` after this.
static func refresh() -> void:
	_loaded = false
	load_all()


static func load_all() -> void:
	_loaded = true
	problems = []
	_kinds = {}
	for kind in SCHEMAS:
		_kinds[kind] = []
	for mod in MODS:
		_load_mod(mod)
	_check_refs()
	for p in problems:
		push_error("content: " + p)


static func _load_mod(mod: String) -> void:
	var dir := "%s/%s" % [ROOT, mod]
	var info: Variant = _read("%s/mod.yaml" % dir)
	if not info is Dictionary:
		if info != null or problems.is_empty():
			problems.append("%s/mod.yaml: expected a mapping" % mod)
		return
	if info.get("id") != mod:
		problems.append("%s/mod.yaml: id must be `%s`" % [mod, mod])
	_check_fields(info, MOD_SCHEMA, mod, "%s/mod.yaml" % mod, "mod")
	for kind in SCHEMAS:
		var path := "%s/data/%s.yaml" % [dir, kind]
		if not FileAccess.file_exists(path):
			continue
		var file := "%s/data/%s.yaml" % [mod, kind]
		var list: Variant = _read(path)
		if list == null:
			continue
		if not list is Array:
			problems.append("%s: expected a list of records" % file)
			continue
		var seen := {}
		for i in list.size():
			var r: Variant = list[i]
			if not r is Dictionary or not r.get("id") is String or r.id == "":
				problems.append("%s: record %d: expected a mapping with an `id`" % [file, i + 1])
				continue
			var id: String = qualify(r.id, mod)
			if not _valid_id(id):
				problems.append("%s: `%s`: id must be `mod:name`, lowercase letters, digits and `_`" % [file, r.id])
				continue
			if seen.has(id):
				problems.append("%s: `%s`: duplicate id" % [file, id])
				continue
			seen[id] = true
			var rec: Dictionary = r.duplicate()
			rec.id = id
			rec.mod = mod
			if not rec.get("title") is String or rec.title == "":
				problems.append("%s: %s.title: expected a string" % [file, id])
				rec.title = id
			_check_fields(rec, SCHEMAS[kind], mod, file, id)
			var list_of_kind: Array = _kinds[kind]
			var at := -1
			for j in list_of_kind.size():
				if list_of_kind[j].id == id:
					at = j
			if at >= 0:
				list_of_kind[at] = rec
			else:
				list_of_kind.append(rec)


## `name` -> `mod:name`; an id that already has a namespace stays as it is.
static func qualify(id: String, mod: String) -> String:
	return id if ":" in id else "%s:%s" % [mod, id]


static func _valid_id(id: String) -> bool:
	var parts := id.split(":")
	if parts.size() != 2:
		return false
	for p in parts:
		if p == "" or not p.is_valid_ascii_identifier() or p != p.to_lower():
			return false
	return true


## Checks the fields of `rec` against `schema`, converting values to their engine
## types (Color, Vector3, qualified ids) and filling in defaults.
static func _check_fields(rec: Dictionary, schema: Dictionary, mod: String, file: String, id: String) -> void:
	for key in rec:
		if key != "id" and key != "title" and key != "mod" and not schema.has(key):
			problems.append("%s: %s.%s: unknown field" % [file, id, key])
	for key in schema:
		var spec: Dictionary = schema[key]
		if not rec.has(key) or rec[key] == null:
			if not spec.has("default"):
				problems.append("%s: %s.%s: missing" % [file, id, key])
				rec[key] = _zero(spec)
			else:
				rec[key] = spec.default
			continue
		var out := [null]
		var what := _convert(rec[key], spec, mod, out)
		if what != "":
			problems.append("%s: %s.%s: %s" % [file, id, key, what])
			rec[key] = spec.default if spec.has("default") else _zero(spec)
		else:
			rec[key] = out[0]


## Converts `v` by `spec` into out[0]; returns what is wrong, or "".
static func _convert(v: Variant, spec: Dictionary, mod: String, out: Array) -> String:
	var type: String = spec.type
	match type:
		"bool":
			if not v is bool:
				return "expected true or false"
			out[0] = v
		"int":
			if not v is int:
				return "expected a whole number"
			out[0] = v
			return _bounds(v, spec)
		"float":
			if not (v is float or v is int):
				return "expected a number"
			out[0] = float(v)
			return _bounds(v, spec)
		"string":
			if not v is String:
				return "expected a string"
			out[0] = v
		"enum":
			if not v is String or not v in spec["values"]:
				return "expected one of %s" % ", ".join(spec["values"])
			out[0] = v
		"color":
			if not v is String or not Color.html_is_valid(v) or not v.begins_with("#"):
				return "expected a colour like \"#5a8f3c\""
			out[0] = Color.html(v)
		"vec3":
			if not v is Array or v.size() != 3:
				return "expected [x, y, z]"
			for n in v:
				if not (n is float or n is int):
					return "expected [x, y, z] of numbers"
			out[0] = Vector3(v[0], v[1], v[2])
		"list":
			if not v is Array:
				return "expected a list"
			if spec.has("len") and v.size() != spec.len:
				return "expected %d items" % spec.len
			if spec.has("least") and v.size() < spec.least:
				return "expected at least %d items" % spec.least
			var items := []
			var item_spec := spec.duplicate()
			item_spec.type = spec.of
			item_spec.erase("len")
			item_spec.erase("least")
			for n in v:
				var one := [null]
				var what := _convert(n, item_spec, mod, one)
				if what != "":
					return what
				items.append(one[0])
			out[0] = items
		_:
			if type.begins_with("ref:"):
				if not v is String or v == "":
					return "expected an id"
				out[0] = qualify(v, mod)
			else:
				return "unknown type %s in the schema" % type
	return ""


static func _bounds(v: Variant, spec: Dictionary) -> String:
	if spec.has("min") and v < spec.min:
		return "must be at least %s" % spec.min
	if spec.has("max") and v > spec.max:
		return "must be at most %s" % spec.max
	return ""


## A harmless stand-in for a missing or broken value, so the game can go on.
static func _zero(spec: Dictionary) -> Variant:
	match spec.type:
		"bool":
			return false
		"int":
			return int(spec.get("min", 0))
		"float":
			return float(spec.get("min", 0.0))
		"enum":
			return spec["values"][0]
		"color":
			return Color.MAGENTA
		"vec3":
			return Vector3.ZERO
		"list":
			var items := []
			var item_spec := spec.duplicate()
			item_spec.type = spec.of
			for i in spec.get("len", spec.get("least", 0)):
				items.append(_zero(item_spec))
			return items
	return ""


## Every ref:<kind> field must name a record that exists.
static func _check_refs() -> void:
	for kind in SCHEMAS:
		for key in SCHEMAS[kind]:
			var spec: Dictionary = SCHEMAS[kind][key]
			var target: String = spec.get("of", spec.type) if spec.type == "list" else spec.type
			if not target.begins_with("ref:"):
				continue
			var of := target.substr(4)
			for r in _kinds[kind]:
				var refs: Array = r[key] if spec.type == "list" else [r[key]]
				for ref in refs:
					if ref == "" and spec.get("default") == "":
						continue
					if find(of, ref).is_empty():
						problems.append("%s/data/%s.yaml: %s.%s: no %s `%s`" % [r.mod, kind, r.id, key, of, ref])


static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		problems.append("%s: cannot read" % path.trim_prefix(ROOT + "/"))
		return null
	var yaml := Yaml.new()
	var value: Variant = yaml.parse(f.get_as_text(), path.trim_prefix(ROOT + "/"))
	if yaml.error != "":
		problems.append(yaml.error)
		return null
	return value
