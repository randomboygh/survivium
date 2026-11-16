extends RefCounted
## One's own mods, the ones the content editor writes (stage 2, decision 186, 13А): where
## they lie and how their records are written. An own mod is a folder like any other mod
## (content/<mod>/mod.yaml, data/<kind>.yaml, a single bundle named like the mod) laid in
## `root()`: the folder `content/` beside the game on a computer that has one (one's own
## mods are folders there), the app's folder on a phone (ModFiles.extra_dir), else
## ModFiles.USER_DIR (the browser; a computer running the built-in copy). Its records are
## new ones, or patches over another mod's record (`patch: true`, only the fields written),
## so the built-in files are never changed and an update of the game keeps them.
##
## Writing changes only the files; the caller reads the mods again (Content.refresh,
## Mods.rescan) for the game to see them.

const Content := preload("res://src/shared/content/content.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")

## The first lines of a data file the editor writes.
const HEAD := "Written by the content editor of the game: records of this mod, and patches\n(patch: true) of other mods' records with only the fields changed."


## The folder one's own mods lie in.
static func root() -> String:
	if Content.beside():
		return Content.ROOT
	if ModFiles.extra_dir == "":
		ModFiles.extra_dir = ModFiles.USER_DIR
	return ModFiles.extra_dir


## Whether `id` may name a mod: lower-case Latin letters, digits and `_`, a letter first.
static func valid_id(id: String) -> bool:
	if id == "" or id.length() > 32 or not (id[0] >= "a" and id[0] <= "z"):
		return false
	for c in id:
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true


## The own mods there are, by id (folders of `root()` with a mod.yaml the editor wrote).
static func list() -> Array:
	var out := []
	var dir := root()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for name in DirAccess.get_directories_at(dir):
		if FileAccess.file_exists(dir.path_join(name).path_join("mod.yaml")) and own(name):
			out.append(name)
	return out


## Whether mod `id` is one of one's own: in `root()`, made by the editor.
static func own(id: String) -> bool:
	var data: Variant = Yaml.new().parse(FileAccess.get_file_as_string(root().path_join(id).path_join("mod.yaml")))
	return data is Dictionary and data.get("own", false) == true


## Makes own mod `id` (its folder and mod.yaml, its title the key `[<id>.mod]`, `name` in
## English in its lang/en.yaml); "" when made or there already, else what is wrong.
static func make(id: String, name := "") -> String:
	if not valid_id(id):
		return "bad mod id `%s`" % id
	var dir := root().path_join(id)
	if FileAccess.file_exists(dir.path_join("mod.yaml")):
		return "" if own(id) else "mod `%s` is not one's own" % id
	if Content.ROOT != root() and DirAccess.dir_exists_absolute(Content.ROOT.path_join(id)):
		return "mod `%s` is one of the game's" % id
	DirAccess.make_dir_recursive_absolute(dir.path_join("data"))
	var manifest := {"id": id, "title": "[%s.mod]" % id, "version": "0.1", "api": 1, "own": true}
	if name != "":
		DirAccess.make_dir_recursive_absolute(dir.path_join("lang"))
		_save(dir.path_join("lang/en.yaml"), Yaml.write({"[%s.mod]" % id: name}, "Phrases of this mod in English."))
	return _save(dir.path_join("mod.yaml"), Yaml.write(manifest, "One's own mod, made by the content editor of the game."))


## The records of kind `kind` in own mod `mod`, as written (patches included).
static func records(mod: String, kind: String) -> Array:
	var path := _data(mod, kind)
	if not FileAccess.file_exists(path):
		return []
	var data: Variant = Yaml.new().parse(FileAccess.get_file_as_string(path), path)
	return data if data is Array else []


## Writes record `rec` of kind `kind` into own mod `mod`: in place of the one with its id,
## else at the end. "" when written, else what is wrong.
static func put(mod: String, kind: String, rec: Dictionary) -> String:
	if not Content.SCHEMAS.has(kind):
		return "no kind `%s`" % kind
	if str(rec.get("id", "")) == "":
		return "a record without an id"
	var all := records(mod, kind)
	var at := _find(all, str(rec.id))
	if at >= 0:
		all[at] = rec
	else:
		all.append(rec)
	return _write(mod, kind, all)


## Writes a patch of another mod's record `id` (qualified, `animals:wolf`) of kind `kind`
## into own mod `mod`: the fields of `fields`, over those of an earlier patch of it there.
static func patch(mod: String, kind: String, id: String, fields: Dictionary) -> String:
	var rec := {"id": id, "patch": true}
	var at := _find(records(mod, kind), id)
	if at >= 0:
		rec = records(mod, kind)[at]
	for key: String in fields:
		if key != "id" and key != "patch":
			rec[key] = fields[key]
	return put(mod, kind, rec)


## Takes record (or patch) `id` of kind `kind` out of own mod `mod`.
static func remove(mod: String, kind: String, id: String) -> String:
	var all := records(mod, kind)
	var at := _find(all, id)
	if at < 0:
		return ""
	all.remove_at(at)
	return _write(mod, kind, all)


static func _data(mod: String, kind: String) -> String:
	return root().path_join(mod).path_join("data").path_join(kind + ".yaml")


static func _find(all: Array, id: String) -> int:
	for i in all.size():
		if all[i] is Dictionary and str(all[i].get("id", "")) == id:
			return i
	return -1


static func _write(mod: String, kind: String, all: Array) -> String:
	if not own(mod):
		return "mod `%s` is not one's own" % mod
	var path := _data(mod, kind)
	if all.is_empty():
		DirAccess.remove_absolute(path)
		return ""
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return _save(path, Yaml.write(all, HEAD))


static func _save(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % path
	f.store_string(text)
	f.close()
	return ""
