extends SceneTree
## Parses every mod's YAML file under content/ and writes them to Content.PARSED (md5 of a
## file's text → its value), which the game reads instead of parsing them at its start.
## CI runs it before each export; a file edited after it is parsed by the game as before.
##     godot --headless --path . --script res://tools/content_cache.gd

const Content := preload("res://src/shared/content/content.gd")


func _init() -> void:
	var parsed := Content.parsed_cache()
	var f := FileAccess.open(Content.PARSED, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s" % Content.PARSED)
		quit(1)
		return
	f.store_var(parsed)
	f.close()
	print("%s: %d files parsed" % [Content.PARSED, parsed.size()])
	quit()
