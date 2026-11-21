extends SceneTree
## Draws the pictures of the player and of the tools held (tools/art/) and saves them as
## the mods' sprites, which the game reads: content/core/sprites/player/<layer>.png,
## player/hands.png and held/lump.png (what a hand shows of a thing without a sheet or an
## icon) in core, held/<tool>.png in the bundle of the item that names the sprite,
## worn/<look>.png (clothes on the figure) in the bundle of the item of that look, and
## for the body's forms player/forms/<build>_<figure>/<layer>.png and worn/<look>/<build>_<figure>.png;
## and the animals drawn from the user's references (ANIMALS) as their species' pictures,
## sprites/creatures/<sprite>.png in the bundle of the species. A picture painted over by hand
## is overwritten, so name the pictures to make (an animal by its file, boar.png):
## godot --headless --path . --script res://tools/make_sprites.gd -- <picture ...> | --all

const Figure := preload("res://src/client/view/figure.gd")
const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const PlayerArt := preload("res://tools/art/player_art.gd")
const FormsArt := preload("res://tools/art/player_forms_art.gd")
const ToolArt := preload("res://tools/art/tool_art.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")

## The animals drawn here, by their species' `sprite`: the art module of each (a `sheet()`).
const ANIMALS := {
	"boar": preload("res://tools/art/boar_art.gd"),
	"deer": preload("res://tools/art/deer_art.gd"),
	"fox": preload("res://tools/art/fox_art.gd"),
}

## Clothes as worn on the figure, by the items' `look`: the shape (PlayerArt.SHAPES)
## and its light, middle and dark colour, then the trim's light and dark (PlayerArt.painted).
const WORN := {
	"fiber_hat": ["brim_hat", "e0c878", "c4ac72", "94783e", "8a5a30", "5a3a20"],
	"fiber_tunic": ["tunic", "c4ac72", "94783e", "6e5a2c", "8a6a40", "5a4428"],
	"flower_wreath": ["wreath", "78a048", "557a38", "3a5a28", "f2d24a", "f4f0e8"],
	"bandana": ["bandana", "e8e0cc", "c8bca0", "9a8e74", "b8a888", "7a6e58"],
	"hood": ["hood", "d9cfba", "b5aa92", "857a64", "9a8e74", "6e6450"],
	"linen_shirt": ["shirt", "e8e0cc", "c8bca0", "9a8e74"],
	"leather_hat": ["dome_hat", "b07a48", "8a5a30", "5e3c20", "4a3020", "2e1c10"],
	"leather_vest": ["vest", "b07a48", "8a5a30", "5e3c20", "d8c9a8", "9a8e74"],
	"apron": ["apron", "b07a48", "8a5a30", "5e3c20", "5e3c20", "3a2414"],
	"kilt": ["kilt", "b8946c", "8c6a48", "5a4a2e", "6e4828", "4a3018"],
	"linen_trousers": ["trousers", "e8e0cc", "c8bca0", "9a8e74"],
	"sandals": ["sandals", "b07a48", "8a5a30", "5e3c20", "9a6a3e", "6e4828"],
	"moccasins": ["moccasins", "b8946c", "8c6a48", "70502e", "e8dcc0", "b8a888"],
	"high_boots": ["high_boots", "8a5a30", "6a4424", "5e3c20", "a07040", "6a4424"],
	"shell_beads": ["beads", "f4ece0", "d8c9a8", "a89880", "8a6a40", "5a4428"],
	"tooth_necklace": ["fangs", "e8e0cc", "c8bca0", "4a3020", "f0ead8", "c8bca0"],
	"bone_amulet": ["amulet", "e8dcc0", "b8a888", "4a3020"],
	"bracelet": ["bracelet", "b8946c", "8c6a48", "6e3a20"],
	"copper_ring": ["ring", "e09a5a", "c0703a", "8a4e28", "c86a30", "8a4e28"],
	"hair_feather": ["feather", "f0f0f0", "a0a8b0", "606870", "c8b890", "8a7a50"],
	"poncho": ["poncho", "d9cfba", "b5aa92", "857a64", "7a5a3a", "4a3422"],
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
		pictures[_worn_path(look)] = PlayerArt.painted(w[0], _tones(look))
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
	for sprite: String in ANIMALS:
		pictures[_creature_path(sprite)] = ANIMALS[sprite].sheet()
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
			var img := PlayerArt.painted(w[0], _tones(look))
			var base := _worn_path(look)
			var at := "%s/%s.png" % [base.get_basename(), form]
			var instead: Image = pictures.get("%s/%s.png" % [base.get_basename(), straight], pictures[base])
			if img.get_data() != instead.get_data():
				pictures[at] = img
	PlayerArt.use_form("normal", "straight")


## Where the picture of clothes `look` goes: sprites/worn/ of the bundle of the item
## with that look.
func _worn_path(look: String) -> String:
	for item in Items.BY_ID.values():
		if item.get("look", "") == look:
			return Content.asset(item, "sprites/worn/%s.png" % look)
	push_error("no item looks %s" % look)
	return "res://%s.png" % look


## The five colours clothes `look` are drawn in (WORN): those of a thing that can be dyed
## (Items.cloth, which its WORN colours must be) with its cloth in the key colours of its
## slot (Figure.dye_key), so the shader shows its own colours or a dye's; a look of three
## colours has no trim of its own, so all of it takes the dye.
func _tones(look: String) -> Array:
	var w: Array = WORN[look]
	var tones: Array = w.slice(1)
	for item in Items.BY_ID.values():
		if item.get("look", "") != look or not Items.dyeable(item.id):
			continue
		for i in 3:
			if (item.cloth[i] as Color).to_html(false) != tones[i]:
				push_error("%s: WORN colour %s is not its cloth %s" % [look, tones[i], (item.cloth[i] as Color).to_html(false)])
		var keys := []
		for i in 3:
			keys.append(Figure.dye_key(item.wear_on, i).to_html(false))
		return keys + (tones.slice(3, 5) if tones.size() >= 5 else [keys[1], keys[2]])
	return tones


## Where the picture of the animals with `sprite` goes: sprites/creatures/ of the bundle of the
## species that names it.
func _creature_path(sprite: String) -> String:
	for spec: Dictionary in AiRules.SPECIES.values():
		if spec.get("sprite", "") == sprite:
			return Content.asset(spec, "sprites/creatures/%s.png" % sprite)
	push_error("no species draws %s" % sprite)
	return "res://%s.png" % sprite


## Where the sheet of `sprite` goes: beside the item that holds it, or core's held/ when none does.
func _held_path(sprite: String) -> String:
	for item in Items.BY_ID.values():
		if item.sprite == sprite:
			return Content.asset(item, "sprites/held/%s.png" % sprite)
	return "%s/held/%s.png" % [Figure.SPRITES, sprite]
