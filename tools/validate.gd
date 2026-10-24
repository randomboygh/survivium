extends SceneTree
## Checks the content files of every mod and fails on any problem, for CI and for a
## quick check after editing data:
## godot --headless --path . --script res://tools/validate.gd

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Items := preload("res://src/shared/content/items.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Figure := preload("res://src/client/view/figure.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const Creatures := preload("res://src/client/game/creatures.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")


func _init() -> void:
	var problems := Content.problems.duplicate()
	problems.append_array(Mat.check())
	problems.append_array(AiRules.check())
	problems.append_array(Trees.check())
	problems.append_array(Bushes.check())
	problems.append_array(Items.check())
	problems.append_array(Crafting.check())
	problems.append_array(Plants.check())
	problems.append_array(_check_held())
	problems.append_array(_check_creature_pictures())
	problems.append_array(_check_models())
	problems.append_array(_check_sound_files())
	problems.append_array(_check_each_mod())
	for p in problems:
		printerr("content: " + p)
	if problems.is_empty():
		print("content OK: %d materials, %d items, %d creatures, %d trees, %d bushes, %d recipes, %d plants" % [
			Mat.COUNT, Items.IDS.size(), AiRules.SPECIES.size(), Trees.SPECIES.size(), Bushes.TYPES.size(),
			Crafting.RECIPES.size(), Plants.BY_ID.size()])
	else:
		printerr("%d content problems" % problems.size())
	quit(1 if problems.size() > 0 else 0)


## Every mod loads clean with only the mods it requires, so a world made without the
## others still works (and the engine finds what it needs).
func _check_each_mod() -> PackedStringArray:
	var out: PackedStringArray = []
	var all := Mods.available()
	for mod in all:
		var set := Mods.closure(mod, all)
		var problems := Mods.activate(set)
		problems.append_array(Mat.check())
		problems.append_array(AiRules.check())
		problems.append_array(Trees.check())
		problems.append_array(Bushes.check())
		problems.append_array(Items.check())
		problems.append_array(Crafting.check())
		problems.append_array(Plants.check())
		for p in problems:
			out.append("with mods %s only: %s" % [", ".join(set), p])
	Mods.activate(all)
	return out


## Every sound has its files, as many as its variants (see Content.sound_files).
func _check_sound_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for rec: Dictionary in Content.records("sounds"):
		for path in Content.sound_files(rec):
			if not ResourceLoader.exists(path):
				out.append("sounds: `%s`: no file %s" % [rec.id, path])
	return out


## Things held: the work each item names is one of the figure's (player.yaml `works`)
## and takes as many hands as the item says; its picture in hand is there, a frame
## wide for carrying plus one for each frame of its work.
func _check_held() -> PackedStringArray:
	var out: PackedStringArray = []
	var fig := Figure.data()
	for id in Items.IDS:
		var item := Items.get_item(id)
		if not fig.works.has(item.anim):
			out.append("items: `%s`: the player has no work `%s`" % [id, item.anim])
			continue
		var work: Dictionary = fig.works[item.anim]
		if work.hands != item.hands:
			out.append("items: `%s`: `%s` takes %d hands, not %d" % [id, item.anim, work.hands, item.hands])
		if item.sprite == "":
			continue
		var path := "res://content/%s/sprites/held/%s.png" % [item.mod, item.sprite]
		if not ResourceLoader.exists(path):
			out.append("items: `%s`: no picture %s" % [id, path])
			continue
		var size: Vector2i = load(path).get_size()
		var want := Vector2i(fig.held.cell[0] * (1 + work.columns.size()), fig.held.cell[1] * fig.directions.size())
		if size != want:
			out.append("items: `%s`: %s is %dx%d, a sheet carried and worked by `%s` is %dx%d" % [id, path.get_file(), size.x, size.y, item.anim, want.x, want.y])
	return out


## Each item's model is there, in its mod, a row of square slices (see VoxelModel.from_image);
## a thing placed on cells has one.
func _check_models() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in Items.IDS:
		var item := Items.get_item(id)
		var name: String = item.get("model", "")
		if name == "":
			if item.get("prop", "none") in ["chest", "workbench", "kiln"]:
				out.append("items: `%s`: a thing placed on cells needs a `model`" % id)
			continue
		var path := VoxelProps.model_path(item.mod, name)
		if not ResourceLoader.exists(path):
			out.append("items: `%s`: no model %s" % [id, path])
			continue
		var size: Vector2i = load(path).get_size()
		if size.y == 0 or size.x % size.y != 0:
			out.append("items: `%s`: %s is %dx%d, not a row of square slices" % [id, path.get_file(), size.x, size.y])
	return out


## Each species' picture is there, a row of as many frames as it says.
func _check_creature_pictures() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in AiRules.SPECIES:
		var spec: Dictionary = AiRules.SPECIES[id]
		if id == AiRules.HUMAN:
			continue
		var path := Creatures.picture_path(spec)
		if not ResourceLoader.exists(path):
			out.append("creatures: `%s`: no picture %s" % [id, path])
		elif load(path).get_width() % spec.frames != 0:
			out.append("creatures: `%s`: %s is not %d frames wide" % [id, path.get_file(), spec.frames])
	return out
