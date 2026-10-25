extends SceneTree
## Checks the content files of every mod and fails on any problem, for CI and for a
## quick check after editing data:
## godot --headless --path . --script res://tools/validate.gd

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const Items := preload("res://src/shared/content/items.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Figure := preload("res://src/client/view/figure.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const Creatures := preload("res://src/client/game/creatures.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")


func _init() -> void:
	# The full set, strictly: a soft reference to nothing is a mistake too.
	Content.strict = true
	# A copy of its own (see Mods.activate): the loader makes a new list with every set.
	var problems := Mods.rescan()
	for b in Content.dropped:
		problems.append("%s: left out, needs `%s`" % [b, Content.dropped[b]])
	problems.append_array(Mat.check())
	problems.append_array(AiRules.check())
	problems.append_array(Trees.check())
	problems.append_array(Bushes.check())
	problems.append_array(Biomes.check())
	problems.append_array(Items.check())
	problems.append_array(Crafting.check())
	problems.append_array(Plants.check())
	problems.append_array(_check_held())
	problems.append_array(_check_creature_pictures())
	problems.append_array(_check_models())
	problems.append_array(_check_icons())
	problems.append_array(_check_sound_files())
	problems.append_array(_check_textures())
	Content.strict = false
	problems.append_array(_check_each_bundle())
	for p in problems:
		printerr("content: " + p)
	if problems.is_empty():
		print("content OK: %d materials, %d items, %d creatures, %d trees, %d bushes, %d recipes, %d plants" % [
			Mat.COUNT, Items.IDS.size(), AiRules.SPECIES.size(), Trees.SPECIES.size(), Bushes.TYPES.size(),
			Crafting.RECIPES.size(), Plants.BY_ID.size()])
	else:
		printerr("%d content problems" % problems.size())
	quit(1 if problems.size() > 0 else 0)


## Every bundle loads clean with only what it cannot do without, so a world made
## without the others still works (and the engine finds what it needs).
func _check_each_bundle() -> PackedStringArray:
	var out: PackedStringArray = []
	var all := Mods.all()
	for bundle in all:
		var set := Mods.closure(bundle, all)
		var problems := Mods.activate(set)
		if not Content.dropped.is_empty():
			problems.append("left out: %s" % [Content.dropped])
		problems.append_array(Mat.check())
		problems.append_array(AiRules.check())
		problems.append_array(Trees.check())
		problems.append_array(Bushes.check())
		problems.append_array(Biomes.check())
		problems.append_array(Items.check())
		problems.append_array(Crafting.check(false))
		problems.append_array(Plants.check())
		for p in problems:
			out.append("with %s only: %s" % [", ".join(set), p])
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
		var path := Content.asset(item, "sprites/held/%s.png" % item.sprite)
		if not ResourceLoader.exists(path):
			out.append("items: `%s`: no picture %s" % [id, path])
			continue
		var size: Vector2i = load(path).get_size()
		var want := Vector2i(fig.held.cell[0] * (1 + work.columns.size()), fig.held.cell[1] * fig.directions.size())
		if size != want:
			out.append("items: `%s`: %s is %dx%d, a sheet carried and worked by `%s` is %dx%d" % [id, path.get_file(), size.x, size.y, item.anim, want.x, want.y])
	return out


## Each item's picture is there, in its bundle, square; the interface's pictures are in assets/ui.
func _check_icons() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in Items.IDS:
		var item := Items.get_item(id)
		if item.icon == "":
			continue
		var path := ItemIcons.icon_path(item)
		if not ResourceLoader.exists(path):
			out.append("items: `%s`: no picture %s" % [id, path])
		elif Vector2i(load(path).get_size()) != Vector2i(12, 12):
			out.append("items: `%s`: %s is not 12x12" % [id, path.get_file()])
	for name in ItemIcons.UI:
		if not ResourceLoader.exists(ItemIcons.ui_path(name)):
			out.append("ui: no picture %s" % ItemIcons.ui_path(name))
	return out


## Every material but air has its texture in its bundle, three tiles side by side (see
## Mat.texture_path), and the roles the loaded trees need are given.
func _check_textures() -> PackedStringArray:
	var out: PackedStringArray = []
	for m in range(1, Mat.COUNT):
		var path := Mat.texture_path(m)
		if not ResourceLoader.exists(path):
			out.append("materials: `%s`: no texture %s" % [Mat.IDS[m], path])
		elif Vector2i(load(path).get_size()) != Vector2i(PixelTextures.TILE * 3, PixelTextures.TILE):
			out.append("materials: `%s`: %s is not three tiles of %d px in a row" % [Mat.IDS[m], path.get_file(), PixelTextures.TILE])
	# A tree's own bark is a texture like a material's; a custom plant's picture is a
	# row of frames of the plant size.
	for i in Trees.SPECIES.size():
		var path := Trees.bark_path(i)
		if path == "":
			continue
		if not ResourceLoader.exists(path):
			out.append("trees: `%s`: no bark texture %s" % [Trees.SPECIES[i].id, path])
		elif Vector2i(load(path).get_size()) != Vector2i(PixelTextures.TILE * 3, PixelTextures.TILE):
			out.append("trees: `%s`: %s is not three tiles of %d px in a row" % [Trees.SPECIES[i].id, path.get_file(), PixelTextures.TILE])
	var barks := 0
	for i in Trees.SPECIES.size():
		if Trees.bark_path(i) != "":
			barks += 1
	if Mat.COUNT + barks > PixelTextures.MOST_MATERIALS:
		out.append("materials: %d materials and %d barks, the atlas holds %d together" % [Mat.COUNT, barks, PixelTextures.MOST_MATERIALS])
	for c in Plants.CUSTOM:
		var path := Plants.sprite_path(c)
		if not ResourceLoader.exists(path):
			out.append("plants: `%s`: no picture %s" % [c.id, path])
		elif Vector2i(load(path).get_size()) != Vector2i(PixelTextures.PLANT_W * c.frames, PixelTextures.PLANT_H):
			out.append("plants: `%s`: %s is not %d frames of %dx%d px" % [c.id, path.get_file(), c.frames, PixelTextures.PLANT_W, PixelTextures.PLANT_H])
	return out


## Each item's model is there, in its bundle, a row of square slices (see VoxelModel.from_image);
## a thing placed on cells has one.
func _check_models() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in Items.IDS:
		var item := Items.get_item(id)
		var name: String = item.get("model", "")
		if name == "":
			if item.get("prop", "none") in ["chest", "workbench", "kiln", "forge"]:
				out.append("items: `%s`: a thing placed on cells needs a `model`" % id)
			continue
		var path := VoxelProps.model_path(item, name)
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
