extends RefCounted
## The content editor's changes (stage 2, decision 186): a record's fields changed in a
## form go into one's own mod `mod` (OwnMods) — into the record itself when it is that
## mod's own, else as a patch of the other mod's record with only the fields changed
## (13А, 2А: the game's files are never written) — and every write can be taken back
## (`undo`, the file as it was). A field's value is checked against its schema first
## (`check`). The values are the data's, as YAML holds them (`data_of`), not the engine's.
## Writing changes only files: the caller reads the mods again.

const Content := preload("res://src/shared/content/content.gd")
const OwnMods := preload("res://src/shared/content/own_mods.gd")

## The most writes kept to take back.
const MOST_UNDO := 50

## The writes done, last last: [file path, its text before ("" when there was none)].
var history: Array = []


## What is wrong with `value` for field `field` of kind `kind` written in mod `mod`, ""
## when it is right (Content's own check of a record's field; English, as the loader's).
static func check(kind: String, field: String, value: Variant, mod: String) -> String:
	var spec: Dictionary = Content.schema(kind).get(field, {})
	if spec.is_empty():
		return "no such field"
	if value == null:
		return "" if spec.has("default") else "required"
	# A field left at its default (an empty reference: none) is right as it is.
	if spec.has("default") and var_to_str(value) == var_to_str(data_of(spec.default)):
		return ""
	return Content._convert(value, spec, mod, [null])


## Value `v` of a loaded record as the data holds it: a colour back to "#rrggbb", a vector
## back to a list.
static func data_of(v: Variant) -> Variant:
	if v is Color:
		return "#" + v.to_html(false)
	if v is Vector3 or v is Vector3i:
		return [v.x, v.y, v.z]
	if v is Vector2 or v is Vector2i:
		return [v.x, v.y]
	if v is Array:
		return v.map(data_of)
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = data_of(v[k])
		return out
	return v


## The fields of `fields` whose values differ from those of loaded record `rec` of `kind`.
static func changed(kind: String, rec: Dictionary, fields: Dictionary) -> Dictionary:
	var out := {}
	for f: String in fields:
		var was: Variant = data_of(rec.get(f, Content.default_of(kind, f)))
		if var_to_str(was) != var_to_str(fields[f]):
			out[f] = fields[f]
	return out


## Whether record `id` of `kind` is own mod `mod`'s own (not a patch of another's).
static func owns(mod: String, kind: String, id: String) -> bool:
	return Content.origin(kind, id).get("bundle", "").get_slice("/", 0) == mod and id.begins_with(mod + ":")


## Writes `fields` of record `id` (qualified) of `kind` into own mod `mod`; "" when written.
func save(mod: String, kind: String, id: String, fields: Dictionary) -> String:
	if fields.is_empty():
		return ""
	var path := OwnMods.root().path_join(mod).path_join("data").path_join(kind + ".yaml")
	var before := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var error := ""
	if owns(mod, kind, id):
		var name := id.trim_prefix(mod + ":")
		var rec := {}
		for r: Dictionary in OwnMods.records(mod, kind):
			if str(r.get("id", "")) == name:
				rec = r
		if rec.is_empty():
			return "record `%s` is not in `%s`" % [id, mod]
		rec.merge(fields, true)
		error = OwnMods.put(mod, kind, rec)
	else:
		error = OwnMods.patch(mod, kind, id, fields)
	if error == "":
		history.append([path, before])
		if history.size() > MOST_UNDO:
			history.pop_front()
	return error


## Takes the last write back; "" when done or there is none.
func undo() -> String:
	if history.is_empty():
		return ""
	var last: Array = history.pop_back()
	if last[1] == "":
		DirAccess.remove_absolute(last[0])
		return ""
	var f := FileAccess.open(last[0], FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % last[0]
	f.store_string(last[1])
	f.close()
	return ""
