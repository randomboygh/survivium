extends RefCounted
## The mods' files taken from servers, kept on this device (decision 189): each file once,
## named by the hash of its bytes with its extension (`user://mod_cache/<hash>.png`), so
## two servers with the same file share it and a server joined again sends only what
## changed since; and the lists of the sets joined lately (`sets/<digest>.bin`: the
## bundles and the files, ModFiles.pack), so a server whose files are all here already is
## joined without asking it for anything. A file is checked before it is kept (its hash,
## its kind and size: ModFiles.may_be). The files not used for the longest go when the
## cache passes LIMIT (`trim`, after a set was taken); «Очистить данные серверов» in the
## settings empties it (`clear`).

const ModFiles := preload("res://src/shared/content/mod_files.gd")

## The folder (the tests set their own), the lists in it, and when each file was last used.
static var dir := "user://mod_cache"
const SETS := "sets"
const USED := "used.json"
## Bytes kept at most, and lists.
const LIMIT := 200 << 20
const SETS_KEPT := 8


## Where the file of `hash` and extension `ext` is kept.
static func path(hash: String, ext: String) -> String:
	return "%s/%s.%s" % [dir, hash, ext]


## Whether the file of `hash` with `size` bytes is kept.
static func has(hash: String, ext: String, size: int) -> bool:
	var f := FileAccess.open(path(hash, ext), FileAccess.READ)
	return f != null and f.get_length() == size


## Keeps `bytes` as the file of `hash`; false when they are not that file (another hash,
## not a file of that kind) or cannot be written.
static func store(hash: String, ext: String, bytes: PackedByteArray) -> bool:
	if not ModFiles.valid_hash(hash) or not ext in ModFiles.KINDS or ModFiles.hash_of(bytes) != hash \
			or not ModFiles.may_be(bytes, ext):
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path(hash, ext) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return DirAccess.rename_absolute(tmp, path(hash, ext)) == OK


## Keeps the list of the set `digest`: its bundles and its files as packed (ModFiles.pack).
static func keep_set(digest: String, bundles: Array, packed: Array) -> void:
	if not ModFiles.valid_hash(digest):
		return
	DirAccess.make_dir_recursive_absolute(dir.path_join(SETS))
	var f := FileAccess.open("%s/%s/%s.bin" % [dir, SETS, digest], FileAccess.WRITE)
	if f != null:
		f.store_var([bundles, packed[0], packed[1]])
		f.close()
	var names := Array(DirAccess.get_files_at(dir.path_join(SETS)))
	if names.size() > SETS_KEPT:
		names.sort_custom(func(a: String, b: String) -> bool:
			return FileAccess.get_modified_time("%s/%s/%s" % [dir, SETS, a]) > FileAccess.get_modified_time("%s/%s/%s" % [dir, SETS, b]))
		for name: String in names.slice(SETS_KEPT):
			DirAccess.remove_absolute("%s/%s/%s" % [dir, SETS, name])


## The set `digest` as kept: {"bundles", "list" ({path: [hash, size]})}, {} when it is not
## kept or is not what its name says.
static func set_of(digest: String) -> Dictionary:
	if not ModFiles.valid_hash(digest):
		return {}
	var f := FileAccess.open("%s/%s/%s.bin" % [dir, SETS, digest], FileAccess.READ)
	var v: Variant = f.get_var() if f != null else null
	if not v is Array or v.size() != 3 or not v[0] is Array:
		return {}
	var list := ModFiles.unpack(v[1], v[2])
	if list.is_empty() or ModFiles.digest(list) != digest:
		return {}
	return {"bundles": v[0], "list": list}


## Notes the files named (`<hash>.<ext>`) as used now, for `trim`.
static func used(names: Array) -> void:
	if names.is_empty():
		return
	var at := _used()
	var now := int(Time.get_unix_time_from_system())
	for n: String in names:
		at[n] = now
	_write_used(at)


## Bytes of the files kept.
static func size() -> int:
	var n := 0
	for name in DirAccess.get_files_at(dir):
		if name != USED:
			var f := FileAccess.open(dir.path_join(name), FileAccess.READ)
			n += f.get_length() if f != null else 0
	return n


## Removes the files used the longest ago until `limit` bytes are kept at most, never one
## of `keep` (names: the set played now); the bytes freed.
static func trim(limit := LIMIT, keep: Dictionary = {}) -> int:
	var at := _used()
	var files := []
	var sum := 0
	for name in DirAccess.get_files_at(dir):
		if name == USED:
			continue
		var f := FileAccess.open(dir.path_join(name), FileAccess.READ)
		var bytes := f.get_length() if f != null else 0
		sum += bytes
		if not keep.has(name):
			files.append([int(at.get(name, 0)), name, bytes])
	files.sort()
	var freed := 0
	for e: Array in files:
		if sum - freed <= limit:
			break
		if DirAccess.remove_absolute(dir.path_join(e[1])) == OK:
			freed += e[2]
			at.erase(e[1])
	if freed > 0:
		_write_used(at)
	return freed


## Removes everything kept but the files of `keep` (names: the set played now); the bytes
## freed.
static func clear(keep: Dictionary = {}) -> int:
	var was := size()
	for name in DirAccess.get_files_at(dir):
		if not keep.has(name):
			DirAccess.remove_absolute(dir.path_join(name))
	for name in DirAccess.get_files_at(dir.path_join(SETS)):
		DirAccess.remove_absolute("%s/%s/%s" % [dir, SETS, name])
	return was - size()


## The files kept that `table` (Content.served: a path → the file that holds it) plays
## with, by name, for `trim` and `clear` to leave alone.
static func in_use(table: Dictionary) -> Dictionary:
	var out := {}
	for rel: String in table:
		var at: String = table[rel]
		if at.begins_with(dir + "/"):
			out[at.get_file()] = true
	return out


static func _used() -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(USED))) \
		if FileAccess.file_exists(dir.path_join(USED)) else null
	return v if v is Dictionary else {}


static func _write_used(at: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join(USED), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(at))
