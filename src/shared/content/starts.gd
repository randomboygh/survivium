extends RefCounted
## How a new world starts, read from `content/*/data/starts.yaml` (see Content): what the
## bag of a new character holds and the camp by the spawn, each thing of it `at` so many
## cells east and south of the spawn. Every new world starts by core's record (DEFAULT) as
## the loaded bundles patch it (the chest's bundle adds the chest), and the content graph
## starts from the same record, so the check and the game begin alike
## (docs/specifications/BUNDLE_SYSTEM.md, section 11). Shared, so the server can start
## worlds and players the same way.

const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")

## The start of every new world.
const DEFAULT := "core:default"

## The record of DEFAULT as loaded: id, title, bag (item id -> how many), camp ([{item,
## at: [east, south]}], in the order they are set down); an empty start when no loaded
## mod has it.
static var START := {}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	START = Content.find("starts", DEFAULT)
	if START.is_empty():
		START = {"id": DEFAULT, "title": DEFAULT, "bag": {}, "camp": []}


## What is wrong with the loaded start for the engine, if anything: a camp thing that is
## not set down in the world (no `prop`), two that would stand on the same cells.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	var camp: Array = START.camp
	for i in camp.size():
		var e: Dictionary = camp[i]
		if Items.get_item(e.item).get("prop", "none") == "none":
			out.append("starts: %s.camp: `%s` is not set down in the world (an item with a prop)" % [START.id, e.item])
		for j in i:
			if absi(e.at[0] - camp[j].at[0]) < 2 and absi(e.at[1] - camp[j].at[1]) < 2:
				out.append("starts: %s.camp: `%s` and `%s` would stand on the same cells" % [START.id, camp[j].item, e.item])
	return out
