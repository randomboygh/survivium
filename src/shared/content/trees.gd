extends RefCounted
## Tree species: what a tree looks like is data here, where it grows is up to the world
## generator (per biome). A species gives the shape of the trunk and crown, the leaves
## (broad leaves or needles), the tints of its trees and what it does in winter.
## This is the registry; growing a tree into the world is Growth's
## (src/shared/world/growth.gd), felling one Felling's (src/shared/game/felling.gd).

const Mat := preload("res://src/shared/content/materials.gd")
const Content := preload("res://src/shared/content/content.gd")

## Leaves of a species.
const BROAD := 0
const NEEDLES := 1

## Shapes of a crown (`shape` in trees.yaml): a low ellipsoid; a few round lobes round the
## trunk's top with dark gaps between them; a narrow crown tapering to a point; an
## ellipsoid whose rim hangs down in a curtain; a flat crown of a few wide lobes high on a
## bare trunk; a cone of tiers (spruce); a tuft of long fronds arching out and down from
## the top of a tall bare trunk (palm). A conifer is a cone unless it says otherwise.
const SHAPES := ["round", "lobed", "column", "weeping", "umbrella", "cone", "palm"]
## How a species' leaf clusters are drawn (`leaf`, see PixelTextures.build_clumps):
## pointed leaves, soft oval ones, round curly lumps, broad rounded leaves lying like scales, needles.
const LEAF_STYLES := ["pointed", "soft", "curly", "scales", "needles"]

## Where a species grows is the biomes' say (Biomes: a biome's `trees` shares), not the
## tree's: the generator asks the biome of a column for a tree, never for a species by name.

## Index -> record from `content/*/data/trees.yaml` (see Content): id, title,
## leaves (BROAD or NEEDLES), trunk [min, max], crown [3 radii], tints (Colors),
## bare (share of trees that drop their leaves in winter), seed (the item a felled
## tree drops besides logs and branches, "" none), bark (the texture of its trunk,
## textures/<bark>.png of its bundle like a material's, "" the log's own). What each means is in the data file; a tree is noted in WorldData.trees by its species index.
static var SPECIES: Array = []


static func _static_init() -> void:
	refresh()


## Most species that blossom (each its own colour, see `blossom` in trees.yaml): the leaf
## shader keeps a colour for each.
const BLOSSOMS := 7


static func refresh() -> void:
	SPECIES = []
	var blossoms := 0
	for r in Content.records("trees"):
		var s: Dictionary = r.duplicate()
		s.leaves = NEEDLES if r.leaves == "needles" else BROAD
		if s.shape == "":
			s.shape = "cone" if s.leaves == NEEDLES else "round"
		if s.leaf == "":
			s.leaf = "needles" if s.leaves == NEEDLES else "pointed"
		s.tiers = s.shape == "cone"
		# The slot of its blossom colour, from 1; 0 for none.
		s.blossom_slot = 0
		if s.blossom != null and blossoms < BLOSSOMS:
			blossoms += 1
			s.blossom_slot = blossoms
		SPECIES.append(s)


## The path of the bark texture of species `i`, "" when it has the log's.
static func bark_path(i: int) -> String:
	var s: Dictionary = SPECIES[i]
	return "" if s.bark == "" else Content.asset(s, "textures/%s.png" % s.bark)


## Index of the species with `id`, or -1.
static func index(id: String) -> int:
	for i in SPECIES.size():
		if SPECIES[i].id == id:
			return i
	return -1


## Any loaded species for the roll `roll` (0..1), each as likely; -1 when none is loaded.
static func any(roll: float) -> int:
	if SPECIES.is_empty():
		return -1
	return mini(int(roll * SPECIES.size()), SPECIES.size() - 1)


## The commonest species with `leaves` (BROAD or NEEDLES; -1 any): the one the loaded
## biomes give the largest share together (ties and species no biome names: by load
## order), or -1. What the test world, the shots and the tests plant where the plan says an
## oak or a spruce, whatever the mods call them.
static func first(leaves := -1) -> int:
	return commonest(SPECIES, "trees", func(s: Dictionary) -> bool: return leaves < 0 or s.leaves == leaves)


## The index in `list` (records with ids) of the record `fits` takes that the loaded biomes
## give the largest share of in their `field` (`trees` or `bushes`), ties and records no
## biome names by load order; -1 when none fits.
static func commonest(list: Array, field: String, fits: Callable) -> int:
	var shares := {}
	for b in Content.records("biomes"):
		for id in b.get(field, {}):
			shares[id] = shares.get(id, 0.0) + b[field][id]
	var best := -1
	for i in list.size():
		if fits.call(list[i]) and (best < 0 or shares.get(list[i].id, 0.0) > shares.get(list[best].id, 0.0)):
			best = i
	return best


## What is wrong with the loaded trees for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	if not SPECIES.is_empty() and (Mat.LOG < 0 or Mat.LEAVES < 0):
		out.append("trees: a tree needs materials of the roles `trunk` and `crown` (materials.yaml `role`)")
	for s in SPECIES:
		if s.trunk[0] > s.trunk[1]:
			out.append("trees: `%s`: trunk [min, max] has min above max" % s.id)
		if s.girth[0] > s.girth[1] or s.roots[0] > s.roots[1]:
			out.append("trees: `%s`: girth and roots [min, max] need min not above max" % s.id)
		if s.blossom != null and s.blossom_slot == 0:
			out.append("trees: `%s`: more than %d species blossom, its blossom is not drawn" % [s.id, BLOSSOMS])
		if s.tiers and s.crown[1] > s.crown[2]:
			out.append("trees: `%s`: crown [radius, min tiers, max tiers] has min above max" % s.id)
		if s.shape == "palm" and (s.crown[1] > s.crown[2] or s.crown[1] < 1.0):
			out.append("trees: `%s`: crown [frond length, min fronds, max fronds] needs 1 to max fronds" % s.id)
	return out
