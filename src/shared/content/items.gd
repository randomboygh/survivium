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
## The name of each tool class the items have, for hints (see tool_title).
static var TOOL_TITLES := {}

## The kinds of items the bag and the craft tab sort and filter by, in their order,
## with their names; an item's kind follows from what it does (see category).
const CATEGORIES := {"tools": "Инструменты", "gear": "Одежда и сумки", "stations": "Станки", "materials": "Материалы",
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
	TOOL_TITLES = {}
	var titles := {}
	for id in IDS:
		var kind: String = BY_ID[id].tool
		if kind != "none":
			titles[kind] = titles.get(kind, []) + [BY_ID[id].title]
	for kind: String in titles:
		TOOL_TITLES[kind] = _shared_ending(titles[kind])


## The record of item `id`; a bare name is taken as a core item (the campfire). Empty if
## there is no such item.
static func get_item(id: String) -> Dictionary:
	return BY_ID.get(Content.qualify(id, "core"), {})


## Item id `id` as it is called now: an id from an old save by RENAMED, then by the
## `was` of the items (see Content.canon), any other as it is.
static func canon(id: String) -> String:
	return Content.canon("items", RENAMED.get(id, id))


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


## The name of tool class `kind` for a hint ("Нужен инструмент: топор"): the last words the
## titles of all its items share («Каменный топор», «Медный топор»: «топор»), else the
## first one's title, from a small letter; the class itself when no item is one.
static func tool_title(kind: String) -> String:
	return TOOL_TITLES.get(kind, kind)


## The last words `titles` all end with, else the first title, from a small letter.
static func _shared_ending(titles: Array) -> String:
	var words: PackedStringArray = titles[0].split(" ")
	var n := words.size()
	for t: String in titles:
		var other := t.split(" ")
		var same := 0
		while same < mini(n, other.size()) and words[words.size() - 1 - same].to_lower() == other[other.size() - 1 - same].to_lower():
			same += 1
		n = same
	var text: String = " ".join(words.slice(words.size() - n)) if n > 0 else titles[0]
	return text.left(1).to_lower() + text.substr(1)


## Whether item `id` is a station: set down in the world (a `prop`) and storing nothing.
static func is_station(id: String) -> bool:
	var item := get_item(id)
	return item.get("prop", "none") != "none" and item.get("storage", 0) == 0


## The most slots a thing set down holds (`storage`), 0 when none stores.
static func most_storage() -> int:
	var most := 0
	for id in IDS:
		most = maxi(most, BY_ID[id].storage)
	return most


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


## The slot of the body item `id` is worn in (head, body, legs, feet, back), "" for none.
static func wear_on(id: String) -> String:
	return get_item(id).get("wear_on", "")


## The slots a bag worn on the back adds to the bag the character always has.
static func bag_slots(id: String) -> int:
	return get_item(id).get("bag_slots", 0)


static func food(id: String) -> float:
	return get_item(id).get("food", 0.0)


## Health one of item `id` gives back (a bandage), 0 for none.
static func heal(id: String) -> float:
	return get_item(id).get("heal", 0.0)


## The kind of item `id` (a key of CATEGORIES): something worn, a tool, a thing set down in the world,
## food, something planted or sown, a block, else a material. The one place that
## decides it, so a `category` field of the data can take over here when items need
## one (decided with the user: derived for now).
static func category(id: String) -> String:
	var item := get_item(id)
	if item.get("wear_on", "") != "":
		return "gear"
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


## What is wrong with the loaded items for the engine, if anything: two items that place
## one material; the flags of a thing set down on an item that is none; a thing that
## serves what is no station; a class of tool to set it down with that no item is.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in IDS:
		var item: Dictionary = BY_ID[id]
		var place: String = item.place
		if place != "" and Mat.index(place) >= 0 and placed_by[Mat.index(place)] != id:
			out.append("items: `%s` and `%s` both place `%s`" % [placed_by[Mat.index(place)], id, place])
		if item.prop == "none":
			for flag: String in ["storage", "fire", "repairs", "serves", "place_tool"]:
				if item[flag] != Content.schema("items")[flag].default:
					out.append("items: `%s`.%s: only a thing set down in the world (a `prop`) has it" % [id, flag])
		for s: String in item.serves:
			if not is_station(s) or s == id:
				out.append("items: `%s`.serves: `%s` is no other station" % [id, s])
		if item.bag_slots > 0 and item.wear_on != "back":
			out.append("items: `%s`.bag_slots: only a bag worn on the back (`wear_on: back`) has slots" % id)
		if item.wear_on != "" and item.stack != 1:
			out.append("items: `%s`: a thing worn (`wear_on`) stacks by one" % id)
		if item.place_tool != "none" and not TOOL_TITLES.has(item.place_tool):
			out.append("items: `%s`.place_tool: no item is a `%s`" % [id, item.place_tool])
	return out
