extends "res://src/shared/content/content_schema.gd"
## The mods' data, part two (content.gd): a YAML file read (from the cache the build
## parsed, PARSED, or parsed now) and the fields of a record checked against its schema,
## converted to the engine's types and filled with their defaults; what is wrong goes
## into `problems`.

const Yaml := preload("res://src/shared/content/yaml.gd")
## The mods' YAML files parsed when the game was built (tools/content_cache.gd, run by CI
## before an export; not in git): md5 of a file's text → its value. A file whose text is
## not in it (edited since, or no cache at all, as in the editor) is parsed as before.
const PARSED := "res://content_cache.bin"

const ROOT := "res://content"
## The validator's mode: a soft reference to nothing is a problem too.
static var strict := false

## Problems found by the last load, "file: id.field: what".
static var problems: PackedStringArray = []
## PARSED, read on the first file (null until then, {} without one).
static var _parsed: Variant = null
## How many files _read took from PARSED and how many it parsed, for the report.
static var cached_files := 0
static var parsed_files := 0


## Checks the fields of `rec` against `schema`, converting values to their engine
## types (Color, Vector3, qualified ids) and filling in defaults.
static func _check_fields(rec: Dictionary, schema: Dictionary, mod: String, file: String, id: String) -> void:
	for key in rec:
		if key != "id" and key != "title" and key != "mod" and key != "bundle" and not schema.has(key):
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
		"sound":
			# The name of a sound, kept as written: the client finds the record of that
			# name in the last loaded mod that has one (Sound.resolve), silence when none,
			# so a mod may name sounds no mod it requires gives.
			if not v is String:
				return "expected the name of a sound"
			out[0] = v
		"word":
			if not v is String or not v.is_valid_ascii_identifier() or v != v.to_lower():
				return "expected a lowercase word, like axe"
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
			var named: bool = spec.has("keys")
			if not v is Dictionary or (v.is_empty() and named):
				return "expected a mapping of %s to shares 0..1, like {%s: 0.5}" % [", ".join(spec.keys), spec.keys[0]] if named \
					else "expected a mapping of ids to shares 0..1, like {oak: 0.5}"
			var shares := {}
			for k in v:
				if not k is String or k == "" or (named and not k in spec.keys):
					return "`%s`: expected one of %s" % [k, ", ".join(spec.keys)] if named else "expected ids as keys"
				if not (v[k] is float or v[k] is int) or v[k] < 0.0 or v[k] > 1.0:
					return "`%s`: expected a share from 0 to 1" % k
				shares[k if named else qualify(k, mod)] = float(v[k])
			out[0] = shares
		"colors":
			if not v is Dictionary:
				return "expected a mapping of %s to colours, like {%s: \"#e8e0c8\"}" % [", ".join(spec.keys), spec.keys[0]]
			var colors := {}
			for k in v:
				if not k is String or not k in spec.keys:
					return "`%s`: expected one of %s" % [k, ", ".join(spec.keys)]
				if not v[k] is String or not Color.html_is_valid(v[k]) or not v[k].begins_with("#"):
					return "`%s`: expected a colour like \"#5a8f3c\"" % k
				colors[k] = Color.html(v[k])
			out[0] = colors
		"entries":
			if not v is Array:
				return "expected a list of mappings, like [{%s}]" % ", ".join(spec.fields.keys().map(func(k: String) -> String: return k + ": …"))
			var entries := []
			for i in v.size():
				if not v[i] is Dictionary:
					return "entry %d: expected a mapping" % (i + 1)
				var e: Dictionary = v[i].duplicate()
				var what := _entry(e, spec.fields, mod)
				if what != "":
					return "entry %d: %s" % [i + 1, what]
				entries.append(e)
			out[0] = entries
		_:
			if type.begins_with("ref:"):
				if not v is String or v == "":
					return "expected an id"
				out[0] = qualify(v, mod)
			else:
				return "unknown type %s in the schema" % type
	return ""


## Checks entry `e` of an `entries` field against `fields` like a record's fields (see
## _check_fields), converting its values and filling in defaults; returns what is wrong,
## or "".
static func _entry(e: Dictionary, fields: Dictionary, mod: String) -> String:
	for key: Variant in e:
		if not fields.has(key):
			return "`%s`: unknown field" % key
	for key: String in fields:
		var spec: Dictionary = fields[key]
		if not e.has(key) or e[key] == null:
			if not spec.has("default"):
				return "`%s`: missing" % key
			e[key] = spec.default
			continue
		var one := [null]
		var what := _convert(e[key], spec, mod, one)
		if what != "":
			return "`%s`: %s" % [key, what]
		e[key] = one[0]
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
		"amounts", "shares", "colors":
			return {}
		"entries":
			return []
		"list":
			var items := []
			var item_spec := spec.duplicate()
			item_spec.type = spec.of
			for i in spec.get("len", spec.get("least", 0)):
				items.append(_zero(item_spec))
			return items
	return ""


static func _broken(r: Dictionary, kind: String, key: String, of: String, ref: String, soft: bool) -> void:
	if not soft or strict:
		problems.append("%s/data/%s.yaml: %s.%s: no %s `%s`" % [r.bundle, kind, r.id, key, of, ref])


static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		problems.append("%s: cannot read" % path.trim_prefix(ROOT + "/"))
		return null
	var text := f.get_as_text()
	if _parsed == null:
		_parsed = {}
		var c := FileAccess.open(PARSED, FileAccess.READ)
		var got: Variant = c.get_var() if c != null else null
		if got is Dictionary:
			_parsed = got
	if not _parsed.is_empty():
		var key := text.md5_text()
		if _parsed.has(key):
			cached_files += 1
			# Its records are changed by who reads them (ids qualified...): a copy each time.
			var v: Variant = _parsed[key]
			return v.duplicate(true) if v is Dictionary or v is Array else v
	parsed_files += 1
	return parse_text(text, path.trim_prefix(ROOT + "/"))


## Every YAML file under content/ parsed, for PARSED: md5 of its text → its value; a
## malformed file is left out (the game parses it and reports it).
static func parsed_cache() -> Dictionary:
	var out := {}
	var files := []
	_yaml_files(ROOT, files)
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		var had := problems.size()
		var value: Variant = parse_text(text, path.trim_prefix(ROOT + "/"))
		if problems.size() > had:
			problems.resize(had)
			continue
		out[text.md5_text()] = value
	return out


static func _yaml_files(dir: String, files: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".yaml"):
			files.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_yaml_files(dir.path_join(d), files)


## The value of YAML `text` (of `file`, for the problem), null with a problem when malformed.
static func parse_text(text: String, file: String) -> Variant:
	var yaml := Yaml.new()
	var value: Variant = yaml.parse(text, file)
	if yaml.error != "":
		problems.append(yaml.error)
		return null
	return value
