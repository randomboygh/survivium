extends "res://tests/unit/test_case.gd"
## The content editor (stage 2, decision 186): writing YAML back, one's own mods and their
## records and patches, and the game reading them.

const OwnMods := preload("res://src/shared/content/own_mods.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")

const DIR := "user://test_editor"


func run() -> void:
	_test_yaml_write()
	_test_every_file()
	_test_own_mods()


## Writing YAML that the reader reads back as the same value.
func _test_yaml_write() -> void:
	var value := [
		{"id": "a", "title": "[x.a]", "weight": 3.0, "stack": 5, "on": true, "none": null,
			"color": "#aabbcc", "word": "yes", "num": "12", "colon": "a: b", "space": " pad",
			"needs": {"core:fiber": 2, "plank": 1}, "list": ["a", "b c", 2.5],
			"entries": [{"prop": "chest", "at": [1, 0]}, {"prop": "bed", "at": [0, 2]}],
			"deep": {"a": {"b": [1, 2]}}, "empty": [], "none_map": {}},
		{"id": "b", "patch": true},
	]
	var text := Yaml.write(value, "a head\nof two lines")
	var yaml := Yaml.new()
	var back: Variant = yaml.parse(text, "written.yaml")
	_check(yaml.error == "" and var_to_str(back) == var_to_str(value), "written YAML reads back the same:\n" + text)
	_check(text.begins_with("# a head\n# of two lines\n- id: a\n"), "a head as comments, a record's first key on its item's line")


## Every data file of the game read, written and read again is the same.
func _test_every_file() -> void:
	var files := []
	_walk("res://content", files)
	var bad := []
	for path: String in files:
		var yaml := Yaml.new()
		var value: Variant = yaml.parse(FileAccess.get_file_as_string(path), path)
		var again := Yaml.new()
		var back: Variant = again.parse(Yaml.write(value), path)
		if again.error != "" or var_to_str(back) != var_to_str(value):
			bad.append(path)
	_check(files.size() > 100 and bad.is_empty(), "%d data files written read back the same, not: %s" % [files.size(), bad.slice(0, 5)])


func _walk(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".yaml"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), out)


## An own mod made in a folder laid over the game's: a new record and a patch of another
## mod's record, read by the game; taken out again.
func _test_own_mods() -> void:
	var stock := Content.playing(true)
	var mass: float = AiRules.SPECIES["animals:wolf"].mass
	if DirAccess.dir_exists_absolute(DIR):
		_remove(DIR)
	ModFiles.extra_dir = DIR
	_check(OwnMods.root() == DIR, "own mods lie in the folder laid over the game's")
	_check(OwnMods.make("Bad-id") != "" and OwnMods.make("core") != "", "a bad id and a mod of the game are refused")
	_check(OwnMods.make("mine") == "" and OwnMods.list() == ["mine"] and OwnMods.own("mine"), "an own mod is made")
	var rec := {"id": "pebble", "title": "[mine.items.pebble]", "weight": 0.1, "stack": 20}
	_check(OwnMods.put("mine", "items", rec) == "" and OwnMods.records("mine", "items") == [rec], "a new record is written")
	_check(OwnMods.patch("mine", "creatures", "animals:wolf", {"mass": mass + 7.0}) == ""
		and OwnMods.patch("mine", "creatures", "animals:wolf", {"speed": 1.5}) == ""
		and OwnMods.records("mine", "creatures") == [{"id": "animals:wolf", "patch": true, "mass": mass + 7.0, "speed": 1.5}],
		"patches of one record gather into one")
	var bundles: Array = Mods.all()
	Content.refresh()
	var problems := Mods.activate(Mods.all())
	_check(Items.has("mine:pebble") and AiRules.SPECIES["animals:wolf"].mass == mass + 7.0,
		"the game reads them: problems %s" % [problems])
	_check(OwnMods.remove("mine", "creatures", "animals:wolf") == "" and OwnMods.records("mine", "creatures").is_empty(),
		"a patch is taken out")
	_remove(DIR)
	ModFiles.extra_dir = ""
	Content.BUNDLES = bundles.duplicate()
	Content.refresh()
	Mods.activate(bundles)
	_check(Content.playing() == stock and not Items.has("mine:pebble") and AiRules.SPECIES["animals:wolf"].mass == mass,
		"without the folder the game is as it was")
