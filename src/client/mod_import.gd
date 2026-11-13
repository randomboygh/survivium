extends RefCounted
## One's own mods brought into the game on a phone (decision 189, 4В): the folder of the
## app they are read from (ModFiles.extra_dir, Android/data/<the app>/files/content) is out
## of reach of the file managers of new Androids, so a .zip is picked with the system's own
## file picker and unpacked into it («Свои моды» in the settings, SettingsMenu). The zip
## holds the mods laid out as in the «content» folder of the PC version (`<mod>/mod.yaml`,
## `<mod>/<bundle>/…`), that folder itself (`content/…`, also inside a folder), or the files
## of one mod (its mod.yaml at the top: the mod is named after the zip). Only the files a
## mod may have go in (ModFiles.valid_path, FILE_MAX); the mods are then read again.

const ModFiles := preload("res://src/shared/content/mod_files.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## Where the picked zip is copied before it is read (the picker gives a content:// path).
const COPY := "user://mod_import.zip"
## Bytes of a zip taken at most, and of all its files unpacked.
const ZIP_MAX := 64 << 20
const UNPACKED_MAX := 256 << 20


## Whether a zip of mods can be picked here: a phone with a folder for its own mods and
## the system's file picker.
static func can_pick() -> bool:
	return ModFiles.extra_dir != "" and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## Opens the system's file picker for a zip; `done` gets what unpack made of the one picked
## (nothing is called when the picker is left).
static func pick(done: Callable) -> void:
	DisplayServer.file_dialog_show(Lang.t("[import_mods_from_a_zip]"), "", "", false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.zip;ZIP;application/zip"]),
		func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			if ok and not paths.is_empty():
				done.call(unpack(paths[0], ModFiles.extra_dir)))


## Unpacks the zip at `path` into the mods' folder `into` (see the top): {"files": how many
## went in, "skipped": how many were left out, "error": a key of what went wrong, or ""}.
static func unpack(path: String, into: String) -> Dictionary:
	var out := {"files": 0, "skipped": 0, "error": ""}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or bytes.size() > ZIP_MAX:
		out.error = "[the_file_could_not_be_read]" if bytes.is_empty() else "[the_zip_is_too_large]"
		return out
	var copy := FileAccess.open(COPY, FileAccess.WRITE)
	if copy == null:
		out.error = "[the_file_could_not_be_read]"
		return out
	copy.store_buffer(bytes)
	copy.close()
	var zip := ZIPReader.new()
	if zip.open(COPY) != OK:
		out.error = "[this_is_not_a_zip]"
		DirAccess.remove_absolute(COPY)
		return out
	var names: PackedStringArray = zip.get_files()
	var place := placing(names, path)
	var total := 0
	for name in names:
		if name.ends_with("/"):
			continue
		var rel := place.call(name.replace("\\", "/")) as String
		if rel == "" or not ModFiles.valid_path(rel):
			out.skipped += 1
			continue
		var data := zip.read_file(name)
		total += data.size()
		if data.size() > ModFiles.FILE_MAX or total > UNPACKED_MAX:
			out.skipped += 1
			continue
		var target := into.path_join(rel)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var f := FileAccess.open(target, FileAccess.WRITE)
		if f == null:
			out.skipped += 1
			continue
		f.store_buffer(data)
		f.close()
		out.files += 1
	zip.close()
	DirAccess.remove_absolute(COPY)
	if out.files == 0 and out.error == "":
		out.error = "[no_mod_files_in_the_zip]"
	ModFiles.read_extra()
	print("mods imported from %s: %d files, %d left out" % [path, out.files, out.skipped])
	return out


## Where each file of a zip of `names` goes inside the mods' folder: a Callable from the
## name in the zip to the path in the folder ("" for one outside the mods). Inside a folder
## `content/` (the shortest such prefix), what is under it; else, when a mod.yaml is at the
## top, the whole zip as one mod named after the file `zip_path`; else as it is.
static func placing(names: PackedStringArray, zip_path: String) -> Callable:
	var prefix := ""
	var best := -1
	for name in names:
		var n := name.replace("\\", "/")
		var at := n.find("content/")
		if (at == 0 or at > 0 and n[at - 1] == "/") and (best < 0 or at < best):
			best = at
			prefix = n.left(at + "content/".length())
	if best >= 0:
		return func(n: String) -> String: return n.trim_prefix(prefix) if n.begins_with(prefix) else ""
	if "mod.yaml" in names:
		var mod := mod_name(zip_path)
		return func(n: String) -> String: return mod.path_join(n) if mod != "" else ""
	return func(n: String) -> String: return n


## A mod's name made of the name of zip file `path` (a content:// path from the picker
## ends in its name, %-encoded): lower case letters, digits and `_`; "" when none is left.
static func mod_name(path: String) -> String:
	var base := path.uri_decode().get_file().get_basename().to_lower()
	base = base.get_slice(":", base.get_slice_count(":") - 1)
	var out := ""
	for i in base.length():
		var c := base[i]
		if c >= "a" and c <= "z" or c >= "0" and c <= "9" or c == "_":
			out += c
		elif c == "-" or c == " " or c == ".":
			out += "_"
	return out.left(32)


## Deletes one's own mods: every file and folder in `dir`.
static func clear(dir: String) -> void:
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	_erase(dir)
	ModFiles.read_extra()


static func _erase(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_erase(path.path_join(d))
		DirAccess.remove_absolute(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
