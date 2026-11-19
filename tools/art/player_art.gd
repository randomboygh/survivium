extends RefCounted
## The pictures of the bare player, drawn pixel by pixel for every direction and frame
## of the sheet laid out in content/core/sprites/player.yaml; tools/make_sprites.gd
## saves them as the core mod's pictures (content/core/sprites/player/), which the game
## reads (Figure) and which can be painted over by hand from there. Layers: the body
## (skin, face, the arms behind the body, skin under the clothes), the loincloth,
## shirt, trousers (with the waistband), shoes, hair, the hair styles and the face's
## options to pick (LooksArt: `hair/<style>`, `face/<option>`), the shapes clothes are worn in
## (SHAPES), the fists (the forearms and hands in front of the body, drawn over what the
## hands hold) and the hands picture marking where each hand is. The hands are empty:
## what they hold has sheets of its own (ToolArt), turned the way the poses here say.
##
## The figure is a chibi: 12 pixels wide and 17 tall inside its outline, the head
## half of it with 2x2 eyes, arms of two pixels, legs a pixel wide on dark soles. It is
## put together from parts written as letters standing for colours (INK): the head
## (rows 2-10 of its 14x18 box), the hair over it (from row 1), the neck and torso
## (11-14) and the legs (15-17), for five directions; the west ones are the east ones
## mirrored with the hands swapped. Arms go from the shoulder to the hand (ARMS). Light
## comes from the upper left. The feet stand on the frame's last row with no outline
## under them, so each foot rests on three dark pixels: its sole and the outline either
## side.
##
## The sheet is drawn for the right hand in use. In the work columns (player.yaml
## `works`) that hand winds up, strikes and follows through (WORKS), and in a
## two-handed work the other hand holds the same thing further along.

const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Figure := preload("res://src/client/view/figure.gd")
const LooksArt := preload("res://tools/art/player_looks_art.gd")

## Directions drawn as another one flipped, with the hands swapped.
const MIRROR := {"sw": "se", "w": "e", "nw": "ne"}
## Where the figure's 14x18 box (its outline on the top and the sides) sits in a frame:
## room on each side and above for a tool swung out or overhead, its feet on the frame's
## last row.
const ORIGIN := Vector2i(9, 14)

## Colour and layer of each letter of the parts.
const INK := {
	"S": ["e8b48a", "body"], "s": ["c98a62", "body"], "k": ["a0603e", "body"],
	# The eyes: the pupil above, the iris under it, the white beside them (shaded above).
	"E": ["1f1a14", "body"], "I": ["272727", "body"], "w": ["b4b4b4", "body"], "W": ["ffffff", "body"],
	"J": ["8a5a36", "hair"], "H": ["6b4228", "hair"], "D": ["4a2c1a", "hair"],
	"L": ["ea323c", "shirt"], "C": ["c42430", "shirt"], "c": ["891e2b", "shirt"],
	# The trousers' waistband (U, u) and legs (T, t).
	"U": ["2c5288", "trousers"], "u": ["1e3a62", "trousers"],
	"T": ["3f6fb0", "trousers"], "t": ["2c5288", "trousers"],
	"B": ["3d3436", "boots"], "b": ["2b2527", "boots"],
	"N": ["c9a66e", "loincloth"], "n": ["9c7c4c", "loincloth"],
	# The dark edge of an arm in front of the body (see ARMS `inner`).
	"#": ["1f1a14", "fists"],
	# The shapes of clothes (see SHAPES): the light, middle and dark tone, painted in
	# the colours of the thing worn (see painted).
	"1": ["c0c0c0", ""], "2": ["808080", ""], "3": ["404040", ""],
	# The face's options (LooksArt.FACES), in their own layers: stubble (the skin's shade
	# and the hair's), a freckle, blush, a scar (the game makes these of the chosen skin
	# and hair, Looks.swaps), war paint, gold, a dark lens, the frame of glasses or a
	# patch and a clear lens.
	"O": ["906042", ""], "F": ["925333", ""], "P": ["e8867c", ""], "X": ["eaa590", ""],
	"Q": ["c42430", ""], "Y": ["f0c040", ""], "Z": ["2a2a33", ""], "G": ["2a2a33", ""], "R": ["9fd3e6", ""],
}
## Skin under each letter of the clothes, in the body layer.
const SKIN := {"L": "S", "C": "S", "c": "s", "U": "S", "u": "s", "T": "S", "t": "s", "B": "s", "b": "k"}
## The darker skin under an arm held out flat.
const DARKER := {"S": "s", "s": "k", "k": "k"}
## The shapes clothes are worn in (see painted), in three greys: what the shirt,
## trousers, shoes and hair are drawn with, cut and joined. A coat goes down over the
## hips and thighs, a hat is the top of the hair, wraps the legs, tall boots the shoes
## and a pixel of leg above.
const SHAPES := ["shirt", "coat", "hat", "trousers", "wraps", "boots", "tall_boots"]
## The tone of each letter of the clothes in a shape.
const TONE := {"L": "1", "C": "2", "c": "3", "U": "2", "u": "3", "T": "1", "t": "2", "B": "2", "b": "3",
	"J": "1", "H": "2", "D": "3"}

## How each drawn direction shows the body.
const VIEW := {"s": "front", "se": "front", "e": "side", "ne": "back", "n": "back"}
## Directions drawn a pixel aside from the places their view gives (SHOULDER, MOVES,
## WORKS): south-east is south turned a little.
const SHIFT := {"se": Vector2i(1, 0)}
## A row of the box with nothing in it.
const EMPTY := ".............."

## The head, rows 2-10 of the box: skin and eyes, the hair goes over it.
const HEAD := {
	"s": [
		"....SSSSSS....",
		"...SSSSSSSS...",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..sSwESSEwSs..",
		"...SWISSIWs...",
		"....sSSSSs....",
	],
	"se": [
		"....SSSSSS....",
		"...SSSSSSSS...",
		"..SSSSSSSSSS..",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..SSsSSSSSSs..",
		"..SSsSwESwES..",
		"...SsSWISWI...",
		".....sSSSSs...",
	],
	"e": [
		"....SSSSSS....",
		"...SSSSSSSS...",
		"..SSSSSSSSSS..",
		"..SSSSSSSSSS..",
		"..SSSSSSSSSS..",
		"..SSSSsSSSSS..",
		"..sSSSsSSwES..",
		"...sSSSSSWIS..",
		".....sSSSSs...",
	],
	"ne": [
		"....SSSSSS....",
		"...SSSSSSSS...",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..SSSSSSSSsS..",
		"..SSSSSSSSsS..",
		"...sSSSSSSs...",
		".....ssssss...",
	],
	"n": [
		"....SSSSSS....",
		"...SSSSSSSS...",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..SSSSSSSSSs..",
		"..sSSSSSSSSs..",
		"..sSSSSSSSss..",
		"..ssSSSSSssk..",
		"....ssssss....",
	],
}
## The hair drawn in the plain layer `hair` (the hair slot of player.yaml `naked`): the
## default look's style (player.yaml `looks`).
const HAIR_STYLE := "short"
## The neck and torso, rows 11-14: the neck, the shoulders, the shirt between the arms
## and the trousers' waistband.
const TORSO := {
	"s": [
		".....kkkk.....",
		"...LCCCCCCc...",
		".....CCCc.....",
		".....UUUu.....",
	],
	"se": [
		"....C.kkkk....",
		"...LCCCCCCc...",
		"......CCCc....",
		"......UUUu....",
	],
	"e": [
		"......kkk.....",
		".....LCCCc....",
		".....cCCCc....",
		".....UUUUu....",
	],
	"ne": [
		"....C.kkkk....",
		"...LCCCCCCc...",
		".....CCCC.....",
		".....UUUu.....",
	],
	"n": [
		".....kkkk.....",
		"...LCCCCCCc...",
		".....CCCc.....",
		".....UUUu.....",
	],
}
## The legs standing, rows 15-17: a pixel wide, the feet on the frame's last row.
const STAND := {
	"s": [
		".....T..t.....",
		".....T..t.....",
		".....B..b.....",
	],
	"se": [
		"......T..t....",
		"......T..t....",
		"......B..b....",
	],
	"e": [
		"......tt......",
		"......Tt......",
		"......BBb.....",
	],
	"ne": [
		".....T..t.....",
		".....T..t.....",
		".....B..b.....",
	],
	"n": [
		".....T..t.....",
		".....T..t.....",
		".....B..b.....",
	],
}
## The legs seen from the side by pose: "stand", "near" or "far" (that leg in front,
## striding), "pass", "tuck" (drawn up, jumping), "sit" (forward, afloat). The front and
## back views raise a leg from STAND instead (see legs).
const SIDE_LEGS := {
	"stand": [
		"......tt......",
		"......Tt......",
		"......BBb.....",
	],
	"near": [
		"......tT......",
		".....t..T.....",
		"....bb..BBb...",
	],
	"far": [
		"......Tt......",
		".....T..t.....",
		"....BB..bbb...",
	],
	"pass": [
		"......tT......",
		"......tT......",
		"......bBB.....",
	],
	"tuck": [
		"......tT......",
		"......bBB.....",
		EMPTY,
	],
	"sit": [
		EMPTY,
		EMPTY,
		"......tTTTB...",
	],
}

## Shoulders by view: where the right arm and the left one hang from (side view: the
## near one and the far one).
const SHOULDER := {
	"front": {"right": Vector2i(3, 13), "left": Vector2i(10, 13)},
	"side": {"right": Vector2i(7, 13), "left": Vector2i(7, 13)},
	"back": {"right": Vector2i(10, 13), "left": Vector2i(3, 13)},
}
## How each arm is drawn, by direction and hand: the letters of the sleeve and of the
## skin [on the line from the shoulder, beside it], the side the second pixel is on
## (`out`; 0: the arm is a pixel wide, the far one), and for an arm over the body seen
## from the side, the side of its dark edge against the body (`inner`).
const ARMS := {
	"s": {
		"right": {"out": -1, "sleeve": ["C", "L"], "hand": ["S", "S"]},
		"left": {"out": 1, "sleeve": ["C", "c"], "hand": ["S", "s"]},
	},
	"se": {
		"right": {"out": -1, "sleeve": ["C", "L"], "hand": ["S", "S"]},
		"left": {"out": 0, "sleeve": ["c", "c"], "hand": ["s", "s"]},
	},
	"e": {
		"right": {"out": -1, "sleeve": ["C", "L"], "hand": ["S", "S"], "inner": 1},
		"left": {"out": 0, "sleeve": ["c", "c"], "hand": ["s", "s"]},
	},
	# From behind the hands are in shade, so they do not read as held behind the back.
	"ne": {
		"right": {"out": 1, "sleeve": ["C", "c"], "hand": ["s", "k"]},
		"left": {"out": 0, "sleeve": ["C", "C"], "hand": ["s", "s"]},
	},
	"n": {
		"right": {"out": 1, "sleeve": ["C", "c"], "hand": ["s", "k"]},
		"left": {"out": -1, "sleeve": ["C", "L"], "hand": ["s", "s"]},
	},
}
## The hands when they do not work, by view and animation, a frame each: [right hand,
## left hand] in the box (moved with the body when it bobs), and the legs and how far
## the body bobs down. A swimmer's strokes go over the water, which comes up to its
## neck (Body.SWIM_DEPTH), the arms reaching out and pulling back in turn. Afloat in a
## vessel the body sits low, its legs forward ("sit"), and rows: both hands reach out
## and pull the oars in (Boats swings the oars in time, ROW_PERIOD). The gestures
## (Gestures): a wave over the head, a nod ("bob"), a shake of the body side to side
## ("lean"), a hand pointing out, beckoning, a bow, clapping in front. The arms are
## short: a hand reaches a few pixels from its shoulder.
const MOVES := {
	"front": {
		"idle": [{"hands": [[3, 14], [10, 14]]}],
		"walk": [
			{"hands": [[3, 14], [10, 14]], "legs": "left"},
			{"hands": [[3, 14], [10, 14]]},
			{"hands": [[3, 14], [10, 14]], "legs": "right"},
			{"hands": [[3, 14], [10, 14]]},
		],
		"jump": [
			{"hands": [[1, 12], [12, 12]], "legs": "tuck"},
			{"hands": [[2, 14], [11, 14]]},
		],
		"swim": [
			{"hands": [[0, 9], [13, 12]], "legs": "left"},
			{"hands": [[0, 11], [13, 10]]},
			{"hands": [[0, 12], [13, 9]], "legs": "right"},
			{"hands": [[0, 10], [13, 11]]},
		],
		"wave": [
			{"hands": [[0, 9], [10, 14]]},
			{"hands": [[-1, 10], [10, 14]]},
		],
		"nod": [{"hands": [[3, 14], [10, 14]], "bob": 1}],
		"shake": [
			{"hands": [[3, 14], [10, 14]], "lean": -1},
			{"hands": [[3, 14], [10, 14]], "lean": 1},
		],
		"point": [{"hands": [[0, 12], [10, 14]]}],
		"beckon": [
			{"hands": [[1, 11], [10, 14]]},
			{"hands": [[2, 13], [10, 14]]},
		],
		"bow": [
			{"hands": [[3, 14], [10, 14]], "bob": 1},
			{"hands": [[4, 14], [9, 14]], "bob": 2},
		],
		"clap": [
			{"hands": [[5, 13], [8, 13]]},
			{"hands": [[6, 13], [7, 13]]},
		],
		"sit": [{"hands": [[3, 14], [10, 14]], "legs": "sit", "bob": 2}],
		"row": [
			{"hands": [[2, 11], [11, 11]], "legs": "sit", "bob": 2},
			{"hands": [[2, 13], [11, 13]], "legs": "sit", "bob": 2},
			{"hands": [[3, 14], [10, 14]], "legs": "sit", "bob": 2},
			{"hands": [[2, 13], [11, 13]], "legs": "sit", "bob": 2},
		],
	},
	"side": {
		"idle": [{"hands": [[7, 14], [6, 14]]}],
		"walk": [
			{"hands": [[6, 14], [10, 14]], "legs": "near"},
			{"hands": [[7, 14], [6, 14]], "legs": "pass"},
			{"hands": [[8, 14], [4, 14]], "legs": "far"},
			{"hands": [[7, 14], [6, 14]], "legs": "pass"},
		],
		"jump": [
			{"hands": [[9, 11], [5, 12]], "legs": "tuck"},
			{"hands": [[9, 13], [5, 13]]},
		],
		"swim": [
			{"hands": [[11, 11], [4, 13]], "legs": "near"},
			{"hands": [[9, 13], [9, 10]]},
			{"hands": [[4, 13], [11, 11]], "legs": "far"},
			{"hands": [[9, 10], [9, 13]]},
		],
		"wave": [
			{"hands": [[12, 10], [6, 14]]},
			{"hands": [[12, 8], [6, 14]]},
		],
		"nod": [{"hands": [[7, 14], [6, 14]], "bob": 1}],
		"shake": [
			{"hands": [[7, 14], [6, 14]], "lean": -1},
			{"hands": [[7, 14], [6, 14]], "lean": 1},
		],
		"point": [{"hands": [[11, 12], [6, 14]]}],
		"beckon": [
			{"hands": [[10, 11], [6, 14]]},
			{"hands": [[9, 13], [6, 14]]},
		],
		"bow": [
			{"hands": [[8, 14], [7, 14]], "lean": 1, "bob": 1},
			{"hands": [[9, 14], [8, 14]], "lean": 2, "bob": 1},
		],
		"clap": [
			{"hands": [[11, 12], [11, 11]]},
			{"hands": [[10, 12], [10, 11]]},
		],
		"sit": [{"hands": [[9, 14], [8, 14]], "legs": "sit", "bob": 2}],
		"row": [
			{"hands": [[10, 12], [9, 12]], "legs": "sit", "bob": 2},
			{"hands": [[9, 14], [8, 14]], "legs": "sit", "bob": 2},
			{"hands": [[5, 13], [4, 13]], "legs": "sit", "bob": 2},
			{"hands": [[7, 13], [6, 13]], "legs": "sit", "bob": 2},
		],
	},
	"back": {
		"idle": [{"hands": [[10, 14], [3, 14]]}],
		"walk": [
			{"hands": [[10, 14], [3, 14]], "legs": "left"},
			{"hands": [[10, 14], [3, 14]]},
			{"hands": [[10, 14], [3, 14]], "legs": "right"},
			{"hands": [[10, 14], [3, 14]]},
		],
		"jump": [
			{"hands": [[12, 12], [1, 12]], "legs": "tuck"},
			{"hands": [[11, 14], [2, 14]]},
		],
		"swim": [
			{"hands": [[13, 9], [0, 12]], "legs": "left"},
			{"hands": [[13, 11], [0, 10]]},
			{"hands": [[13, 12], [0, 9]], "legs": "right"},
			{"hands": [[13, 10], [0, 11]]},
		],
		"wave": [
			{"hands": [[13, 9], [3, 14]]},
			{"hands": [[14, 10], [3, 14]]},
		],
		"nod": [{"hands": [[10, 14], [3, 14]], "bob": 1}],
		"shake": [
			{"hands": [[10, 14], [3, 14]], "lean": -1},
			{"hands": [[10, 14], [3, 14]], "lean": 1},
		],
		"point": [{"hands": [[13, 12], [3, 14]]}],
		"beckon": [
			{"hands": [[12, 11], [3, 14]]},
			{"hands": [[11, 13], [3, 14]]},
		],
		"bow": [
			{"hands": [[10, 14], [3, 14]], "bob": 1},
			{"hands": [[9, 14], [4, 14]], "bob": 2},
		],
		"clap": [
			{"hands": [[8, 13], [5, 13]]},
			{"hands": [[7, 13], [6, 13]]},
		],
		"sit": [{"hands": [[10, 14], [3, 14]], "legs": "sit", "bob": 2}],
		"row": [
			{"hands": [[11, 11], [2, 11]], "legs": "sit", "bob": 2},
			{"hands": [[11, 13], [2, 13]], "legs": "sit", "bob": 2},
			{"hands": [[10, 14], [3, 14]], "legs": "sit", "bob": 2},
			{"hands": [[11, 13], [2, 13]], "legs": "sit", "bob": 2},
		],
	},
}
## The hand in use in each frame of the works, by view, for the right hand (side view:
## the near one): "r" where it is, "a" the way what it holds points (0 up, then
## clockwise by eighths; -1: as carried), "ccw" when the thing turns anticlockwise (its
## edge leads the other way), "f" in front of the body or not (by default as the view
## has it), "o" where the other hand holds a two-handed thing, "bob" and "lean" how far
## the body bends down and forward, "eyes" "shut". A thing swung up over the head goes
## behind it, the hand hidden, so it does not cover the face.
const WORKS := {
	"front": {
		"chop": [
			{"r": [1, 9], "a": 0, "f": false},
			{"r": [4, 4], "a": 0, "f": false},
			{"r": [5, 12], "a": TOWARD},
			{"r": [5, 13], "a": TOWARD, "bob": 1},
		],
		"dig": [
			{"r": [4, 12], "a": TOWARD},
			{"r": [4, 13], "a": TOWARD, "bob": 1},
			{"r": [5, 14], "a": TOWARD, "bob": 1},
			{"r": [3, 12], "a": 7},
		],
		"slash": [
			{"r": [1, 11], "a": 7},
			{"r": [0, 8], "a": 6, "f": false},
			{"r": [7, 13], "a": 2},
			{"r": [8, 13], "a": 3},
		],
		"reach": [
			{"r": [3, 13], "a": -1},
			{"r": [4, 14], "a": -1},
			{"r": [5, 15], "a": -1, "bob": 1},
			{"r": [4, 14], "a": -1},
		],
		"mow": [
			{"r": [3, 13], "a": 6, "o": [5, 13], "ccw": true},
			{"r": [4, 13], "a": TOWARD, "o": [6, 13], "ccw": true, "bob": 1},
			{"r": [6, 13], "a": TOWARD, "o": [8, 13], "ccw": true, "bob": 1},
			{"r": [8, 13], "a": 2, "o": [10, 13], "ccw": true},
		],
		"aim": [
			{"r": [4, 13], "a": TOWARD, "o": [7, 13]},
			{"r": [5, 12], "a": TOWARD, "o": [8, 12]},
			{"r": [5, 11], "a": TOWARD, "o": [8, 11]},
			{"r": [5, 12], "a": TOWARD, "o": [8, 12]},
		],
		"eat": [
			{"r": [4, 14], "a": -1},
			{"r": [5, 12], "a": -1},
			{"r": [6, 10], "a": -1, "eyes": "shut"},
			{"r": [5, 11], "a": -1},
		],
	},
	"side": {
		"chop": [
			{"r": [4, 9], "a": 7, "f": false},
			{"r": [5, 5], "a": 6, "f": false},
			{"r": [10, 12], "a": 3, "lean": 1},
			{"r": [10, 14], "a": 3, "bob": 1, "lean": 1},
		],
		"dig": [
			{"r": [9, 12], "a": 3},
			{"r": [10, 13], "a": 3, "bob": 1},
			{"r": [10, 14], "a": 3, "bob": 1, "lean": 1},
			{"r": [9, 12], "a": 2},
		],
		"slash": [
			{"r": [6, 7], "a": 0, "f": false},
			{"r": [5, 6], "a": 7, "f": false},
			{"r": [11, 12], "a": 2, "lean": 1},
			{"r": [10, 14], "a": 3},
		],
		"reach": [
			{"r": [8, 13], "a": -1},
			{"r": [10, 13], "a": -1},
			{"r": [11, 13], "a": -1, "lean": 1},
			{"r": [9, 14], "a": -1},
		],
		"mow": [
			{"r": [7, 12], "a": 6, "o": [6, 13], "ccw": true},
			{"r": [8, 13], "a": 5, "o": [7, 14], "ccw": true, "bob": 1},
			{"r": [10, 13], "a": 3, "o": [11, 14], "ccw": true, "bob": 1, "lean": 1},
			{"r": [10, 12], "a": 2, "o": [12, 12], "ccw": true},
		],
		"aim": [
			{"r": [9, 14], "a": 2, "o": [11, 14]},
			{"r": [9, 13], "a": 2, "o": [11, 13]},
			{"r": [8, 13], "a": 2, "o": [10, 13]},
			{"r": [9, 13], "a": 2, "o": [11, 13]},
		],
		"eat": [
			{"r": [8, 13], "a": -1},
			{"r": [9, 12], "a": -1},
			{"r": [10, 10], "a": -1, "eyes": "shut"},
			{"r": [9, 11], "a": -1},
		],
	},
	"back": {
		"chop": [
			{"r": [11, 9], "a": 0, "f": true},
			{"r": [9, 4], "a": 0, "f": true},
			{"r": [8, 13], "a": 0},
			{"r": [8, 14], "a": 0, "bob": 1},
		],
		"dig": [
			{"r": [9, 13], "a": 0},
			{"r": [9, 14], "a": 0, "bob": 1},
			{"r": [8, 15], "a": 0, "bob": 1},
			{"r": [9, 13], "a": 1},
		],
		"slash": [
			{"r": [12, 11], "a": 1, "f": true},
			{"r": [12, 9], "a": 2, "f": true},
			{"r": [6, 13], "a": 7},
			{"r": [5, 14], "a": 0},
		],
		"reach": [
			{"r": [10, 13], "a": -1},
			{"r": [9, 14], "a": -1},
			{"r": [8, 15], "a": -1, "bob": 1},
			{"r": [9, 14], "a": -1},
		],
		"mow": [
			{"r": [10, 14], "a": 2, "o": [8, 14], "ccw": true, "f": true},
			{"r": [9, 15], "a": 1, "o": [7, 15], "ccw": true, "bob": 1},
			{"r": [7, 15], "a": 0, "o": [5, 15], "ccw": true, "bob": 1},
			{"r": [5, 14], "a": 7, "o": [3, 14], "ccw": true},
		],
		"aim": [
			{"r": [9, 14], "a": 0, "o": [6, 14]},
			{"r": [9, 13], "a": 0, "o": [6, 13]},
			{"r": [9, 12], "a": 0, "o": [6, 12]},
			{"r": [9, 13], "a": 0, "o": [6, 13]},
		],
		"eat": [
			{"r": [10, 14], "a": -1},
			{"r": [9, 12], "a": -1},
			{"r": [8, 11], "a": -1},
			{"r": [9, 13], "a": -1},
		],
	},
}
## A thing held pointing at the ground in front of a body facing the viewer, drawn
## foreshortened (one more way after the eight).
const TOWARD := 8
## The eight ways a thing held can point, clockwise from up.
const WAYS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

## Layer images already drawn, by name, and the hands' places (see anchors).
static var _drawn := {}
static var _anchors := []


## The image of layer `name` (player.yaml `layers` or `fists`), drawn the first time.
static func layer(name: String) -> Image:
	if not _drawn.has(name):
		var s := SpriteSheet.new(Figure.data())
		var img := Image.create_empty(s.image_size().x, s.image_size().y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for row in s.directions.size():
			var dir: String = s.directions[row]
			var drawn: String = MIRROR.get(dir, dir)
			var flipped := MIRROR.has(dir)
			for col in s.columns:
				var frame := Rect2i(Vector2i(col * s.frame_size.x, row * s.frame_size.y), s.frame_size)
				var letters: Dictionary = frame_letters(drawn, "left" if flipped else "right", col, dir)[name]
				for p: Vector2i in letters:
					var at := ORIGIN + p
					if flipped:
						at.x = s.frame_size.x - 1 - at.x
					# The frame's top and sides stay clear for the outline; the feet stand
					# on its bottom row.
					if at.x > 0 and at.y > 0 and at.x < s.frame_size.x - 1 and at.y < s.frame_size.y:
						img.set_pixelv(frame.position + at, Color.html(INK[letters[p]][0]))
		_drawn[name] = img
	return _drawn[name]


## Where the hands are, by row and column of the sheet: {"right": hand, "left": hand},
## a hand being {"at": its pixel in the frame, "front": over the body or not, "angle":
## the way what it holds points, -1 as carried}, or {} for the other hand of a
## two-handed work, which holds the same thing.
static func anchors() -> Array:
	if _anchors.is_empty():
		var s := SpriteSheet.new(Figure.data())
		for row in s.directions.size():
			var dir: String = s.directions[row]
			var drawn: String = MIRROR.get(dir, dir)
			var flipped := MIRROR.has(dir)
			var cols := []
			for col in s.columns:
				var p := pose(drawn, "left" if flipped else "right", col)
				var both := {}
				for hand in ["right", "left"]:
					var h: Dictionary = p[_other(hand) if flipped else hand]
					if not h.holds:
						both[hand] = {}
						continue
					var at: Vector2i = ORIGIN + h.at
					if flipped:
						at.x = s.frame_size.x - 1 - at.x
					var angle: int = h.angle
					if angle == TOWARD:
						angle = 4
					if flipped and angle >= 0:
						angle = mirrored(angle)
					both[hand] = {"at": at, "front": h.front, "angle": angle}
				cols.append(both)
			_anchors.append(cols)
	return _anchors


## The picture of clothes worn in shape `shape` (SHAPES): its light, middle and dark
## tones in `colors` (html colours), as the game lays it over the figure (Figure.dressed).
static func painted(shape: String, colors: Array) -> Image:
	var img: Image = layer("shapes/" + shape).duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, Color.html(colors[0 if p.r > 0.6 else (1 if p.r > 0.4 else 2)]))
	return img


## The hands picture: in each frame a pixel at each hand, red for the right one, blue
## for the left one, darker behind the body, its green the way what the hand holds
## points (see player.yaml).
static func marks() -> Image:
	var s := SpriteSheet.new(Figure.data())
	var img := Image.create_empty(s.image_size().x, s.image_size().y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var all := anchors()
	for row in all.size():
		for col in all[row].size():
			for hand in ["right", "left"]:
				var a: Dictionary = all[row][col][hand]
				var other: Dictionary = all[row][col][_other(hand)]
				if not a.is_empty() and not other.is_empty() and a.at == other.at:
					push_error("both hands on one pixel in row %d, column %d" % [row, col])
				if not a.is_empty():
					var c: Color = Figure.MARKS[hand] * (1.0 if a.front else 0.5)
					c.a = 1.0
					c.g = (a.angle + 1) / 8.0 if a.angle >= 0 else 0.0
					img.set_pixelv(Vector2i(col, row) * s.frame_size + a.at, c)
	return img


static func _other(hand: String) -> String:
	return "left" if hand == "right" else "right"


## The animation playing in column `col` of the sheet and its frame there: [name, i].
static func column(col: int) -> Array:
	var works: Dictionary = Figure.data().works
	for kind in works:
		if works[kind].columns.has(col):
			return [kind, works[kind].columns.find(col)]
	var anims: Dictionary = Figure.data().animations
	for name in anims:
		var seen := []
		for c in anims[name].frames:
			if not seen.has(c):
				seen.append(c)
		if seen.has(col):
			return [name, seen.find(col)]
	return ["idle", 0]


## Way `a` mirrored left to right.
static func mirrored(a: int) -> int:
	return a if a == TOWARD else (8 - a) % 8


## The pose of column `col` drawn in direction `dir` (a drawn one: s, se, e, ne, n) with
## hand `active` in use: {"bob", "lean", "legs", "eyes", "right": hand, "left": hand}, a
## hand being {"at": where it is in the box, "shoulder", "front": in front of the body,
## "holds": false for the other hand of a two-handed work, "worked", "angle": the way
## what it holds points (-1: as carried), "ccw"}.
static func pose(dir: String, active: String, col: int) -> Dictionary:
	var view: String = VIEW[dir]
	var c := column(col)
	var moves: Dictionary = MOVES[view]
	var move: Dictionary = moves.idle[0]
	if moves.has(c[0]):
		move = moves[c[0]][mini(c[1], moves[c[0]].size() - 1)]
	var p := {"bob": move.get("bob", 0), "lean": move.get("lean", 0), "legs": move.get("legs", "stand"), "eyes": "open"}
	# The blink, which the sleep frame is made from too (Figure._lay_down).
	if col == int(Figure.data().get("blink", -1)):
		p.eyes = "shut"
	for i in 2:
		var hand: String = ["right", "left"][i]
		var at: Array = move.hands[i]
		p[hand] = {"at": Vector2i(at[0], at[1] + p.bob), "front": _front(view, hand), "holds": true, "worked": false, "angle": -1, "ccw": false}
	if WORKS[view].has(c[0]):
		var w: Dictionary = WORKS[view][c[0]][c[1]]
		p.bob = w.get("bob", 0)
		p.lean = w.get("lean", 0)
		p.eyes = w.get("eyes", "open")
		var other := _other(active)
		var at := Vector2i(w.r[0], w.r[1])
		var angle: int = w.a
		var ccw: bool = w.get("ccw", false)
		var front: bool = w.get("f", _front(view, "right"))
		var off: Vector2i = Vector2i(w.o[0], w.o[1]) if w.has("o") else Vector2i(-1, -1)
		if active == "left":
			if view == "side":
				# The far hand does the same a pixel further back, behind the body.
				at.x -= 1
				front = false
			else:
				# The left hand does it on the other side of the body.
				at.x = 13 - at.x
				off.x = 13 - off.x
				if angle >= 0:
					angle = mirrored(angle)
				ccw = not ccw
		if dir in ["se", "ne"] and angle >= 0:
			# Turned a little to the east: what it holds swings that way.
			angle = [1, 1, 2, 3, 3, 4, 6, 0, TOWARD][angle]
		p[active] = {"at": at, "front": front, "holds": true, "worked": true, "angle": angle, "ccw": ccw}
		if w.has("o"):
			p[other] = {"at": off, "front": front if view != "side" else active == "left", "holds": false, "worked": true, "angle": -1, "ccw": false}
		else:
			# The other hand hangs as it does standing.
			var still: Array = moves.idle[0].hands[1 if other == "left" else 0]
			p[other].at = Vector2i(still[0], still[1] + p.bob)
	var shift: Vector2i = SHIFT.get(dir, Vector2i.ZERO)
	for hand in ["right", "left"]:
		var s: Vector2i = SHOULDER[view][hand]
		p[hand].shoulder = s + Vector2i(p.lean, p.bob) + shift
		p[hand].at += shift
	return p


## Whether a hand of a view is in front of the body by default.
static func _front(view: String, hand: String) -> bool:
	match view:
		"front":
			return true
		"side":
			return hand == "right"
	return false


## The legs of direction `dir` in pose `kind`, rows 15-17 of the box. Seen from the front
## or the back a step raises a leg a pixel ("right": the one on the west of the picture,
## "left": the other, "tuck": both), its foot where its shin was.
static func legs(dir: String, kind: String) -> Array:
	if VIEW[dir] == "side":
		return SIDE_LEGS[kind]
	var rows: Array = STAND[dir]
	if kind == "sit":
		return [EMPTY, EMPTY, rows[2]]
	var shin := ""
	var foot := ""
	for x in EMPTY.length():
		var up: bool = kind == "tuck" or (kind == "right" and x < 7) or (kind == "left" and x >= 7)
		shin += rows[2][x] if up else rows[1][x]
		foot += "." if up else rows[2][x]
	return [rows[0], shin, foot]


## The letters of every layer in one frame: {layer: {pixel in the box: letter}}.
static func frame_letters(dir: String, active: String, col: int, real := "") -> Dictionary:
	var p := pose(dir, active, col)
	var out := {"body": {}, "shirt": {}, "trousers": {}, "boots": {}, "hair": {}, "fists": {}, "loincloth": {}}
	var up := Vector2i(p.lean, p.bob)
	var parts := []
	_stamp(parts, legs(dir, p.legs), 15, Vector2i.ZERO)
	_stamp(parts, TORSO[dir], 11, up)
	var head: Array = HEAD[dir]
	if p.eyes == "shut":
		# Shut, an eye is a dark line where the iris and the white were.
		head = head.map(func(r: String) -> String: return r.replace("E", "S").replace("w", "S").replace("I", "E").replace("W", "E"))
	_stamp(parts, head, 2, up)
	_stamp(parts, LooksArt.HAIRS[HAIR_STYLE][dir], 1, up)
	var solid := {}
	for e: Array in parts:
		solid[e[0]] = true
	# Arms behind the body show only where the body leaves them.
	for hand in ["left", "right"]:
		if not p[hand].front:
			_arm(out, p[hand], dir, hand, solid, false)
	for e: Array in parts:
		_put(out, e[0], e[1])
	for hand in ["left", "right"]:
		if p[hand].front:
			_arm(out, p[hand], dir, hand, solid, true)
	_loincloth(out)
	_shapes(out, up)
	_looks(out, dir, up, real)
	return out


## The layers of the looks to pick (LooksArt): `hair/<style>` and `face/<option>`, over
## the head as it bobs and leans. `real` is the direction the frame shows when `dir` is
## drawn for it flipped (sw, w, nw): a look that is not the same on both sides (an eye
## patch) has its own rows for it, written as seen, so they are flipped here to come out
## right.
static func _looks(out: Dictionary, dir: String, up: Vector2i, real := "") -> void:
	for kind: String in ["hair", "face"]:
		var all: Dictionary = LooksArt.HAIRS if kind == "hair" else LooksArt.FACES
		for id: String in all:
			var drawn := {}
			var rows: Array = all[id].get(dir, [])
			if real != "" and real != dir and all[id].has(real):
				rows = all[id][real].map(func(r: String) -> String: return r.reverse())
			for y in rows.size():
				var r: String = rows[y]
				for x in r.length():
					if r[x] != ".":
						drawn[Vector2i(x, 1 + y) + up] = r[x]
			out[kind + "/" + id] = drawn


## The loincloth the character is born in: the trousers' waistband, in cloth.
static func _loincloth(out: Dictionary) -> void:
	var t: Dictionary = out.trousers
	for at: Vector2i in t:
		if t[at] == "U":
			out.loincloth[at] = "N"
		elif t[at] == "u":
			out.loincloth[at] = "n"


## The shapes of clothes (SHAPES) of the frame, out of the letters of the clothes drawn.
static func _shapes(out: Dictionary, up: Vector2i) -> void:
	var t: Dictionary = out.trousers
	var b: Dictionary = out.boots
	var shapes := {}
	for name: String in SHAPES:
		shapes[name] = {}
	for at: Vector2i in out.shirt:
		shapes.shirt[at] = TONE[out.shirt[at]]
		shapes.coat[at] = TONE[out.shirt[at]]
	for at: Vector2i in t:
		var tone: String = TONE[t[at]]
		shapes.trousers[at] = tone
		if at.y <= 15 + up.y:
			shapes.coat[at] = tone
		if t[at] in ["T", "t"]:
			shapes.wraps[at] = "3" if t[at] == "t" else ("1" if at.y % 2 == 0 else "2")
		if b.has(at + Vector2i.DOWN) and t[at] in ["T", "t"]:
			shapes.tall_boots[at] = tone
	for at: Vector2i in b:
		shapes.boots[at] = TONE[b[at]]
		shapes.tall_boots[at] = TONE[b[at]]
	for at: Vector2i in out.hair:
		if at.y - up.y <= 5:
			shapes.hat[at] = TONE[out.hair[at]]
	for name: String in SHAPES:
		out["shapes/" + name] = shapes[name]


static func _stamp(parts: Array, rows: Array, y0: int, shift: Vector2i) -> void:
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if r[x] != ".":
				parts.append([Vector2i(x, y0 + y) + shift, r[x]])


## A letter in its layer, with skin under it in the body layer where it is clothes.
static func _put(out: Dictionary, at: Vector2i, letter: String) -> void:
	out[INK[letter][1]][at] = letter
	if SKIN.has(letter) and not out.body.has(at):
		out.body[at] = SKIN[letter]


## An arm from the shoulder to the hand, drawn as ARMS says: the sleeve the first half,
## then the skin; a second pixel beside the line (under it when the arm is held out
## flat). In front of the body the skin goes to the fists, over what the hand holds;
## behind it the arm shows only where the body leaves it.
static func _arm(out: Dictionary, h: Dictionary, dir: String, hand: String, solid: Dictionary, front: bool) -> void:
	var spec: Dictionary = ARMS[dir][hand]
	var line := _line(h.shoulder, h.at)
	var sleeve := maxi(1, line.size() / 2) if line.size() > 1 else 0
	var d: Vector2i = h.at - h.shoulder
	var flat := absi(d.x) > absi(d.y)
	var arm := {}
	for i in line.size():
		arm[line[i]] = spec.sleeve[0] if i < sleeve else spec.hand[0]
	if spec.out != 0:
		for i in line.size():
			var beside: Vector2i = line[i] + (Vector2i.DOWN if flat else Vector2i(spec.out, 0))
			if not arm.has(beside):
				if flat:
					arm[beside] = "c" if i < sleeve else DARKER[spec.hand[0]]
				else:
					arm[beside] = spec.sleeve[1] if i < sleeve else spec.hand[1]
	for at: Vector2i in arm:
		if not front and solid.has(at):
			continue
		var letter: String = arm[at]
		if INK[letter][1] == "shirt":
			_put(out, at, letter)
		elif front:
			out.fists[at] = letter
		else:
			out.body[at] = letter
	if front and spec.has("inner") and d.x == 0:
		# Only along an arm hanging straight down from the shoulder.
		for at: Vector2i in line:
			var edge: Vector2i = at + Vector2i(spec.inner, 0)
			if solid.has(edge) and not arm.has(edge):
				out.fists[edge] = "#"


## The pixels of a line from `a` to `b`, both ends included.
static func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(1.0, n)
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out
