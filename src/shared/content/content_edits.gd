extends RefCounted
## The content editor's changes (stage 2, decision 186): a record's fields changed in a
## form go into one's own mod `mod` (OwnMods) — into the record itself when it is that
## mod's own, else as a patch of the other mod's record with only the fields changed
## (13А, 2А: the game's files are never written) — and every write can be taken back
## (`undo`, the file as it was). A field's value is checked against its schema first
## (`check`). New records are copies of others (`copy`), titles and descriptions phrases
## in the mod's language files (`key_of`), one's own records can be taken out (`delete`).
## The values are the data's, as YAML holds them (`data_of`), not the engine's.
## Writing changes only files: the caller reads the mods again.

const Content := preload("res://src/shared/content/content.gd")
const OwnMods := preload("res://src/shared/content/own_mods.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")

## The fields that name a picture, by `<kind>.<field>`: the folder of a bundle it lies in
## (as the registries read them: ItemIcons, Hands, Figure, Creatures, Plants, Materials,
## Trees, VoxelProps), `<folder>/<name>.png`.
const PICTURES := {"items.icon": "icons", "items.sprite": "sprites/held", "items.look": "sprites/worn",
	"creatures.sprite": "sprites/creatures", "plants.sprite": "sprites/plants", "materials.texture": "textures",
	"trees.bark": "textures", "items.model": "models"}
## The picture fields that are voxel models (PNG sheets of slices, VoxelModel.from_image),
## which the voxel editor paints.
const MODELS := ["items.model"]

## The most writes kept to take back.
const MOST_UNDO := 50

## The writes done, last last: each a list of the files it changed, [path, its text
## before ("" when there was none)].
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


## The key of the title (or with `about` the description) of record `id` (qualified) of
## `kind` written by own mod `mod`: `[<mod>.<kind>.<name>]` for its own record (the way
## every mod names its titles, `….about` for a description), with the other mod's name in
## it for a patch of another's (`[mine.creatures.animals_wolf]`).
static func key_of(mod: String, kind: String, id: String, about := false) -> String:
	var name := id.trim_prefix(mod + ":") if id.begins_with(mod + ":") else id.replace(":", "_")
	return "[%s.%s.%s%s]" % [mod, kind, name, ".about" if about else ""]


## The language a title written now is in: the game's, English when none is set.
static func language() -> String:
	return Lang.code if Lang.code != "" else Lang.SOURCE


## Writes `fields` of record `id` (qualified) of `kind` into own mod `mod`, and `texts`,
## its title and description ({"title": …, "description": …}) in the game's language:
## the record gets its keys (key_of) and the mod's language files the phrases (English's
## too while it has none, so a player in another language reads something). "" when written.
func save(mod: String, kind: String, id: String, fields: Dictionary, texts := {}) -> String:
	if fields.is_empty() and texts.is_empty():
		return ""
	fields = fields.duplicate()
	var phrases := {}
	for field: String in texts:
		var key := key_of(mod, kind, id, field == "description")
		# An empty title stays as it was; an empty description is none.
		if texts[field] == "" and field == "title":
			continue
		phrases[key] = texts[field]
		var value := key if texts[field] != "" else ""
		if str(Content.find(kind, id).get(field, "")) != value:
			fields[field] = value
	if fields.is_empty() and phrases.is_empty():
		return ""
	var group := _keep(mod, kind, not phrases.is_empty())
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
	elif not fields.is_empty():
		error = OwnMods.patch(mod, kind, id, fields)
	for key: String in phrases:
		if error == "":
			error = _say(mod, language(), key, phrases[key], language() != Lang.SOURCE)
	return _done(group, error)


## Writes a copy of record `from` (qualified, any mod's) of `kind` into own mod `mod` as
## its own record `name`: every field the original has as loaded (references qualified),
## those left at their defaults and the ids it had before (`was`) left out; its title and
## description under the copy's own keys, in English and the game's language. "" when written.
func copy(mod: String, kind: String, from: String, name: String) -> String:
	var src := Content.find(kind, from)
	if src.is_empty():
		return "no record `%s`" % from
	if not OwnMods.valid_id(name):
		return "bad id `%s`" % name
	var id := "%s:%s" % [mod, name]
	if not Content.find(kind, id).is_empty() or OwnMods._find(OwnMods.records(mod, kind), name) >= 0:
		return "record `%s` is there already" % id
	var rec := {"id": name}
	var schema: Dictionary = Content.schema(kind)
	for field: String in schema:
		if field in ["id", "title", "description", "was"] or not src.has(field):
			continue
		var value: Variant = data_of(src[field])
		if schema[field].has("default") and var_to_str(value) == var_to_str(data_of(schema[field].default)):
			continue
		rec[field] = value
	var phrases := {}
	for field: String in ["title", "description"]:
		var text := str(src.get(field, ""))
		if text == "":
			continue
		var key := key_of(mod, kind, id, field == "description")
		rec[field] = key
		phrases[key] = [Lang.english().text_of(text), Lang.t(text)]
	var group := _keep(mod, kind, not phrases.is_empty())
	var error := OwnMods.put(mod, kind, rec)
	for key: String in phrases:
		if error == "":
			error = _say(mod, Lang.SOURCE, key, phrases[key][0])
		if error == "" and language() != Lang.SOURCE:
			error = _say(mod, language(), key, phrases[key][1])
	return _done(group, error)


## Takes record `id` (qualified) of `kind` out of own mod `mod`: its own record with its
## phrases, else its patch of another mod's record (that one is as its mod has it again).
func delete(mod: String, kind: String, id: String) -> String:
	var own := owns(mod, kind, id)
	var name := id.trim_prefix(mod + ":") if own else id
	if OwnMods._find(OwnMods.records(mod, kind), name) < 0:
		return "record `%s` is not in `%s`" % [id, mod]
	var group := _keep(mod, kind, true)
	var error := OwnMods.remove(mod, kind, name)
	for lang_code: String in _languages(mod):
		for key: String in [key_of(mod, kind, id), key_of(mod, kind, id, true)]:
			if error == "":
				error = _say(mod, lang_code, key, "")
	return _done(group, error)


## The file of picture field `field` of record `rec` of `kind` as loaded ("" for none):
## Content.asset of its folder and name (a material's texture is named by its id when none).
static func picture_path(kind: String, rec: Dictionary, field: String, value := "") -> String:
	var dir: String = PICTURES.get("%s.%s" % [kind, field], "")
	var name := value if value != "" else str(rec.get(field, ""))
	if name == "" and kind == "materials":
		name = str(rec.get("id", "")).get_slice(":", 1)
	if dir == "" or name == "":
		return ""
	return Content.asset(rec, "%s/%s.png" % [dir, name])


## Writes picture `bytes` (a PNG, ModFiles.may_be) into own mod `mod` for picture field
## `field` of record `id` (qualified) of `kind`, and the field: its own record names it by
## its name, another mod's by `<mod>:<other>_<name>` (Content.asset), as a patch. "" when written.
func picture(mod: String, kind: String, id: String, field: String, bytes: PackedByteArray) -> String:
	var dir: String = PICTURES.get("%s.%s" % [kind, field], "")
	if dir == "":
		return "`%s` of %s names no picture" % [field, kind]
	if not ModFiles.may_be(bytes, "png"):
		return "not a PNG of at most %d px" % ModFiles.PICTURE_MAX
	var own := owns(mod, kind, id)
	var name := id.trim_prefix(mod + ":") if own else id.replace(":", "_")
	var path := OwnMods.root().path_join(mod).path_join(dir).path_join(name + ".png")
	var before: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else ""
	var error := save(mod, kind, id, {field: name if own else "%s:%s" % [mod, name]})
	if error != "":
		return error
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % path
	f.store_buffer(bytes)
	f.close()
	# The same write as the field's (save kept it last): taken back together.
	history[-1].append([path, before])
	return ""


## Takes the last write back (every file it changed); "" when done or there is none.
func undo() -> String:
	if history.is_empty():
		return ""
	var group: Array = history.pop_back()
	group.reverse()
	for last: Array in group:
		if last[1] is String and last[1] == "":
			if FileAccess.file_exists(last[0]):
				DirAccess.remove_absolute(last[0])
			continue
		var f := FileAccess.open(last[0], FileAccess.WRITE)
		if f == null:
			return "cannot write %s" % last[0]
		if last[1] is PackedByteArray:
			f.store_buffer(last[1])
		else:
			f.store_string(last[1])
		f.close()
	return ""


## The files a write of `kind` in `mod` may change (its data file, with `phrases` the
## mod's language files) as they are before it: [path, text ("" when there is none)].
func _keep(mod: String, kind: String, phrases: bool) -> Array:
	var paths := [OwnMods.root().path_join(mod).path_join("data").path_join(kind + ".yaml")]
	if phrases:
		var langs := _languages(mod)
		for lang_code: String in [Lang.SOURCE, language()]:
			if not lang_code in langs:
				langs.append(lang_code)
		for lang_code: String in langs:
			paths.append(_lang_file(mod, lang_code))
	var group := []
	for path: String in paths:
		group.append([path, FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""])
	return group


## Keeps the write `group` to be taken back when it went well (`error` ""); `error`.
func _done(group: Array, error: String) -> String:
	if error == "":
		history.append(group)
		if history.size() > MOST_UNDO:
			history.pop_front()
	return error


## The languages own mod `mod` has phrases in.
static func _languages(mod: String) -> Array:
	var out := []
	var dir := OwnMods.root().path_join(mod).path_join("lang")
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".yaml"):
				out.append(f.get_basename())
	return out


static func _lang_file(mod: String, lang_code: String) -> String:
	return OwnMods.root().path_join(mod).path_join("lang").path_join(lang_code + ".yaml")


## Puts phrase `text` of `key` into own mod `mod`'s file of language `lang_code` ("" takes
## it out); with `also_english` into English's too when it has none. "" when written.
static func _say(mod: String, lang_code: String, key: String, text: String, also_english := false) -> String:
	if also_english:
		var english := _phrases(mod, Lang.SOURCE)
		if not english.has(key):
			var error := _say(mod, Lang.SOURCE, key, text)
			if error != "":
				return error
	var path := _lang_file(mod, lang_code)
	var all := _phrases(mod, lang_code)
	if text == "":
		if not all.has(key):
			return ""
		all.erase(key)
	else:
		all[key] = text
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % path
	f.store_string(Yaml.write(all, "Phrases of this mod in language `%s`, written by the content editor." % lang_code))
	f.close()
	return ""


static func _phrases(mod: String, lang_code: String) -> Dictionary:
	var path := _lang_file(mod, lang_code)
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = Yaml.new().parse(FileAccess.get_file_as_string(path), path)
	return data if data is Dictionary else {}
