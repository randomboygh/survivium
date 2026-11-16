extends "res://tests/unit/test_case.gd"
## The content editor (stage 2, decision 186): writing YAML back, one's own mods and their
## records and patches, and the game reading them.

const OwnMods := preload("res://src/shared/content/own_mods.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const ContentEdits := preload("res://src/shared/content/content_edits.gd")

const DIR := "user://test_editor"


func run() -> void:
	_test_yaml_write()
	_test_every_file()
	_test_own_mods()
	_test_edits()
	_test_new_records()


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


## A form's changes saved: another mod's record as a patch of the fields changed, one's
## own record in place; each taken back; a wrong value refused by the check.
func _test_edits() -> void:
	var bundles: Array = Mods.all()
	var mass: float = AiRules.SPECIES["animals:wolf"].mass
	if DirAccess.dir_exists_absolute(DIR):
		_remove(DIR)
	ModFiles.extra_dir = DIR
	OwnMods.make("mine")
	OwnMods.put("mine", "items", {"id": "pebble", "title": "[mine.items.pebble]", "weight": 0.1, "stack": 20})
	Content.BUNDLES = Mods.all()
	Content.refresh()
	Mods.activate(Mods.all())
	_check(ContentEdits.check("creatures", "mass", -1.0, "mine") != "" and ContentEdits.check("creatures", "mass", 50, "mine") == ""
		and ContentEdits.check("creatures", "active", "noon", "mine") != "", "a wrong value is found")
	var wolf := Content.find("creatures", "animals:wolf")
	var fields := ContentEdits.changed("creatures", wolf, {"mass": mass + 3.0, "speed": ContentEdits.data_of(wolf.speed)})
	_check(fields == {"mass": mass + 3.0}, "only the fields changed: %s" % [fields])
	var edits := ContentEdits.new()
	_check(edits.save("mine", "creatures", "animals:wolf", fields) == ""
		and OwnMods.records("mine", "creatures") == [{"id": "animals:wolf", "patch": true, "mass": mass + 3.0}],
		"another mod's record is changed by a patch")
	_check(not ContentEdits.owns("mine", "creatures", "animals:wolf") and ContentEdits.owns("mine", "items", "mine:pebble"),
		"the mod's own records are told from others'")
	_check(edits.save("mine", "items", "mine:pebble", {"stack": 30}) == ""
		and OwnMods.records("mine", "items")[0].stack == 30 and not OwnMods.records("mine", "items")[0].has("patch"),
		"one's own record is changed in place")
	Mods.rescan()
	_check(AiRules.SPECIES["animals:wolf"].mass == mass + 3.0 and Content.find("items", "mine:pebble").stack == 30, "the game reads the changes")
	_check(edits.undo() == "" and OwnMods.records("mine", "items")[0].stack == 20, "a save is taken back")
	_check(edits.undo() == "" and OwnMods.records("mine", "creatures").is_empty() and edits.history.is_empty(),
		"and the first one: the file it made is gone")
	_remove(DIR)
	ModFiles.extra_dir = ""
	Content.BUNDLES = bundles.duplicate()
	Content.refresh()
	Mods.activate(bundles)
	_check(AiRules.SPECIES["animals:wolf"].mass == mass, "the game is as it was")


## A copy of another mod's record made one's own, its title in the mod's language files;
## a title written in place; the copy taken out with its phrases; each taken back.
func _test_new_records() -> void:
	var bundles: Array = Mods.all()
	if DirAccess.dir_exists_absolute(DIR):
		_remove(DIR)
	ModFiles.extra_dir = DIR
	OwnMods.make("mine")
	# Titles are written in the game's language: English here.
	var lang_was := Lang.code
	Lang.use(Lang.SOURCE)
	var read_all := func() -> void:
		Content.BUNDLES = Mods.all()
		Content.refresh()
		Mods.activate(Mods.all())
		Lang.reread()
	read_all.call()
	var edits := ContentEdits.new()
	var wolf := Content.find("creatures", "animals:wolf")
	_check(edits.copy("mine", "creatures", "animals:wolf", "Bad id") != ""
		and edits.copy("mine", "creatures", "animals:nothing", "dog") != "", "a bad id or a missing record is refused")
	_check(edits.copy("mine", "creatures", "animals:wolf", "dog") == "", "a copy is written")
	var dog: Dictionary = OwnMods.records("mine", "creatures")[0]
	_check(dog.id == "dog" and dog.title == "[mine.creatures.dog]" and not dog.has("was") and dog.has("mass"),
		"the copy has its own id and title key: %s" % [dog])
	_check(ContentEdits._phrases("mine", "en").get("[mine.creatures.dog]") == Lang.english().text_of(wolf.title),
		"its title is in the mod's English")
	_check(edits.copy("mine", "creatures", "animals:wolf", "dog") != "", "an id there already is refused")
	read_all.call()
	var problems := Array(Content.problems).filter(func(p: String) -> bool: return p.contains("mine"))
	_check(not Content.find("creatures", "mine:dog").is_empty() and AiRules.SPECIES.has("mine:dog") and problems.is_empty(),
		"the game reads the copy: %s" % [problems])
	_check(Lang.t("[mine.creatures.dog]") == Lang.t(wolf.title), "and its title")
	_check(edits.save("mine", "creatures", "mine:dog", {}, {"title": "Dog"}) == ""
		and ContentEdits._phrases("mine", "en")["[mine.creatures.dog]"] == "Dog", "a title written in place")
	_check(edits.save("mine", "creatures", "animals:wolf", {}, {"title": "Grey wolf"}) == ""
		and OwnMods.records("mine", "creatures")[1] == {"id": "animals:wolf", "patch": true, "title": "[mine.creatures.animals_wolf]"},
		"another mod's title by a patch with the mod's own key")
	read_all.call()
	_check(Lang.t(Content.find("creatures", "animals:wolf").title) == "Grey wolf" and Lang.t("[mine.creatures.dog]") == "Dog",
		"the game reads the titles")
	_check(edits.delete("mine", "creatures", "mine:dog") == "" and OwnMods.records("mine", "creatures").size() == 1
		and not ContentEdits._phrases("mine", "en").has("[mine.creatures.dog]"), "the copy is taken out with its phrases")
	_check(edits.delete("mine", "creatures", "animals:wolf") == "" and OwnMods.records("mine", "creatures").is_empty(),
		"a patch is taken out")
	_check(edits.undo() == "" and edits.undo() == "" and OwnMods.records("mine", "creatures").size() == 2
		and ContentEdits._phrases("mine", "en").has("[mine.creatures.dog]"), "deletes are taken back")
	_check(edits.undo() == "" and edits.undo() == "" and ContentEdits._phrases("mine", "en")["[mine.creatures.dog]"] == Lang.english().text_of(wolf.title)
		and OwnMods.records("mine", "creatures").size() == 1, "titles are taken back")
	_check(edits.undo() == "" and OwnMods.records("mine", "creatures").is_empty() and not ContentEdits._phrases("mine", "en").has("[mine.creatures.dog]"),
		"and the copy")
	_remove(DIR)
	ModFiles.extra_dir = ""
	Content.BUNDLES = bundles.duplicate()
	Content.refresh()
	Mods.activate(bundles)
	# The phrases read again without the mod, and no table left in the TranslationServer: a
	# scripted one crashes the engine on the way out (Lang.drop).
	Lang.code = lang_was
	Lang.reread()
	Lang.drop()
	_check(Content.find("creatures", "mine:dog").is_empty(), "the game is as it was")
