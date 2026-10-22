extends RefCounted
## Plants on grass: what each gives when the layer of grass it grows on is cut (see the
## material's `mow`). Which plants grow where is Grass.plants_on, the same for the
## client that draws them and the server that hands out what they give.

const Content := preload("res://src/shared/content/content.gd")

## Plants the engine refers to; the validator demands them.
const KNOWN := {"TUFT": "core:tuft", "TALL": "core:tall_grass", "FLOWERS": "core:flowers",
	"HERBS": "core:herbs", "EARS": "core:ears", "REEDS": "core:reeds", "MOSS": "core:moss",
	"MUSHROOMS": "core:mushrooms", "GLOW": "core:glow_mushrooms"}

static var TUFT := ""
static var TALL := ""
static var FLOWERS := ""
static var HERBS := ""
static var EARS := ""
static var REEDS := ""
static var MOSS := ""
static var MUSHROOMS := ""
static var GLOW := ""

## Id -> record from `content/*/data/plants.yaml` (see Content): id, title, gives
## (item id -> how many), chance, pick (picked by hand rather than cut, for the hint).
static var BY_ID := {}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	BY_ID = {}
	for r in Content.records("plants"):
		BY_ID[r.id] = r
	TUFT = KNOWN.TUFT
	TALL = KNOWN.TALL
	FLOWERS = KNOWN.FLOWERS
	HERBS = KNOWN.HERBS
	EARS = KNOWN.EARS
	REEDS = KNOWN.REEDS
	MOSS = KNOWN.MOSS
	MUSHROOMS = KNOWN.MUSHROOMS
	GLOW = KNOWN.GLOW


## What is wrong with the loaded plants for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for name in KNOWN:
		if not BY_ID.has(KNOWN[name]):
			out.append("plants: the engine needs `%s`" % KNOWN[name])
	return out


## What cutting plants `ids` (one id per plant) gives, item id -> how many, rolled with
## `rng`.
static func harvest(ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for id in ids:
		var p: Dictionary = BY_ID.get(id, {})
		if p.is_empty() or rng.randf() >= p.chance:
			continue
		for item in p.gives:
			out[item] = out.get(item, 0) + p.gives[item]
	return out
