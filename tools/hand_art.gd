extends RefCounted
## The pictures and sounds made or finished by hand, which the art generators of tools/
## leave as they are (make_sprites.gd, make_icons.gd, make_models.gd, make_textures.gd,
## make_sounds.gd; the Python ones ask tools/hand_art.py, which reads the same lists). A
## bundle names them in its bundle.yaml, a mod in its mod.yaml (the files of a mod of one
## bundle and of a mod's own folders), each as a path inside that folder; assets/hand.yaml
## names those of assets/ the same way:
##
##   hand: [models/grave.png]
##
## A file named so is the one the game shows: it is changed by hand, or its name is taken
## out of the list to let its generator write it again.

const Yaml := preload("res://src/shared/content/yaml.gd")

## Manifest -> the paths its `hand` lists, read once.
static var _read := {}


## Whether `path` (res://, or absolute inside the project) is named as made by hand.
static func marked(path: String) -> bool:
	var rel := path.trim_prefix("res://")
	var project := ProjectSettings.globalize_path("res://")
	if rel.begins_with(project):
		rel = rel.substr(project.length())
	var at := _manifest_of(rel)
	return not at.is_empty() and _names(at[0]).has(rel.substr(at[1].length()))


## True, after saying so, when `path` is made by hand: the generator leaves it as it is.
static func kept(path: String) -> bool:
	if not marked(path):
		return false
	print("kept, made by hand: ", path)
	return true


## The manifest that names the file `rel` (a path in the project) and its folder, or [].
static func _manifest_of(rel: String) -> Array:
	var parts := rel.split("/")
	if parts[0] == "content" and parts.size() >= 3:
		var bundle := "content/%s/%s/" % [parts[1], parts[2]]
		if parts.size() >= 4 and FileAccess.file_exists("res://" + bundle + "bundle.yaml"):
			return [bundle + "bundle.yaml", bundle]
		return ["content/%s/mod.yaml" % parts[1], "content/%s/" % parts[1]]
	if parts[0] == "assets" and parts.size() >= 2:
		return ["assets/hand.yaml", "assets/"]
	return []


static func _names(manifest: String) -> Array:
	if not _read.has(manifest):
		var names: Array = []
		if FileAccess.file_exists("res://" + manifest):
			var data: Variant = Yaml.new().parse(FileAccess.get_file_as_string("res://" + manifest), manifest)
			if data is Dictionary and data.get("hand") is Array:
				names = data.hand
		_read[manifest] = names
	return _read[manifest]
