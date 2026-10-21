extends RefCounted
## What the player holds, shown in the hands of the sprite (Figure): every frame it
## reads the two hands and the one in use from Controls and gives their looks to the
## player when they change. A thing is drawn by its item's `sprite`, a picture in its
## mod; a block without one is a lump of its tile's colour, anything else a lump of
## cloth. `game` is the Main node that owns the scene.

const Items := preload("res://src/shared/items.gd")
const Mat := preload("res://src/shared/materials.gd")
const Figure := preload("res://src/client/figure.gd")

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


## The look of item `id` in a hand (see Figure), {} for an empty hand: the sheet of its
## `sprite` in its mod, or a lump tinted with the colour of the block it places or of
## cloth, and the work it is used with (`anim`).
func look(id: String) -> Dictionary:
	var item := Items.get_item(id)
	if item.is_empty():
		return {}
	if item.sprite != "":
		return {"sprite": "res://content/%s/sprites/held/%s.png" % [item.mod, item.sprite], "anim": item.anim}
	var out := {"sprite": Figure.LUMP, "anim": item.anim, "colour": CLOTH}
	var m := Mat.index(item.get("place", ""))
	if m >= 0:
		if not _blocks.has(m):
			_blocks[m] = game.props._tile_colour(m)
		out.colour = _blocks[m]
	return out
