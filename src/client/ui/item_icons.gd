extends RefCounted
## Pictures of items for the bag and the hotbar, and the small pictures of the interface
## (the hand, the sack, the vitals' heart, food and bolt, the weight). An item's `icon`
## names `content/<mod>/icons/<icon>.png` of its mod (12×12, drawn once by
## `tools/art/icon_art.gd` and written by `tools/make_icons.gd`, so a mod paints its own);
## an item without one shows the material it places as a small block, drawn from its
## tiles in the atlas the HUD is given (see use_atlas, block_image). The interface's
## pictures are `assets/ui/<name>.png`.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Items := preload("res://src/shared/content/items.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")

## The interface's own pictures (see picture), among them the bare hands (`hand` the right one,
## `hand_left`) and the empty slots of the character (`slot_<place>`, Inventory's places).
const UI := ["hand", "hand_left", "sack", "heart", "heart_big", "heart_gold", "food", "bolt", "weight", "thermo",
	"drop", "water", "sleep", "slot_head", "slot_body", "slot_legs", "slot_feet", "slot_back", "slot_neck",
	"slot_wrists", "slot_ornament"]
## The warm light and the cool shade a block's picture is lit with (see block_image).
const BLOCK_LIGHT := Color("#fff4d6")
const BLOCK_SHADE := Color("#141028")

static var _cache := {}
## Where each item's picture lies, by its bundle, mod and icon (see icon_path): looking
## for the file costs a check of the disk each time, and the hotbar asks on every change.
static var _paths := {}
## The images the pictures were made from, by their file (see image_of).
static var _images := {}
## The pictures of the blocks, by material (see block_image).
static var _blocks := {}
static var _atlas: Texture2D
static var _tile := 16
static var _tiles := 1


## The terrain atlas the tiles of block items are cut from.
static func use_atlas(atlas: Texture2D, tile: int, tiles: int) -> void:
	_atlas = atlas
	_tile = tile
	_tiles = tiles
	_cache.clear()
	_blocks.clear()


## Where item `item` keeps its picture `icon`: in its bundle (see Content.asset).
static func icon_path(item: Dictionary) -> String:
	var key := "%s|%s|%s" % [item.get("bundle", ""), item.get("mod", ""), item.icon]
	if not _paths.has(key):
		_paths[key] = Content.asset(item, "icons/%s.png" % item.icon)
	return _paths[key]


## Where the interface's picture `name` is.
static func ui_path(name: String) -> String:
	return "res://assets/ui/%s.png" % name


## Forgets the pictures read, for a hot reload of the mods (ModReload): the items'
## icons are read again, from their files (Content.picture).
static func forget() -> void:
	_cache = {}
	_paths = {}
	_images = {}
	_blocks = {}
	UiStyle.forget()


## The interface's picture `name` (see UI), null for none.
static func picture(name: String) -> Texture2D:
	return _read(ui_path(name))


## The picture of the first loaded item used as a tool of `kind` (an axe, a pickaxe),
## null when no mod has one.
static func of_tool(kind: String) -> Texture2D:
	return of_item(Items.with_tool(kind))


## The picture at `path`, read once, null when there is none.
static func _read(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	var img := Content.picture(path)
	if img != null:
		tex = ImageTexture.create_from_image(img)
		_images[path] = img
		UiStyle.remember(tex, img)
	_cache[path] = tex
	return tex


## The image of item `id`'s picture (see of_item), null for none: kept from the file,
## not read back from the texture, which in the browser waits for the graphics card.
static func image_of(id: String) -> Image:
	var item := Items.get_item(id)
	if item.is_empty():
		return null
	if item.icon != "":
		var path := icon_path(item)
		_read(path)
		return _images.get(path)
	var m := Mat.index(item.place)
	return block_image(m) if m >= 0 else null


## The picture of item `id`: its icon, or the block of the material it places.
static func of_item(id: String) -> Texture2D:
	var item := Items.get_item(id)
	if item.is_empty():
		return null
	if item.icon != "":
		return _read(icon_path(item))
	var m := Mat.index(item.place)
	return block(m) if m >= 0 else null


## The picture of stack `s` (a bag slot's array, Inventory.slots; null: none): its item's,
## in the colours of its dye when it is dyed (dyed).
static func of_stack(s) -> Texture2D:
	if s == null:
		return null
	var dye := Inventory.dye_of(s)
	return dyed(s[0], dye) if dye != "" else of_item(s[0])


## The picture of item `id` dyed with dye `dye` (Items.cloth, Items.dye_shades): the
## pixels of its cloth's three colours in the dye's three shades; made once.
static func dyed(id: String, dye: String) -> Texture2D:
	var key := "dye:%s:%s" % [id, dye]
	if _cache.has(key):
		return _cache[key]
	var img := image_of(id)
	var cloth := Items.cloth(id)
	var shades := Items.dye_shades(dye)
	if img == null or cloth.size() != 3 or shades.size() != 3:
		return of_item(id)
	img = img.duplicate()
	var to := {}
	for i in 3:
		to[(cloth[i] as Color).to_rgba32() | 0xff] = shades[i]
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			var k := Color(p.r, p.g, p.b).to_rgba32() | 0xff
			if p.a > 0.0 and to.has(k):
				var c: Color = to[k]
				img.set_pixel(x, y, Color(c.r, c.g, c.b, p.a))
	var tex := ImageTexture.create_from_image(img)
	UiStyle.remember(tex, img)
	_cache[key] = tex
	return tex


## The average colour of item `id`'s picture, `fallback` without one.
static func colour_of(id: String, fallback: Color) -> Color:
	var img := image_of(id)
	if img == null:
		return fallback
	var sum := Color(0, 0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			sum += Color(p.r, p.g, p.b, 1.0) * p.a
	return Color(sum.r / sum.a, sum.g / sum.a, sum.b / sum.a) if sum.a > 0.0 else fallback


## The picture of material `m` as a block (see block_image), null without the atlas.
static func block(m: int) -> Texture2D:
	var key := "block:%d" % m
	if _cache.has(key):
		return _cache[key]
	var img := block_image(m)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	UiStyle.remember(tex, img)
	_cache[key] = tex
	return tex


## Material `m` as a small cube in the items' style (tools/art/icon_art.gd), the way the
## items' metal bars lie: 12x12, its front a square of its side tile, shaded towards the
## bottom, under a lid of two rows of its top tile going back up to the right, lit, with
## a pixel of shine, and its right side two columns of the side tile in shade; an outline
## round it in a dark tone of its colour. Made once from the atlas, null without it.
static func block_image(m: int) -> Image:
	if _blocks.has(m):
		return _blocks[m]
	if _atlas == null:
		return null
	var atlas_img: Image = PixelTextures.atlas_image if PixelTextures.atlas_image != null else _atlas.get_image()
	var top := _tile_at(m * 3)
	var side := _tile_at(m * 3 + 1)
	# The pieces are cut from the middle of the tiles.
	var o := int((_tile - 8) / 2.0)
	var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 8:
		for x in 8:
			var c := atlas_img.get_pixelv(side + Vector2i(x + o, y + o)).lerp(BLOCK_SHADE, 0.04 * y)
			if y == 0:
				c = c.lerp(BLOCK_LIGHT, 0.18)
			img.set_pixel(1 + x, 3 + y, c)
	for x in 8:
		img.set_pixel(2 + x, 2, atlas_img.get_pixelv(top + Vector2i(x + o, o + 5)).lerp(BLOCK_LIGHT, 0.3))
		img.set_pixel(3 + x, 1, atlas_img.get_pixelv(top + Vector2i(x + o, o + 3)).lerp(BLOCK_LIGHT, 0.42))
	for y in 7:
		img.set_pixel(9, 3 + y, atlas_img.get_pixelv(side + Vector2i(o + 8, y + o)).lerp(BLOCK_SHADE, 0.35))
		img.set_pixel(10, 2 + y, atlas_img.get_pixelv(side + Vector2i(o + 9, y + o)).lerp(BLOCK_SHADE, 0.45))
	img.set_pixel(3, 1, img.get_pixel(3, 1).lerp(BLOCK_LIGHT, 0.6))
	var line := _block_outline(atlas_img, top)
	var filled := img.duplicate()
	for y in 12:
		for x in 12:
			if filled.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < 12 and n.y < 12 and filled.get_pixelv(n).a > 0.0:
					img.set_pixel(x, y, line)
					break
	_blocks[m] = img
	return img


## The outline of a block's picture: the mean colour of its top tile (at `top` in the atlas
## `atlas_img`), darker and a little more saturated, like the outlines of the items' ramps.
static func _block_outline(atlas_img: Image, top: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y in _tile:
		for x in _tile:
			sum += atlas_img.get_pixelv(top + Vector2i(x, y))
	var mean := sum / float(_tile * _tile)
	return Color.from_hsv(mean.h, minf(1.0, mean.s * 1.25), mean.v * 0.4)


## The corner of tile `t` of the atlas.
static func _tile_at(t: int) -> Vector2i:
	return Vector2i((t % _tiles) * _tile, floori(t / float(_tiles)) * _tile)
