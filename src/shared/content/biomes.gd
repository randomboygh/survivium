extends RefCounted
## Biomes from `content/*/data/biomes.yaml` (see Content): where a biome lies and what grows
## there. The layout decides a column's relief itself (the sea, a beach, bare rock, a
## plateau, a swamp) and takes the record of that `where` for it; the rest of the land
## goes by climate: the climate biome whose `warmth` and `moisture` windows hold the
## column's, the most specific (the smallest window) first, the first loaded on a tie.
## No record fits: the column is NONE, bare grass with nothing growing. A biome's `trees`
## and `bushes` are shares of the loaded species (soft: a species of a bundle left out is
## dropped and its share grows nothing).

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")

## The biome byte of a column no record fits.
const NONE := 255

## Index -> record, in load order; the `trees` and `bushes` shares are rewritten as
## [[species index, share], ...] in `tree_shares` and `bush_shares`.
static var RECORDS: Array = []
static var IDS: PackedStringArray = []
## The biome of each relief the layout decides itself (the last loaded record of that
## `where`), -1 when no loaded bundle gives one.
static var SEA := -1
static var BEACH := -1
static var ROCK := -1
static var PLATEAU := -1
static var SWAMP := -1
## The climate biomes, most specific first (see pick).
static var CLIMATE: Array = []


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	RECORDS = []
	IDS = []
	SEA = -1
	BEACH = -1
	ROCK = -1
	PLATEAU = -1
	SWAMP = -1
	CLIMATE = []
	for r in Content.records("biomes"):
		var b: Dictionary = r.duplicate()
		b.tree_shares = _shares(b.trees, Trees.SPECIES)
		b.bush_shares = _shares(b.bushes, Bushes.TYPES)
		b.area = (b.warmth[1] - b.warmth[0]) * (b.moisture[1] - b.moisture[0])
		var i := RECORDS.size()
		RECORDS.append(b)
		IDS.append(b.id)
		match b.where:
			"sea":
				SEA = i
			"beach":
				BEACH = i
			"rock":
				ROCK = i
			"plateau":
				PLATEAU = i
			"swamp":
				SWAMP = i
			_:
				CLIMATE.append(i)
	CLIMATE.sort_custom(func(a: int, c: int) -> bool:
		return RECORDS[a].area < RECORDS[c].area if RECORDS[a].area != RECORDS[c].area else a < c)


## `shares` (id -> share) as [[index in `list`, share], ...], the ids not in the list left out.
static func _shares(shares: Dictionary, list: Array) -> Array:
	var out := []
	for id in shares:
		for i in list.size():
			if list[i].id == id:
				out.append([i, shares[id]])
				break
	return out


## Index of the biome with `id`, or -1.
static func index(id: String) -> int:
	for i in RECORDS.size():
		if RECORDS[i].id == id:
			return i
	return -1


## Index of the loaded biome named `name` (the id without its mod), or -1: what the
## places of the playtest page and the shots ask for ("forest", "desert").
static func named(name: String) -> int:
	for i in RECORDS.size():
		if RECORDS[i].id.get_slice(":", 1) == name:
			return i
	return -1


## The climate biome of a column of warmth `t` and moisture `m` (0..1 each), NONE when no
## loaded biome holds them.
static func pick(t: float, m: float) -> int:
	for i in CLIMATE:
		var b: Dictionary = RECORDS[i]
		if t >= b.warmth[0] and t <= b.warmth[1] and m >= b.moisture[0] and m <= b.moisture[1]:
			return i
	return NONE


## The record of biome `b`, {} for NONE.
static func of(b: int) -> Dictionary:
	return RECORDS[b] if b >= 0 and b < RECORDS.size() else {}


## The species of the tree biome `b` grows for the roll `roll` (0..1): each species takes
## its share of the roll in turn; what is left grows nothing (-1).
static func tree(b: int, roll: float) -> int:
	return _roll(of(b).get("tree_shares", []), roll)


## The type of the bush biome `b` grows for the roll `roll`, -1 for none (see tree).
static func bush(b: int, roll: float) -> int:
	return _roll(of(b).get("bush_shares", []), roll)


static func _roll(shares: Array, roll: float) -> int:
	for s in shares:
		if roll < s[1]:
			return s[0]
		roll -= s[1]
	return -1


## The chance of a tree on a lattice column of biome `b`, and the chance in its groves
## (where the forest noise is high).
static func tree_chance(b: int) -> float:
	return of(b).get("tree_chance", 0.0)


static func groves(b: int) -> float:
	return of(b).get("groves", 0.0)


## One bush try per this many cells of biome `b`; 0 for none.
static func sparsity(b: int) -> int:
	return of(b).get("bush_sparsity", 0)


## The material biome `b` lays on top: grass unless its record says otherwise (sand, clay
## and snow are the loaded mods' beach, bank and snow materials, `beach`, `bank` and `snow`
## here).
static func top(b: int, beach: int, bank: int, snow := Mat.STONE) -> int:
	match of(b).get("top", "grass"):
		"stone":
			return Mat.STONE
		"dirt":
			return Mat.DIRT
		"sand":
			return beach
		"clay":
			return bank
		"snow":
			return snow
	return Mat.GRASS


## The colour of biome `b` on the map; a dull green for NONE.
static func color(b: int) -> Color:
	return of(b).get("color", Color(0.45, 0.5, 0.35))


static func sandstorms(b: int) -> bool:
	return of(b).get("sandstorms", false)


## Whether the player may start in biome `b`: a biome that says `spawn`, or any climate
## biome when none does.
static func spawn_ok(b: int) -> bool:
	if b < 0 or b >= RECORDS.size() or not b in CLIMATE:
		return false
	for i in CLIMATE:
		if RECORDS[i].spawn:
			return RECORDS[b].spawn
	return true


## The title of biome `b` for the player, "" for NONE.
static func title(b: int) -> String:
	return of(b).get("title", "")


## What is wrong with the loaded biomes for the engine, if anything: a window must not
## be empty, and a relief may have one biome.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	var seen := {}
	for b in RECORDS:
		if b.warmth[0] > b.warmth[1] or b.moisture[0] > b.moisture[1]:
			out.append("biomes: `%s`: an empty warmth or moisture window" % b.id)
		if b.where != "climate":
			if seen.has(b.where):
				out.append("biomes: `%s` and `%s` both stand for the %s" % [seen[b.where], b.id, b.where])
			seen[b.where] = b.id
	return out
