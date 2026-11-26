extends RefCounted
## The shapes of the clothes worn on the head that are not the top of the hair (PlayerArt
## SHAPES): drawn by way (s, se, e, ne, n; the west ones are the east ones mirrored) as
## rows of the figure's 14-wide box from its row 0, over the head as it bobs and leans
## (PlayerArt._wear). Letters are the tones of a shape: 1, 2, 3 the cloth's light, middle
## and dark (what a dye will colour), 4 and 5 the trim's light and dark (a band, a hem,
## flowers: they keep the colours of the thing). The head is 10 pixels wide (columns
## 2-11) from row 2; its eyes are on rows 8-9. Light comes from the upper left.
## Not loaded by the game: tools/make_sprites.gd paints them (PlayerArt.painted).

## A wide-brimmed hat: a crown with a band, the brim a pixel past the head each side and
## its shade over the forehead.
const BRIM := [
	"..............",
	"....111112....",
	"...11111122...",
	"...11111122...",
	"...44444455...",
	".111111111222.",
	"..3333333333..",
]
## A rounder leather hat: a domed crown, a band, a narrower brim curled at its ends.
const DOME := [
	"..............",
	".....1112.....",
	"....111112....",
	"...11111122...",
	"...44444455...",
	".311111111223.",
]
## A wreath: leaves round the head with flowers in them.
const WREATH := [
	"..............",
	"..............",
	"..............",
	"....323232....",
	"..2414151412..",
	"..3........3..",
]

## A feather stuck upright in the hair over the right ear, its quill in the hair: on the
## screen's right from behind (FEATHER), on its left from the front and the east side
## (FEATHER_SIDE). It is the same ear in every way, so the west ways have rows of their
## own, as seen (a mirrored east one would move it to the left ear): south-west and west
## it is on the far side of the head, only its tip over the hair (FEATHER_TIP, FEATHER_TIP_SIDE).
const FEATHER := [
	"...........1..",
	"..........12..",
	"..........2...",
	"..........4...",
]
const FEATHER_SIDE := [
	"..1...........",
	"..21..........",
	"...2..........",
	"...4..........",
]
const FEATHER_TIP := [
	"...........1..",
	"..........12..",
]
const FEATHER_TIP_SIDE := [
	"..1...........",
	"..21..........",
]

const SHAPES := {
	"feather": {"s": FEATHER_SIDE, "se": FEATHER_SIDE, "e": FEATHER_SIDE, "ne": FEATHER, "n": FEATHER,
		"sw": FEATHER_TIP_SIDE, "w": FEATHER_TIP, "nw": FEATHER},
	"brim_hat": {"s": BRIM, "se": BRIM, "e": BRIM, "ne": BRIM, "n": BRIM},
	"dome_hat": {"s": DOME, "se": DOME, "e": DOME, "ne": DOME, "n": DOME},
	"wreath": {"s": WREATH, "se": WREATH, "e": WREATH, "ne": WREATH, "n": WREATH},
	# A kerchief over the top of the head, its hem on the forehead, knotted behind with the
	# ends hanging.
	"bandana": {
		"s": [
			"..............",
			"..............",
			"....111112....",
			"...11111122...",
			"..1111111122..",
			"..4444444455..",
		],
		"se": [
			"..............",
			"..............",
			"....111112....",
			"...11111122...",
			"..1111111122..",
			"..4444444455..",
			"..3...........",
		],
		"e": [
			"..............",
			"..............",
			"....111112....",
			"...11111122...",
			"..1111111122..",
			"..2444444455..",
			".33...........",
			".3............",
		],
		"ne": [
			"..............",
			"..............",
			"....111112....",
			"...11111122...",
			"..1111111122..",
			"..4444444455..",
			"....33........",
			"...3..3.......",
		],
		"n": [
			"..............",
			"..............",
			"....111112....",
			"...11111122...",
			"..1111111122..",
			"..4444444455..",
			"......33......",
			".....3..3.....",
		],
	},
	# A hood: pointed at the top, round the face with a hemmed opening, its sides down to
	# the chin; from behind it hides the hair.
	"hood": {
		"s": [
			"..............",
			".....112......",
			"....11112.....",
			"...1111112....",
			"..1111111122..",
			"..1444444452..",
			"..14......52..",
			"..1........2..",
			"..1........2..",
			"..2........3..",
			"..22......33..",
		],
		"se": [
			"..............",
			".....112......",
			"....11112.....",
			"...1111112....",
			"..1111111122..",
			"..1144444445..",
			"..114......5..",
			"..11.......2..",
			"..11..........",
			"..21..........",
			"..22..........",
		],
		"e": [
			"..............",
			"....112.......",
			"...11112......",
			"..11111122....",
			"..111111114...",
			"..11111114....",
			"..1111114.....",
			"..1111114.....",
			"..2111114.....",
			"..2211114.....",
			"...22224......",
		],
		"ne": [
			"..............",
			"......112.....",
			".....11112....",
			"....1111112...",
			"..1111111122..",
			"..1111111122..",
			"..1111111122..",
			"..1111111122..",
			"..1111111122..",
			"..2111111123..",
			"...22222223...",
		],
		"n": [
			"..............",
			".....112......",
			"....11112.....",
			"...1111112....",
			"..1111111122..",
			"..1111111122..",
			"..1111111122..",
			"..1111111122..",
			"..1111111122..",
			"..2111111123..",
			"...22222233...",
		],
	},
}
