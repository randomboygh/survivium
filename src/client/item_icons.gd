extends RefCounted
## Pictures of items for the bag and the hotbar, and the small state icons of the
## vitals panel. An item's `icon` names a picture here, one character per pixel
## (see PALETTE); an item without one shows the terrain tile of the material it
## places, cut from the atlas the HUD is given (see use_atlas). Placeholder art until
## items get PNG pictures in the mod.

const UiStyle := preload("res://src/client/ui_style.gd")
const Items := preload("res://src/shared/items.gd")
const Mat := preload("res://src/shared/materials.gd")

const PALETTE := {
	"b": Color("#4a3322"), "B": Color("#6b4a2f"), "t": Color("#9a7448"), "l": Color("#557a38"),
	"L": Color("#78a048"), "r": Color("#b8243a"), "R": Color("#e0546a"), "u": Color("#3b4590"),
	"U": Color("#6d7ad0"), "k": Color("#1c140d"), "s": Color("#8a8f94"), "S": Color("#b6bcc1"),
	"o": Color("#c0703a"), "O": Color("#3f9a6a"), "c": Color("#d8c9a8"), "w": UiStyle.INK,
	"h": UiStyle.DANGER, "a": UiStyle.ACCENT, "g": UiStyle.GOOD, "m": UiStyle.MUTED,
}

const PICTURES := {
	"fiber": [
		"............",
		"........L...",
		"...l...L....",
		"....l.Ll..L.",
		"..L.lLl..L..",
		"...LlLl.L...",
		"....lLlL....",
		".....tlt....",
		"....tttt....",
		".....tt.....",
		"....t..t....",
		"............",
	],
	"hand": [
		"............",
		"....c.c.....",
		"...cc.cc.c..",
		"...cc.cc.cc.",
		"...cc.cc.cc.",
		".c.cccccccc.",
		".cccccccccc.",
		"..ccccccccc.",
		"..cccccccc..",
		"...cccccc...",
		"....cccc....",
		"............",
	],
	"axe": [
		"............",
		"......sSs...",
		".....sSSSs..",
		"....bsSSSSs.",
		"...b.sSSSs..",
		"..b...sss...",
		".tb.........",
		".bt.........",
		"tb..........",
		"bt..........",
		"t...........",
		"............",
	],
	"pickaxe": [
		"............",
		"...sSSSs....",
		"..s....Ss...",
		"......t.Ss..",
		".....t...s..",
		"....t....s..",
		"...t........",
		"..t.........",
		".t..........",
		"t...........",
		"............",
		"............",
	],
	"shovel": [
		"............",
		".........tt.",
		"........tb..",
		".......tb...",
		"......tb....",
		"..BBtt......",
		".BtBB.......",
		"BtBBB.......",
		"BBBB........",
		".BB.........",
		"............",
		"............",
	],
	"scythe": [
		"............",
		"..sSSSSs....",
		".s.....SSs..",
		"s.......tSs.",
		".......t..s.",
		"......t.....",
		".....t......",
		"....tb......",
		"...t........",
		"..t.........",
		".t..........",
		"............",
	],
	"grain": [
		"............",
		"............",
		"............",
		"............",
		".....o......",
		"...o.co.o...",
		"..ocoococo..",
		".ococooocoo.",
		".oocoocooco.",
		"ooococoocooo",
		"............",
		"............",
	],
	"flour": [
		"............",
		"............",
		"............",
		".....cc.....",
		"....cwwc....",
		"...cwwwwc...",
		"..cwwwwwwc..",
		".cwwcwwwcwc.",
		".ccwwwcwwcc.",
		"cccccccccccc",
		"............",
		"............",
	],
	"flatbread": [
		"............",
		"............",
		"............",
		"....tttt....",
		"..ttcttcto..",
		".tctoctttct.",
		".ttcttotcto.",
		".otttcttctt.",
		"..ootttoot..",
		"....oooo....",
		"............",
		"............",
	],
	"seeds": [
		"............",
		"............",
		"............",
		"....t.......",
		".......t....",
		"..t..o......",
		"......t..o..",
		"...o.t...t..",
		".t...ot.o...",
		"..ottotto...",
		".tottoototo.",
		"............",
	],
	"sword": [
		"............",
		"..........t.",
		".........tB.",
		"........tB..",
		".......tB...",
		"......tB....",
		"..b..tB.....",
		"...btB......",
		"...bb.......",
		"..b..b......",
		".b..........",
		"............",
	],
	"bush": [
		"............",
		"............",
		"....lL......",
		"...lLLl.L...",
		"..lLlLLlLl..",
		".lLLlLlLLLl.",
		".llLLlLLlLl.",
		"..llLlllLl..",
		"...lbllbl...",
		"....b..b....",
		"...BBBBBB...",
		"............",
	],
	"bush_raspberry": [
		"............",
		"............",
		"....lL......",
		"...lLrl.L...",
		"..lLlLLlrl..",
		".lrLlLlLLLl.",
		".llLLrLLlLl.",
		"..llLlllrl..",
		"...lbllbl...",
		"....b..b....",
		"...BBBBBB...",
		"............",
	],
	"bush_blueberry": [
		"............",
		"............",
		"............",
		"............",
		"....lL.lL...",
		"..lLuLlLul..",
		".lLLlLuLLLl.",
		".luLLlLLuLl.",
		"..llbllbl...",
		"............",
		"...BBBBBB...",
		"............",
	],
	"branch": [
		"..........L.",
		".........lL.",
		"........b...",
		"...L...b....",
		"...lb.b.....",
		".....b......",
		"....b.bL....",
		"...b...l....",
		"..b.........",
		".b..........",
		"b...........",
		"............",
	],
	"log": [
		"............",
		"............",
		"...bbbbbbbb.",
		"..bBBBBBBBct",
		".bBbBBBbBctc",
		".bBBBbBBBtct",
		".bBBBBBBBctc",
		".bbBBBBbBBt.",
		"..bbbbbbbb..",
		"............",
		"............",
		"............",
	],
	"acorn": [
		"............",
		"............",
		".....b......",
		"...BBBBB....",
		"..BBtBtBB...",
		"..bbbbbbb...",
		"...ooooo....",
		"...ooooo....",
		"...ooooo....",
		"....ooo.....",
		".....o......",
		"............",
	],
	"cone": [
		"............",
		".....b......",
		"....BtB.....",
		"...BtBtB....",
		"...tBtBt....",
		"..BtBtBtB...",
		"..tBtBtBt...",
		"..BtBtBtB...",
		"...tBtBt....",
		"...BtBtB....",
		"....BtB.....",
		"............",
	],
	"raspberry": [
		"............",
		".....l......",
		"....lLl.....",
		"..........L.",
		"...rRr...lL.",
		"..rRrRr.....",
		"..rrRrr.rRr.",
		"..RrrrR.RrR.",
		"...rRr..rrr.",
		".........r..",
		"............",
		"............",
	],
	"blueberry": [
		"............",
		"............",
		".........l..",
		"...uu...lL..",
		"..uUuu......",
		"..uuuu.uu...",
		"...uu.uUuu..",
		"......uuuu..",
		"..uu...uu...",
		".uUuu.......",
		".uuuu.......",
		"..uu........",
	],
	"copper_ore": [
		"............",
		"....ssss....",
		"..sSssOss...",
		".sSoossSss..",
		".ssooOsssS..",
		".sSsssooss..",
		".sssOsoosS..",
		"..ssssssss..",
		"...sssss....",
		"............",
		"............",
		"............",
	],
	# State icons of the vitals panel, 9 pixels.
	"flint": [
		"............",
		"............",
		"......ss....",
		"....sskss...",
		"...skkkkSs..",
		"..skkkkkkS..",
		"..skkkkksS..",
		"...sskkkS...",
		".....ssS....",
		"............",
		"............",
		"............",
	],
	"cord": [
		"............",
		"....tttt....",
		"..tt....tt..",
		".t..tttt..t.",
		".t.t....t.t.",
		".t.t.tt.t.t.",
		".t.t.t..t.t.",
		".t..t..t..t.",
		"..t..tt..t..",
		"...tt..tt.t.",
		".......tt..t",
		"............",
	],
	"workbench": [
		"............",
		"............",
		"....ss......",
		".tttttttttt.",
		".BBBBBBBBBB.",
		".b........b.",
		".b........b.",
		".b........b.",
		".bbbbbbbbbb.",
		".b........b.",
		".b........b.",
		"............",
	],
	"kiln": [
		"............",
		".....kk.....",
		"....oooo....",
		"...oossoo...",
		"..oosoooso..",
		"..osoooooo..",
		".oooookkooo.",
		".osookkkoso.",
		".ooookookoo.",
		".ssssoossss.",
		"............",
		"............",
	],
	"campfire": [
		"............",
		".....R......",
		"....RoR.....",
		"....ooR.....",
		"...oRooR....",
		"...ooRoo....",
		"..b.oooo.b..",
		"...bBttBb...",
		"..BbtBBtbB..",
		".bB.b..b.Bb.",
		"............",
		"............",
	],
	"chest": [
		"............",
		"............",
		"..bbbbbbbb..",
		".bBBBBBBBBb.",
		".bBBBBBBBBb.",
		".bbbbaabbbb.",
		".bBBBaaBBBb.",
		".bBBBBBBBBb.",
		".bBBBBBBBBb.",
		".bbbbbbbbbb.",
		"............",
		"............",
	],
	"heart": [
		".hh...hh.",
		"hhhh.hhhh",
		"hhhhhhhhh",
		"hhhhhhhhh",
		".hhhhhhh.",
		"..hhhhh..",
		"...hhh...",
		"....h....",
		".........",
	],
	"food": [
		"....l....",
		"...lL....",
		"..aaaa...",
		".aaaaaa..",
		".aawaaa..",
		".aaaaaa..",
		".aaaaaa..",
		"..aaaa...",
		".........",
	],
	"bolt": [
		".....gg..",
		"....gg...",
		"...gg....",
		"..gggggg.",
		".....gg..",
		"....gg...",
		"...gg....",
		"..g......",
		".........",
	],
	"weight": [
		"...mmm...",
		"..m...m..",
		"..m...m..",
		".mmmmmmm.",
		"mmmmmmmmm",
		"mmmmmmmmm",
		"mmmmmmmmm",
		".mmmmmmm.",
		".........",
	],
}

static var _cache := {}
static var _atlas: Texture2D
static var _tile := 16
static var _tiles := 1


## The terrain atlas the tiles of block items are cut from.
static func use_atlas(atlas: Texture2D, tile: int, tiles: int) -> void:
	_atlas = atlas
	_tile = tile
	_tiles = tiles
	_cache.clear()


## The picture of a named icon (see PICTURES).
static func picture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var rows: Array = PICTURES.get(name, [])
	if rows.is_empty():
		return null
	var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if PALETTE.has(row[x]):
				img.set_pixel(x, y, PALETTE[row[x]])
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex


## The picture of item `id`: its icon, or the tile of the material it places.
static func of_item(id: String) -> Texture2D:
	var item := Items.get_item(id)
	if item.is_empty():
		return null
	if item.icon != "":
		return picture(item.icon)
	var m := Mat.index(item.place)
	return tile(m) if m >= 0 else null


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
	return icon
