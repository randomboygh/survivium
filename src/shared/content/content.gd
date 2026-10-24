extends RefCounted
## Mods and their data files. A mod is a folder under `content/` with `mod.yaml` and
## `data/<kind>.yaml`, one file per kind of record (materials, items, creatures,
## trees, bushes, recipes, plants, sounds; a sound's files are the mod's
## `sounds/<name>.wav`, or `<name>_1.wav` ... for its variants), each a list of records with an `id`. Ids carry the mod's namespace:
## `grass` in the core mod is `core:grass`, and a reference without a namespace
## means the same mod. A later mod may redefine a record of an earlier one by id, or
## patch it: a record with `patch: true` changes only the fields it gives, and a key
## with a `+` at the end (`diet+: [plants]`, `needs+: {core:cord: 1}`) adds to a list
## or an amounts field instead of replacing it.
##
## `mod.yaml` names what a mod `requires`: those mods load first, whatever the order
## asked for, and a mod whose requirement is not among the mods loaded is skipped
## with a problem. MODS is the set a world plays with (the world remembers it, see
## WorldStore); `available()` finds every mod under `content/`. Switch sets through
## mods.gd, which also refreshes the registries.
##
## Records are checked against SCHEMAS on load: wrong types, values out of range,
## unknown fields, missing fields without a default and broken references are
## reported with the file and the id. The game loads what it can and reports the
## problems; `tools/validate.gd` runs the same checks in CI and fails on any.
## The registries (materials.gd, items.gd, ai_rules.gd, trees.gd, bushes.gd, crafting.gd, plants.gd) read their kind
## with `records(kind)` when their class loads, so the rest of the code keeps using
## `Mat.GRASS`, `Trees.OAK` or `AiRules.SPECIES` as before.

const Yaml := preload("res://src/shared/content/yaml.gd")

const ROOT := "res://content"
## The mods to load, as asked for; `loaded` has the order they were loaded in after
## their requirements, without the ones that could not be.
static var MODS: Array = available()
static var loaded: Array = []

## Field types: bool, int, float, string, color ("#rrggbb"), vec3 ([x, y, z]),
## enum (one of `values`), list (of `of`, with `len` or at `least` so many items),
## ref:<kind> (an id of a record of that kind; an empty default means none), amounts
## (a mapping of ids of `of` to how many, at least 1 each). `min`/`max` bound numbers,
## in a list each item. A field without `default` is required. `id` and
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
		"bonus": {"type": "ref:items", "default": ""},
		"bonus_chance": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"mow": {"type": "ref:materials", "default": ""},
		"mow_gives": {"type": "amounts", "of": "ref:items", "default": {}},
		"step": {"type": "ref:sounds", "default": ""},
		"hit": {"type": "ref:sounds", "default": ""},
	},
	"items": {
		"weight": {"type": "float", "min": 0.0},
		"stack": {"type": "int", "min": 1},
		"food": {"type": "float", "min": 0.0, "default": 0.0},
		"heal": {"type": "float", "min": 0.0, "default": 0.0},
		"place": {"type": "ref:materials", "default": ""},
		"model": {"type": "string", "default": ""},
		"icon": {"type": "string", "default": ""},
		"tool": {"type": "enum", "values": ["none", "axe", "pickaxe", "shovel", "sword", "scythe"], "default": "none"},
		"power": {"type": "int", "min": 0, "default": 0},
		"area": {"type": "int", "min": 1, "default": 1},
		"mows": {"type": "enum", "values": ["none", "tall", "all"], "default": "none"},
		"swing": {"type": "float", "min": 0.05, "default": 0.5},
		"plant": {"type": "ref:bushes", "default": ""},
		"sow": {"type": "ref:materials", "default": ""},
		"crop": {"type": "ref:plants", "default": ""},
		"reach": {"type": "int", "min": 1, "default": 8},
		"durability": {"type": "int", "min": 0, "default": 0},
		"repair": {"type": "amounts", "of": "ref:items", "default": {}},
		"prop": {"type": "enum", "values": ["none", "chest", "workbench", "kiln", "campfire"], "default": "none"},
		"sprite": {"type": "string", "default": ""},
		"anim": {"type": "string", "default": "reach"},
		"hands": {"type": "int", "min": 1, "max": 2, "default": 1},
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
		"frames": {"type": "int", "min": 1, "default": 1},
		"flies": {"type": "bool", "default": false},
		"flock": {"type": "list", "of": "int", "len": 2, "min": 1, "default": [1, 1]},
		"roost": {"type": "enum", "values": ["ground", "trees"], "default": "ground"},
		"likes": {"type": "list", "of": "ref:plants", "default": []},
		"calls": {"type": "ref:sounds", "default": ""},
		"alarm": {"type": "ref:sounds", "default": ""},
	},
	"trees": {
		"leaves": {"type": "enum", "values": ["broad", "needles"]},
		"land": {"type": "enum", "values": ["lowland", "highland"]},
		"trunk": {"type": "list", "of": "int", "len": 2, "min": 0},
		"girth": {"type": "list", "of": "int", "len": 2, "min": 2, "default": [6, 6]},
		"taper": {"type": "float", "min": 0.0, "default": 0.0},
		"crook": {"type": "int", "min": 0, "default": 0},
		"roots": {"type": "list", "of": "int", "len": 2, "min": 0, "default": [0, 0]},
		"crown": {"type": "list", "of": "float", "len": 3, "min": 0.0},
		"tints": {"type": "list", "of": "color", "least": 1},
		"bare": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"seed": {"type": "ref:items", "default": ""},
		"hits": {"type": "int", "min": 1, "default": 4},
		"twigs": {"type": "int", "min": 0, "default": 0},
		"seeds": {"type": "int", "min": 0, "default": 0},
	},
	"bushes": {
		"tint": {"type": "color"},
		"under": {"type": "shares", "keys": ["lowland", "highland", "open", "any"]},
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
	"recipes": {
		"makes": {"type": "ref:items"},
		"count": {"type": "int", "min": 1, "default": 1},
		"needs": {"type": "amounts", "of": "ref:items"},
		"at": {"type": "ref:items", "default": ""},
		"tool": {"type": "enum", "values": ["none", "axe", "pickaxe", "shovel", "sword", "scythe"], "default": "none"},
		"time": {"type": "float", "min": 0.0, "default": 2.0},
	},
	"sounds": {
		"variants": {"type": "int", "min": 1, "default": 1},
		"volume": {"type": "float", "min": 0.0, "max": 4.0, "default": 1.0},
		"loop": {"type": "bool", "default": false},
	},
	"plants": {
		"kind": {"type": "enum", "values": ["tuft", "tall_grass", "flowers", "herbs", "ears", "reeds", "moss",
			"mushrooms", "glow_mushrooms"]},
		"gives": {"type": "amounts", "of": "ref:items"},
		"chance": {"type": "float", "min": 0.0, "max": 1.0, "default": 1.0},
		"pick": {"type": "bool", "default": false},
		"winter": {"type": "bool", "default": true},
	},
}
const MOD_SCHEMA := {
	"title": {"type": "string"},
	"version": {"type": "string"},
	"api": {"type": "int", "min": 1, "max": 1},
	"requires": {"type": "list", "of": "string", "default": []},
}

## Problems found by the last load, "file: id.field: what".
static var problems: PackedStringArray = []
## kind -> Array of records in load order; a record's `mod` names its mod.
static var _kinds := {}
## kind -> id -> the record as written (before conversion), for patches to build on.
static var _raw := {}
## mod -> its mod.yaml as read (checked), for the load being done.
static var _infos := {}
static var _loaded := false


## Every mod under `content/`: the folders with a mod.yaml, core first, then by name.
static func available() -> Array:
	var out := []
	for name in DirAccess.get_directories_at(ROOT):
		if name.begins_with("_") or not FileAccess.file_exists("%s/%s/mod.yaml" % [ROOT, name]):
			continue
		out.append(name)
	out.sort()
	if "core" in out:
		out.erase("core")
		out.push_front("core")
	return out


## The mod.yaml of `mod` as a Dictionary with its fields checked, empty when it cannot
## be read.
static func info(mod: String) -> Dictionary:
	var path := "%s/%s/mod.yaml" % [ROOT, mod]
	var d: Variant = _read(path)
	if not d is Dictionary:
		if d != null:
			problems.append("%s/mod.yaml: expected a mapping" % mod)
		return {}
	if d.get("id") != mod:
		problems.append("%s/mod.yaml: id must be `%s`" % [mod, mod])
	var out: Dictionary = d.duplicate()
	_check_fields(out, MOD_SCHEMA, mod, "%s/mod.yaml" % mod, "mod")
	out.erase("id")
	return out


## The mods of `infos` (mod -> its mod.yaml, see `info`) in load order: each after what
## it requires, otherwise as given; a mod that requires one not among them (or in a
## cycle) is left out with a problem.
static func order(infos: Dictionary) -> Array:
	var mods := infos.keys()
	var out := []
	var waiting := mods.duplicate()
	while not waiting.is_empty():
		var progress := false
		for mod in waiting.duplicate():
			var needs: Array = infos[mod].get("requires", [])
			var missing := needs.filter(func(m: String) -> bool: return not m in mods)
			if not missing.is_empty():
				problems.append("%s/mod.yaml: requires `%s`, which is not loaded" % [mod, "`, `".join(missing)])
				waiting.erase(mod)
				continue
			if needs.all(func(m: String) -> bool: return m in out):
				out.append(mod)
				waiting.erase(mod)
				progress = true
		if not progress:
			problems.append("%s: mods require each other in a circle" % ", ".join(waiting))
			break
	return out


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


## The files of sound record `rec` (see the `sounds` kind): one, or one per variant.
static func sound_files(rec: Dictionary) -> PackedStringArray:
	var name: String = rec.id.get_slice(":", 1)
	var dir := "%s/%s/sounds/" % [ROOT, rec.mod]
	if rec.variants == 1:
		return [dir + name + ".wav"]
	var out: PackedStringArray = []
	for i in rec.variants:
		out.append("%s%s_%d.wav" % [dir, name, i + 1])
	return out


## Reads every mod again; the registries call their own `reload` after this.
static func refresh() -> void:
	_loaded = false
	load_all()


static func load_all() -> void:
	_loaded = true
	problems = []
	_kinds = {}
	_raw = {}
	_infos = {}
	for kind in SCHEMAS:
		_kinds[kind] = []
		_raw[kind] = {}
	for mod in MODS:
		var i := info(mod)
		if i.is_empty():
			problems.append("%s/mod.yaml: cannot read the mod" % mod)
		else:
			_infos[mod] = i
	loaded = order(_infos)
	for mod in loaded:
		_load_mod(mod)
	_check_refs()
	for p in problems:
		push_error("content: " + p)


static func _load_mod(mod: String) -> void:
	var dir := "%s/%s" % [ROOT, mod]
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
			var raw: Dictionary = _raw[kind]
			if rec.get("patch") == true:
				rec.erase("patch")
				if not raw.has(id):
					problems.append("%s: %s: patches a record no loaded mod has" % [file, id])
					continue
				rec = _patched(raw[id], rec, file, id)
			else:
				rec.mod = mod
			raw[id] = rec.duplicate()
			if not rec.get("title") is String or rec.title == "":
				problems.append("%s: %s.title: expected a string" % [file, id])
				rec.title = id
			_check_fields(rec, SCHEMAS[kind], rec.mod, file, id)
			var list_of_kind: Array = _kinds[kind]
			var at := -1
			for j in list_of_kind.size():
				if list_of_kind[j].id == id:
					at = j
			if at >= 0:
				list_of_kind[at] = rec
			else:
				list_of_kind.append(rec)


## `base` with the fields of `patch` over it; a key ending in `+` adds its list or
## mapping to the field's. The record stays its first mod's (its pictures and sounds
## are looked for there).
static func _patched(base: Dictionary, patch: Dictionary, file: String, id: String) -> Dictionary:
	var out := base.duplicate(true)
	for key in patch:
		if key == "id":
			continue
		var v: Variant = patch[key]
		if key.ends_with("+"):
			var field: String = key.trim_suffix("+")
			var had: Variant = out.get(field)
			if had is Array and v is Array:
				out[field] = had + v
			elif had is Dictionary and v is Dictionary:
				var merged: Dictionary = had.duplicate()
				merged.merge(v, true)
				out[field] = merged
			else:
				problems.append("%s: %s.%s: `+` adds to a list or a mapping the record has" % [file, id, field])
		else:
			out[key] = v
	return out


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
		"amounts":
			if not v is Dictionary or v.is_empty():
				return "expected a mapping of ids to how many, like {branch: 2}"
			var amounts := {}
			for k in v:
				if not k is String or k == "":
					return "expected ids as keys"
				if not v[k] is int or v[k] < 1:
					return "`%s`: expected a whole number of at least 1" % k
				amounts[qualify(k, mod)] = v[k]
			out[0] = amounts
		"shares":
			if not v is Dictionary or v.is_empty():
				return "expected a mapping of %s to shares 0..1, like {%s: 0.5}" % [", ".join(spec.keys), spec.keys[0]]
			var shares := {}
			for k in v:
				if not k is String or not k in spec.keys:
					return "`%s`: expected one of %s" % [k, ", ".join(spec.keys)]
				if not (v[k] is float or v[k] is int) or v[k] < 0.0 or v[k] > 1.0:
					return "`%s`: expected a share from 0 to 1" % k
				shares[k] = float(v[k])
			out[0] = shares
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
		"amounts", "shares":
			return {}
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
			var target: String = spec.get("of", spec.type) if spec.type in ["list", "amounts"] else spec.type
			if not target.begins_with("ref:"):
				continue
			var of := target.substr(4)
			for r in _kinds[kind]:
				var refs: Array = r[key] if spec.type == "list" else (r[key].keys() if spec.type == "amounts" else [r[key]])
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
