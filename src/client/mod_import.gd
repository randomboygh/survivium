extends RefCounted
## One's own mods brought into the game on a phone (decision 189, 4В): the folder of the
## app they are read from (ModFiles.extra_dir, Android/data/<the app>/files/content) is out
## of reach of the file managers of new Androids, so a .zip is picked with the system's own
## file picker and unpacked into it («Свои моды» in the settings, SettingsMenu). The zip
## holds the mods laid out as in the «content» folder of the PC version (`<mod>/mod.yaml`,
## `<mod>/<bundle>/…`), that folder itself (`content/…`, also inside a folder), or the files
## of one mod (its mod.yaml at the top: the mod is named after the zip). Only the files a
## mod may have go in (ModFiles.valid_path, FILE_MAX); the mods are then read again.
## The content editor packs one's own mod into such a zip (ModZip.pack, `<mod>/…`) and
## hands it to the player (`offer`: the browser's download, the system's save dialog) —
## stage 2 item 3, step 6 — and unpacks one picked (ModZip.unpack_bytes). Reading and
## making zips is ModZip's (src/shared: the server takes an author's mod the same way).

const ModFiles := preload("res://src/shared/content/mod_files.gd")
const ModZip := preload("res://src/shared/content/mod_zip.gd")
const Lang := preload("res://src/shared/content/lang.gd")


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


## Unpacks the zip at `path` into the mods' folder `into` (see the top, ModZip.unpack_bytes):
## {"files": how many went in, "skipped": how many were left out, "error": a key of what
## went wrong, or ""}.
static func unpack(path: String, into: String) -> Dictionary:
	return ModZip.unpack_bytes(FileAccess.get_file_as_bytes(path), path, into)


## Deletes one's own mods: every file and folder in `dir`.
static func clear(dir: String) -> void:
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	ModZip.erase(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	ModFiles.read_extra()


## Whether a zip can be handed to the player here (a download in the browser, the
## system's save dialog elsewhere).
static func can_offer() -> bool:
	return OS.has_feature("web") or DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## Hands zip `bytes` to the player as file `name`: the browser downloads it; elsewhere the
## system's save dialog asks where. `done(where: String)` gets where it went ("" when the
## dialog was left or it could not be written).
static func offer(bytes: PackedByteArray, name: String, done: Callable) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, name, "application/zip")
		done.call(name)
		return
	DisplayServer.file_dialog_show(Lang.t("[editor_export_zip]"), "", name, false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.zip;ZIP;application/zip"]),
		func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			if not ok or paths.is_empty():
				return
			var f := FileAccess.open(paths[0], FileAccess.WRITE)
			if f == null:
				done.call("")
				return
			f.store_buffer(bytes)
			f.close()
			done.call(paths[0].uri_decode().get_file()))
