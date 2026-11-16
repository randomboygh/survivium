extends RefCounted
## Zips of mods, read and made the same way by the game and the server (stage 2 item 3):
## `unpack_bytes` takes a zip laid out as the «content» folder (`<mod>/mod.yaml`,
## `<mod>/<bundle>/…`), that folder itself (`content/…`) or one mod's files into a mods'
## folder, by the zip's own list of sizes (`sizes_of`, so a zip bomb is never unpacked to
## be weighed) and only the files a mod may have (ModFiles.valid_path, FILE_MAX); `pack`
## makes one of an own mod's folder; `unpack_mod` takes a zip of one own mod in whole, in
## place of what that mod had (a host putting their mod on a server, Server.put_mod).
## The game's side (the system's file picker, the browser's download) is ModImport.

const ModFiles := preload("res://src/shared/content/mod_files.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")

## Where a zip being read is copied first, and where one being packed is written.
const COPY := "user://mod_import.zip"
const PACKED := "user://mod_export.zip"
## Where a zip of one mod is unpacked before it takes the mod's place (unpack_mod).
const STAGE := "user://mod_stage"
## Bytes of a zip taken at most, and of all its files unpacked.
const ZIP_MAX := 64 << 20
const UNPACKED_MAX := 256 << 20


## Unpacks zip `bytes` (a file named `path`, the mod's name when it holds one mod's files)
## into the mods' folder `into` (see the top): {"files": how many went in, "skipped": how
## many were left out, "error": a key of what went wrong or "", "mods": the mods' folders
## it wrote into}.
## The files of mods named in `refuse` are left out (the game's own, which a zip must not
## write over where one's own mods lie beside them).
static func unpack_bytes(bytes: PackedByteArray, path: String, into: String, refuse: Array = []) -> Dictionary:
	var out := {"files": 0, "skipped": 0, "error": "", "mods": []}
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
	# The sizes from the zip's own list, so an entry too big is never unpacked to be
	# weighed (a zip bomb would run the game out of memory).
	var sizes := sizes_of(bytes)
	var total := 0
	for name in names:
		if name.ends_with("/"):
			continue
		var rel := place.call(name.replace("\\", "/")) as String
		if rel == "" or not ModFiles.valid_path(rel) or rel.get_slice("/", 0) in refuse:
			out.skipped += 1
			continue
		var size: int = sizes.get(name, -1)
		if size < 0 or size > ModFiles.FILE_MAX or total + size > UNPACKED_MAX:
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
		if rel.contains("/") and not rel.get_slice("/", 0) in out.mods:
			out.mods.append(rel.get_slice("/", 0))
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


## The unpacked size of each file of the zip `bytes` by its name, read from the zip's
## central directory; {} when it has none that can be read (zip64 sizes are left out).
static func sizes_of(bytes: PackedByteArray) -> Dictionary:
	var out := {}
	var end := -1
	for i in range(bytes.size() - 22, maxi(-1, bytes.size() - 22 - 65536), -1):
		if bytes.decode_u32(i) == 0x06054b50:
			end = i
			break
	if end < 0:
		return out
	var count := bytes.decode_u16(end + 10)
	var at := bytes.decode_u32(end + 16)
	for n in count:
		if at < 0 or at + 46 > bytes.size() or bytes.decode_u32(at) != 0x02014b50:
			break
		var size := bytes.decode_u32(at + 24)
		var name_len := bytes.decode_u16(at + 28)
		var skip := bytes.decode_u16(at + 30) + bytes.decode_u16(at + 32)
		if at + 46 + name_len > bytes.size():
			break
		if size != 0xFFFFFFFF:
			out[bytes.slice(at + 46, at + 46 + name_len).get_string_from_utf8()] = size
		at += 46 + name_len + skip
	return out


## The files of mod folder `dir` (one's own mod) packed into a zip, each under the mod's
## name (`<mod>/mod.yaml`, `<mod>/data/items.yaml`…): only the files a mod may have
## (ModFiles.valid_path). Empty when nothing could be packed.
static func pack(dir: String) -> PackedByteArray:
	var mod := dir.trim_suffix("/").get_file()
	var files: Array[String] = []
	_files(dir, "", files)
	files.sort()
	var zip := ZIPPacker.new()
	if files.is_empty() or zip.open(PACKED) != OK:
		return PackedByteArray()
	for rel in files:
		if not ModFiles.valid_path(mod.path_join(rel)):
			continue
		zip.start_file(mod.path_join(rel))
		zip.write_file(FileAccess.get_file_as_bytes(dir.path_join(rel)))
		zip.close_file()
	zip.close()
	var bytes := FileAccess.get_file_as_bytes(PACKED)
	DirAccess.remove_absolute(PACKED)
	return bytes


static func _files(dir: String, rel: String, out: Array[String]) -> void:
	var at := dir.path_join(rel)
	for f in DirAccess.get_files_at(at):
		out.append(rel.path_join(f) if rel != "" else f)
	for d in DirAccess.get_directories_at(at):
		_files(dir, rel.path_join(d) if rel != "" else d, out)


## Takes zip `bytes` of own mod `mod` (as `pack` makes it: every file under `<mod>/`) in
## whole into the mods' folder `into`, in place of what the mod had there: unpacked into
## STAGE first, and only when it holds the mod's mod.yaml with `own: true` the mod's old
## folder is erased and the new one put there. What goes in is checked as by
## `unpack_bytes` (only the mod's own files, the sizes from the zip's list). The answer as
## `unpack_bytes`'s, "error" also "[the_zip_is_not_that_mod]".
static func unpack_mod(bytes: PackedByteArray, mod: String, into: String) -> Dictionary:
	erase(STAGE)
	DirAccess.make_dir_recursive_absolute(STAGE)
	var out := unpack_bytes(bytes, mod + ".zip", STAGE)
	out.mods = (out.mods as Array).filter(func(m: String) -> bool: return m == mod)
	var manifest: Variant = Yaml.new().parse(FileAccess.get_file_as_string(STAGE.path_join(mod).path_join("mod.yaml")))
	if out.error == "" and not (manifest is Dictionary and manifest.get("own", false) == true and str(manifest.get("id", "")) == mod):
		out.error = "[the_zip_is_not_that_mod]"
	if out.error == "":
		var target := into.path_join(mod)
		erase(target)
		DirAccess.make_dir_recursive_absolute(target)
		var moved := _move(STAGE.path_join(mod), target)
		out.skipped += out.files - moved
		out.files = moved
	erase(STAGE)
	ModFiles.read_extra()
	return out


## Moves every file of folder `from` into folder `to` (made as needed); how many moved.
static func _move(from: String, to: String) -> int:
	var count := 0
	for f in DirAccess.get_files_at(from):
		if DirAccess.rename_absolute(from.path_join(f), to.path_join(f)) == OK:
			count += 1
	for d in DirAccess.get_directories_at(from):
		DirAccess.make_dir_recursive_absolute(to.path_join(d))
		count += _move(from.path_join(d), to.path_join(d))
	return count


## Erases folder `path` with everything in it (the folder too, when it can be).
static func erase(path: String) -> void:
	if path == "" or not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		erase(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
