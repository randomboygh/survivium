extends SceneTree
## Draws the placeholder pictures of the player and of the things held (tools/art/) and
## saves them as the core mod's sprites, which the game reads: content/core/sprites/
## player/<layer>.png, player/hands.png and held/<thing>.png. Run it again after
## changing the placeholders; a picture drawn by hand is overwritten, so leave it out
## (name the pictures to make):
## godot --headless --path . --script res://tools/make_sprites.gd -- [picture ...]

const Figure := preload("res://src/client/figure.gd")
const PlayerArt := preload("res://tools/art/player_art.gd")
const ToolArt := preload("res://tools/art/tool_art.gd")

const STONE := Color(0.56, 0.57, 0.6)
const WOOD := Color(0.72, 0.55, 0.32)
## Things held: their work and the colour of the head.
const HELD := {
	"axe": ["chop", STONE],
	"pickaxe": ["chop", STONE],
	"shovel": ["dig", WOOD],
	"sword": ["slash", WOOD],
	"scythe": ["mow", STONE],
	"lump": ["", Color.WHITE],
}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var dir := Figure.SPRITES
	var pictures := {}
	for name in Figure.data().layers + [Figure.data().fists]:
		pictures["player/" + name] = PlayerArt.layer(name)
	pictures["player/" + Figure.data().hands] = PlayerArt.marks()
	for name in HELD:
		pictures["held/" + name] = ToolArt.sheet(name, HELD[name][1], HELD[name][0])
	for path in pictures:
		if only.is_empty() or only.has(path.get_file()) or only.has(path):
			var file: String = ProjectSettings.globalize_path("%s/%s.png" % [dir, path])
			DirAccess.make_dir_recursive_absolute(file.get_base_dir())
			pictures[path].save_png(file)
			print("saved ", file)
	quit()
