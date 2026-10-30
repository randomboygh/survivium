extends RefCounted
## Items: what a bag holds and what lies on the ground, read from
## `content/*/data/items.yaml` (see Content). An item is known by its id
## (`resources:branch`); a stack of items is an id and a count. Cells give an item when
## dug (the material's `item`) and an item with `place` puts that material back.

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")

## What lies on the ground where someone died: a sack with their things, not an item.
const SACK := "sack"
## Ids of items and recipes a save from before 2026-10-25 (`content` below 7) may hold, by
## what they are called now: the base items went to the resources and materials mods.
const RENAMED := {
	"core:log": "resources:log", "core:branch": "resources:branch", "core:stone": "resources:stone",
	"core:dirt": "resources:dirt", "core:fiber": "resources:fiber", "core:flint": "resources:flint",
	"core:cord": "materials:cord", "materials:sand": "resources:sand",
	"materials:clay": "resources:clay", "tools:planks": "materials:planks", "tools:brick": "materials:brick",
}

## id -> record from the data files: id, title, weight (kg), stack, food, heal, place (a
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
	"blocks": "Блоки", "food": "Еда", "heal": "Лечение", "plants": "Посадки"}


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


## The record of item `id`; a bare name is taken as a core item (the campfire). Empty if
## there is no such item.
static func get_item(id: String) -> Dictionary:
	return BY_ID.get(Content.qualify(id, "core"), {})


## Item id `id` as it is called now: an id from an old save by RENAMED, any other as it is.
static func canon(id: String) -> String:
	return RENAMED.get(id, id)


## The id of the first item in bag `inv` that lights a fire (`fuel`), "" when it has none.
static func fuel_in(inv) -> String:
	for id in IDS:
		if BY_ID[id].fuel and inv.count(id) > 0:
			return id
	return ""


static func has(id: String) -> bool:
	return BY_ID.has(Content.qualify(id, "core"))


## The id of the first item placed as a `prop` of `kind` (a chest, a workbench), "" when
## no loaded mod has one.
static func with_prop(kind: String) -> String:
	return _first("prop", kind)


## The id of the first item used as a `tool` of `kind` (an axe, a pickaxe), "" for none.
static func with_tool(kind: String) -> String:
	return _first("tool", kind)


## The id of the first item of `category` (see category), "" for none.
static func of_category(category: String) -> String:
	for id in IDS:
		if category(id) == category:
			return id
	return ""


static func _first(field: String, value: String) -> String:
	for id in IDS:
		if BY_ID[id].get(field, "none") == value:
			return id
	return ""


static func title(id: String) -> String:
	return get_item(id).get("title", id)


static func weight(id: String) -> float:
	return get_item(id).get("weight", 0.0)


static func stack_size(id: String) -> int:
	return get_item(id).get("stack", 1)


static func food(id: String) -> float:
	return get_item(id).get("food", 0.0)


## Health one of item `id` gives back (a bandage), 0 for none.
static func heal(id: String) -> float:
	return get_item(id).get("heal", 0.0)


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
	if item.get("heal", 0.0) > 0.0:
		return "heal"
	if item.get("plant", "") != "" or item.get("sow", "") != "":
		return "plants"
	if item.get("place", "") != "":
		return "blocks"
	return "materials"


## What is wrong with the loaded items for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in IDS:
		var place: String = BY_ID[id].place
		if place != "" and Mat.index(place) >= 0 and placed_by[Mat.index(place)] != id:
			out.append("items: `%s` and `%s` both place `%s`" % [placed_by[Mat.index(place)], id, place])
	return out
