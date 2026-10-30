extends RefCounted
## Recipes: what is made by hand, at a workbench, in a kiln, read from
## `content/*/data/recipes.yaml` (see Content; plan/design/crafting.md). A recipe makes
## `count` of item `makes` from the items of `needs` in `time` seconds, by hand or at
## the station `at` (an item with a `prop` that stores nothing, placed in the world; one
## that `serves` it does too), with a tool of class `tool` in the bag. A recipe is known
## once every item it needs has been in the bag (see Knowledge). Shared, so the server
## can check the same rules.

const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")

## Records in the order of the data files, and by id.
static var RECIPES: Array = []
static var BY_ID := {}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	RECIPES = Content.records("recipes")
	BY_ID = {}
	for r in RECIPES:
		BY_ID[r.id] = r


static func get_recipe(id: String) -> Dictionary:
	return BY_ID.get(id, {})


## Ids of recipes a save from before 2026-10-25 may hold (see Items.RENAMED), by their ids now.
const RENAMED := {"core:cord": "materials:cord", "core:campfire": "resources:campfire"}


## Recipe id `id` as it is called now (RENAMED, then the recipes' `was`).
static func canon(id: String) -> String:
	return Content.canon("recipes", RENAMED.get(id, id))


## Whether a character who has seen the items of `seen` (id -> true) knows recipe `r`.
static func is_known(r: Dictionary, seen: Dictionary) -> bool:
	for id in r.needs:
		if not seen.has(id):
			return false
	return true


## What bag `inv` lacks for recipe `r`: item id -> how many more.
static func missing(r: Dictionary, inv) -> Dictionary:
	var out := {}
	for id in r.needs:
		var short: int = r.needs[id] - inv.count(id)
		if short > 0:
			out[id] = short
	return out


## Whether bag `inv` holds a tool of the class recipe `r` needs (or it needs none).
static func has_tool(r: Dictionary, inv) -> bool:
	return r.tool == "none" or Tools.holds(inv, r.tool)


## Why recipe `r` cannot be started now with bag `inv` and the stations near
## (`stations`: station item id -> true), for the window; "" when it can.
static func why_not(r: Dictionary, inv, stations: Dictionary) -> String:
	if r.at != "" and not stations.has(r.at):
		return "Нужен станок: %s" % Items.title(r.at)
	if not has_tool(r, inv):
		return "Нужен инструмент: %s" % Items.tool_title(r.tool)
	var short := missing(r, inv)
	if not short.is_empty():
		return "Не хватает: %s" % amounts_text(short)
	return ""


## "2 Ветка, 1 Верёвка" for a mapping of item ids to how many.
static func amounts_text(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in amounts:
		parts.append("%d %s" % [amounts[id], Items.title(id)])
	return ", ".join(parts)


## Takes the materials of recipe `r` out of bag `inv`; false (and nothing taken) when
## something is missing.
static func take(r: Dictionary, inv) -> bool:
	if not missing(r, inv).is_empty():
		return false
	for id in r.needs:
		inv.remove(id, r.needs[id])
	return true


## What is wrong with the loaded recipes for the engine: a station that is none. Whether
## each can be made from what the world gives is the content graph's (ContentGraph).
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for r in RECIPES:
		if r.at != "" and not Items.is_station(r.at):
			out.append("recipes: %s.at: `%s` is no station (an item with a `prop` that stores nothing)" % [r.id, r.at])
	return out
