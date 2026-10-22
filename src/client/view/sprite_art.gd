extends RefCounted
## Placeholder pixel sprites drawn from text, one character per pixel.

const OUTLINE := Color(0.12, 0.1, 0.08)

const ART := {
	"rabbit": [
		"......o.o...",
		".....olol...",
		".....olol...",
		"....obbbbo..",
		"...obbbebo..",
		"oo.obbbbbpo.",
		"olobbbbbbo..",
		".obbbbbbbo..",
		".obbbbbbbo..",
		"..obo.obo...",
		"...o...o....",
	],
	"squirrel": [
		".oo.......",
		"obbo......",
		"obbbo.....",
		"obbbo..oo.",
		".obbo.obbo",
		"..obbobebo",
		"..obbbbbo.",
		"...obbbo..",
		"...obbbo..",
		"...ob.bo..",
		"....o..o..",
	],
	"cat": [
		"...........o.o.",
		"..........obobo",
		"o.........obebo",
		"ob........obbbo",
		".ob.oooooobbbo.",
		"..obbbbbbbbbo..",
		"..obbbbbbbbbo..",
		"..obo.obo.obo..",
		"..obo.obo.obo..",
		"...o...o...o...",
	],
	"deer": [
		"............o.o.",
		"...........ododo",
		"............odo.",
		"...........obbo.",
		"..........obebo.",
		"..........obbbbo",
		".........obbbo..",
		"..ooooooobbbo...",
		".obbbbbbbbbbo...",
		"obllbbbbbbbbo...",
		"obbbbbbbbbbbo...",
		".obbbbbbbbbo....",
		"..obo.....obo...",
		"..obo.....obo...",
		"..obo.....obo...",
		"...o.......o....",
	],
	"wolf": [
		"............o.o.",
		"...........obob.",
		"..........obbbbo",
		"..........obebbo",
		"..........obbbbpo",
		".o.......obbbbo..",
		"obo.ooooobbbbo...",
		".obbbbbbbbbbo....",
		"..obbbbbbbbbo....",
		"..olllllllllo....",
		"..obo.....obo....",
		"..obo.....obo....",
		"...o.......o.....",
	],
	"player": [
		"...oooo...",
		"..ohhhho..",
		".ohhhhhho.",
		".ohssssho.",
		".osesseso.",
		"..osssso..",
		"...oooo...",
		"..occcco..",
		".occcccco.",
		"osccccccso",
		"osccccccso",
		".otttttto.",
		".ottootto.",
		".ott..tto.",
		".okk..kko.",
		".ooo..ooo.",
	],
}

const PALETTES := {
	"rabbit": {"b": Color(0.6, 0.5, 0.4), "l": Color(0.88, 0.82, 0.75)},
	"squirrel": {"b": Color(0.75, 0.4, 0.18)},
	"cat": {"b": Color(0.55, 0.55, 0.58), "e": Color(0.75, 0.8, 0.25)},
	"deer": {"b": Color(0.62, 0.43, 0.26), "l": Color(0.88, 0.78, 0.62), "d": Color(0.5, 0.4, 0.3)},
	"wolf": {"b": Color(0.52, 0.52, 0.55), "l": Color(0.78, 0.78, 0.8), "e": Color(0.85, 0.75, 0.2)},
	"player": {"h": Color(0.35, 0.22, 0.12), "s": Color(0.95, 0.78, 0.62), "e": Color(0.1, 0.1, 0.15),
		"c": Color(0.25, 0.45, 0.72), "t": Color(0.35, 0.3, 0.24), "k": Color(0.25, 0.17, 0.1)},
}


static func texture(kind: String) -> ImageTexture:
	var rows: Array = ART[kind]
	var palette: Dictionary = {"o": OUTLINE, "e": Color(0.05, 0.05, 0.05), "p": Color(0.85, 0.55, 0.55)}
	palette.merge(PALETTES[kind], true)
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	var img := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)
