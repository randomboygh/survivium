extends RefCounted
## Pictures of items for the bag and the hotbar, and the small pictures of the interface
## (the hand, the sack, the vitals' heart, food and bolt, the weight). An item's `icon`
## names `content/<mod>/icons/<icon>.png` of its mod (12×12, drawn once by
## `tools/art/icon_art.gd` and written by `tools/make_icons.gd`, so a mod paints its own);
## an item without one shows the terrain tile of the material it places, cut from the
## atlas the HUD is given (see use_atlas). The interface's pictures are `assets/ui/<name>.png`.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Items := preload("res://src/shared/content/items.gd")
const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")

## The interface's own pictures (see picture).
const UI := ["hand", "sack", "heart", "food", "bolt", "weight"]

static var _cache := {}
## The images the pictures were made from, by their file (see image_of).
static var _images := {}
static var _atlas: Texture2D
static var _tile := 16
static var _tiles := 1


## The terrain atlas the tiles of block items are cut from.
static func use_atlas(atlas: Texture2D, tile: int, tiles: int) -> void:
	_atlas = atlas
	_tile = tile
	_tiles = tiles
	_cache.clear()


## Where item `item` keeps its picture `icon`: in its bundle (see Content.asset).
static func icon_path(item: Dictionary) -> String:
	return Content.asset(item, "icons/%s.png" % item.icon)


## Where the interface's picture `name` is.
static func ui_path(name: String) -> String:
	return "res://assets/ui/%s.png" % name


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
	if ResourceLoader.exists(path):
		var img: Image = load(path).get_image()
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
	if m < 0 or _atlas == null:
		return null
	var at: Rect2 = (tile(m) as AtlasTexture).region
	var atlas_img: Image = PixelTextures.atlas_image if PixelTextures.atlas_image != null else _atlas.get_image()
	return atlas_img.get_region(Rect2i(at))


## The picture of item `id`: its icon, or the tile of the material it places.
static func of_item(id: String) -> Texture2D:
	var item := Items.get_item(id)
	if item.is_empty():
		return null
	if item.icon != "":
		return _read(icon_path(item))
	var m := Mat.index(item.place)
	return tile(m) if m >= 0 else null


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


## The middle 12x12 of the terrain tile of material `m`.
static func tile(m: int) -> Texture2D:
	var key := "tile:%d" % m
	if _cache.has(key):
		return _cache[key]
	if _atlas == null:
		return null
	var t := m * 3
	var icon := AtlasTexture.new()
	icon.atlas = _atlas
	icon.region = Rect2((t % _tiles) * _tile + 2, floori(t / float(_tiles)) * _tile + 2, 12, 12)
	_cache[key] = icon
	if PixelTextures.atlas_image != null:
		UiStyle.remember(icon, PixelTextures.atlas_image.get_region(Rect2i(icon.region)))
	return icon
