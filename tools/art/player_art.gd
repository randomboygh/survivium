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
## half of it with 2x2 eyes, the body under it in the proportions of the walk copied from
## a reference (WalkArt): bare arms of two pixels, legs two pixels wide. It is put together
## from parts written as letters standing for colours (INK): the head (rows 2-10 of its
## 14x18 box), the hair over it (from row 1) and the body standing (BODY: the neck, the
## torso and the legs), for five directions; the west ones are the east ones mirrored
## with the hands swapped. Arms go from the shoulder to the hand (ARMS). Light comes from
## the upper left. The feet stand on the frame's last row with no outline under them. The
## walk's body under the head is copied pixel by pixel from the reference (WalkArt): the
## arms swinging, the body bobbing; the jump's, the swim's, the chop's, the dig's, the
## slash's, the bow's shot, the eat's, the reach's, the mow's, the gestures' and the rowing's
## are drawn whole the same way (JumpArt, SwimArt, ChopArt, DigArt, SlashArt, AimArt, EatArt,
## ReachArt, MowArt, GestureArt, RowArt).
##
## The sheet is drawn for the right hand in use. In the work columns (player.yaml
## `works`) that hand winds up, strikes and follows through (WORKS), and in a
## two-handed work the other hand holds the same thing further along.

const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Figure := preload("res://src/client/view/figure.gd")
const LooksArt := preload("res://tools/art/player_looks_art.gd")
const FormsArt := preload("res://tools/art/player_forms_art.gd")
const WalkArt := preload("res://tools/art/player_walk_art.gd")
const JumpArt := preload("res://tools/art/player_jump_art.gd")
const SwimArt := preload("res://tools/art/player_swim_art.gd")
const ChopArt := preload("res://tools/art/player_chop_art.gd")
const DigArt := preload("res://tools/art/player_dig_art.gd")
const SlashArt := preload("res://tools/art/player_slash_art.gd")
const AimArt := preload("res://tools/art/player_aim_art.gd")
const EatArt := preload("res://tools/art/player_eat_art.gd")
const ReachArt := preload("res://tools/art/player_reach_art.gd")
const MowArt := preload("res://tools/art/player_mow_art.gd")
const GestureArt := preload("res://tools/art/player_gesture_art.gd")
const RowArt := preload("res://tools/art/player_row_art.gd")
const WearArt := preload("res://tools/art/player_wear_art.gd")

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
	# The shade under a bust (FormsArt): the shirt's dark over the skin's deepest.
	"V": ["891e2b", "shirt"],
	# The trousers' waistband (U, u) and legs (T, t).
	"U": ["2c5288", "trousers"], "u": ["1e3a62", "trousers"],
	"T": ["3f6fb0", "trousers"], "t": ["2c5288", "trousers"],
	"B": ["3d3436", "boots"], "b": ["2b2527", "boots"],
	# Drawn over the skin's light (shoes) and its deepest (trousers) where the reference's
	# body has it (WalkArt, BODY).
	"K": ["3d3436", "boots"], "m": ["1e3a62", "trousers"],
	"N": ["c9a66e", "loincloth"], "n": ["9c7c4c", "loincloth"],
	# A blade's trail as it is swung (SlashArt, MowArt `trail`), drawn over the figure and its
	# outline (Figure, player.yaml `trail`): its bright middle, its shade, its fading end.
	"o": ["f7f1e6", "trail"], "+": ["e2d8c6", "trail"], "-": ["c9bda9", "trail"],
	# A dark line in a hair style (LooksArt): a ponytail's tie, a bun's band.
	"#": ["1f1a14", "hair"],
	# The shapes of clothes (see SHAPES): the light, middle and dark tone, painted in
	# the colours of the thing worn (see painted), then the trim's light and dark: a band, a
	# hem, laces, which keep the thing's own colours whatever it is dyed.
	"1": ["c0c0c0", ""], "2": ["808080", ""], "3": ["404040", ""], "4": ["f0f0f0", ""], "5": ["202020", ""],
	# The face's options (LooksArt.FACES), in their own layers: stubble (the skin's shade
	# and the hair's), a freckle, blush, a scar (the game makes these of the chosen skin
	# and hair, Looks.swaps), war paint, gold, a dark lens, the frame of glasses or a
	# patch and a clear lens.
	"O": ["906042", ""], "F": ["925333", ""], "P": ["e8867c", ""], "X": ["eaa590", ""],
	"Q": ["c42430", ""], "Y": ["f0c040", ""], "Z": ["2a2a33", ""], "G": ["2a2a33", ""], "R": ["9fd3e6", ""],
}
## Skin under each letter of the clothes, in the body layer.
const SKIN := {"L": "S", "C": "S", "c": "s", "V": "k", "U": "S", "u": "s", "T": "S", "t": "s", "m": "k",
	"K": "S", "B": "s", "b": "k"}
## The darker skin under an arm held out flat.
const DARKER := {"S": "s", "s": "k", "k": "k"}
## The shapes clothes are worn in (see painted), in three greys: what the shirt,
## trousers, shoes and hair are drawn with, cut and joined. A coat goes down over the
## hips and thighs, a hat is the top of the hair, wraps the legs, tall boots the shoes
## and a pixel of leg above. A tunic is the shirt with the waistband and a hemmed edge, a
## vest the shirt open down the front, a poncho the coat striped, an apron a panel over
## the front tied at the waist; the hats with a brim, the wreath, the bandana and the hood
## are drawn by way over the head (WearArt). A kilt is the waistband and two rows of the
## legs filled across, pleated and hemmed; sandals the soles and straps over the skin,
## moccasins the shoes with a stitched edge, high boots the shoes and two rows of leg.
const SHAPES := ["shirt", "coat", "hat", "trousers", "wraps", "boots", "tall_boots",
	"tunic", "vest", "poncho", "apron", "brim_hat", "dome_hat", "wreath", "bandana", "hood",
	"kilt", "sandals", "moccasins", "high_boots"]
## The tone of each letter of the clothes in a shape.
const TONE := {"L": "1", "C": "2", "c": "3", "V": "3", "U": "2", "u": "3", "T": "1", "t": "2", "m": "3",
	"K": "1", "B": "2", "b": "3",
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
## The body standing under the head, in the walk's proportions (WalkArt, copied from the
## reference): the neck, the torso down to the trousers' waistband (row `hips`) and the
## legs two pixels wide, their feet on the frame's last row; `rows` from row 11 + `drop`
## down to row 17 of the box. In every direction the head sits a row lower than the
## reference has it (`drop`, the body's bob when it stands), on legs of two rows: from the
## front too since the user's note of 2026-11-20 (shortened makes its frames drawn whole so).
## Each leg is drawn as the reference has it in the step it stands on; the arms hang over
## it (ARMS).
const BODY := {
	"s": {"drop": 1, "hips": 15, "rows": [
		"....cVkkVc....",
		"...ccCCCCcc...",
		"....cCCCCc....",
		"....UUuuUU....",
		"....tt..TT....",
		"....BB..BB....",
	]},
	"se": {"drop": 1, "hips": 15, "rows": [
		".....VkkVc....",
		"....ccCCC.....",
		".....cCCC.....",
		".....UUuUU....",
		".....TT.Tt....",
		".....KB.KB....",
	]},
	"e": {"drop": 1, "hips": 14, "rows": [
		"......CVk.....",
		".....cCCc.....",
		".....UUUu.....",
		".....ttt......",
		"......tTt.....",
		"......BBb.....",
	]},
	"ne": {"drop": 1, "hips": 15, "rows": [
		".....VVVC.....",
		"....ccccCCC...",
		".....VcccC....",
		".....uuuuu....",
		".....mm.tt....",
		".....bb.BB....",
	]},
	"n": {"drop": 1, "hips": 15, "rows": [
		"...CCVVVVCC...",
		"...CCccccCC...",
		"....CccccC....",
		"....uuuuuu....",
		"....mm..mm....",
		"....bb..bb....",
	]},
}
## The legs seen from the side, rows 15-17, by pose: "near" or "far" (that leg in front,
## striding), "sit" (forward, afloat; as long as the user asked on 2026-11-20); standing
## they are BODY's. The front and back views raise a leg from BODY instead (see legs).
const SIDE_LEGS := {
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
	"sit": [
		EMPTY,
		EMPTY,
		"......tTTB....",
	],
}
## Sitting, the knee that shows a pixel east of the waistband (on the frame's last row),
## by direction: its letter. Turned a little (se) the legs reach that far (the user's note
## of 2026-11-20), in every build.
const SIT_KNEE := {"se": "t"}

## Shoulders by direction: where the right arm and the left one hang from (side view: the
## near one and the far one), in the box as the view places them (moved by SHIFT and with
## the body's bob). Turned a little (se) the far arm hangs short and high by the body's
## side.
const SHOULDER := {
	"s": {"right": Vector2i(3, 13), "left": Vector2i(10, 13)},
	"se": {"right": Vector2i(3, 13), "left": Vector2i(9, 12)},
	"e": {"right": Vector2i(7, 13), "left": Vector2i(7, 13)},
	"ne": {"right": Vector2i(10, 13), "left": Vector2i(3, 13)},
	"n": {"right": Vector2i(10, 13), "left": Vector2i(3, 13)},
}
## Where a hand hangs at rest where its direction has it elsewhere than its view's idle
## (MOVES), in the same places as SHOULDER: turned a little (se) the far one is short.
const REST := {"se": {"left": Vector2i(9, 13)}}
## How each arm is drawn, by direction and hand: the skin's tones [on the line from the
## shoulder, beside it], those of the hand if they differ (`hand`: the line's second
## half) and the side the second pixel is on (`out`; 0: the arm is a pixel wide). The
## arms are bare, as the reference's are: what is worn covers the torso.
const ARMS := {
	"s": {
		"right": {"out": -1, "skin": ["s", "S"]},
		"left": {"out": 1, "skin": ["s", "S"]},
	},
	"se": {
		"right": {"out": -1, "skin": ["S", "S"]},
		"left": {"out": -1, "skin": ["s", "s"]},
	},
	"e": {
		"right": {"out": 1, "skin": ["S", "S"]},
		"left": {"out": 0, "skin": ["s", "s"]},
	},
	"ne": {
		"right": {"out": 1, "skin": ["S", "S"]},
		"left": {"out": 1, "skin": ["s", "s"]},
	},
	"n": {
		"right": {"out": 1, "skin": ["S", "S"], "hand": ["s", "s"]},
		"left": {"out": -1, "skin": ["S", "S"], "hand": ["s", "s"]},
	},
}
## The hands when they do not work, by view and animation, a frame each: [right hand,
## left hand] in the box (moved with the body when it bobs), and the legs and how far
## the body bobs down. The walk is copied from a reference instead (WalkArt), the jump,
## the swim and the rowing drawn whole (JumpArt, SwimArt, RowArt). Afloat in a vessel
## the body sits low, its legs forward ("sit"). Asleep the body stands facing south with
## its eyes shut and its legs pressed together ("together"), and Figure lays that frame
## on its side (Figure._lay_down). The gestures
## (Gestures): a wave over the head, a nod ("bob"), a shake of the body side to side
## ("lean"), a hand pointing out, beckoning, a bow, clapping in front, where a gesture
## has no frames drawn whole (GestureArt). The arms are short: a hand reaches a few
## pixels from its shoulder.
const MOVES := {
	"front": {
		"idle": [{"hands": [[3, 14], [10, 14]]}],
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
		"sleep": [{"hands": [[3, 14], [10, 14]], "legs": "together"}],
	},
	"side": {
		"idle": [{"hands": [[7, 14], [6, 14]]}],
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
	},
	"back": {
		"idle": [{"hands": [[10, 14], [3, 14]]}],
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
	},
}
## The hand in use in each frame of the works, by view, for the right hand (side view:
## the near one): "r" where it is, "a" the way what it holds points (0 up, then
## clockwise by eighths; -1: as carried), "ccw" when the thing turns anticlockwise (its
## edge leads the other way), "f" in front of the body or not (by default as the view
## has it), "o" where the other hand holds a two-handed thing, "bob" and "lean" how far
## the body bends down and forward, "eyes" "shut". A thing swung up over the head goes
## behind it, the hand hidden, so it does not cover the face. The chop, the dig, the
## slash, the aim, the eat, the reach and the mow are drawn whole with the thing's ways in
## their frames (ChopArt, DigArt, SlashArt, AimArt, EatArt, ReachArt, MowArt): every work
## now, so the table is left for one without frames of its own.
const WORKS := {
	"front": {},
	"side": {},
	"back": {},
}
## A thing held pointing at the ground in front of a body facing the viewer, drawn
## foreshortened (one more way after the eight).
const TOWARD := 8
## A thing held pointing right and down about 30 degrees, as a blade swept through and
## down to the ground (two more ways: LOW, and LOW_LEFT its mirror, ToolArt.turned).
const LOW := 9
const LOW_LEFT := 10
## The eight ways a thing held can point, clockwise from up.
const WAYS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

## Layer images already drawn, by name, and the hands' places (see anchors).
static var _drawn := {}
static var _anchors := []
## The body's form drawn (FormsArt: the build and the figure); use_form changes it.
static var build := "normal"
static var figure := "straight"


## Draws the body in another form from now on (FormsArt).
static func use_form(b: String, f: String) -> void:
	if b != build or f != figure:
		build = b
		figure = f
		_drawn = {}
		_anchors = []


## The image of layer `name` (player.yaml `layers`, `fists` or `trail`), drawn the first time.
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
					var angle: int = eighth(h.angle)
					if flipped and angle >= 0:
						angle = mirrored(angle)
					both[hand] = {"at": at, "front": h.front, "angle": angle}
				cols.append(both)
			_anchors.append(cols)
	return _anchors


## The picture of clothes worn in shape `shape` (SHAPES): its light, middle and dark
## tones in `colors` (html colours), as the game lays it over the figure (Figure.dressed).
## tones in `colors` (html colours), then the trim's light and dark (the middle and dark
## tones when not given), as the game lays it over the figure (Figure.dressed).
static func painted(shape: String, colors: Array) -> Image:
	var img: Image = layer("shapes/" + shape).duplicate()
	var tones := {}
	for i in 5:
		tones[INK[str(i + 1)][0]] = colors[i] if i < colors.size() else colors[i - 2]
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, Color.html(tones[p.to_html(false)]))
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


## The frame of column `c` ([name, i], see column) drawn whole under the head in
## direction `dir`, its hands with it: the walk's (WalkArt), the jump's (JumpArt), the
## swim's (SwimArt), the chop's (ChopArt, with the way the axe points: `a`), the dig's
## (DigArt, the shovel held up its shaft: `slide`), the slash's (SlashArt), the aim's
## (AimArt, the bow drawn for the frame: `bow`), the eat's (EatArt, the food as it is
## carried: `a` -1, the eyes shut on the bite: `eyes`), the reach's (ReachArt), the mow's
## (MowArt, the scythe drawn for the frame: `scythe`), a gesture's (GestureArt, its rows
## from column `x0`) or the rowing's (RowArt); {} for any other, made of the body standing
## and a pose.
static func whole_frame(dir: String, c: Array) -> Dictionary:
	var f := _whole_drawn(dir, c)
	if dir == "s" and not f.is_empty() and not c[0] in ["swim", "jump"]:
		return shortened(f)
	return f


## The frame of column `c` in direction `dir` as its module draws it (see whole_frame).
static func _whole_drawn(dir: String, c: Array) -> Dictionary:
	if GestureArt.FRAMES.has(c[0]):
		return GestureArt.frame(c[0], dir, c[1])
	match c[0]:
		"walk":
			return WalkArt.frame(dir, c[1])
		"jump":
			return JumpArt.frame(dir, c[1])
		"swim":
			return SwimArt.frame(dir, c[1])
		"chop":
			return ChopArt.frame(dir, c[1])
		"dig":
			return DigArt.frame(dir, c[1])
		"slash":
			return SlashArt.frame(dir, c[1])
		"aim":
			return AimArt.frame(dir, c[1])
		"eat":
			return EatArt.frame(dir, c[1])
		"reach":
			return ReachArt.frame(dir, c[1])
		"mow":
			return MowArt.frame(dir, c[1])
		"row":
			return RowArt.frame(dir, c[1])
	return {}


## A frame drawn whole for the front (south) with legs a pixel shorter (the user's note
## of 2026-11-20: the front's legs were a row longer than every other view's): the body
## over the waistband a row lower (`bob`, `top`, `neck`, `hips`, a blade's `trail`; the
## hands' places are less the bob), each leg a pixel shorter under it. A leg standing on
## the frame's last row loses the pixel under the waistband, its foot stays; a leg drawn
## up off the ground the same, a leg of one pixel goes down with the body. The hands'
## skin under the waistband stays where it is (the arm a row shorter, the hand as high over
## the ground as turned and from the side), and so do a scythe's blade (its snath goes
## down with the hands) and a bow lowered to the feet.
static func shortened(f: Dictionary) -> Dictionary:
	var out := f.duplicate()
	var top: int = f.get("top", 10)
	var rows: Array = f.rows
	var hips: int = f.hips - top
	# The rows under the waistband: `size` of them, a row fewer drawn from one lower.
	var size: int = rows.size() - hips - 1
	var low := []
	for j in size - 1:
		low.append(".".repeat((rows[0] as String).length()))
	var width := (rows[0] as String).length()
	var hands: Array = f.hands.duplicate(true)
	var low_hands := {}
	# What goes up to the waistband's row, which the row over it fills when it goes down.
	var up := {}
	for x in width:
		for j in size:
			var ch: String = (rows[hips + 1 + j] as String)[x]
			if WalkArt.HANDS.has(ch):
				# A hand under the waistband stays where it is, its arm a row shorter (as
				# turned, from the side and from behind: as high over the ground).
				low_hands[WalkArt.HANDS[ch][0]] = true
				if j > 0:
					low[j - 1][x] = ch
				else:
					up[x] = ch
	for i in 2:
		if low_hands.has(["right", "left"][i]):
			hands[i] = [hands[i][0], hands[i][1] - 1]
	out.hands = hands
	# Each leg (the west half of the picture, the east one, as legs splits them; a gesture's
	# rows start `x0` aside).
	var mid: int = 7 - int(f.get("x0", 0))
	for half: Array in [[0, mid], [mid, width]]:
		var leg := []
		for j in size:
			if _leg_part(rows[hips + 1 + j], half) != "":
				leg.append(j)
		var to := {}
		if leg.size() == 1:
			# A foot right under the waistband goes down with it.
			to[leg[0]] = mini(leg[0], size - 2)
		else:
			# The row under the waistband goes; the rest stays where it is.
			for j: int in leg.slice(1):
				to[j] = j - 1
		for j: int in to:
			var r: String = rows[hips + 1 + j]
			for x in range(half[0], half[1]):
				if r[x] != "." and not WalkArt.HANDS.has(r[x]):
					low[to[j]][x] = r[x]
	out.rows = rows.slice(0, hips + 1) + low
	var waist: String = out.rows[hips]
	for x: int in up:
		waist[x] = up[x]
	out.rows[hips] = waist
	if f.has("top"):
		out.top = top + 1
	else:
		# The walk's rows are from row 10 always (WalkArt.rows): a row empty over them.
		out.rows = [".".repeat((rows[0] as String).length())] + out.rows
	out.bob = f.bob + 1
	out.hips = f.hips + 1
	if f.has("neck"):
		out.neck = f.neck + 1
	if f.has("scythe"):
		# The scythe's blade hangs to the ground: it stays where it was.
		# The snath (`w`) goes down with the hands that hold it.
		var sc: Dictionary = f.scythe.duplicate()
		sc.at = [sc.at[0], sc.at[1] - 1]
		var drawn: Array = []
		for y in sc.rows.size():
			var r: String = (sc.rows[y] as String).replace("w", ".")
			if y > 0:
				var over: String = sc.rows[y - 1]
				for x in over.length():
					if over[x] == "w":
						r[x] = "w"
			drawn.append(r)
		sc.rows = drawn
		out.scythe = sc
	if f.has("bow"):
		# A bow lowered to the feet stays where it was, over the ground's row.
		var bw: Dictionary = f.bow.duplicate()
		if hands[0][1] + out.bob + bw.at[1] + bw.rows.size() - 1 >= 17:
			bw.at = [bw.at[0], bw.at[1] - 1]
		out.bow = bw
	if f.has("trail"):
		var t: Dictionary = f.trail.duplicate()
		t.at = [t.at[0], t.at[1] + 1]
		out.trail = t
	return out


## Way `a` mirrored left to right.
static func mirrored(a: int) -> int:
	if a == LOW or a == LOW_LEFT:
		return LOW + LOW_LEFT - a
	return a if a == TOWARD else (8 - a) % 8


## The eighth nearest to way `a`, for the hands' marks (an icon held turns by it).
static func eighth(a: int) -> int:
	match a:
		TOWARD:
			return 4
		LOW:
			return 3
		LOW_LEFT:
			return 5
	return a


## The pose of column `col` drawn in direction `dir` (a drawn one: s, se, e, ne, n) with
## hand `active` in use: {"bob", "lean", "legs", "eyes" ("open", or "shut" in the blink, the
## sleep and where a frame drawn whole has them so), "right": hand, "left": hand}, a hand
## being {"at": where it is in the box, "shoulder", "front": in front of the body,
## "holds": false for the other hand of a two-handed work, "worked", "angle": the way
## what it holds points (-1: as carried), "ccw", and for a frame drawn whole "slide": how
## far up its length it is held, ToolArt.turned, and "bow", "scythe": a bow, a scythe as
## the frame draws it (ToolArt.DRAWN)}.
static func pose(dir: String, active: String, col: int) -> Dictionary:
	var view: String = VIEW[dir]
	var c := column(col)
	var moves: Dictionary = MOVES[view]
	var move: Dictionary = moves.idle[0]
	if moves.has(c[0]):
		move = moves[c[0]][mini(c[1], moves[c[0]].size() - 1)]
	var whole := whole_frame(dir, c)
	# Standing the body is a row lower (BODY `drop`); the frames
	# drawn whole have it in their bob already.
	var drop: int = BODY[dir].drop
	if not whole.is_empty():
		# Its `lean` moves only the head (a shake): the body's rows are drawn where they are.
		move = {"hands": whole.hands, "bob": whole.bob - drop, "lean": whole.get("lean", 0)}
	var p := {"bob": move.get("bob", 0) + drop, "lean": move.get("lean", 0), "legs": move.get("legs", "stand"), "eyes": whole.get("eyes", "open")}
	# The blink, and the sleep (Figure._lay_down lays its frame down).
	if col == int(Figure.data().get("blink", -1)) or c[0] == "sleep":
		p.eyes = "shut"
	for i in 2:
		var hand: String = ["right", "left"][i]
		var at := Vector2i(move.hands[i][0], move.hands[i][1])
		if whole.is_empty() and at == _idle(view, hand):
			at = _rest(dir, hand)
		p[hand] = {"at": at + Vector2i(0, p.bob), "front": _front(view, hand), "holds": true, "worked": false, "angle": -1, "ccw": false}
	if WORKS[view].has(c[0]):
		var w: Dictionary = WORKS[view][c[0]][c[1]]
		p.bob = w.get("bob", 0) + drop
		p.lean = w.get("lean", 0)
		p.eyes = w.get("eyes", "open")
		var other := _other(active)
		var at := Vector2i(w.r[0], w.r[1] + drop)
		var angle: int = w.a
		var ccw: bool = w.get("ccw", false)
		var front: bool = w.get("f", _front(view, "right"))
		var off: Vector2i = Vector2i(w.o[0], w.o[1] + drop) if w.has("o") else Vector2i(-1, -1)
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
			p[other].at = _rest(dir, other) + Vector2i(0, p.bob)
	elif whole.has("a"):
		# A work drawn whole: the hand drawn holding the tool holds it whichever hand works
		# (a west direction is the east one mirrored, the tool with it); the other hangs as
		# drawn.
		p.eyes = whole.get("eyes", "open")
		var other := _other(active)
		p[active] = {"at": Vector2i(whole.hands[0][0], whole.hands[0][1] + p.bob), "front": whole.f, "holds": true,
			"worked": true, "angle": whole.a, "ccw": whole.get("ccw", false), "slide": whole.get("slide", 0),
			"bow": whole.get("bow", {}), "scythe": whole.get("scythe", {})}
		p[other].at = Vector2i(whole.hands[1][0], whole.hands[1][1] + p.bob)
		# A two-handed work (the aim: the other hand draws the string; the mow: both hands
		# on the snath) shows nothing of the other hand's own.
		p[other].holds = not whole.get("two", false)
		# The other hand is in front of the body as its view has it, unless the frame puts it
		# behind (`of`: a blade swept across in front of it).
		p[other].front = whole.get("of", _front(view, "left"))
	# A frame drawn whole has its hands where it draws them.
	var shift: Vector2i = SHIFT.get(dir, Vector2i.ZERO) if whole.is_empty() else Vector2i.ZERO
	for hand in ["right", "left"]:
		var s: Vector2i = SHOULDER[dir][hand]
		# A wider build hangs its arms further out (FormsArt.OUT), and the hands that
		# do not work with them.
		var out := Vector2i.ZERO
		if view != "side":
			out.x = FormsArt.OUT.get(build, 0) * (1 if s.x > 6 else -1)
		p[hand].shoulder = s + out + Vector2i(p.lean, p.bob) + SHIFT.get(dir, Vector2i.ZERO)
		# A hand raised over the neck of a frame drawn whole stays where it is in every form.
		var raised: bool = whole.has("neck") and p[hand].at.y < whole.neck
		var moved := out
		if not whole.is_empty() and view != "side":
			# A frame drawn whole is made wider by the side of the picture each pixel is on
			# (FormsArt.body), so a hand reaching across the middle goes with that side.
			moved.x = FormsArt.OUT.get(build, 0) * (1 if p[hand].at.x >= 7 else -1)
		p[hand].at += shift + (Vector2i.ZERO if (p[hand].worked and whole.is_empty()) or raised else moved)
	return p


## Where hand `hand` hangs standing in view `view` (MOVES idle), in the view's places.
static func _idle(view: String, hand: String) -> Vector2i:
	var at: Array = MOVES[view].idle[0].hands[0 if hand == "right" else 1]
	return Vector2i(at[0], at[1])


## Where hand `hand` hangs at rest in direction `dir` (REST, else as its view stands).
static func _rest(dir: String, hand: String) -> Vector2i:
	return REST.get(dir, {}).get(hand, _idle(VIEW[dir], hand))


## Whether a hand of a view is in front of the body by default.
static func _front(view: String, hand: String) -> bool:
	match view:
		"front":
			return true
		"side":
			return hand == "right"
	return false


## The legs of direction `dir` in pose `kind`: `rows`, BODY's legs standing (under the
## waistband down to the feet), as the pose has them. Seen from the side the other poses
## are SIDE_LEGS'. Seen from the front or the back a step raises a leg a pixel ("right":
## the one on the west of the picture, "left": the other), its foot where its shin was;
## sitting ("sit") only the feet show, under the body (and a knee, SIT_KNEE).
## Pressed together ("together", the sleep's) the leg on the east of the picture is a
## pixel nearer the other where two pixels part them; from the side they stand as they are.
static func legs(dir: String, kind: String, rows: Array) -> Array:
	if kind == "stand":
		return rows
	if kind == "together":
		if VIEW[dir] == "side":
			return rows
		return rows.map(func(r: String) -> String: return (r.substr(0, 6) + r.substr(7) + ".") if r.substr(6, 2) == ".." else r)
	if VIEW[dir] == "side":
		return SIDE_LEGS[kind]
	var n := rows.size()
	var out := []
	for y in n:
		var r := ""
		for x in EMPTY.length():
			var up: bool = kind == "sit" or (kind == "right" and x < 7) or (kind == "left" and x >= 7)
			if not up:
				r += rows[y][x]
			elif kind == "sit":
				r += rows[y][x] if y == n - 1 else "."
			else:
				r += rows[y + 1][x] if y + 1 < n else "."
		out.append(r)
	return out


## Row `r`'s pixels of a leg in columns `half` ([from, to)), the hands' skin left out.
static func _leg_part(r: String, half: Array) -> String:
	var out := ""
	for x in range(half[0], half[1]):
		if r[x] != "." and not WalkArt.HANDS.has(r[x]):
			out += r[x]
	return out


## The legs of direction `dir` sitting (legs "sit", the build's) as rows of the box from
## under BODY's waistband, as the sit draws them (frame_letters).
static func _seated(dir: String) -> Array:
	var b: Dictionary = BODY[dir]
	var hips: int = b.hips - 11 - b.drop
	return _low(dir, "sit", FormsArt.body(b.rows, dir, build, figure, 0, hips), hips)


## The legs `kind` (legs) under the waistband, row `hips` of `rows` (BODY's rows in the
## build's form), as frame_letters draws them: the side's hips curved, a knee seated.
static func _low(dir: String, kind: String, rows: Array, hips: int) -> Array:
	var low: Array = legs(dir, kind, rows.slice(hips + 1)).duplicate()
	if kind != "stand" and VIEW[dir] == "side" and figure == "curvy":
		low[0] = FormsArt.hipped(low[0], dir)
	if kind == "sit" and SIT_KNEE.has(dir):
		# Seated the waistband is on the last row: the knee goes past its east end.
		var last: String = low[-1]
		last[(rows[hips] as String).rstrip(".").length()] = SIT_KNEE[dir]
		low[-1] = last
	return low


## The letters of every layer in one frame: {layer: {pixel in the box: letter}}.
static func frame_letters(dir: String, active: String, col: int, real := "") -> Dictionary:
	var p := pose(dir, active, col)
	var out := {"body": {}, "shirt": {}, "trousers": {}, "boots": {}, "hair": {}, "fists": {}, "loincloth": {}, "trail": {}}
	var up := Vector2i(p.lean, p.bob)
	var parts := []
	var c := column(col)
	# A frame of the walk or the jump has its whole body under the head drawn.
	var whole := whole_frame(dir, c)
	if whole.is_empty():
		# The body standing in its form, the legs as the pose has them, the torso bobbing.
		var b: Dictionary = BODY[dir]
		var hips: int = b.hips - 11 - b.drop
		var rows := FormsArt.body(b.rows, dir, build, figure, 0, hips)
		_stamp(parts, _low(dir, p.legs, rows, hips), b.hips + 1, Vector2i.ZERO)
		_stamp(parts, rows.slice(0, hips + 1), 11, up)
	else:
		var rows: Array
		match c[0]:
			"jump":
				rows = JumpArt.rows(whole, dir, build, figure)
			"swim":
				rows = SwimArt.rows(whole, dir, build, figure)
			"chop":
				rows = ChopArt.rows(whole, dir, build, figure)
			"dig":
				rows = DigArt.rows(whole, dir, build, figure)
			"slash":
				rows = SlashArt.rows(whole, dir, build, figure)
			"aim":
				rows = AimArt.rows(whole, dir, build, figure)
			"eat":
				rows = EatArt.rows(whole, dir, build, figure)
			"reach":
				rows = ReachArt.rows(whole, dir, build, figure)
			"mow":
				rows = MowArt.rows(whole, dir, build, figure)
			"row":
				rows = RowArt.rows(whole, dir, build, figure)
				# The legs are the sit's, so the two follow each other without a jump in
				# every form; the body drawn whole goes over them.
				_stamp(parts, _seated(dir), BODY[dir].hips + 1, Vector2i.ZERO)
			_:
				if GestureArt.FRAMES.has(c[0]):
					rows = GestureArt.rows(whole, dir, build, figure)
				else:
					rows = WalkArt.rows(whole, dir, build, figure)
		_stamp(parts, rows, whole.get("top", 10), Vector2i(whole.get("x0", 0), 0))
		if whole.has("trail"):
			# A blade's trail (SlashArt, MowArt), its rows in the frame's pixels from `at`.
			var t: Dictionary = whole.trail
			_stamp(parts, t.rows, t.at[1] - ORIGIN.y, Vector2i(t.at[0] - ORIGIN.x, 0))
	# A frame drawn whole can turn the head another way (`head`: a shake), as drawn here
	# before a west frame is flipped; `seen` is the way it shows in the sheet.
	var turned: String = whole.get("head", dir)
	var seen := _mirrored(turned) if real != "" and real != dir else turned
	var head: Array = _turned(HEAD, turned, seen)
	if p.eyes == "shut":
		# Shut, an eye is a dark line where the iris and the white were.
		head = head.map(func(r: String) -> String: return r.replace("E", "S").replace("w", "S").replace("I", "E").replace("W", "E"))
	var head_from := parts.size()
	_stamp(parts, head, 2, up)
	var head_to := parts.size()
	_stamp(parts, _turned(LooksArt.HAIRS[HAIR_STYLE], turned, seen), 1, up)
	var solid := {}
	for e: Array in parts:
		solid[e[0]] = true
	# Arms behind the body show only where the body leaves them.
	for hand in ["left", "right"]:
		if not p[hand].front and whole.is_empty():
			_arm(out, p[hand], dir, hand, solid, false)
	for e: Array in parts:
		if WalkArt.HANDS.has(e[1]):
			# A hand of a frame drawn whole: with the fists in front of the body, else with it.
			var h: Array = WalkArt.HANDS[e[1]]
			var hand: String = h[0]
			if whole.has("a"):
				# A work's frame draws the hand holding the tool as the right one.
				hand = active if hand == "right" else _other(active)
			out["fists" if p[hand].front else "body"][e[0]] = h[1]
		else:
			_put(out, e[0], e[1])
	# The head is in front of the body: what the body wears does not show over it (the chin
	# of a nod over the collar).
	for i in range(head_from, head_to):
		for worn: String in ["shirt", "trousers", "boots"]:
			out[worn].erase(parts[i][0])
	for hand in ["left", "right"]:
		if p[hand].front and whole.is_empty():
			_arm(out, p[hand], dir, hand, solid, true)
	_loincloth(out)
	_shapes(out, up, dir)
	_looks(out, turned, seen, up)
	_wear(out, turned, seen, up)
	return out


## The layers of the looks to pick (LooksArt): `hair/<style>` and `face/<option>`, over
## the head as it bobs and leans, turned `turned` (see _turned: `seen` is the way the frame
## shows it; a look that is not the same on both sides, an eye patch, has its own rows for
## a west way, written as seen).
static func _looks(out: Dictionary, turned: String, seen: String, up: Vector2i) -> void:
	for kind: String in ["hair", "face"]:
		var all: Dictionary = LooksArt.HAIRS if kind == "hair" else LooksArt.FACES
		for id: String in all:
			var drawn := {}
			var rows := _turned(all[id], turned, seen)
			for y in rows.size():
				var r: String = rows[y]
				for x in r.length():
					if r[x] != ".":
						drawn[Vector2i(x, 1 + y) + up] = r[x]
			out[kind + "/" + id] = drawn


## The rows of a head's part (`table`: by way, s, se, e, ne and n, and a look's own west
## ways) turned `turned` as drawn, `seen` the way it shows: a frame drawn to be flipped
## into a west one takes a look's own rows for that way flipped, so they come out right;
## a head turned west in a frame not flipped (a shake from the front or behind) is its
## east one flipped, unless the look has rows of its own for it.
static func _turned(table: Dictionary, turned: String, seen: String) -> Array:
	if seen != turned and table.has(seen):
		return table[seen].map(func(r: String) -> String: return r.reverse())
	if table.has(turned):
		return table[turned]
	if MIRROR.has(turned) and table.has(MIRROR[turned]):
		return table[MIRROR[turned]].map(func(r: String) -> String: return r.reverse())
	return []


## Way `d` as a mirror shows it.
static func _mirrored(d: String) -> String:
	for west: String in MIRROR:
		if MIRROR[west] == d:
			return west
	return MIRROR.get(d, d)


## The loincloth the character is born in: the trousers' waistband, in cloth.
static func _loincloth(out: Dictionary) -> void:
	var t: Dictionary = out.trousers
	for at: Vector2i in t:
		if t[at] == "U":
			out.loincloth[at] = "N"
		elif t[at] == "u":
			out.loincloth[at] = "n"


## The shapes of the hats drawn by way (WearArt), over the head as it bobs and leans.
static func _wear(out: Dictionary, turned: String, seen: String, up: Vector2i) -> void:
	for id: String in WearArt.SHAPES:
		var drawn := {}
		var rows := _turned(WearArt.SHAPES[id], turned, seen)
		for y in rows.size():
			var r: String = rows[y]
			for x in r.length():
				if r[x] != ".":
					drawn[Vector2i(x, y) + up] = r[x]
		out["shapes/" + id] = drawn


## The shapes of clothes (SHAPES) of the frame, out of the letters of the clothes drawn
## (the hats of WearArt are _wear's).
static func _shapes(out: Dictionary, up: Vector2i, dir: String) -> void:
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
		if t[at] in ["T", "t", "m"]:
			shapes.wraps[at] = "1" if t[at] == "T" and at.y % 2 == 0 else ("2" if t[at] == "T" else "3")
		if b.has(at + Vector2i.DOWN) and t[at] in ["T", "t", "m"]:
			shapes.tall_boots[at] = tone
	for at: Vector2i in b:
		shapes.boots[at] = TONE[b[at]]
		shapes.tall_boots[at] = TONE[b[at]]
	for at: Vector2i in out.hair:
		if at.y - up.y <= 5:
			shapes.hat[at] = TONE[out.hair[at]]
	_garments(shapes, out, dir)
	_legwear(shapes, out)
	for name: String in SHAPES:
		if not WearArt.SHAPES.has(name):
			out["shapes/" + name] = shapes[name]


## The kilt, sandals, moccasins and high boots of a frame, out of its trousers and shoes.
static func _legwear(shapes: Dictionary, out: Dictionary) -> void:
	var t: Dictionary = out.trousers
	var b: Dictionary = out.boots
	var waist := -1000
	for at: Vector2i in t:
		if t[at] in ["U", "u"]:
			waist = maxi(waist, at.y)
	if waist > -1000:
		var rows := {}
		for at: Vector2i in t:
			if at.y <= waist + 2:
				var r: Vector2i = rows.get(at.y, Vector2i(at.x, at.x))
				rows[at.y] = Vector2i(mini(r.x, at.x), maxi(r.y, at.x))
		for y: int in rows:
			var r: Vector2i = rows[y]
			for x in range(r.x, r.y + 1):
				var tone := "2" if x == r.y else ("1" if (x - r.x) % 2 == 0 else "2")
				if y == waist + 2:
					tone = "4" if x % 2 == 0 else "5"
				elif y == waist and t.has(Vector2i(x, y)) and t[Vector2i(x, y)] == "u":
					tone = "3"
				shapes.kilt[Vector2i(x, y)] = tone
	for at: Vector2i in b:
		var sole := not b.has(at + Vector2i.DOWN)
		var top := not b.has(at + Vector2i.UP)
		if sole:
			shapes.sandals[at] = "3"
		elif (at.x + at.y) % 2 == 0:
			shapes.sandals[at] = "4"
		shapes.moccasins[at] = "4" if top and at.x % 2 == 0 else TONE[b[at]]
		shapes.high_boots[at] = TONE[b[at]]
	for at: Vector2i in t:
		if t[at] in ["T", "t", "m"] and (b.has(at + Vector2i.DOWN) or b.has(at + Vector2i(0, 2))):
			# The cuff on the upper of the two rows.
			var cuff := b.has(at + Vector2i(0, 2)) and not b.has(at + Vector2i.DOWN)
			shapes.high_boots[at] = "4" if cuff else TONE[t[at]]


## The tunic, vest, poncho and apron of a frame, out of its shirt and coat (_shapes).
static func _garments(shapes: Dictionary, out: Dictionary, dir: String) -> void:
	var view: String = VIEW[dir]
	var shirt: Dictionary = shapes.shirt
	var coat: Dictionary = shapes.coat
	if coat.is_empty():
		return
	# Each row's ends and the coat's lowest row.
	var rows := {}
	var top := 1000
	var bottom := -1000
	for at: Vector2i in coat:
		var r: Vector2i = rows.get(at.y, Vector2i(at.x, at.x))
		rows[at.y] = Vector2i(mini(r.x, at.x), maxi(r.y, at.x))
		top = mini(top, at.y)
		bottom = maxi(bottom, at.y)
	var waist := -1000
	for at: Vector2i in out.trousers:
		if out.trousers[at] in ["U", "u"]:
			waist = maxi(waist, at.y)
	for at: Vector2i in coat:
		var tone: String = coat[at]
		var r: Vector2i = rows[at.y]
		var middle := (r.x + r.y) / 2.0
		# The tunic: the shirt and the waistband, the last row hemmed.
		if shirt.has(at) or at.y <= waist:
			shapes.tunic[at] = "4" if at.y == mini(waist, bottom) and waist > -1000 else tone
		# The vest: the shirt, open down the middle in front, laced at the edges.
		if shirt.has(at):
			var open := view == "front" and at.y > top and absf(at.x - middle) < 1.0
			if not open:
				var edge := view == "front" and at.y > top and absf(at.x - middle) < 2.0
				shapes.vest[at] = "4" if edge and at.y % 2 == 0 else tone
		# The poncho: the coat striped every third row, its hem fringed.
		if at.y == bottom:
			if at.x % 2 == 0:
				shapes.poncho[at] = "5"
		else:
			shapes.poncho[at] = "4" if (at.y - top) % 3 == 2 else tone
		# The apron: a panel over the front from below the chest, the strings round the waist.
		var string := at.y == waist
		var panel := false
		if at.y > top + 1:
			match view:
				"front":
					panel = absf(at.x - middle) < 2.0
				"side":
					panel = at.x == r.y
		if string:
			shapes.apron[at] = "5"
		elif panel:
			shapes.apron[at] = tone


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


## An arm from the shoulder to the hand, drawn as ARMS says: a second pixel beside the
## line (under it, darker, when the arm is held out flat). In front of the body the skin
## goes to the fists, over what the hand holds; behind it the arm shows only where the
## body leaves it.
static func _arm(out: Dictionary, h: Dictionary, dir: String, hand: String, solid: Dictionary, front: bool) -> void:
	var spec: Dictionary = ARMS[dir][hand]
	var side: int = 0 if build in FormsArt.NARROW else spec.out
	var line := _line(h.shoulder, h.at)
	var d: Vector2i = h.at - h.shoulder
	var flat := absi(d.x) > absi(d.y)
	# The hand: the line's second half.
	var from := maxi(1, line.size() / 2) if line.size() > 1 else 0
	var arm := {}
	for i in line.size():
		arm[line[i]] = _tones(spec, i >= from)[0]
	if side != 0:
		for i in line.size():
			var beside: Vector2i = line[i] + (Vector2i.DOWN if flat else Vector2i(side, 0))
			if not arm.has(beside):
				var tones: Array = _tones(spec, i >= from)
				arm[beside] = DARKER[tones[0]] if flat else tones[1]
	for at: Vector2i in arm:
		if not front and solid.has(at):
			continue
		if front:
			out.fists[at] = arm[at]
		else:
			out.body[at] = arm[at]


## The skin's tones of an arm drawn as `spec` (ARMS) says, of its hand or not.
static func _tones(spec: Dictionary, hand: bool) -> Array:
	return spec.hand if hand and spec.has("hand") else spec.skin


## The pixels of a line from `a` to `b`, both ends included.
static func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(1.0, n)
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out
