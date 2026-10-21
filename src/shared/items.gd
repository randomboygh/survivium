extends RefCounted
## Items: what a bag holds and what lies on the ground, read from
## `content/*/data/items.yaml` (see Content). An item is known by its id
## (`core:branch`); a stack of items is an id and a count. Cells give an item when
## dug (the material's `item`) and an item with `place` puts that material back.

const Content := preload("res://src/shared/content.gd")
const Mat := preload("res://src/shared/materials.gd")

## Items the engine itself refers to; the validator demands them.
const KNOWN := {"BRANCH": "core:branch", "LOG": "core:log"}
## What lies on the ground where someone died: a sack with their things, not an item.
const SACK := "sack"

static var BRANCH := ""
static var LOG := ""

## id -> record from the data files: id, title, weight (kg), stack, food, place (a
## material id or ""), model, icon, sprite, anim, hands.
static var BY_ID := {}
## Item ids in the order of the data files.
static var IDS: PackedStringArray = []
## By material index: the item a dug cell gives ("" none), and the item that places
## the material ("" none).
static var dug: PackedStringArray = []
static var placed_by: PackedStringArray = []

## The kinds of items the bag and the craft tab sort and filter by, in their order,
## with their names; an item's kind follows from what it does (see category).
const CATEGORIES := {"tools": "Инструменты", "stations": "Станки", "materials": "Материалы",
	"blocks": "Блоки", "food": "Еда", "plants": "Посадки"}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	BY_ID = {}
	IDS = []
	for r in Content.records("items"):
		BY_ID[r.id] = r
		IDS.append(r.id)
	dug = []
	placed_by = []
	dug.resize(Mat.COUNT)
	placed_by.resize(Mat.COUNT)
	for m in Mat.COUNT:
		dug[m] = Mat.RECORDS[m].item
	for id in IDS:
		var place: String = BY_ID[id].place
		if place != "":
			var m := Mat.index(place)
			if m >= 0 and placed_by[m] == "":
				placed_by[m] = id
	BRANCH = KNOWN.BRANCH
	LOG = KNOWN.LOG


## The record of item `id`; a bare name is taken as a core item (the kinds of things a
## felled tree drops are named so). Empty if there is no such item.
static func get_item(id: String) -> Dictionary:
	return BY_ID.get(Content.qualify(id, "core"), {})


static func has(id: String) -> bool:
	return BY_ID.has(Content.qualify(id, "core"))


static func title(id: String) -> String:
	return get_item(id).get("title", id)


static func weight(id: String) -> float:
	return get_item(id).get("weight", 0.0)


static func stack_size(id: String) -> int:
	return get_item(id).get("stack", 1)


static func food(id: String) -> float:
	return get_item(id).get("food", 0.0)


## The kind of item `id` (a key of CATEGORIES): a tool, a thing set down in the world,
## food, something planted or sown, a block, else a material. The one place that
## decides it, so a `category` field of the data can take over here when items need
## one (decided with the user: derived for now).
static func category(id: String) -> String:
	var item := get_item(id)
	if item.get("tool", "none") != "none":
		return "tools"
	if item.get("prop", "none") != "none":
		return "stations"
	if item.get("food", 0.0) > 0.0:
		return "food"
	if item.get("plant", "") != "" or item.get("sow", "") != "":
		return "plants"
	if item.get("place", "") != "":
		return "blocks"
	return "materials"


## What is wrong with the loaded items for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for name in KNOWN:
		if not BY_ID.has(KNOWN[name]):
			out.append("items: the engine needs `%s`" % KNOWN[name])
	for m in Mat.PLACEABLE:
		if placed_by[m] == "":
			out.append("items: `%s` is on the hotbar but no item places it" % Mat.IDS[m])
	return out
