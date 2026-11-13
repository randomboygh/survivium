extends SceneTree
## Parses every mod's YAML file under content/ and writes them to Content.PARSED (md5 of a
## file's text → its value), which the game reads instead of parsing them at its start;
## and writes the list of the mods' files with the hash of each to ModFiles.LISTED, by
## which an exported game knows its built-in mods when a server's are others (decision
## 189: the browser and a phone hold the pictures and sounds only as imported).
## CI runs it before each export; a file edited after it is parsed by the game as before.
##     godot --headless --path . --script res://tools/content_cache.gd

const Content := preload("res://src/shared/content/content.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")


func _init() -> void:
	var parsed := Content.parsed_cache()
	var files := ModFiles.scan(ModFiles.BUILT_IN)
	if not _write(Content.PARSED, parsed) or not _write(ModFiles.LISTED, ModFiles.pack(files)):
		quit(1)
		return
	print("%s: %d files parsed" % [Content.PARSED, parsed.size()])
	print("%s: %d files, %d KB, %s" % [ModFiles.LISTED, files.size(), ModFiles.total(files) >> 10, ModFiles.digest(files)])
	quit()


func _write(path: String, value: Variant) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s" % path)
		return false
	f.store_var(value)
	f.close()
	return true
