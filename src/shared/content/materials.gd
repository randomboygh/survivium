extends RefCounted
## Cell materials, read from `content/*/data/materials.yaml` (see Content). A cell
## holds a material's index: the order of the records, with `core:air` first so an
## empty cell is 0. The usual names (Mat.GRASS, Mat.STONE...) are filled in from the
## ids the engine knows, so code reads as before; `index(id)` finds any other.

const Content := preload("res://src/shared/content/content.gd")

## Flag bits of `flags`.
const SOLID := 1
const ROOF := 2
const SLOPE := 4

## Materials the engine itself refers to; the validator demands them.
const KNOWN := {
	"AIR": "core:air", "GRASS": "core:grass", "DIRT": "core:dirt", "STONE": "core:stone",
	"SAND": "core:sand", "WATER": "core:water", "LOG": "core:log", "LEAVES": "core:leaves",
	"PLANKS": "core:planks", "CLAY": "core:clay", "COPPER_ORE": "core:copper_ore",
	"BRICK": "core:brick", "SCREE": "core:scree",
}

static var AIR := 0
static var GRASS := 0
static var DIRT := 0
static var STONE := 0
static var SAND := 0
static var WATER := 0
static var LOG := 0
static var LEAVES := 0
static var PLANKS := 0
static var CLAY := 0
static var COPPER_ORE := 0
static var BRICK := 0
static var SCREE := 0
static var COUNT := 0

## Index -> id (`core:grass`), title shown to players, record from the data file.
static var IDS: PackedStringArray = []
static var NAMES: PackedStringArray = []
static var RECORDS: Array = []
## Blocks the player can place, in hotbar order.
static var PLACEABLE: Array = []
static var flags: PackedByteArray = []
## How round the cut corners of natural ground are, by material: 0 a straight cut at
## 45 degrees, 1 a little rounded, 2 a quarter circle (see ChunkMesher.CORNER_P).
static var corner_shape: PackedByteArray = []


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	RECORDS = Content.records("materials")
	COUNT = RECORDS.size()
	IDS = []
	NAMES = []
	flags = []
	corner_shape = []
	var hotbar := []
	for i in COUNT:
		var r: Dictionary = RECORDS[i]
		IDS.append(r.id)
		NAMES.append(r.title)
		flags.append((SOLID if r.solid else 0) | (ROOF if r.roof else 0) | (SLOPE if r.slope else 0))
		corner_shape.append(["sharp", "soft", "round"].find(r.corners))
		if r.hotbar > 0:
			hotbar.append([r.hotbar, i])
	hotbar.sort()
	PLACEABLE = []
	for h in hotbar:
		PLACEABLE.append(h[1])
	AIR = index(KNOWN.AIR)
	GRASS = index(KNOWN.GRASS)
	DIRT = index(KNOWN.DIRT)
	STONE = index(KNOWN.STONE)
	SAND = index(KNOWN.SAND)
	WATER = index(KNOWN.WATER)
	LOG = index(KNOWN.LOG)
	LEAVES = index(KNOWN.LEAVES)
	PLANKS = index(KNOWN.PLANKS)
	CLAY = index(KNOWN.CLAY)
	COPPER_ORE = index(KNOWN.COPPER_ORE)
	BRICK = index(KNOWN.BRICK)
	SCREE = index(KNOWN.SCREE)


## Index of the material with `id`, or -1.
static func index(id: String) -> int:
	return IDS.find(id)


## What is wrong with the loaded materials for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	if COUNT == 0 or IDS[0] != KNOWN.AIR:
		out.append("materials: `%s` must be the first material (an empty cell is 0)" % KNOWN.AIR)
	for name in KNOWN:
		if index(KNOWN[name]) < 0:
			out.append("materials: the engine needs `%s`" % KNOWN[name])
	if COUNT > 255:
		out.append("materials: at most 255 materials fit in a cell")
	var places := {}
	for i in COUNT:
		var h: int = RECORDS[i].hotbar
		if h > 0 and places.has(h):
			out.append("materials: `%s` and `%s` share hotbar slot %d" % [IDS[places[h]], IDS[i], h])
		places[h] = i
	return out


static func is_solid(m: int) -> bool:
	return flags[m] & SOLID != 0


## Solid cells that count as a roof for the level cutaway (tree trunks and crowns do not).
static func is_roof(m: int) -> bool:
	return flags[m] & ROOF != 0


## Loose ground that lies as a slope where it steps down one level (see WorldData.slope_mask).
static func can_slope(m: int) -> bool:
	return flags[m] & SLOPE != 0
