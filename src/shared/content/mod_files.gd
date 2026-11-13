extends RefCounted
## The files of the mods as a server gives them to its players (decision 189): the list
## of what a set of bundles is made of, each file with the hash of its bytes, the one hash
## that names the whole set (`digest`: a client and a server with the same one play with
## the same data and send nothing), and the list packed for the wire. A file is named by
## its path inside `content/` (`animals/wolf/data/creatures.yaml`); only data goes
## (KINDS: YAML, PNG, WAV), never a script.
##
## A set's list (`of_set`) holds every YAML under `content/`, of every mod and bundle, so
## the client reads the same mods as the server and decides the same about each (what a
## bundle needs, what is left out and why), and the pictures and sounds of the set's
## bundles and of their mods only.
##
## An exported game for the browser or a phone holds the mods' pictures and sounds only
## as the engine imported them, so the hashes of its built-in copy are written when the
## game is built (LISTED, tools/content_cache.gd, run by CI before an export); a game run
## from the project's folder or with `content/` beside it reads the files themselves.
##
## Where the game's mods are sealed inside it (a phone), one's own go into a folder of the
## app (`extra_dir`): its files are laid over the built-in ones (`own`, `where`), new mods
## and bundles or other files for the built-in ones, and a server made there gives them.

## The files a set is made of, by extension.
const KINDS := ["yaml", "png", "wav"]
## The mods built into the game, and the list of their files written by the build
## (`pack`ed).
const BUILT_IN := "res://content"
const LISTED := "res://content_files.bin"
## Letters of a hash (the first 128 bits of the SHA-256 of the bytes, as hex).
const HASH_LEN := 32
## The file only the test mod of a server for checking has (src/server/test_mod.gd): a
## game that plays with a server's files (Content.served) knows the mod is on by it.
const TEST_MARK := "core/icons/test_mod.png"
## What a client takes at most: bytes of one file, of a whole set, files of a set,
## letters of a path, bytes of a packed list before and after it is unpacked, and pixels
## along a side of a picture.
const FILE_MAX := 8 << 20
const SET_MAX := 256 << 20
const FILES_MAX := 20000
const PATH_MAX := 160
const LIST_MAX := 4 << 20
const PICTURE_MAX := 2048


## Every file of KINDS under `root`: {path inside it: [hash, size]}. The built-in copy of
## an exported game is read from LISTED.
static func scan(root: String) -> Dictionary:
	if root == BUILT_IN and OS.has_feature("template"):
		return listed()
	var out := {}
	_walk(root, "", out)
	return out


## LISTED as the build wrote it (`pack`ed), {} without one; read once.
static func listed() -> Dictionary:
	if _listed == null:
		_listed = {}
		var f := FileAccess.open(LISTED, FileAccess.READ) if FileAccess.file_exists(LISTED) else null
		var got: Variant = f.get_var() if f != null else null
		if got is Array and got.size() == 2:
			# The build's own list: its paths are not checked letter by letter.
			_listed = unpack(got[0], got[1], true)
	return _listed


static var _listed: Variant = null

## The folder of one's own mods laid over the game's (a phone), "" where there is none
## (a computer has `content/` beside the game; the tests set their own).
static var extra_dir := find_extra()
## Its files ({path inside content/: [hash, size]}), null until read.
static var _extra: Variant = null
## Files under a mods' folder left out of the last scans: a name no list may carry, or
## more bytes than a file may have (`valid_path`, FILE_MAX).
static var skipped: PackedStringArray = []


## On a phone, `content` in the app's own folder of the shared storage
## (Android/data/<the app>/files/content: no permission is asked for it).
static func find_extra() -> String:
	if OS.get_name() != "Android":
		return ""
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS, false)
	return docs.get_base_dir().path_join("content") if docs != "" else ""


## The files of `extra_dir`, read once (the folder is made, so that it can be found);
## `read_extra` reads them again at the next call.
static func extra() -> Dictionary:
	if _extra == null:
		_extra = {}
		if extra_dir != "":
			DirAccess.make_dir_recursive_absolute(extra_dir)
			_walk(extra_dir, "", _extra)
	return _extra


static func read_extra() -> void:
	_extra = null


## The files of the mods of `root` with one's own laid over them (`extra`).
static func own(root: String) -> Dictionary:
	var all := scan(root)
	if extra().is_empty():
		return all
	all = all.duplicate()
	all.merge(extra(), true)
	return all


## Where the file `rel` (a path inside content/) of the mods of `root` is.
static func where(root: String, rel: String) -> String:
	return extra_dir.path_join(rel) if extra().has(rel) else root.path_join(rel)


## Where each file of `own(root)` is, {} when nothing is laid over the mods of `root`.
static func own_table(root: String) -> Dictionary:
	var out := {}
	if not extra().is_empty():
		for rel: String in own(root):
			out[rel] = where(root, rel)
	return out


static func _walk(root: String, inside: String, out: Dictionary) -> void:
	var dir := root if inside == "" else root.path_join(inside)
	for name in DirAccess.get_files_at(dir):
		if not name.get_extension() in KINDS:
			continue
		var path := dir.path_join(name)
		var rel := name if inside == "" else inside.path_join(name)
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		# What no game would take in a server's list is not in it.
		if not valid_path(rel) or f.get_length() > FILE_MAX:
			if not rel in skipped and skipped.size() < 100:
				skipped.append(rel)
			continue
		out[rel] = [FileAccess.get_sha256(path).left(HASH_LEN), f.get_length()]
	for name in DirAccess.get_directories_at(dir):
		if not name.begins_with("."):
			_walk(root, name if inside == "" else inside.path_join(name), out)


## The hash of `bytes` as `scan` gives it for a file.
static func hash_of(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		h.update(bytes)
	return h.finish().hex_encode().left(HASH_LEN)


## The files out of `all` (a scan) that a game playing `bundles` reads: every YAML, and
## the pictures and sounds of those bundles and of their mods (a mod's own folders:
## `common/`, a mod of one bundle whole).
static func of_set(all: Dictionary, bundles: Array) -> Dictionary:
	var mods := {}
	var on := {}
	for b: String in bundles:
		on[b] = true
		mods[b.get_slice("/", 0)] = true
	var out := {}
	for rel: String in all:
		if rel.ends_with(".yaml"):
			out[rel] = all[rel]
			continue
		var mod := rel.get_slice("/", 0)
		if not mods.has(mod):
			continue
		var folder := rel.get_slice("/", 1)
		if rel.get_slice_count("/") >= 3 and all.has("%s/%s/bundle.yaml" % [mod, folder]) and not on.has("%s/%s" % [mod, folder]):
			continue
		out[rel] = all[rel]
	return out


## The one hash that names the files of `list` ({path: [hash, size]}): the same for the
## same paths with the same bytes, whatever order they were found in.
static func digest(list: Dictionary) -> String:
	var paths := list.keys()
	paths.sort()
	var lines := PackedStringArray()
	for rel: String in paths:
		lines.append("%s %s" % [rel, list[rel][0]])
	return hash_of("\n".join(lines).to_utf8_buffer())


## The bytes of all the files of `list`.
static func total(list: Dictionary) -> int:
	var n := 0
	for rel in list:
		n += int(list[rel][1])
	return n


## `list` for the wire: [bytes before packing, the bytes], see unpack.
static func pack(list: Dictionary) -> Array:
	var paths := PackedStringArray()
	var hashes := PackedByteArray()
	var sizes := PackedInt32Array()
	var keys := list.keys()
	keys.sort()
	for rel: String in keys:
		paths.append(rel)
		hashes.append_array(str(list[rel][0]).hex_decode())
		sizes.append(int(list[rel][1]))
	var raw := var_to_bytes([paths, hashes, sizes])
	return [raw.size(), raw.compress(FileAccess.COMPRESSION_ZSTD)]


## The list out of what `pack` made (`size` and `bytes` as a server sent them): {} when it
## is not one, or holds a path that is no file of a mod, a file or a set too large
## (FILE_MAX, SET_MAX, FILES_MAX): what comes from a server is checked before any of it
## is used (`trusted`: the game's own list, its paths taken as they are).
static func unpack(size: Variant, bytes: Variant, trusted := false) -> Dictionary:
	if not size is int or not bytes is PackedByteArray or size <= 0 or size > LIST_MAX or bytes.size() > LIST_MAX:
		return {}
	var raw: PackedByteArray = bytes.decompress(size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != size:
		return {}
	var v: Variant = bytes_to_var(raw)
	if not v is Array or v.size() != 3 or not v[0] is PackedStringArray or not v[1] is PackedByteArray \
			or not v[2] is PackedInt32Array:
		return {}
	var paths: PackedStringArray = v[0]
	var hashes: PackedByteArray = v[1]
	var sizes: PackedInt32Array = v[2]
	var half := HASH_LEN / 2
	if paths.size() > FILES_MAX or sizes.size() != paths.size() or hashes.size() != paths.size() * half:
		return {}
	var out := {}
	var sum := 0
	for i in paths.size():
		if not (trusted or valid_path(paths[i])) or sizes[i] < 0 or sizes[i] > FILE_MAX:
			return {}
		sum += sizes[i]
		out[paths[i]] = [hashes.slice(i * half, (i + 1) * half).hex_encode(), sizes[i]]
	if sum > SET_MAX or out.size() != paths.size():
		return {}
	return out


## Whether `rel` may be the path of a mod's file inside content/: folders and a name of
## plain letters, with an extension of KINDS, nothing that leads out of the folder.
static func valid_path(rel: String) -> bool:
	if rel == "" or rel.length() > PATH_MAX or not rel.get_extension() in KINDS:
		return false
	for part in rel.split("/"):
		if part == "" or part.begins_with(".") or part.ends_with("."):
			return false
		for i in part.length():
			var c := part.unicode_at(i)
			# Letters, digits, `_`, `-`, `.`, `+`: what a file of a mod is named with.
			if not (c >= 0x30 and c <= 0x39 or c >= 0x41 and c <= 0x5A or c >= 0x61 and c <= 0x7A
					or c == 0x5F or c == 0x2D or c == 0x2E or c == 0x2B):
				return false
	return true


## Whether `hash` is one as `scan` writes them.
static func valid_hash(hash: Variant) -> bool:
	return hash is String and hash.length() == HASH_LEN and hash.is_valid_hex_number()


## Whether `bytes` may be a file of kind `ext` a server sent: not larger than FILE_MAX, a
## picture a PNG no wider or taller than PICTURE_MAX (read from its header: a picture is
## not decoded before its size is known), a sound a RIFF WAVE.
static func may_be(bytes: PackedByteArray, ext: String) -> bool:
	if bytes.size() > FILE_MAX:
		return false
	match ext:
		"png":
			if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) \
					or bytes.slice(12, 16).get_string_from_ascii() != "IHDR":
				return false
			var w := bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19]
			var h := bytes[20] << 24 | bytes[21] << 16 | bytes[22] << 8 | bytes[23]
			return w >= 1 and h >= 1 and w <= PICTURE_MAX and h <= PICTURE_MAX
		"wav":
			return bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
				and bytes.slice(8, 12).get_string_from_ascii() == "WAVE"
		"yaml":
			return true
	return false
