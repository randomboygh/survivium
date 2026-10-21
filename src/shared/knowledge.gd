extends RefCounted
## What a character knows (plan/design/crafting.md, "Открытие рецептов"): the items
## that have been in the bag, and so the recipes made of them. The knowledge book
## (plan/design/ui.md, section 5) will show it. Saved with the player.

const Crafting := preload("res://src/shared/crafting.gd")
const Items := preload("res://src/shared/items.gd")

## A recipe became known: its id.
signal learned(recipe: String)

## Item ids that have been in the bag -> true.
var seen := {}
## Recipe ids known so far -> true, so each is announced once.
var _known := {}


## Notes the items now in bag `inv`; recipes they complete are learned (and announced
## unless `announce` is false).
func look_at(inv, announce := true) -> void:
	var fresh := false
	for s in inv.slots:
		if s != null and not seen.has(s[0]):
			seen[s[0]] = true
			fresh = true
	if not fresh:
		return
	for r in Crafting.RECIPES:
		if not _known.has(r.id) and Crafting.is_known(r, seen):
			_known[r.id] = true
			if announce:
				learned.emit(r.id)


func knows(r: Dictionary) -> bool:
	return _known.has(r.id)


## Recipes known, in the order of the data files.
func recipes() -> Array:
	return Crafting.RECIPES.filter(knows)


func to_dict() -> Dictionary:
	return {"seen": seen.keys()}


## Fills the knowledge from to_dict() data; unknown items are left out, and the
## recipes known then are not announced again.
func from_dict(d: Dictionary) -> void:
	seen = {}
	for id in d.get("seen", []):
		if id is String and Items.has(id):
			seen[id] = true
	_known = {}
	for r in Crafting.RECIPES:
		if Crafting.is_known(r, seen):
			_known[r.id] = true
