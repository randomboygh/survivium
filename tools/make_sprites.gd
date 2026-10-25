extends SceneTree
## Draws the pictures of the player and of the tools held (tools/art/) and saves them as
## the mods' sprites, which the game reads: content/core/sprites/player/<layer>.png,
## player/hands.png and held/lump.png (what a hand shows of a thing without a sheet or an
## icon) in core, held/<tool>.png in the bundle of the item that names the sprite. A picture painted over by hand is overwritten, so name
## the pictures to make:
## godot --headless --path . --script res://tools/make_sprites.gd -- [picture ...]

const Figure := preload("res://src/client/view/figure.gd")
const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const PlayerArt := preload("res://tools/art/player_art.gd")
const ToolArt := preload("res://tools/art/tool_art.gd")

## Tools and their work.
const HELD := {
	"axe": "chop",
	"pickaxe": "chop",
	"shovel": "dig",
	"sword": "slash",
	"scythe": "mow",
	"stone_sword": "slash",
	"wooden_pickaxe": "chop",
	"wooden_scythe": "mow",
	"copper_axe": "chop",
	"copper_pickaxe": "chop",
	"copper_shovel": "dig",
	"copper_sword": "slash",
	"copper_scythe": "mow",
	"torch": "reach",
}
const LUMP := [
	".aaa.",
	"aAaaq",
	"aaaaq",
	".qqq.",
]


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var dir := Figure.SPRITES
	var pictures := {}
	for name in Figure.data().layers + [Figure.data().fists]:
		pictures["player/" + name] = PlayerArt.layer(name)
	pictures["player/" + Figure.data().hands] = PlayerArt.marks()
	for name in HELD:
		pictures[_held_path(name)] = ToolArt.sheet(name, HELD[name])
	var lump := Image.create_empty(LUMP[0].length(), LUMP.size(), false, Image.FORMAT_RGBA8)
	lump.fill(Color(0, 0, 0, 0))
	for y in LUMP.size():
		for x in LUMP[y].length():
			if LUMP[y][x] != ".":
				lump.set_pixel(x, y, Color.html(ToolArt.INK[LUMP[y][x]]))
	pictures["held/lump"] = lump
	for path in pictures:
		if only.is_empty() or only.has(path.get_file()) or only.has(path):
			var file: String = ProjectSettings.globalize_path(path if path.begins_with("res://") else "%s/%s.png" % [dir, path])
			DirAccess.make_dir_recursive_absolute(file.get_base_dir())
			pictures[path].save_png(file)
			print("saved ", file)
	quit()


## Where the sheet of `sprite` goes: beside the item that holds it, or core's held/ when none does.
func _held_path(sprite: String) -> String:
	for item in Items.BY_ID.values():
		if item.sprite == sprite:
			return Content.asset(item, "sprites/held/%s.png" % sprite)
	return "%s/held/%s.png" % [Figure.SPRITES, sprite]
