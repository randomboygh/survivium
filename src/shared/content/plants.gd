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
## crowns, in the woods (that shade and the open ground round it) or on the banks), how much of that ground it covers and whether in clumps;
## any number of those grow side by side (CUSTOM, each with its frames after the last).
## A crop (kind `crop`, grows `field`) is drawn the same way, a frame a stage of its
## growth, the last one ripe; it grows only where it was sown on a bed (WorldData.fields).
## A sapling (kind `sapling`) is planted from a tree's seed on open ground, drawn a frame a
## stage the same way, and grown it becomes its `tree` (a species of Trees). A frame may be
## `across` columns wide, drawn as that many cards side by side.
const KINDS := {"TUFT": "tuft", "TALL": "tall_grass", "FLOWERS": "flowers", "HERBS": "herbs",
	"EARS": "ears", "REEDS": "reeds", "MOSS": "moss", "MUSHROOMS": "mushrooms", "GLOW": "glow_mushrooms",
	"CUSTOM": "custom", "CROP": "crop", "SAPLING": "sapling"}

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
## (item id -> how many), chance, finds (item id -> the chance of one besides), pick (picked by hand rather than cut, for the hint).
static var BY_ID := {}
## kind -> the id of the last loaded plant of that kind.
static var BY_KIND := {}
## The custom plants in load order, each the record with `first`: the index of its
## first frame among all custom frames (see Grass.CUSTOM).
static var CUSTOM: Array = []
## By custom frame column (Grass.CUSTOM + column): how many cards side by side draw the
## frame starting at that column (its plant's `across`), 0 for the other columns of a
## wide frame.
static var ACROSS := PackedByteArray()


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	BY_ID = {}
	BY_KIND = {}
	CUSTOM = []
	ACROSS = PackedByteArray()
	var frames := 0
	for r in Content.records("plants"):
		BY_ID[r.id] = r
		BY_KIND[r.kind] = r.id
		if r.kind in [KINDS.CUSTOM, KINDS.CROP, KINDS.SAPLING]:
			var c: Dictionary = r.duplicate()
			c.first = frames
			frames += columns(r)
			CUSTOM.append(c)
			var across: int = r.get("across", 1)
			for k in columns(r):
				ACROSS.append(across if k % across == 0 else 0)
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
	return 0 if CUSTOM.is_empty() else CUSTOM[-1].first + columns(CUSTOM[-1])


## How many columns of PixelTextures.PLANT_W px the sprite of custom plant `c` has: its
## frames, each `across` wide.
static func columns(c: Dictionary) -> int:
	return c.frames * c.get("across", 1)


## The custom plant whose frame `frame` (among all custom frames) is, "" past the end.
static func custom_of(frame: int) -> String:
	for c in CUSTOM:
		if frame < c.first + columns(c):
			return c.id
	return ""


## Whether plant `id` is a crop (sown on a bed, see WorldData.fields).
static func is_crop(id: String) -> bool:
	return kind_of(id) == KINDS.CROP


## Whether plant `id` is a sapling (planted from a tree's seed, grows into its `tree`).
static func is_sapling(id: String) -> bool:
	return kind_of(id) == KINDS.SAPLING


## Whether plant `id` grows from what is sown or planted (a crop or a sapling: an item's `crop`).
static func is_sown(id: String) -> bool:
	return is_crop(id) or is_sapling(id)


## The custom record (CUSTOM, with its `first` frame) of plant `id`, {} for none.
static func custom(id: String) -> Dictionary:
	for c in CUSTOM:
		if c.id == id:
			return c
	return {}


## The stage (frame, 0 a sprout .. frames - 1 ripe) of crop `id` that has grown `grown`
## days; a sapling shows its last frame before it is grown (grown, it is a tree).
static func stage(id: String, grown: float) -> int:
	var c: Dictionary = BY_ID.get(id, {})
	if c.is_empty():
		return 0
	var last: int = c.frames - 1
	if last <= 0:
		return 0
	if c.grow_days <= 0.0 or grown >= c.grow_days:
		return last
	if c.kind == KINDS.SAPLING:
		var span: float = c.grow_days * (c.young if c.young > 0.0 else 1.0)
		return mini(last, floori(grown / span * c.frames))
	return mini(last - 1, floori(grown / c.grow_days * last))


## Whether sapling `id` grown `grown` days is a young tree by now (its `young` share of
## its `grow_days`; never when it has no young stage).
static func young(id: String, grown: float) -> bool:
	var c: Dictionary = BY_ID.get(id, {})
	return not c.is_empty() and c.get("young", 0.0) > 0.0 and grown >= c.grow_days * c.young


## Whether crop `id` grown `grown` days is ripe.
static func ripe(id: String, grown: float) -> bool:
	var c: Dictionary = BY_ID.get(id, {})
	return not c.is_empty() and grown >= c.grow_days


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
## `rng`: its `gives` by its `chance`, and one of each item it `finds` by that item's own.
static func harvest(ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for id in ids:
		var p: Dictionary = BY_ID.get(id, {})
		if p.is_empty():
			continue
		if rng.randf() < p.chance:
			for item in p.gives:
				out[item] = out.get(item, 0) + p.gives[item]
		for item in p.get("finds", {}):
			if rng.randf() < p.finds[item]:
				out[item] = out.get(item, 0) + 1
	return out
