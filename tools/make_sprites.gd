extends SceneTree
## Draws the pictures of the player and of the tools held (tools/art/) and saves them as
## the mods' sprites, which the game reads: content/core/sprites/player/<layer>.png,
## player/hands.png and held/lump.png (what a hand shows of a thing without a sheet or an
## icon) in core, held/<tool>.png in the bundle of the item that names the sprite,
## worn/<look>.png (clothes on the figure) in the bundle of the item of that look, and
## for the body's forms player/forms/<build>_<figure>/<layer>.png and worn/<look>/<build>_<figure>.png. A picture painted over by hand is overwritten, so name
## the pictures to make:
## godot --headless --path . --script res://tools/make_sprites.gd -- <picture ...> | --all

const Figure := preload("res://src/client/view/figure.gd")
const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const PlayerArt := preload("res://tools/art/player_art.gd")
const FormsArt := preload("res://tools/art/player_forms_art.gd")
const ToolArt := preload("res://tools/art/tool_art.gd")

## Clothes as worn on the figure, by the items' `look`: the shape (PlayerArt.SHAPES)
## and its light, middle and dark colour.
const WORN := {
	"fiber_hat": ["hat", "c4ac72", "94783e", "6e5a2c"],
	"grass_cape": ["shirt", "8fb558", "78a048", "557a38"],
	"leg_wraps": ["wraps", "c4ac72", "94783e", "6e5a2c"],
	"bast_shoes": ["boots", "c4ac72", "94783e", "6e5a2c"],
	"fur_hat": ["hat", "d8c9a8", "9a7448", "6b4a2f"],
	"fur_coat": ["coat", "b48a5a", "9a7448", "6b4a2f"],
	"leather_trousers": ["trousers", "e09a5a", "c0703a", "8a4e28"],
	"fur_boots": ["tall_boots", "b48a5a", "9a7448", "6b4a2f"],
}

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
	"bronze_axe": "chop",
	"bronze_pickaxe": "chop",
	"bronze_shovel": "dig",
	"bronze_sword": "slash",
	"bronze_scythe": "mow",
	"iron_axe": "chop",
	"iron_pickaxe": "chop",
	"iron_shovel": "dig",
	"iron_sword": "slash",
	"iron_scythe": "mow",
	"steel_axe": "chop",
	"steel_pickaxe": "chop",
	"steel_shovel": "dig",
	"steel_sword": "slash",
	"steel_scythe": "mow",
	"flint_knife": "slash",
	"copper_knife": "slash",
	"bronze_knife": "slash",
	"iron_knife": "slash",
	"steel_knife": "slash",
	"sickle": "slash",
	"copper_sickle": "slash",
	"iron_sickle": "slash",
	"flint_spear": "slash",
	"bronze_spear": "slash",
	"iron_spear": "slash",
	"cord_sling": "slash",
	"fishing_rod": "slash",
	"winter_rod": "slash",
	"ice_pick": "dig",
	"ice_auger": "dig",
	"wooden_bow": "aim",
	"leather_sling": "slash",
	"composite_bow": "aim",
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
	# Everything is drawn again only when asked for by `--all`: what was painted over
	# by hand would be lost.
	if only.is_empty():
		printerr("name what to make, or --all for everything (it overwrites what was painted by hand)")
		quit(1)
		return
	if only == PackedStringArray(["--all"]):
		only = PackedStringArray()
	var dir := Figure.SPRITES
	var pictures := {}
	for name in Figure.data().layers + [Figure.data().fists, Figure.data().trail]:
		pictures["player/" + name] = PlayerArt.layer(name)
	# The looks to pick (player.yaml `looks`): a picture each but for bald.
	for style in PlayerArt.LooksArt.HAIRS:
		if style != "bald":
			pictures["player/hair/" + style] = PlayerArt.layer("hair/" + style)
	for option in PlayerArt.LooksArt.FACES:
		pictures["player/face/" + option] = PlayerArt.layer("face/" + option)
	for look in WORN:
		var w: Array = WORN[look]
		pictures[_worn_path(look)] = PlayerArt.painted(w[0], w.slice(1))
	pictures["player/" + Figure.data().hands] = PlayerArt.marks()
	_forms(pictures)
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


## The body's forms (FormsArt, player.yaml `looks` build and figure): the layers and the
## clothes worn drawn again in each, kept only where they differ from what the game
## takes instead (Figure._form_path: the build straight, else the plain picture).
func _forms(pictures: Dictionary) -> void:
	var names: Array = Figure.data().layers + [Figure.data().fists, Figure.data().hands]
	for form: String in FormsArt.all().slice(1):
		var parts := form.split("_")
		PlayerArt.use_form(parts[0], parts[1])
		var straight := parts[0] + "_straight"
		for name: String in names:
			var img: Image = PlayerArt.marks() if name == Figure.data().hands else PlayerArt.layer(name)
			var instead: Image = pictures.get("player/forms/%s/%s" % [straight, name], pictures["player/" + name])
			if img.get_data() != instead.get_data():
				pictures["player/forms/%s/%s" % [form, name]] = img
		for look: String in WORN:
			var w: Array = WORN[look]
			var img := PlayerArt.painted(w[0], w.slice(1))
			var base := _worn_path(look)
			var at := "%s/%s.png" % [base.get_basename(), form]
			var instead: Image = pictures.get("%s/%s.png" % [base.get_basename(), straight], pictures[base])
			if img.get_data() != instead.get_data():
				pictures[at] = img
	PlayerArt.use_form("normal", "straight")


## Where the sheet of `sprite` goes: beside the item that holds it, or core's held/ when none does.
## Where the picture of clothes `look` goes: sprites/worn/ of the bundle of the item
## with that look.
func _worn_path(look: String) -> String:
	for item in Items.BY_ID.values():
		if item.get("look", "") == look:
			return Content.asset(item, "sprites/worn/%s.png" % look)
	push_error("no item looks %s" % look)
	return "res://%s.png" % look


func _held_path(sprite: String) -> String:
	for item in Items.BY_ID.values():
		if item.sprite == sprite:
			return Content.asset(item, "sprites/held/%s.png" % sprite)
	return "%s/held/%s.png" % [Figure.SPRITES, sprite]
