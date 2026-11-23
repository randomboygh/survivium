extends RefCounted
## The pictures of the items and the small pictures of the interface, drawn one character
## per pixel: `tools/make_icons.gd` writes the items' into `content/<mod>/icons/<icon>.png`
## and the interface's into `assets/ui/<name>.png`, where the game reads them and where
## they can be painted over by hand. Not loaded by the game.
##
## The items' pictures (ART of the parts, PARTS) are drawn in the style of the reference
## sheets the user gave (2026-11-22): every thing in ramps of hue-shifted tones (RAMPS:
## shades cooler, lights warmer), lit from the upper left with a pixel or two of shine,
## and closed by an outline a pixel wide in the darkest tone of what it runs round,
## drawn by `drawn` round whatever is filled. The interface's small pictures (PICTURES,
## ItemIcons.UI) are drawn in PALETTE's letters, but for the bare hands and the empty slots
## of the character, drawn as the items are (in the wear part).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const NatureArt := preload("res://tools/art/icon_nature_art.gd")
const MaterialArt := preload("res://tools/art/icon_material_art.gd")
const ToolArt := preload("res://tools/art/icon_tool_art.gd")
const WearArt := preload("res://tools/art/icon_wear_art.gd")
const BuildArt := preload("res://tools/art/icon_build_art.gd")

## The parts that hold the items' pictures: each has ART (name -> [the ramps it is drawn
## in, its rows]) and VARIANTS (name -> [a picture of ART, {ramp: the ramp it is drawn in
## instead}]: the same thing of another metal or colour).
const PARTS := [NatureArt, MaterialArt, ToolArt, WearArt, BuildArt]

## The letters of ART's rows: four for each ramp a picture names, in the order it names
## them, for the ramp's shade, body, light and shine; the first one's capital is the ramp's
## outline drawn by hand (inside a thing, or where the outline drawn round it would not
## do). `#` is an outline inside a thing in the darkest outline of the ramps beside it,
## `.` is empty (outlined where it touches something filled by a side) and `,` is empty
## and never outlined.
const GROUPS := ["abcd", "efgh", "ijkl", "mnop", "qrst", "uvwx"]

## The colours things are drawn in, five to a ramp from the dark: the outline, the shade,
## the body, the light and the shine. A ramp of a thing that can be dyed has the item's
## `cloth` colours (light, middle, dark) as its light, body and shade, which the dyes swap
## (ItemIcons.dyed); its pictures leave the shine out.
const RAMPS := {
	"bark": ["#42221a", "#64392a", "#8a573a", "#ae7b50", "#d0a46e"],
	"endgrain": ["#6e3c20", "#b47a44", "#d8a462", "#f0ca88", "#fff0c0"],
	"wood": ["#4a2014", "#7c3e24", "#a8643a", "#d0924f", "#f2c47c"],
	"stone": ["#34323e", "#5a5868", "#86848f", "#b4b2b6", "#e2e0da"],
	"flint": ["#23283a", "#384058", "#56627e", "#8290ae", "#cfdcf0"],
	"chalk": ["#5a5a62", "#a4a4ac", "#cacaca", "#ecece6", "#ffffff"],
	"rock": ["#2e2a30", "#4c4650", "#6e6872", "#948e94", "#bcb6b8"],
	"copper": ["#5a1c10", "#923622", "#c85e30", "#ec914c", "#fdd08e"],
	"iron": ["#262c40", "#464f68", "#6e7a94", "#a0acc2", "#dde6f0"],
	"cord": ["#4e3412", "#7e5a26", "#a8843c", "#ceaa5a", "#ecd690"],
	"leather": ["#4a2414", "#6e3c20", "#965a30", "#bc7e48", "#e0ac76"],
	"red": ["#5a1424", "#9a2232", "#d0383e", "#f06c54", "#ffc8a8"],
	"leaf": ["#1c3a14", "#305a22", "#4e8a30", "#7cb440", "#bce070"],
	"meat": ["#5a1420", "#8e1e2c", "#c0303c", "#e0606a", "#ffb0b0"],
	"bone": ["#5a4a34", "#a8926e", "#d2bc96", "#f0e2c2", "#fffcf2"],
	"linen": ["#4e4636", "#9a8e74", "#c8bca0", "#e8e0cc", "#fffaf0"],
	"fire": ["#6a160a", "#c0340e", "#f27418", "#fdb634", "#fff6b4"],
	"perch": ["#2c3c18", "#56702a", "#86a23a", "#bcd256", "#f0f4a8"],
	"fin": ["#6a2410", "#b04418", "#e47028", "#faa44c", "#ffdca4"],
	"raspberry": ["#5a1030", "#9c1e48", "#d23a5e", "#f26c80", "#ffc4cc"],
	"planks": ["#5a3418", "#9a6436", "#c48c50", "#e2b470", "#f6dca0"],
	"bronze": ["#4a2a0c", "#7d4c19", "#b47d2e", "#dbab4c", "#f6dc94"],
	"tin": ["#2e3036", "#5b5e68", "#8d9098", "#bcbfc4", "#ebedec"],
	"steel": ["#1e2e4c", "#3a5a80", "#6090b8", "#98c6e4", "#e0f6ff"],
	"silver": ["#30344a", "#6a6e88", "#a3a9bf", "#d3d8e6", "#ffffff"],
	"gold": ["#6e2c08", "#b06016", "#e4a024", "#fad048", "#fff4ac"],
	"platinum": ["#2a3a44", "#587280", "#90aab4", "#c6dcdc", "#f2fdf8"],
	"fibre": ["#2e3a10", "#5a6a22", "#8a9838", "#b8c45a", "#e4ec9a"],
	"straw": ["#5a3e14", "#8c6a28", "#b8923c", "#dcbc5c", "#f6e49a"],
	"nut": ["#4a2a10", "#8a5420", "#c08038", "#e0a858", "#f8d898"],
	"roast": ["#3a1608", "#6e3014", "#a05424", "#cc8040", "#f0b878"],
	"black": ["#1a1020", "#2e1c38", "#4a2c58", "#725088", "#b8a0d0"],
	"blue": ["#141c40", "#263a78", "#3c5aac", "#6a8ad8", "#c0d4ff"],
	"orange": ["#5a1c08", "#a43c10", "#e06a1c", "#f8a040", "#ffdc98"],
	"yellow": ["#5a400c", "#a8801c", "#e0bc30", "#f8e060", "#fffcc0"],
	"coconut": ["#2c1a10", "#4e3020", "#765034", "#9c7450", "#c8a47c"],
	"pink": ["#5a1440", "#a02866", "#d84a8c", "#f47cb0", "#ffc8e0"],
	"purple": ["#3a1448", "#6a2880", "#9a48b0", "#c47cd8", "#ecc4f8"],
	"white": ["#4a4a58", "#a4a4b4", "#d0d0d8", "#f0f0f0", "#ffffff"],
	"pea": ["#1c3c10", "#3a6a1c", "#5c9a2c", "#8cc848", "#c8f088"],
	"wheat": ["#5a3c0c", "#9a7020", "#d0a438", "#ecd064", "#fff4b0"],
	"bread": ["#4a2410", "#8a4c1c", "#c47e34", "#e4ac58", "#f8dc98"],
	"mushroom": ["#3a180c", "#6e3218", "#a0582c", "#c8844a", "#ecbc84"],
	"glow": ["#0c3438", "#18706c", "#2cb4a4", "#6ae8cc", "#d4fff4"],
	"moss": ["#1a3010", "#2e5218", "#4a7a24", "#74a838", "#b0d868"],
	"woad": ["#14302c", "#2a5a50", "#44867a", "#6eb4a4", "#b4e4d8"],
	"madder": ["#4a1014", "#8a2024", "#bc3a36", "#e06650", "#f8a888"],
	"clay": ["#4a1c10", "#7c3422", "#b0583a", "#d6825a", "#f0b088"],
	"tea": ["#4a1c08", "#8a3c10", "#c06420", "#e09040", "#f8c880"],
	"ash": ["#34343c", "#5c5c66", "#8a8a92", "#b4b4b8", "#dcdcdc"],
	"juniper": ["#122a22", "#1e4636", "#2e6a4e", "#4a9468", "#8cc49c"],
	"fish": ["#1e2c3a", "#4a6278", "#7c98ac", "#b4ccd8", "#eaf6fc"],
	"finred": ["#5a1418", "#9c2828", "#d04838", "#f07858", "#ffc0a0"],
	"pike": ["#1c2c14", "#3c5626", "#62823a", "#94b25a", "#d0e49a"],
	"salmon": ["#3c2030", "#7c5068", "#b88898", "#e0b8c0", "#fff0f0"],
	"cod": ["#2c2818", "#5c5434", "#8c8058", "#bcb084", "#ece4c0"],
	"parrot": ["#0c3038", "#187060", "#28a890", "#60dcb8", "#c8fff0"],
	"catfish": ["#1a1614", "#3a322c", "#5c5048", "#847466", "#b0a08c"],
	"fur": ["#2a2018", "#584838", "#80705c", "#a89880", "#d4c6ac"],
	"hide": ["#3a2014", "#7a4c2c", "#a8744a", "#cc9e6c", "#ecd0a0"],
	"wool": ["#3e3628", "#857a64", "#b5aa92", "#d9cfba", "#f4eee0"],
	"soil": ["#2e1c12", "#4a3020", "#6a4a30", "#8c6a46", "#b08e64"],
	"rot": ["#1a140c", "#2e2418", "#4a3c26", "#6a5a3a", "#8a7c56"],
	"amber": ["#4a1e06", "#8c4210", "#c87018", "#f0a830", "#ffe08a"],
	"rawclay": ["#3e3a30", "#6e6858", "#9a9280", "#c2baa6", "#e6e0cc"],
	"coal": ["#120e12", "#24202a", "#3a3442", "#5a5464", "#9a94a4"],
	"glass": ["#0c3438", "#1c6a68", "#3aa49a", "#7cd8c8", "#e0fff8"],
	"fossil": ["#3a3024", "#6a5c48", "#968670", "#bcae94", "#e4dac0"],
	"shell": ["#5a3a34", "#a8786a", "#d8a898", "#f0d0c0", "#fff4ec"],
	"ochre": ["#4a2a0c", "#8a5418", "#c08028", "#e0a840", "#f8d47a"],
	"tar": ["#0c0806", "#1e1410", "#32241c", "#4e3a2c", "#a08870"],
	# A dye's own ramp is made of its shades (dye_picture); this one is the red's, for
	# a look at the bowl alone.
	"dye": ["#381010", "#702020", "#a03028", "#c84838", "#e4a49c"],
	"water": ["#102040", "#1e4878", "#3a78b0", "#6aa8d8", "#c0e4f8"],
	# The clothes that can be dyed, each in its item's `cloth` (light, middle, dark).
	"kilt": ["#2e2416", "#5a4a2e", "#8c6a48", "#b8946c", "#e0c49c"],
	"hatstraw": ["#4a3a18", "#94783e", "#c4ac72", "#e0c878", "#f8eab0"],
	"grasscape": ["#24361a", "#557a38", "#78a048", "#8fb558", "#c8e090"],
	"bast": ["#382c14", "#6e5a2c", "#94783e", "#c4ac72", "#ecdca4"],
	"tan": ["#4a2410", "#8a4e28", "#c0703a", "#e09a5a", "#f8cc94"],
	"hidebrown": ["#2e1a0e", "#5e3c20", "#8a5a30", "#b07a48", "#dcac78"],
	"suede": ["#38261a", "#70502e", "#8c6a48", "#b8946c", "#e0c49c"],
	"boot": ["#2a180c", "#5e3c20", "#6a4424", "#8a5a30", "#b88452"],
	"beads": ["#4a4034", "#a89880", "#d8c9a8", "#f4ece0", "#ffffff"],
	"braid": ["#341a0c", "#6e3a20", "#8c6a48", "#b8946c", "#e0c49c"],
	# Bare hands (hand, hand_left), in the old picture's beige.
	"palm": ["#4a3a2a", "#a8946e", "#d8c9a8", "#efe4c8", "#fffaf0"],
	# The faint pictures of the character's empty slots (slot_<place>), shown at 0.6.
	"ghost": ["#2e3236", "#5e646a", "#848a90", "#a9b0b4", "#d0d4d6"],
	"ghostdark": ["#23262a", "#464b50", "#5e646a", "#7a8086", "#9ea4a8"],
}

## The letters of the interface's pictures (PICTURES).
const PALETTE := {
	"B": Color("#6b4a2f"), "t": Color("#9a7448"), "l": Color("#557a38"), "L": Color("#78a048"),
	"r": Color("#b8243a"), "U": Color("#6d7ad0"), "w": UiStyle.INK,
	"h": UiStyle.DANGER, "a": UiStyle.ACCENT, "g": UiStyle.GOOD, "m": UiStyle.MUTED,
	"j": Color("#54595f"), "z": Color("#9aaabb"), "Z": Color("#e0e8f0"),
}

const PICTURES := {
	# State icons of the vitals panel, 9 pixels.
	"sack": [
		"............",
		"....t..t....",
		".....tt.....",
		".....rr.....",
		"....tttt....",
		"...tttttt...",
		"..tttttttt..",
		"..tttttttt..",
		"..ttttttBt..",
		"..tttttBBt..",
		"...BBBBBB...",
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
	## The big heart before the health bar (VitalsPanel), with a shine.
	"heart_big": [
		"..hhh...hhh..",
		".hhhhh.hhhhh.",
		"hhwwhhhhhhhhh",
		"hhwhhhhhhhhhh",
		"hhhhhhhhhhhhh",
		"hhhhhhhhhhhhh",
		".hhhhhhhhhhh.",
		"..hhhhhhhhh..",
		"...hhhhhhh...",
		"....hhhhh....",
		".....hhh.....",
		"......h......",
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
	"thermo": [
		"...www...",
		"...wcw...",
		"...wcw...",
		"...wcw...",
		"...wrw...",
		"..wrrrw..",
		"..wrrrw..",
		"...www...",
		".........",
	],
	"sleep": [
		"...mmmm..",
		"..mmm....",
		".mmm.....",
		".mmm.....",
		".mmm.....",
		".mmm.....",
		"..mmm....",
		"...mmmm..",
		".........",
	],
	"water": [
		".jjjjjj..",
		".jZZZZjj.",
		".jUzUUj.j",
		".jUUUUj.j",
		".jUUUUjj.",
		".jUUUUj..",
		".jUUUUj..",
		"..jjjj...",
		".........",
	],
	"drop": [
		"....U....",
		"....Z....",
		"...UZU...",
		"..UZZZU..",
		"..UZUZU..",
		".UZZZZUU.",
		".UZZZUUU.",
		"..UUUUU..",
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


## A dye's picture: a bowl of it (dye_bowl of NatureArt), its shades (light, middle,
## dark) as the light, body and shade of the dye's ramp, the outline darker and the
## shine lighter than they.
static func dye_picture(shades: Array) -> Image:
	var light := Color(shades[0])
	var dark := Color(shades[2])
	var dye := [dark.darkened(0.5), dark, Color(shades[1]), light, light.lightened(0.5)]
	var bowl: Array = NatureArt.ART["dye_bowl"]
	return drawn(bowl[1], [RAMPS[bowl[0][0]], dye])


## Pictures drawn as another one with some colours swapped: name -> [the picture,
## {letter: letter}] (the golden heart).
const RECOLOURED := {
	"heart_gold": ["heart", {"h": "a"}],
}


## The picture `name` as an image (see PARTS, then PICTURES), null for a name not drawn here.
static func picture(name: String) -> Image:
	var styled := _styled(name)
	if styled != null:
		return styled
	var rows: Array = PICTURES.get(name, [])
	var swap: Dictionary = {}
	if RECOLOURED.has(name):
		rows = PICTURES[RECOLOURED[name][0]]
		swap = RECOLOURED[name][1]
	if rows.is_empty():
		return null
	var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var letter: String = swap.get(row[x], row[x])
			if PALETTE.has(letter):
				img.set_pixel(x, y, PALETTE[letter])
	return img


## The picture `name` of the parts (PARTS), null for one they do not draw.
static func _styled(name: String) -> Image:
	var key := name
	var swap := {}
	for part in PARTS:
		if part.VARIANTS.has(name):
			key = part.VARIANTS[name][0]
			swap = part.VARIANTS[name][1]
	for part in PARTS:
		if part.ART.has(key):
			var rows: Array = part.ART[key][1]
			if rows.size() != 12 or (rows[0] as String).length() != 12:
				push_error("%s: the picture is not 12 by 12" % key)
			var ramps := []
			for r: String in part.ART[key][0]:
				ramps.append(RAMPS[swap.get(r, r)])
			return drawn(part.ART[key][1], ramps)
	return null


## Rows `rows` (see GROUPS) drawn in `ramps` (lists of RAMPS), with an outline round what
## is filled: an empty pixel beside a filled one (by a side) takes the darkest outline of
## the ramps it touches.
static func drawn(rows: Array, ramps: Array) -> Image:
	var h := rows.size()
	var w: int = (rows[0] as String).length()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# The ramp of each filled pixel, -1 where none is.
	var ramp_at := PackedInt32Array()
	ramp_at.resize(w * h)
	ramp_at.fill(-1)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if ch == "." or ch == "," or ch == "#":
				continue
			var known := false
			for g in GROUPS.size():
				var tone: int = (GROUPS[g] as String).find(ch)
				if tone >= 0:
					img.set_pixel(x, y, Color(ramps[g][tone + 1]))
					ramp_at[y * w + x] = g
					known = true
					break
				if ch == (GROUPS[g] as String)[0].to_upper():
					img.set_pixel(x, y, Color(ramps[g][0]))
					known = true
					break
			if not known:
				push_error("a letter of no ramp: %s" % ch)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if ch != "." and ch != "#":
				continue
			var edge := _edge(ramp_at, ramps, x, y, w, h, false)
			if edge.a == 0.0 and ch == "#":
				edge = _edge(ramp_at, ramps, x, y, w, h, true)
			if edge.a > 0.0:
				img.set_pixel(x, y, edge)
	return img


## The darkest outline of the ramps of the filled pixels beside (x, y): by a side, or also
## by a corner (`corners`); transparent where none is.
static func _edge(ramp_at: PackedInt32Array, ramps: Array, x: int, y: int, w: int, h: int, corners: bool) -> Color:
	var best := Color(0, 0, 0, 0)
	var sides := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	if corners:
		sides += [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for d: Vector2i in sides:
		var nx := x + d.x
		var ny := y + d.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h or ramp_at[ny * w + nx] < 0:
			continue
		var c := Color(ramps[ramp_at[ny * w + nx]][0])
		if best.a == 0.0 or c.get_luminance() < best.get_luminance():
			best = c
	return best
