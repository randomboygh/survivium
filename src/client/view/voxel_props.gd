extends RefCounted
## The voxel models of things: read from `content/<mod>/models/<model>.png` (an item's
## `model`, see VoxelModel.from_image), drawn once by `tools/art/voxel_art.gd` and
## written by `tools/make_models.gd`, so a mod paints its own. Here only what the engine
## makes itself: a clod of a block's colour, the sack a death leaves and the bundle of a
## thing without a model (the boxes a placed thing takes are Placed.footprint's).

const Content := preload("res://src/shared/content/content.gd")
const VoxelModel := preload("res://src/client/view/voxel_model.gd")
const Items := preload("res://src/shared/content/items.gd")
const RES := VoxelModel.RES

## Models read, by their file.
static var _read := {}


## The model of a thing placed on two by two cells by its item's `prop` (16 voxels a
## world unit, the front to the south, the file's pixels as voxel columns), a plain
## crate for a prop without a model file.
static func prop(kind: String) -> VoxelModel:
	var m := of_item(Items.get_item(Items.with_prop(kind)), false)
	return m if m != null else crate()


## The model of item `item` lying on the ground, centred on the origin (see
## WorldData.drops), null without a model file.
static func drop(item: Dictionary) -> VoxelModel:
	return of_item(item, true)


## The model of `item`'s `model` from its mod's `models/` folder, null for none.
static func of_item(item: Dictionary, centred: bool) -> VoxelModel:
	var name: String = item.get("model", "")
	if name == "":
		return null
	var path := model_path(item, name)
	if not _read.has(path):
		_read[path] = VoxelModel.from_image(load(path).get_image(), centred) if ResourceLoader.exists(path) else null
	return _read[path]


## Where item `item` keeps model `name`: in its bundle (see Content.asset).
static func model_path(item: Dictionary, name: String) -> String:
	return Content.asset(item, "models/%s.png" % name)


## Forgets the models read, for a reload of the mods.
static func forget() -> void:
	_read = {}


## A plain crate on the four cells, for a placed thing without a model.
static func crate() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.55, 0.4, 0.24)
	for y in 8:
		for z in range(1, 15):
			for x in range(1, 15):
				if x == 1 or x == 14 or z == 1 or z == 14 or y == 0 or y == 7:
					m.set_voxel(Vector3i(x, y, z), wood * (0.85 if (x + y + z) % 5 == 0 else 1.0))
	return m


## A clod of a dug block, four voxels a side, of colour `c`.
static func block(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for y in 4:
		for z in range(-2, 2):
			for x in range(-2, 2):
				m.set_voxel(Vector3i(x, y, z), c * (1.12 if y == 3 else (0.9 if (x + z) % 2 == 0 else 1.0)))
	return m


## A tied cloth sack, a little taller than wide.
static func sack() -> VoxelModel:
	var m := VoxelModel.new()
	var cloth := Color(0.62, 0.52, 0.36)
	var rope := Color(0.36, 0.26, 0.16)
	for y in range(0, 8):
		var r := 4 if y < 5 else (3 if y < 6 else 1)
		for z in range(-r, r):
			for x in range(-r, r):
				if (x == -r or x == r - 1) and (z == -r or z == r - 1):
					continue
				var c := cloth * (0.88 if (x + y * 2 + z) % 4 == 0 else 1.0)
				m.set_voxel(Vector3i(x, y, z), rope if y == 6 else c)
	m.set_voxel(Vector3i(0, 8, 0), rope)
	m.set_voxel(Vector3i(-1, 8, -1), rope)
	return m


## A small bundle of cloth for things without a model of their own.
static func bundle() -> VoxelModel:
	var m := VoxelModel.new()
	var cloth := Color(0.55, 0.47, 0.34)
	for y in range(0, 3):
		for z in range(-2, 2):
			for x in range(-3, 3):
				if y == 2 and (x == -3 or x == 2):
					continue
				m.set_voxel(Vector3i(x, y, z), cloth * (0.85 if (x + z) % 3 == 0 else 1.0))
	return m
