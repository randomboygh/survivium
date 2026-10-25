extends RefCounted
## Recipes: what is made by hand, at a workbench, in a kiln, read from
## `content/*/data/recipes.yaml` (see Content; plan/design/crafting.md). A recipe makes
## `count` of item `makes` from the items of `needs` in `time` seconds, by hand or at
## the station `at` (an item with a `prop`, placed in the world), with a tool of kind
## `tool` in the bag. A recipe is known once every item it needs has been in the bag
## (see Knowledge). Shared, so the server can check the same rules.

const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Plants := preload("res://src/shared/content/plants.gd")

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


## Recipe id `id` as it is called now.
static func canon(id: String) -> String:
	return RENAMED.get(id, id)


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


## Whether bag `inv` holds a tool of the kind recipe `r` needs (or it needs none).
static func has_tool(r: Dictionary, inv) -> bool:
	if r.tool == "none":
		return true
	for s in inv.slots:
		if s != null and Items.get_item(s[0]).get("tool", "none") == r.tool:
			return true
	return false


## Why recipe `r` cannot be started now with bag `inv` and the stations near
## (`stations`: station item id -> true), for the window; "" when it can.
static func why_not(r: Dictionary, inv, stations: Dictionary) -> String:
	if r.at != "" and not stations.has(r.at):
		return "Нужен станок: %s" % Items.title(r.at)
	if not has_tool(r, inv):
		return "Нужен инструмент: %s" % TOOL_NAMES.get(r.tool, r.tool)
	var short := missing(r, inv)
	if not short.is_empty():
		return "Не хватает: %s" % amounts_text(short)
	return ""


const TOOL_NAMES := {"axe": "топор", "pickaxe": "кирка", "shovel": "лопата", "sword": "меч", "scythe": "коса"}


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


## Every item a player can get: what cells, the plants on them, trees and bushes give, the
## campfire the camp starts with, and what recipes make from those; the recipes that can never
## be made are reported by check().
static func reachable() -> Dictionary:
	var have := {}
	for id in Items.IDS:
		if Items.get_item(id).prop == "campfire":
			have[id] = true
	for rec: Dictionary in Mat.RECORDS:
		for id in [rec.item, rec.bonus] + rec.mow_gives.keys():
			if id != "":
				have[id] = true
	for p: Dictionary in Plants.BY_ID.values():
		for id in p.gives:
			have[id] = true
	for s: Dictionary in Trees.SPECIES:
		for id in [s.seed, s.log, s.twig]:
			if id != "":
				have[id] = true
	for b: Dictionary in Bushes.TYPES:
		for id in [b.fruit, b.item, b.twig]:
			if id != "":
				have[id] = true
	var grew := true
	while grew:
		grew = false
		for r in RECIPES:
			if have.has(r.makes) or (r.at != "" and not have.has(r.at)):
				continue
			if r.tool != "none" and not _has_tool_kind(have, r.tool):
				continue
			var ok := true
			for id in r.needs:
				ok = ok and have.has(id)
			if ok:
				have[r.makes] = true
				grew = true
	return have


static func _has_tool_kind(have: Dictionary, kind: String) -> bool:
	for id in have:
		if Items.get_item(id).get("tool", "none") == kind:
			return true
	return false


## What is wrong with the loaded recipes for the engine, if anything.
## What is wrong with the loaded recipes: a station that is none, and, with `whole` (the
## full set of mods; a part of it may well lack the source of something), a recipe that can
## never be made from what the world gives.
static func check(whole := true) -> PackedStringArray:
	var out: PackedStringArray = []
	for r in RECIPES:
		if r.at != "" and Items.get_item(r.at).get("prop", "none") in ["none", "chest"]:
			out.append("recipes: %s.at: `%s` is no station (an item with prop workbench, kiln, forge or campfire)" % [r.id, r.at])
	if not whole:
		return out
	var have := reachable()
	for r in RECIPES:
		if not have.has(r.makes):
			out.append("recipes: %s can never be made: its materials, station or tool cannot be had" % r.id)
	return out
