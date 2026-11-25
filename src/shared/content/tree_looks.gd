extends RefCounted
## A tree species drawn as pictures (`picture` in trees.yaml): the approved drawing of the
## tree from the 8 sides the camera turns to, in a few looks (sizes and variants), and the
## shape of each look's crown in cells. The pictures are made from the mockup the drawing
## was approved in (survivium-builds/trees-redraw, integration/pr1/src/pack_pr1.py); this
## reads their `look.yaml`. Growth grows such a tree's trunk and crown cells from its look
## (Growth.look_of), the client draws it (TreeSprites).

const Content := preload("res://src/shared/content/content.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")

## How many variants each size has (the looks are size by size, a variant each in turn).
const VARIANTS := 2

## How the leaves in a species' frames are lit (look.yaml `rule`, tree.gdshader): the
## broadleaf trees' leaf bundles (MODULES), the conifers' fronds (FRONDS), the willow's
## hanging strands (HANGING) or the palms' leaves, whose light is drawn at 8 suns of the
## day as the bark's (PALMS: they keep their leaves all year, see TreeSprites).
const MODULES := 0
const FRONDS := 1
const HANGING := 2
const PALMS := 3
const RULES := {"fronds": FRONDS, "hanging": HANGING, "palms": PALMS}

## How far from a trunk's axis the middle of a body's feet is held (`hold`, Body): the
## trunk is drawn round but flat, a foot `front` pixels deep under a bark `half width`
## pixels to each side (look.yaml `foot`, measured by tools/tree_feet.py), the same from
## every side the camera turns to. So a body is held off an oval lying across the view:
## its feet come up to the foot's front with FEET_FRONT pixels of their own, beside it the
## sprite keeps FEET_SIDE pixels from the bark's middle line, and the oval reaches back
## away from the camera DEPTH of its width (behind the trunk a body stands off it, not in
## its picture). Without a view (the server) a circle round the axis inside the oval.
const FEET_FRONT := 2.0
const FEET_SIDE := 3.0
const DEPTH := 0.5
## Pixels of the pictures a cell (16 a world unit, a cell half a unit).
const TEXELS_CELL := 8.0
## The widest hold of any look (cells), so a body looks for trunks only this far round.
static var hold_most := 0.0


## The looks of species record `s`, from its `picture` file (a path in its bundle): a
## Dictionary {since, rule, leaves: [Color], bark: [Color], looks: [look], frames, bare
## (paths)}, `since` the trees' looks (WorldCells.TREE_LOOKS) its pictures came with, 1
## unless the file says (a chunk saved at an earlier one grows the species' trees again),
## `rule` how its leaves are lit (MODULES, or as the file's `rule` says: RULES), each
## look {size, variant, x, y, w, h, ax, ay, trunk, crown: [x0, z0, nx, ny, nz],
## cells: PackedByteArray of nx * ny * nz bits, x fastest, then y, then z, hold: cells
## from the trunk's axis a body's feet are held across and along the view (see
## FEET_FRONT), foot: Vector2 (look.yaml
## `foot`: the bark's half width and the foot's front, pixels)}; empty when it
## has none or it cannot be read.
static func read(s: Dictionary) -> Dictionary:
	var file: String = s.get("picture", "")
	if file == "":
		return {}
	var path := Content.asset(s, file)
	var yaml := Yaml.new()
	var data: Variant = yaml.parse(Content.text(path), path)
	if yaml.error != "" or not data is Dictionary or not data.get("looks") is Array:
		push_warning("tree pictures: cannot read %s %s" % [path, yaml.error])
		return {}
	var out := {"since": int(data.get("since", 1)),
		"rule": int(RULES.get(str(data.get("rule", "")), MODULES)), "leaves": [], "bark": [], "looks": [],
		"frames": path.get_base_dir().path_join("frames.png"), "bare": path.get_base_dir().path_join("bare.png")}
	for c in data.get("leaves", []):
		out.leaves.append(Color(str(c)))
	for c in data.get("bark", []):
		out.bark.append(Color(str(c)))
	for l: Dictionary in data.looks:
		var c: Array = l.crown
		var look := {}
		for k in ["x", "y", "w", "h", "ax", "ay", "trunk", "variant"]:
			look[k] = int(l[k])
		look.size = float(l.size)
		look.crown = [int(c[0]), int(c[1]), int(c[2]), int(c[3]), int(c[4])]
		look.cells = Marshalls.base64_to_raw(str(c[5]))
		var foot: Array = l.get("foot", [4.0, 1.0])
		look.foot = Vector2(float(foot[0]), float(foot[1]))
		look.hold = hold_of(look.foot)
		hold_most = maxf(hold_most, maxf(look.hold.x, look.hold.y + look.hold.z))
		out.looks.append(look)
	return out


## The hold (cells, see FEET_FRONT) of a look whose foot is `foot` (half width, front:
## pixels): the oval's half across the view, its half along it, and how far its middle
## lies behind the axis, away from the camera (its front edge FEET_FRONT before the foot's).
static func hold_of(foot: Vector2) -> Vector3:
	var across := (foot.x + FEET_SIDE) / TEXELS_CELL
	var front := (foot.y + FEET_FRONT) / TEXELS_CELL
	var half := maxf(front, DEPTH * across)
	return Vector3(across, half, half - front)


## Whether the crown of `look` has a cell at x, y, z of the tree's own frame (cells east,
## up from the foot's cell, south, the trunk at 0, 0).
static func crown_has(look: Dictionary, x: int, y: int, z: int) -> bool:
	var c: Array = look.crown
	var ix := x - int(c[0])
	var iz := z - int(c[1])
	if ix < 0 or y < 0 or iz < 0 or ix >= c[2] or y >= c[3] or iz >= c[4]:
		return false
	var i: int = (iz * int(c[3]) + y) * int(c[2]) + ix
	var bytes: PackedByteArray = look.cells
	return (bytes[i >> 3] >> (i & 7)) & 1 == 1


## The tree's own frame turned by `turn` eighths: where a world offset (dx, dz) from the
## trunk lies in it. The camera turned `c` eighths shows the tree's own drawing of turn
## c + turn (PixelView.view_of: a turn `a` looks with right = (cos a, -sin a)).
static func to_own(dx: float, dz: float, turn: int) -> Vector2:
	var a := -turn * PI / 4.0
	return Vector2(dx * cos(a) - dz * sin(a), dx * sin(a) + dz * cos(a))
