extends RefCounted
## Plants on grass: what each gives when the layer of grass it grows on is cut (see the
## material's `mow`). Which plants grow where is Grass.plants_on, the same for the
## client that draws them and the server that hands out what they give.

const Content := preload("res://src/shared/content/content.gd")

## The kinds of plant the world grows (a record's `kind`, see Grass for where each
## grows): the id of the loaded plant of each kind, "" when no mod gives one, so that
## kind does not grow.
const KINDS := {"TUFT": "tuft", "TALL": "tall_grass", "FLOWERS": "flowers", "HERBS": "herbs",
	"EARS": "ears", "REEDS": "reeds", "MOSS": "moss", "MUSHROOMS": "mushrooms", "GLOW": "glow_mushrooms"}

static var TUFT := ""
static var TALL := ""
static var FLOWERS := ""
static var HERBS := ""
static var EARS := ""
static var REEDS := ""
static var MOSS := ""
static var MUSHROOMS := ""
static var GLOW := ""

## Id -> record from `content/*/data/plants.yaml` (see Content): id, title, kind, gives
## (item id -> how many), chance, pick (picked by hand rather than cut, for the hint).
static var BY_ID := {}
## kind -> the id of the last loaded plant of that kind.
static var BY_KIND := {}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	BY_ID = {}
	BY_KIND = {}
	for r in Content.records("plants"):
		BY_ID[r.id] = r
		BY_KIND[r.kind] = r.id
	TUFT = of_kind(KINDS.TUFT)
	TALL = of_kind(KINDS.TALL)
	FLOWERS = of_kind(KINDS.FLOWERS)
	HERBS = of_kind(KINDS.HERBS)
	EARS = of_kind(KINDS.EARS)
	REEDS = of_kind(KINDS.REEDS)
	MOSS = of_kind(KINDS.MOSS)
	MUSHROOMS = of_kind(KINDS.MUSHROOMS)
	GLOW = of_kind(KINDS.GLOW)


## The id of the plant of `kind`, "" when none is loaded.
static func of_kind(kind: String) -> String:
	return BY_KIND.get(kind, "")


## The kind of plant `id`, "" for none.
static func kind_of(id: String) -> String:
	return BY_ID.get(id, {}).get("kind", "")


## What is wrong with the loaded plants for the engine, if anything.
static func check() -> PackedStringArray:
	return []


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
