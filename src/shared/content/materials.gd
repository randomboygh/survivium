extends RefCounted
## Cell materials, read from `content/*/data/materials.yaml` (see Content). A cell
## holds a material's index: the order of the records, with `core:air` first so an
## empty cell is 0. The engine names only the five materials of the core mod (Mat.AIR,
## GRASS, DIRT, STONE, WATER); the rest it asks for by `role`: the material of the
## beaches and deserts (BEACH), of river banks and bogs (BANK), of mountain slopes
## (SCREE), the ore in the rock (ORE: the first loaded, every ore in ORES), a tree's trunk
## (LOG) and crown (LEAVES), each the last loaded material of that role or -1 when no mod gives one (the generator
## then lays dirt or stone, and no tree can stand). `index(id)` finds any other.

const Content := preload("res://src/shared/content/content.gd")

## Flag bits of `flags`.
const SOLID := 1
const ROOF := 2
const SLOPE := 4

## Materials the engine itself refers to; the validator demands them.
const KNOWN := {
	"AIR": "core:air", "GRASS": "core:grass", "DIRT": "core:dirt", "STONE": "core:stone",
	"WATER": "core:water",
}
## Ids of materials a save from before 2026-10-25 (`content` below 7) numbered, by what
## they are called now: the landscape's went to the resources mod, the built ones to materials.
const RENAMED := {
	"materials:sand": "resources:sand", "materials:clay": "resources:clay", "materials:scree": "resources:scree",
	"tools:planks": "materials:planks", "tools:brick": "materials:brick",
}
## The roles the engine asks materials for (the `role` field), and the static var each
## fills.
const ROLES := {
	"beach": "BEACH", "bank": "BANK", "scree": "SCREE", "snow": "SNOW", "peat": "PEAT", "salt": "SALT", "ice": "ICE", "ore": "ORE", "trunk": "LOG", "crown": "LEAVES",
}
## Bits of `shader_bits`, one word per material for world.gdshader: the priority at a
## boundary (low 4 bits), DRAINS (no puddles), and the kind of patches on open ground
## (`ground`: none, soil, sand, rock) in bits 5 and 6.
const PRIORITY_MASK := 15
const DRAINS := 16
const GROUND_SHIFT := 5
## The bit main.gd adds for the log and the barks: they clear round the player.
const TRUNK := 128
const GROUNDS := ["none", "soil", "sand", "rock"]

static var AIR := 0
static var GRASS := 0
static var DIRT := 0
static var STONE := 0
static var WATER := 0
## The materials of the roles (see ROLES), -1 when no mod gives one.
static var BEACH := -1
static var BANK := -1
static var SCREE := -1
static var SNOW := -1
static var PEAT := -1
static var SALT := -1
static var ICE := -1
static var ORE := -1
static var LOG := -1
static var LEAVES := -1
static var COUNT := 0
## Every material of role ore, and the running sum of their `veins` (see vein_at).
static var ORES: PackedInt32Array = []
static var ORE_SUMS: PackedFloat32Array = []

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
## How many cells of the material lie under it where the generator lays it as the top,
## in place of the dirt (the `layers` field).
static var layers: PackedByteArray = []
## The word of each material for the world shader (see DRAINS).
static var shader_bits: PackedInt32Array = []


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	RECORDS = Content.records("materials")
	COUNT = RECORDS.size()
	IDS = []
	NAMES = []
	flags = []
	corner_shape = []
	layers = []
	shader_bits = []
	var hotbar := []
	for i in COUNT:
		var r: Dictionary = RECORDS[i]
		IDS.append(r.id)
		NAMES.append(r.title)
		flags.append((SOLID if r.solid else 0) | (ROOF if r.roof else 0) | (SLOPE if r.slope else 0))
		corner_shape.append(["sharp", "soft", "round"].find(r.corners))
		layers.append(r.layers)
		shader_bits.append(r.priority | (DRAINS if r.drains else 0) | (GROUNDS.find(r.ground) << GROUND_SHIFT))
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
	WATER = index(KNOWN.WATER)
	# The roles: the last loaded material of each (a mod replaces an earlier mod's).
	BEACH = -1
	BANK = -1
	SCREE = -1
	SNOW = -1
	PEAT = -1
	SALT = -1
	ICE = -1
	ORE = -1
	LOG = -1
	LEAVES = -1
	ORES = []
	ORE_SUMS = []
	for i in COUNT:
		if RECORDS[i].role == "ore" and RECORDS[i].veins > 0.0:
			ORES.append(i)
			ORE_SUMS.append((ORE_SUMS[-1] if not ORE_SUMS.is_empty() else 0.0) + RECORDS[i].veins)
	for i in COUNT:
		var role: String = RECORDS[i].role
		if role != "none":
			BEACH = i if role == "beach" else BEACH
			BANK = i if role == "bank" else BANK
			SCREE = i if role == "scree" else SCREE
			SNOW = i if role == "snow" else SNOW
			PEAT = i if role == "peat" else PEAT
			SALT = i if role == "salt" else SALT
			ICE = i if role == "ice" else ICE
			ORE = i if role == "ore" and ORE < 0 else ORE
			LOG = i if role == "trunk" else LOG
			LEAVES = i if role == "crown" else LEAVES


## The ore of the vein a share `pick` (0..1) of the way through the ores' `veins`, or
## `fallback` when no mod gives an ore.
static func vein_at(pick: float, fallback: int) -> int:
	if ORES.is_empty():
		return fallback
	var at := pick * ORE_SUMS[-1]
	for k in ORES.size():
		if at < ORE_SUMS[k]:
			return ORES[k]
	return ORES[-1]


## Index of the material with `id`, or -1.
static func index(id: String) -> int:
	return IDS.find(id)


## The material of `role` (one of ROLES), `fallback` when no loaded mod gives one.
static func of_role(role: String, fallback: int) -> int:
	var m := -1
	for i in COUNT:
		if RECORDS[i].role == role:
			m = i
	return m if m >= 0 else fallback


## The texture of material `m`: textures/<texture>.png of its bundle (see Content.asset),
## three tiles of PixelTextures.TILE px side by side (the top, the sides and the underside).
static func texture_path(m: int) -> String:
	var r: Dictionary = RECORDS[m]
	var name: String = r.texture if r.texture != "" else r.id.get_slice(":", 1)
	return Content.asset(r, "textures/%s.png" % name)


## Remaps cell values from a world saved with materials in the order `saved` (ids)
## to the materials loaded now: index -> index, as a table, or an empty one when the
## order is the same. A renamed material is found by RENAMED or its `was` (see
## Content.canon); a saved material no loaded mod has becomes stone.
static func remap(saved: PackedStringArray) -> PackedByteArray:
	if saved == IDS:
		return PackedByteArray()
	var out := PackedByteArray()
	for id in saved:
		var m := index(Content.canon("materials", RENAMED.get(id, id)))
		out.append(m if m >= 0 else STONE)
	return out


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
