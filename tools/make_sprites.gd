extends SceneTree
## Draws the pictures of the player and of the tools held (tools/art/) and saves them as
## the core mod's sprites, which the game reads: content/core/sprites/player/<layer>.png,
## player/hands.png, held/<tool>.png and held/lump.png (what a hand shows of a thing
## without a sheet or an icon). A picture painted over by hand is overwritten, so name
## the pictures to make:
## godot --headless --path . --script res://tools/make_sprites.gd -- [picture ...]

const Figure := preload("res://src/client/view/figure.gd")
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
		pictures["held/" + name] = ToolArt.sheet(name, HELD[name])
	var lump := Image.create_empty(LUMP[0].length(), LUMP.size(), false, Image.FORMAT_RGBA8)
	lump.fill(Color(0, 0, 0, 0))
	for y in LUMP.size():
		for x in LUMP[y].length():
			if LUMP[y][x] != ".":
				lump.set_pixel(x, y, Color.html(ToolArt.INK[LUMP[y][x]]))
	pictures["held/lump"] = lump
	for path in pictures:
		if only.is_empty() or only.has(path.get_file()) or only.has(path):
			var file: String = ProjectSettings.globalize_path("%s/%s.png" % [dir, path])
			DirAccess.make_dir_recursive_absolute(file.get_base_dir())
			pictures[path].save_png(file)
			print("saved ", file)
	quit()
