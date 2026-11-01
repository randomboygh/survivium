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

## Where a bush grows is the biomes' say (Biomes: a biome's `bushes` shares), not the
## bush's: the generator asks the biome of a column for a bush, never for a type by name.

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


## Index of the type with `id`, or -1.
static func index(id: String) -> int:
	for i in TYPES.size():
		if TYPES[i].id == id:
			return i
	return -1


## The commonest type with berries (`berries` true) or without, skipping `skip` such
## types, or -1: the ones the loaded biomes give the largest share together first (see
## Trees.commonest). What the test world, the shots and the tests plant where the plan
## says a raspberry, a blueberry or a plain shrub, whatever the mods call them.
static func first(berries: bool, skip := 0) -> int:
	var taken := {}
	var found := -1
	for k in skip + 1:
		found = Trees.commonest(TYPES, "bushes", func(b: Dictionary) -> bool:
			return (b.berries != Color.BLACK) == berries and not taken.has(b.id))
		if found < 0:
			return -1
		taken[TYPES[found].id] = true
	return found


## What is wrong with the loaded bushes for the engine, if anything.
static func check() -> PackedStringArray:
	return []


## True when a bush can stand in cell x, y, z: air on level grass.
static func fits(w, x: int, y: int, z: int) -> bool:
	return y > 0 and y < w.size_y and w.get_cell(x, y - 1, z) == Mat.GRASS and w.get_cell(x, y, z) == Mat.AIR \
		and w.slope_mask(x, y - 1, z) == w.FULL


## Grows a bush of `type` in cell x, y, z (the first cell above the ground).
static func place(w, x: int, y: int, z: int, type: int) -> void:
	w.add_bush(Vector3i(x, y, z), type)

