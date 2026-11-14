extends RefCounted
## Watches the mods' files under content/ for a hot reload (ModReload, the game on a
## computer): `step` looks at a few of them each call (`budget`), the
## folders walked a step at a time too, so a pass over the two thousand and more files takes
## many frames and none of them long; at the end of a pass it says whether a file was
## changed, added or removed since the pass before. The first pass only learns the times.
## Works where the files are there (`can_watch`): the game run from the project's folder,
## or an exported game on a computer reading the mods beside it (Content.ROOT, decision
## 186); not an exported game's copy built in, whose files are packed.

const ContentFields := preload("res://src/shared/content/content_fields.gd")
## The kinds of files a mod is made of.
const KINDS := ["yaml", "png", "wav"]
## Files and folders looked at by a step; by one while the game is played, its window in
## front (ModReload.update).
const BUDGET := 120
const BUDGET_PLAYED := 12

## path -> its time, from the last pass done; the pass going on.
var _times := {}
var _now := {}
## What is still to be looked at in this pass: folders end with "/".
var _todo: PackedStringArray = []
var _primed := false
## Passes done, for the tests.
var passes := 0
## The folder watched (the tests watch one of their own).
var root: String = ContentFields.ROOT


func _init(folder := "") -> void:
	root = folder if folder != "" else ContentFields.ROOT


## Whether the files of the mods can be watched here: the game run by the editor's engine
## from the project's folder, or the mods read from the folder beside an exported game,
## where they are files of their own.
static func can_watch() -> bool:
	return (OS.has_feature("editor") or ContentFields.beside()) and DirAccess.dir_exists_absolute(ContentFields.ROOT)


## Looks at up to `budget` files and folders; true when a pass ended now and found a file
## changed, added or removed (never on the first pass, which only learns them).
func step(budget := BUDGET) -> bool:
	if _todo.is_empty():
		_todo.append(root + "/")
	while budget > 0 and not _todo.is_empty():
		budget -= 1
		var path: String = _todo[_todo.size() - 1]
		_todo.remove_at(_todo.size() - 1)
		if path.ends_with("/"):
			var dir := path.trim_suffix("/")
			for d in DirAccess.get_directories_at(dir):
				if not d.begins_with("."):
					_todo.append("%s/%s/" % [dir, d])
			for f in DirAccess.get_files_at(dir):
				if f.get_extension() in KINDS:
					_todo.append("%s/%s" % [dir, f])
		else:
			_now[path] = FileAccess.get_modified_time(path)
		if _todo.is_empty():
			return _end_pass()
	return false


func _end_pass() -> bool:
	var changed := _primed and _now != _times
	_times = _now
	_now = {}
	_primed = true
	passes += 1
	return changed
