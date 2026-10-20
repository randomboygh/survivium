extends RefCounted
## Bush types: what a bush looks like is data here, where it grows is up to the world
## generator (per biome). A bush stands in one air cell on grass and is noted in
## WorldData.bushes by that cell; the client draws it as a few leaf clusters (see
## Foliage.bushes), some of them with berries that ripen in summer.

const Mat := preload("res://src/shared/materials.gd")
const Trees := preload("res://src/shared/trees.gd")

const SHRUB := 0
const RASPBERRY := 1
const BLUEBERRY := 2

## name: id for content files; title: shown to players. tint: leaf colour. berries:
## colour of ripe berries, black for none; berry_cards: share of the clusters that
## carry them. cards: leaf clusters per bush; rise: height of their middle above the
## ground in world units; spread: how far they reach out across x and z, and up;
## small: smaller bunches of leaves (a low, fine-leaved bush).
const TYPES := [
	{
		"name": "shrub", "title": "Куст", "tint": Color(0.2, 0.33, 0.17),
		"berries": Color(0, 0, 0), "berry_cards": 0.0,
		"cards": 6, "rise": 0.3, "spread": Vector3(0.22, 0.15, 0.15), "small": false,
	},
	{
		"name": "raspberry", "title": "Малина", "tint": Color(0.23, 0.36, 0.15),
		"berries": Color(0.78, 0.13, 0.2), "berry_cards": 0.5,
		"cards": 9, "rise": 0.38, "spread": Vector3(0.26, 0.4, 0.16), "small": false,
	},
	{
		"name": "blueberry", "title": "Черника", "tint": Color(0.19, 0.33, 0.21),
		"berries": Color(0.2, 0.24, 0.52), "berry_cards": 0.6,
		"cards": 8, "rise": 0.16, "spread": Vector3(0.28, 0.08, 0.2), "small": true,
	},
]


## True when a bush can stand in cell x, y, z: air on level grass.
static func fits(w, x: int, y: int, z: int) -> bool:
	return y > 0 and y < w.size_y and w.get_cell(x, y - 1, z) == Mat.GRASS and w.get_cell(x, y, z) == Mat.AIR \
		and w.slope_mask(x, y - 1, z) == w.FULL


## Grows a bush of `type` in cell x, y, z (the first cell above the ground).
static func place(w, x: int, y: int, z: int, type: int) -> void:
	w.bushes[Vector3i(x, y, z)] = type


## A plain scattering until the world generator places bushes per biome: about one
## try per 160 cells of the map, blueberries near spruces, raspberries near oaks and in
## the open, plain shrubs among them.
static func scatter(w, world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for i in w.size_x * w.size_z / 160:
		var x := rng.randi_range(1, w.size_x - 2)
		var z := rng.randi_range(1, w.size_z - 2)
		var y: int = w.surface_y(x, z)
		if not fits(w, x, y, z):
			continue
		var near := _tree_near(w, x, z, 10)
		var roll := rng.randf()
		var type := SHRUB
		if near == Trees.SPRUCE:
			type = BLUEBERRY if roll < 0.7 else SHRUB
		elif roll < (0.5 if near == Trees.OAK else 0.35):
			type = RASPBERRY
		place(w, x, y, z, type)


## Species of a tree within `reach` cells of column x, z, -1 for none. Trunks stand on
## odd columns.
static func _tree_near(w, x: int, z: int, reach: int) -> int:
	for tz in range((z - reach) | 1, z + reach + 1, 2):
		for tx in range((x - reach) | 1, x + reach + 1, 2):
			var at := Vector2i(tx, tz)
			if w.trees.has(at):
				return w.trees[at]
	return -1
