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
## The kinds of pieces of wood lying in the woods (look.yaml `pieces`), in the order of
## Growth.PIECE_LOG, PIECE_FALLEN, PIECE_BROKEN.
const PIECES := ["log", "fallen", "broken"]

## How far the middle of a body's feet keeps off a trunk's `ring` (Body): pixels of the pictures, the feet's own half
## width. The ring is the stump's cut as it is drawn (look.yaml `cut`, measured by tools/tree_feet.py), from the
## ground up to the cut, and the standing tree's is the ring of the stump it leaves, up to its crown, narrower there
## where its trunk is drawn so (`taper`; the user's ask, 2026-11-27: outline the stump's cut and carry it down to the
## ground and up to the crown, as a cone where a trunk narrows much).
const FEET := 3.0
## Pixels of the pictures a cell (16 a world unit, a cell half a unit).
const TEXELS_CELL := 8.0
## The farthest any look's or stump's ring reaches from the axis, FEET with it (cells), so a body looks for trunks
## only this far round.
static var hold_most := 0.0


## The looks of species record `s`, from its `picture` file (a path in its bundle): a
## Dictionary {since, rule, leaves: [Color], bark: [Color], looks: [look], frames, bare
## (paths)}, `since` the trees' looks (WorldCells.TREE_LOOKS) its pictures came with, 1
## unless the file says (a chunk saved at an earlier one grows the species' trees again),
## `rule` how its leaves are lit (MODULES, or as the file's `rule` says: RULES), each
## look {size, variant, x, y, w, h, ax, ay, trunk, crown: [x0, z0, nx, ny, nz],
## cells: PackedByteArray of nx * ny * nz bits, x fastest, then y, then z, ring: the
## ring its trunk holds a body off at its foot (ring_of: its stump's, on its axis), ring_top: the ring under its crown
## (as narrow as look.yaml `taper` says, as deep for its width as `ring`), narrow: Vector2 the heights the ring
## narrows from `ring` to `ring_top` between (cells over its foot: from its stump's cut to its crown; ring_at), hold:
## how far from the axis `ring` reaches, FEET with it (cells), top: how high the ring stands (its cells of log, up
## into the crown), foot: Vector2 (look.yaml `foot`: the bark's half width and the foot's front, pixels)}, and for the
## seasons
## (TreeSprites, tree.gdshader): `dry` the 7 steps of the dry leaves a tree that keeps them
## shows in winter and `blossom` the 7 of its spring blossom ([] none), `snow` and
## `snow_dry` the pictures of the snow on the tree in winter (the look it shows then: bare,
## or the evergreen crown) and on the crown of a tree that keeps its dry leaves ("" none),
## `evergreen` true for a tree that keeps its summer leaves all year (the hot zones'); empty
## when it has none or it cannot be read. The stump a felled tree leaves (Growth.stump_look):
## `stumps` its looks, one a size, {size, x, y, w, h, ax, ay, ring: its cut as drawn (ring_of), ring_top and
## narrow as a tree's (the same ring all the way up), hold, top: how high its cut stands over its foot as drawn,
## cells} in `stump_frames` (a row of the
## 8 turns of summer, then the 8 of winter with snow on its cut when `stump_snow`), `wood` the
## colours of its cut wood (6 steps, then the resin's; tree.gdshader). The pieces of it lying
## in the woods (Growth.place_piece): `pieces` by kind ("log", "fallen", "broken": the
## order of Growth's PIECE_*), each {logs, twigs (what the axe makes of it), reach (cells it
## lies out from its column at most), views: 16 [x, y, w, h, ax, ay] in `piece_frames`, the
## 8 turns of summer, then the 8 of winter; back, ahead: cells it lies behind and ahead of
## its column along its way, which hold a body off (Body._piece_touched)}.
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
	for k in ["dry", "blossom"]:
		out[k] = []
		for c in data.get(k, []):
			out[k].append(Color(str(c)))
	for k in ["snow", "snow_dry"]:
		var f := str(data.get(k, ""))
		out[k] = path.get_base_dir().path_join(f) if f != "" else ""
	out.evergreen = data.get("evergreen", false) == true
	out.wood = []
	for c in data.get("wood", []):
		out.wood.append(Color(str(c)))
	out.stumps = []
	var sf := str(data.get("stump_frames", ""))
	out.stump_frames = path.get_base_dir().path_join(sf) if sf != "" else ""
	out.stump_snow = data.get("stump_snow", false) == true
	for l in data.get("stumps", []):
		if l is Dictionary:
			var st := {"size": float(l.get("size", 0.0))}
			for k in ["x", "y", "w", "h", "ax", "ay"]:
				st[k] = int(l.get(k, 0))
			st.ring = ring_of(l.get("cut"), float(st.w) * 0.5 - 1.0)
			# How high its cut stands over its foot (cells; one cell of log before cuts were measured).
			st.top = float(l.get("top", TEXELS_CELL)) / TEXELS_CELL
			st.ring_top = st.ring
			st.narrow = Vector2(st.top, st.top)
			st.hold = _reach(st.ring)
			hold_most = maxf(hold_most, st.hold)
			out.stumps.append(st)
	out.pieces = {}
	var pf := str(data.get("piece_frames", ""))
	out.piece_frames = path.get_base_dir().path_join(pf) if pf != "" else ""
	var pieces: Variant = data.get("pieces", {})
	for kind in PIECES:
		var d: Variant = pieces.get(kind) if pieces is Dictionary else null
		if not d is Dictionary or not d.get("views") is Array or d.views.size() != 16:
			continue
		var views := []
		for v in d.views:
			if v is Array and v.size() == 6:
				views.append([int(v[0]), int(v[1]), int(v[2]), int(v[3]), int(v[4]), int(v[5])])
		if views.size() == 16:
			# How far it lies back and ahead along its way from its column (cells): its turn-0
			# summer view drawn across the screen.
			out.pieces[kind] = {"logs": int(d.get("logs", 1)), "twigs": int(d.get("twigs", 0)),
				"reach": float(d.get("reach", 1.0)), "views": views,
				"back": views[0][4] / TEXELS_CELL, "ahead": (views[0][2] - views[0][4]) / TEXELS_CELL}
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
		# The ring of the stump it leaves (Growth.stump_look: one a size), on its axis, up to the stump's cut; the
		# bark's half width round its foot when it leaves none. Over the cut it narrows to its crown as its trunk does
		# where that is drawn narrower (look.yaml `taper`: [height, half width], pixels).
		var stump: int = mini(out.looks.size() / VARIANTS, out.stumps.size() - 1)
		var ring: Vector3 = out.stumps[stump].ring if stump >= 0 else ring_of(null, look.foot.x)
		var cut: float = out.stumps[stump].top if stump >= 0 else 0.0
		look.ring = Vector3(ring.x, ring.y, 0.0)
		look.ring_top = look.ring
		look.narrow = Vector2(cut, cut)
		var taper: Variant = l.get("taper")
		if taper is Array and taper.size() == 2 and ring.x > 0.0:
			var crown := float(taper[0]) / TEXELS_CELL
			var half := float(taper[1]) / TEXELS_CELL
			if crown > cut and half > 0.0 and half < ring.x:
				look.ring_top = Vector3(half, ring.y * half / ring.x, 0.0)
				look.narrow = Vector2(cut, crown)
		look.top = float(look.trunk)
		look.hold = _reach(look.ring)
		hold_most = maxf(hold_most, look.hold)
		out.looks.append(look)
	return out


## The ring a trunk holds the middle of a body's feet off (with FEET, Body._trunk_touched), from look.yaml `cut`
## ([half width, half depth, across], pixels: the ellipse a stump's cut is drawn as, the same from every side, see
## tools/tree_feet.py): Vector3(half width, half depth, across) in cells, an ellipse on the ground that stands with
## its front on the axis (a body in front of the axis is drawn in front of the picture), its middle half its depth
## behind it and `across` to the camera's right, its width across the picture and its depth along the way the camera
## looks, as drawn. One with no `cut` (a mod's drawn before) is `half` pixels wide and half as deep.
static func ring_of(cut: Variant, half: float) -> Vector3:
	if cut is Array and cut.size() == 3:
		return Vector3(float(cut[0]), float(cut[1]), float(cut[2])) / TEXELS_CELL
	return Vector3(half, half * 0.5, 0.0) / TEXELS_CELL


## The ring of `look` (a tree's or a stump's: read) `h` cells over its foot: `ring` up to its stump's cut, narrowing
## from there to `ring_top` at its crown, that over it (`narrow`).
static func ring_at(look: Dictionary, h: float) -> Vector3:
	var narrow: Vector2 = look.narrow
	if h <= narrow.x or narrow.y <= narrow.x:
		return look.ring
	return (look.ring as Vector3).lerp(look.ring_top, minf(1.0, (h - narrow.x) / (narrow.y - narrow.x)))


## How far from the axis the ring `ring` (ring_of) reaches, FEET with it (cells): the corner of its box.
static func _reach(ring: Vector3) -> float:
	var gap := FEET / TEXELS_CELL
	return Vector2(absf(ring.z) + ring.x + gap, 2.0 * ring.y + gap).length()


## Where point `q` (cells from the axis: across the picture, to the camera's right, and along the way the camera
## looks, behind the axis) is from the ring `ring` (ring_of) grown by `grow` cells: under 1 inside it, 1 on its edge,
## over 1 outside, as the ellipse measures from its middle.
static func ring_depth(ring: Vector3, q: Vector2, grow: float) -> float:
	return Vector2((q.x - ring.z) / (ring.x + grow), (q.y - ring.y) / (ring.y + grow)).length()


## Point `q` (as in ring_depth) put on the edge of the ring `ring` grown by `grow` cells, straight away from its
## middle (Body slides a body round a trunk so).
static func ring_out(ring: Vector3, q: Vector2, grow: float) -> Vector2:
	var mid := Vector2(ring.z, ring.y)
	var d := ring_depth(ring, q, grow)
	if d < 0.000001:
		return Vector2(ring.z, -grow)
	return mid + (q - mid) / d


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
