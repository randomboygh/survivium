extends RefCounted
## What the player holds, shown in the hands of the sprite (Figure): every frame it
## reads the two hands and the one in use from Controls and gives their looks to the
## player when they change. A tool is drawn by its item's `sprite`, a sheet in its mod;
## anything else by its icon, which the figure turns with the hand. `game` is the Main
## node that owns the scene.

const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")

var game
## The hands last given to the player, "left|right|active".
var _shown := ""
## Icons of the things held by item, read once.
var _pictures := {}


func _init(g) -> void:
	game = g


func update() -> void:
	var c = game.controls
	var left: String = c.hands[0]
	var right: String = c.hands[1]
	var active := "left" if c.active == 0 else "right"
	var key := "%s|%s|%s" % [left, right, active]
	if key == _shown:
		return
	_shown = key
	game.player.hold(look(left), look(right), active)


## The look of item `id` in a hand (see Figure), {} for an empty hand: the sheet of its
## `sprite` in its mod, or its icon (the tile of the block it places), and the work it
## is used with (`anim`).
func look(id: String) -> Dictionary:
	var item := Items.get_item(id)
	if item.is_empty():
		return {}
	if item.sprite != "":
		return {"sprite": Content.asset(item, "sprites/held/%s.png" % item.sprite), "anim": item.anim}
	if not _pictures.has(id):
		_pictures[id] = ItemIcons.image_of(id)
	return {"icon": id, "picture": _pictures[id], "anim": item.anim}
