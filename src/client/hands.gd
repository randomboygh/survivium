extends RefCounted
## What the player holds, shown in the hands of the sprite (PlayerArt): every frame it
## reads the two hands and the one in use from Controls and gives their looks to the
## player when they change. A tool is drawn by its kind (an item's `tool`) with a head
## coloured by what it is made of; a block is a lump of its tile's colour, anything else
## a lump of cloth. `game` is the Main node that owns the scene.

const Items := preload("res://src/shared/items.gd")
const Mat := preload("res://src/shared/materials.gd")
const PlayerArt := preload("res://src/client/player_art.gd")

## The colour of a tool's head by what it is made of: the first word of its id.
const HEADS := {
	"stone": Color(0.56, 0.57, 0.6),
	"wooden": Color(0.72, 0.55, 0.32),
	"copper": Color(0.8, 0.48, 0.25),
	"iron": Color(0.7, 0.72, 0.76),
}
const METAL := Color(0.62, 0.64, 0.68)
## A thing that is neither a tool nor a block.
const CLOTH := Color(0.78, 0.7, 0.52)

var game
## The hands last given to the player, "left|right|active".
var _shown := ""
## Colours of the blocks by material, read once from the terrain atlas.
var _blocks := {}


func _init(g) -> void:
	game = g


func update() -> void:
	var c = game.controls
	var left: String
	var right: String
	var active: String
	if "hands" in c:
		left = c.hands[0]
		right = c.hands[1]
		active = "left" if c.active == 0 else "right"
	else:
		# The left hand holds a tool, the right one the block of the hotbar while the
		# bag has it.
		left = c.tool
		right = Items.placed_by[Mat.PLACEABLE[c.selected]]
		if not game.settings.free_build and game.character.inventory.count(right) == 0:
			right = ""
		active = "left" if c.dig_mode else "right"
	var key := "%s|%s|%s" % [left, right, active]
	if key == _shown:
		return
	_shown = key
	game.player.hold(look(left), look(right), active)


## The look of item `id` in a hand (see PlayerArt.sheet), {} for an empty hand.
func look(id: String) -> Dictionary:
	var item := Items.get_item(id)
	if item.is_empty():
		return {}
	var tool: String = item.get("tool", "none")
	if PlayerArt.SHAPES.has(tool):
		var made: String = item.id.get_slice(":", 1).get_slice("_", 0)
		return {"model": tool, "colour": HEADS.get(made, METAL)}
	var m := Mat.index(item.get("place", ""))
	if m < 0:
		return {"model": "thing", "colour": CLOTH}
	if not _blocks.has(m):
		_blocks[m] = game.props._tile_colour(m)
	return {"model": "block", "colour": _blocks[m]}
