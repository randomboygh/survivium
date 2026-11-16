extends "res://tests/unit/test_case.gd"
## The content editor (stage 2, decision 186): writing YAML back, one's own mods and their
## records and patches, and the game reading them.

const OwnMods := preload("res://src/shared/content/own_mods.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const ContentEdits := preload("res://src/shared/content/content_edits.gd")
const VoxelSheet := preload("res://src/client/ui/editor/voxel_sheet.gd")
const SliceGrid := preload("res://src/client/ui/editor/slice_grid.gd")
const ModZip := preload("res://src/shared/content/mod_zip.gd")
const Server := preload("res://src/server/server.gd")
const Config := preload("res://src/server/config.gd")

const DIR := "user://test_editor"


func run() -> void:
	_test_yaml_write()
	_test_every_file()
	_test_own_mods()
	_test_edits()
	_test_new_records()
	_test_field_names()
	_test_pictures()
	_test_voxels()
	_test_zips()
	_test_server_put()


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


## Every field a form shows has a name and a line in the game's languages (FieldNames).
func _test_field_names() -> void:
	var FieldNames := load("res://src/client/ui/editor/field_names.gd")
	var RecordForm := load("res://src/client/ui/editor/record_form.gd")
	var english := Lang.english()
	var bad := []
	for kind: String in Content.SCHEMAS:
		for field: String in Content.schema(kind):
			if field in RecordForm.HIDDEN:
				continue
			var keys: Array = FieldNames.of(kind, field)
			if keys[1] == "" or english.text_of(keys[0]) == keys[0] or english.text_of(keys[1]) == keys[1]:
				bad.append("%s.%s" % [kind, field])
	_check(bad.is_empty(), "every field has a name and a line: not %s" % [bad.slice(0, 8)])


## A picture taken into one's own mod: for its own record by its name, for another mod's
## by `<mod>:<name>` in a patch; the game finds both; a file that is no PNG is refused;
## each taken back with its field.
func _test_pictures() -> void:
	var bundles: Array = Mods.all()
	if DirAccess.dir_exists_absolute(DIR):
		_remove(DIR)
	ModFiles.extra_dir = DIR
	OwnMods.make("mine")
	var read_all := func() -> void:
		Content.BUNDLES = Mods.all()
		Content.refresh()
		Mods.activate(Mods.all())
	read_all.call()
	var img := Image.create(5, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var png := img.save_png_to_buffer()
	var edits := ContentEdits.new()
	_check(edits.copy("mine", "creatures", "animals:wolf", "dog") == "", "a copy to give a picture")
	read_all.call()
	_check(edits.picture("mine", "creatures", "mine:dog", "sprite", "no png".to_utf8_buffer()) != ""
		and edits.picture("mine", "creatures", "mine:dog", "mass", png) != "", "no PNG, or a field of no picture, is refused")
	_check(edits.picture("mine", "creatures", "mine:dog", "sprite", png) == ""
		and FileAccess.file_exists(DIR.path_join("mine/sprites/creatures/dog.png"))
		and OwnMods.records("mine", "creatures")[0].sprite == "dog", "one's own record's picture by its name")
	_check(edits.picture("mine", "creatures", "animals:wolf", "sprite", png) == ""
		and OwnMods.records("mine", "creatures")[1] == {"id": "animals:wolf", "patch": true, "sprite": "mine:animals_wolf"},
		"another mod's record's picture by a patch")
	read_all.call()
	for id: String in ["mine:dog", "animals:wolf"]:
		var at := ContentEdits.picture_path("creatures", Content.find("creatures", id), "sprite")
		var got := Content.picture(at)
		_check(got != null and got.get_width() == 5, "the game finds the picture of %s at %s" % [id, at])
	_check(Content.asset({"bundle": "x"}, "sprites/creatures/..:y.png").begins_with(Content.ROOT + "/x/"),
		"a mod's name that is no name takes no other folder")
	_check(edits.undo() == "" and not FileAccess.file_exists(DIR.path_join("mine/sprites/creatures/animals_wolf.png"))
		and OwnMods.records("mine", "creatures").size() == 1, "a picture is taken back with its field")
	_remove(DIR)
	ModFiles.extra_dir = ""
	Content.BUNDLES = bundles.duplicate()
	Content.refresh()
	Mods.activate(bundles)


## The voxel editor's sheet: painting, leaves, fill, levels added, copied and taken out, a
## slice made narrower round its middle or its corner, undo; its PNG is the model the game
## reads; a stroke on the grid is taken back at once; the model written into one's own mod.
func _test_voxels() -> void:
	var s: VoxelSheet = VoxelSheet.of(null)
	_check(s.side == 16 and s.levels == 1 and s.count() == 0, "an empty sheet: one level 16 across")
	var red := Color(0.8, 0.1, 0.1)
	s.remember()
	_check(s.put(3, 0, 4, VoxelSheet.ink(red, false)) and s.at(3, 0, 4).is_equal_approx(VoxelSheet.exact(red))
		and not s.leaf(3, 0, 4), "a voxel painted")
	_check(s.put(5, 0, 5, VoxelSheet.ink(red, true)) and s.leaf(5, 0, 5), "a leaf painted")
	_check(not s.put(30, 0, 0, Color.RED), "nothing painted outside")
	_check(s.add_level(0, true) and s.levels == 2 and s.at(3, 1, 4) == s.at(3, 0, 4) and s.count() == 4,
		"a level copied up")
	_check(s.add_level(1, false) and s.levels == 3 and s.count() == 4, "an empty level added")
	_check(s.fill(0, 2, 0, Color.BLUE) and s.count() == 4 + 256, "a fill covers the empty level")
	_check(s.remove_level(2) and s.levels == 2 and s.count() == 4, "a level taken out")
	var m = s.model()
	_check(m.voxels.size() == 4 and m.foliage.size() == 2 and m.voxels.has(Vector3i(3 - 8, 1, 4 - 8)),
		"the sheet is the model the game reads, centred")
	var back: VoxelSheet = VoxelSheet.of(Image.create_from_data(s.img.get_width(), s.img.get_height(), false,
		Image.FORMAT_RGBA8, s.img.get_data()))
	_check(back.levels == 2 and back.side == 16 and back.count() == 4, "a sheet read from its picture")
	_check(s.resize(8) and s.side == 8 and s.at(3 - 4, 0, 4 - 4).a == 0.0 and s.at(5 - 4, 0, 5 - 4).a > 0.0,
		"a centred slice made narrower keeps its middle")
	var corner: VoxelSheet = VoxelSheet.of(null, false)
	corner.put(0, 0, 0, Color.RED)
	corner.put(15, 0, 15, Color.RED)
	_check(corner.resize(8) and corner.at(0, 0, 0).a > 0.0 and corner.count() == 1,
		"a placed thing's slice keeps its corner")
	var steps := 0
	while s.undo():
		steps += 1
	_check(s.side == 16 and s.levels == 1 and s.count() == 0 and steps == 5, "every change taken back (%d)" % steps)
	var pike := Content.picture("res://content/animals/fish/models/pike.png")
	var p: VoxelSheet = VoxelSheet.of(pike)
	_check(p.side == pike.get_height() and p.levels == pike.get_width() / pike.get_height()
		and p.png().size() > 0 and not p.colours().is_empty(), "a model of the game opened as it is")
	var grid := SliceGrid.new()
	grid.sheet = p
	grid.size = Vector2(160, 160)
	grid.color = Color.YELLOW
	var was := p.count()
	grid.use(Vector2i(0, 0), true)
	grid.use(Vector2i(1, 0), false)
	grid.use(Vector2i(2, 0), false)
	_check(p.history.size() == 1 and p.undo() and p.count() == was, "a stroke is one step back")
	grid.tool = SliceGrid.Tool.TAKE
	grid.use(Vector2i(0, 0), true)
	grid.free()
	# The model written into one's own mod, for its own record and as a patch of another's.
	var bundles: Array = Mods.all()
	if DirAccess.dir_exists_absolute(DIR):
		_remove(DIR)
	ModFiles.extra_dir = DIR
	OwnMods.make("mine")
	var read_all := func() -> void:
		Content.BUNDLES = Mods.all()
		Content.refresh()
		Mods.activate(Mods.all())
	read_all.call()
	var item := ""
	for r: Dictionary in Content.records("items"):
		if str(r.get("model", "")) != "":
			item = r.id
			break
	var edits := ContentEdits.new()
	_check(item != "" and edits.picture("mine", "items", item, "model", p.png()) == "", "a model written for %s" % item)
	read_all.call()
	var at := ContentEdits.picture_path("items", Content.find("items", item), "model")
	var got := Content.picture(at)
	_check(at.contains("/mine/") and got != null and got.get_width() == p.img.get_width(), "the game finds the model at %s" % at)
	_remove(DIR)
	ModFiles.extra_dir = ""
	Content.BUNDLES = bundles.duplicate()
	Content.refresh()
	Mods.activate(bundles)


## One's own mod packed into a zip (`<mod>/…`) and taken in again, still one's own; a zip
## never writes over a mod that is not.
func _test_zips() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		_remove(DIR)
	ModFiles.extra_dir = DIR
	OwnMods.make("mine", "Mine")
	_check(OwnMods.put("mine", "items", {"id": "pebble", "title": "[mine.items.pebble]", "weight": 0.1, "stack": 10}) == "",
		"a record to pack")
	var bytes := ModZip.pack(OwnMods.root().path_join("mine"))
	var sizes := ModZip.sizes_of(bytes)
	_check(sizes.has("mine/mod.yaml") and sizes.has("mine/data/items.yaml") and sizes.has("mine/lang/en.yaml"),
		"the zip holds the mod under its name: %s" % [sizes.keys()])
	_remove(DIR)
	ModFiles.extra_dir = DIR
	var got := ModZip.unpack_bytes(bytes, "whatever.zip", OwnMods.root(), ["core"])
	_check(got.error == "" and got.files == sizes.size() and got.mods == ["mine"] and "mine" in OwnMods.list()
		and OwnMods.records("mine", "items")[0].id == "pebble", "the zip taken in is one's own mod again")
	var zip := ZIPPacker.new()
	zip.open(DIR.path_join("bad.zip"))
	for name: String in ["core/mod.yaml", "other/mod.yaml"]:
		zip.start_file(name)
		zip.write_file("id: x\n".to_utf8_buffer())
		zip.close_file()
	zip.close()
	got = ModZip.unpack_bytes(FileAccess.get_file_as_bytes(DIR.path_join("bad.zip")), "bad.zip", OwnMods.root(), ["core"])
	_check(got.files == 1 and got.skipped == 1 and not FileAccess.file_exists(DIR.path_join("core/mod.yaml")),
		"a zip writes nothing over a mod that is not one's own")
	_remove(DIR)
	ModFiles.extra_dir = ""


## A host's own mod put on a server (Protocol.MOD_PUT, Server.put_mod): it takes the
## place of what the server had of it (a file gone from the zip is gone there too), its
## bundle joins the world's, and the files the players are given change.
func _test_server_put() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		_remove(DIR)
	ModFiles.extra_dir = DIR
	var bundles: Array = Mods.all()
	var world: Array = bundles.duplicate()
	OwnMods.make("mine", "Mine")
	OwnMods.put("mine", "items", {"id": "pebble", "title": "[mine.items.pebble]", "weight": 0.1, "stack": 10})
	var bytes := ModZip.pack(OwnMods.root().path_join("mine"))
	_remove(DIR)
	ModFiles.extra_dir = DIR
	OwnMods.make("mine", "Mine")
	var stale := FileAccess.open(DIR.path_join("mine/data/old.yaml"), FileAccess.WRITE)
	stale.store_string("[]\n")
	stale.close()
	ModFiles.read_extra()
	Content.refresh()
	var net := Server.new(null, Config.new(), {"mods": world})
	net.content.ready()
	var digest: String = net.content.digest
	net.access.authors[Server.kept("author")] = "Author"
	var got := net.put_mod("mine", bytes, "author")
	_check(got.error == "" and got.files == 3 and not FileAccess.file_exists(DIR.path_join("mine/data/old.yaml"))
		and OwnMods.records("mine", "items")[0].id == "pebble", "the mod takes the place of the server's copy: %s" % [got])
	_check("mine" in world and Items.has("mine:pebble") and net.content.digest != digest and net.content.list.has("mine/data/items.yaml"),
		"its bundle joins the world's (%s) and its files are given to the players" % [world.filter(func(b: String) -> bool: return b.begins_with("mine"))])
	_remove(DIR)
	ModFiles.extra_dir = ""
	Content.BUNDLES = bundles.duplicate()
	Content.refresh()
	Mods.activate(bundles)
