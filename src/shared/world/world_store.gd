extends RefCounted
## A world saved on disk (plan/architecture/simulation.md). The generator makes the
## same world again from its seed and settings, so a save keeps only what the player
## changed. One directory per world, under `root`, named by world_dir:
##   world.json            seed, settings, mods, levels, the clock, the props (JSON)
##   players/<name>.json   a player: position and the sections other modules keep
##   chunks/<cx>_<cz>.bin  a changed chunk: WorldGen.pack, store_var, zstd
##   map/<rx>_<rz>.bin     a region of the map the player explored: its pixels, zstd
## Files are written beside their place and then moved over it, so a save cut off
## halfway leaves the old file whole. On the web user:// is kept in IndexedDB, on
## Android and the desktop it is a folder; the server keeps its worlds the same way
## (src/server/server_store.gd: players/<hash of the key>.json). current.json in the
## root names the world the game starts with.

## The test world's seed (TestGround.SEED): named here, so what only asks whether a
## world is the test one does not compile the test ground's plan.
const TEST_SEED := -1

const FORMAT := 1
const WORLD := "world.json"
## The version of the content a world is saved with (`content` in world.json), for the
## translations of older saves (materials_of, Mods.of_world).
const CONTENT := 9
## The materials of a world saved before they were split among the mods (`content`
## below 5), in the order its cells were numbered, by their ids now.
const OLD_MATERIALS: PackedStringArray = ["core:air", "core:grass", "core:dirt", "core:stone", "resources:sand",
	"core:water", "plants:log", "plants:leaves", "materials:planks", "resources:clay", "materials:copper_ore",
	"materials:brick", "resources:scree"]
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
## digit per setting (size, water, mountains, rivers, biomes, then caves unless 1 and
## "r" and the relief and "c" and the climate unless 0, as worlds made before those
## settings have); the test
## world is "test".
static func world_dir(seed_value: int, options: Dictionary) -> String:
	if seed_value == TEST_SEED:
		return root + "/test"
	var digits := ""
	for k in ["size", "water", "mountains", "rivers", "biomes"]:
		digits += str(int(options.get(k, 1)))
	if int(options.get("caves", 1)) != 1:
		digits += str(int(options.caves))
	if int(options.get("relief", 0)) != 0:
		digits += "r%d" % int(options.relief)
	if int(options.get("climate", 0)) != 0:
		digits += "c%d" % int(options.climate)
	return "%s/%d-%s" % [root, seed_value, digits]


## The ids of the materials in the order the cells of the world saved as `meta` (its
## world.json) are numbered, for Mat.remap: the save's own list, the core's thirteen for
## one from before the split; empty for a new world.
static func materials_of(meta: Dictionary) -> PackedStringArray:
	return PackedStringArray(meta.get("materials", OLD_MATERIALS if int(meta.get("content", 1)) < 5 else []))


## The world the game starts with: {"seed", "settings"}, empty when none was chosen.
static func read_current() -> Dictionary:
	var d := read_json_at(root + "/current.json")
	if not d.get("seed") is float or not d.get("settings") is Dictionary:
		return {}
	return d


static func write_current(seed_value: int, options: Dictionary) -> void:
	write_json_at(root + "/current.json", {"seed": seed_value, "settings": options})


## The saved worlds, the one saved last first: {"dir", "seed", "settings", "mods", "day",
## "saved", "played"} each, from their world.json (`mods` empty before they were kept:
## every mod there was).
static func list_worlds() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(root):
		return out
	for name in DirAccess.get_directories_at(root):
		var meta := read_json_at("%s/%s/%s" % [root, name, WORLD])
		if meta.get("format") != float(FORMAT) or not meta.get("seed") is float:
			continue
		var settings := {}
		var saved_settings: Dictionary = meta.get("settings", {})
		for k in ["size", "water", "mountains", "rivers", "biomes", "caves", "relief", "climate"]:
			settings[k] = int(saved_settings.get(k, 0 if k in ["relief", "climate"] else 1))
		var mods: Array = Array(meta.get("mods", [])).filter(func(m) -> bool: return m is String)
		out.append({"dir": "%s/%s" % [root, name], "seed": int(meta.seed), "settings": settings, "mods": mods,
			"day": int(meta.get("sky", {}).get("day", 1)), "saved": str(meta.get("saved", "")),
			"played": float(meta.get("played", 0.0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved > b.saved)
	return out


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
	if not _written(f, path, f.store_var(d)) or not _replace(path):
		return false
	_chunks[key] = true
	return true


## The regions of the explored map on disk: their pixels (as write_map took them) by
## region key.
func read_maps() -> Dictionary:
	var out := {}
	if not DirAccess.dir_exists_absolute(dir + "/map"):
		return out
	for f in DirAccess.get_files_at(dir + "/map"):
		var parts := f.get_basename().split("_")
		if not f.ends_with(".bin") or parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue
		var file := FileAccess.open_compressed(dir + "/map/" + f, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if file == null:
			continue
		var data: Variant = file.get_var()
		if data is PackedByteArray:
			out[Vector2i(int(parts[0]), int(parts[1]))] = data
	return out


func write_map(key: Vector2i, data: PackedByteArray) -> bool:
	var path := "%s/map/%d_%d.bin" % [dir, key.x, key.y]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open_compressed(path + ".tmp", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	return _written(f, path, f.store_var(data)) and _replace(path)


## How many chunks are on disk.
func chunk_count() -> int:
	return _chunks.size()


## Deletes the whole world from disk.
func erase() -> void:
	erase_dir(dir)
	_chunks.clear()


func _chunk_path(key: Vector2i) -> String:
	return "%s/chunks/%d_%d.bin" % [dir, key.x, key.y]


static func read_json_at(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


static func write_json_at(path: String, d: Dictionary) -> bool:
	return write_json_beside(path, d) and move_over(path)


## Writes `d` beside `path` (path.tmp), for move_over to put in its place: several files
## written first and moved after are a save that is all old or all new but for the
## moves (the server's snapshot, ServerStore).
static func write_json_beside(path: String, d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	return _written(f, path, f.store_string(JSON.stringify(d, "\t")))


## Closes `f`, the file written beside `path`, and tells whether the write went well
## (`stored`, what the store call returned, no error on the file, something on disk). A
## write that failed (a full disk, a storage quota) leaves no `.tmp` behind, so it never
## replaces the good file at `path`.
static func _written(f: FileAccess, path: String, stored: bool) -> bool:
	var ok := stored and f.get_error() == OK
	f.close()
	if ok:
		var back := FileAccess.open(path + ".tmp", FileAccess.READ)
		ok = back != null and back.get_length() > 0
	if not ok:
		push_error("cannot write %s: the write failed, the file there is kept" % path)
		DirAccess.remove_absolute(path + ".tmp")
	return ok


## Moves the file written beside `path` over it.
static func move_over(path: String) -> bool:
	return _replace(path)


## Removes the files left beside their place in `path` and the folders in it by a save
## cut off before it moved them (*.tmp): what they hold is not the save.
static func remove_beside(path: String) -> int:
	var n := 0
	if not DirAccess.dir_exists_absolute(path):
		return n
	for d in DirAccess.get_directories_at(path):
		n += remove_beside(path + "/" + d)
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".tmp"):
			DirAccess.remove_absolute(path + "/" + f)
			n += 1
	return n


## Moves the file written beside `path` over it.
static func _replace(path: String) -> bool:
	var err := DirAccess.rename_absolute(path + ".tmp", path)
	if err != OK:
		push_error("cannot replace %s: %s" % [path, error_string(err)])
		return false
	return true


## Removes directory `path` with all it holds.
static func erase_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		erase_dir(path + "/" + d)
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)
