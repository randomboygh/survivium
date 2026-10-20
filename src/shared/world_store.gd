extends RefCounted
## A world saved on disk (plan/architecture/simulation.md). The generator makes the
## same world again from its seed and settings, so a save keeps only what the player
## changed. One directory per world, under `root`, named by world_dir:
##   world.json            seed, settings, levels, the clock, the props (JSON)
##   players/<name>.json   a player: position and the sections other modules keep
##   chunks/<cx>_<cz>.bin  a changed chunk: WorldGen.pack, store_var, zstd
## Files are written beside their place and then moved over it, so a save cut off
## halfway leaves the old file whole. On the web user:// is kept in IndexedDB, on
## Android and the desktop it is a folder; the server will keep its worlds the same
## way. current.json in the root names the world the game starts with.

const FORMAT := 1
const WORLD := "world.json"
## Where the worlds are kept (tests keep theirs apart).
static var root := "user://saves"

## The world's directory.
var dir: String
## Keys of the chunks on disk.
var _chunks := {}


## A store over `path`; reads which chunks it has.
func _init(path: String) -> void:
	dir = path
	if not DirAccess.dir_exists_absolute(dir + "/chunks"):
		return
	for f in DirAccess.get_files_at(dir + "/chunks"):
		if not f.ends_with(".bin"):
			continue
		var parts := f.get_basename().split("_")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			_chunks[Vector2i(int(parts[0]), int(parts[1]))] = true


## The directory of the world of `seed_value` and WorldGen `options`: the seed and one
## digit per setting (size, water, mountains, rivers, biomes).
static func world_dir(seed_value: int, options: Dictionary) -> String:
	var digits := ""
	for k in ["size", "water", "mountains", "rivers", "biomes"]:
		digits += str(int(options.get(k, 1)))
	return "%s/%d-%s" % [root, seed_value, digits]


## The world the game starts with: {"seed", "settings"}, empty when none was chosen.
static func read_current() -> Dictionary:
	var d := read_json_at(root + "/current.json")
	if not d.get("seed") is float or not d.get("settings") is Dictionary:
		return {}
	return d


static func write_current(seed_value: int, options: Dictionary) -> void:
	write_json_at(root + "/current.json", {"seed": seed_value, "settings": options})


## True once the world has been saved.
func exists() -> bool:
	return FileAccess.file_exists(dir + "/" + WORLD)


func read_json(name: String) -> Dictionary:
	return read_json_at(dir + "/" + name)


func write_json(name: String, d: Dictionary) -> bool:
	return write_json_at(dir + "/" + name, d)


func has_chunk(key: Vector2i) -> bool:
	return _chunks.has(key)


## The record of chunk `key` (see WorldGen.pack), empty when it cannot be read.
func read_chunk(key: Vector2i) -> Dictionary:
	var f := FileAccess.open_compressed(_chunk_path(key), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var d: Variant = f.get_var()
	return d if d is Dictionary else {}


func write_chunk(key: Vector2i, d: Dictionary) -> bool:
	var path := _chunk_path(key)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open_compressed(path + ".tmp", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_var(d)
	f.close()
	if not _replace(path):
		return false
	_chunks[key] = true
	return true


## How many chunks are on disk.
func chunk_count() -> int:
	return _chunks.size()


## Deletes the whole world from disk.
func erase() -> void:
	_erase_dir(dir)
	_chunks.clear()


func _chunk_path(key: Vector2i) -> String:
	return "%s/chunks/%d_%d.bin" % [dir, key.x, key.y]


static func read_json_at(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


static func write_json_at(path: String, d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return _replace(path)


## Moves the file written beside `path` over it.
static func _replace(path: String) -> bool:
	var err := DirAccess.rename_absolute(path + ".tmp", path)
	if err != OK:
		push_error("cannot replace %s: %s" % [path, error_string(err)])
		return false
	return true


static func _erase_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_erase_dir(path + "/" + d)
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)
