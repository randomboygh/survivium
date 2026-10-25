extends RefCounted
## Plants on grass: what each gives when the layer of grass it grows on is cut (see the
## material's `mow`). Which plants grow where is Grass.plants_on, the same for the
## client that draws them and the server that hands out what they give.

const Content := preload("res://src/shared/content/content.gd")

## The kinds of plant the world grows (a record's `kind`, see Grass for where each
## grows): the id of the loaded plant of each kind, "" when no mod gives one, so that
## kind does not grow. A plant of kind `custom` brings its own picture (`sprite`, a row
## of `frames` frames of PixelTextures.PLANT_W x PLANT_H px in the bundle's
## sprites/plants/) and says where it grows (`grows`: on open grass, in the shade of
## crowns or on the banks), how much of that ground it covers and whether in clumps;
## any number of those grow side by side (CUSTOM, each with its frames after the last).
const KINDS := {"TUFT": "tuft", "TALL": "tall_grass", "FLOWERS": "flowers", "HERBS": "herbs",
	"EARS": "ears", "REEDS": "reeds", "MOSS": "moss", "MUSHROOMS": "mushrooms", "GLOW": "glow_mushrooms",
	"CUSTOM": "custom"}

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
## The custom plants in load order, each the record with `first`: the index of its
## first frame among all custom frames (see Grass.CUSTOM).
static var CUSTOM: Array = []


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	BY_ID = {}
	BY_KIND = {}
	CUSTOM = []
	var frames := 0
	for r in Content.records("plants"):
		BY_ID[r.id] = r
		BY_KIND[r.kind] = r.id
		if r.kind == KINDS.CUSTOM:
			var c: Dictionary = r.duplicate()
			c.first = frames
			frames += r.frames
			CUSTOM.append(c)
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


## How many frames the custom plants have together (the columns after the engine's
## own in the plant texture).
static func custom_frames() -> int:
	return 0 if CUSTOM.is_empty() else CUSTOM[-1].first + CUSTOM[-1].frames


## The custom plant whose frame `frame` (among all custom frames) is, "" past the end.
static func custom_of(frame: int) -> String:
	for c in CUSTOM:
		if frame < c.first + c.frames:
			return c.id
	return ""


## The path of the picture of custom plant `c` (a record of CUSTOM).
static func sprite_path(c: Dictionary) -> String:
	return Content.asset(c, "sprites/plants/%s.png" % c.sprite)


## What is wrong with the loaded plants for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for c in CUSTOM:
		if c.sprite == "":
			out.append("plants: `%s`: a custom plant needs a `sprite`" % c.id)
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
