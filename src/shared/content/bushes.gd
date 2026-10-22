extends RefCounted
## Bush types: what a bush looks like is data here, where it grows is up to the world
## generator (per biome). A bush stands in one air cell on grass and is noted in
## WorldData.bushes by that cell; the client draws it as a few leaf clusters (see
## Foliage.bushes), some of them with berries that ripen in summer.

const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Content := preload("res://src/shared/content/content.gd")

## Share of the berries ripe on bushes in each season, spring to winter: what picking
## gives and what the client draws.
const BERRY_AMOUNT := [0.0, 1.0, 0.55, 0.0]

## Types the engine refers to; the validator demands them.
const KNOWN := {"SHRUB": "core:shrub", "RASPBERRY": "core:raspberry", "BLUEBERRY": "core:blueberry"}

static var SHRUB := 0
static var RASPBERRY := 0
static var BLUEBERRY := 0

## Index -> record from `content/*/data/bushes.yaml` (see Content): id, title, tint
## (Color), berries (Color, black for none), berry_cards, cards, rise, spread
## (Vector3), small. What each means is in the data file; a bush is noted in
## WorldData.bushes by its type index.
static var TYPES: Array = []


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	TYPES = []
	for r in Content.records("bushes"):
		var b: Dictionary = r.duplicate()
		if b.berries == null:
			b.berries = Color.BLACK
		TYPES.append(b)
	SHRUB = index(KNOWN.SHRUB)
	RASPBERRY = index(KNOWN.RASPBERRY)
	BLUEBERRY = index(KNOWN.BLUEBERRY)


## Index of the type with `id`, or -1.
static func index(id: String) -> int:
	for i in TYPES.size():
		if TYPES[i].id == id:
			return i
	return -1


## What is wrong with the loaded bushes for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for name in KNOWN:
		if index(KNOWN[name]) < 0:
			out.append("bushes: the engine needs `%s`" % KNOWN[name])
	return out


## True when a bush can stand in cell x, y, z: air on level grass.
static func fits(w, x: int, y: int, z: int) -> bool:
	return y > 0 and y < w.size_y and w.get_cell(x, y - 1, z) == Mat.GRASS and w.get_cell(x, y, z) == Mat.AIR \
		and w.slope_mask(x, y - 1, z) == w.FULL


## Grows a bush of `type` in cell x, y, z (the first cell above the ground).
static func place(w, x: int, y: int, z: int, type: int) -> void:
	w.add_bush(Vector3i(x, y, z), type)


## Species of a tree within `reach` cells of column x, z, -1 for none. Trunks stand on
## odd columns.
static func tree_near(w, x: int, z: int, reach: int) -> int:
	for tz in range((z - reach) | 1, z + reach + 1, 2):
		for tx in range((x - reach) | 1, x + reach + 1, 2):
			var at := Vector2i(tx, tz)
			if w.trees.has(at):
				return w.trees[at]
	return -1
