extends RefCounted
## Trees and bushes growing in the world: the shape a tree of a species takes (Trees has
## the species) and the cells it fills. A tree grows on the lattice the crowns use:
## trunks on odd cells, crown points two cells apart on even levels, each point a 3x3x3
## block of leaf cells (see Foliage). Every tree is noted in WorldData.trees by its
## trunk's column, so the client knows the species of a crown; a chopped tree may stay
## noted, which harms nothing. A bush stands in one air cell on level grass and is noted
## in WorldData.bushes by that cell. Felling a tree is a rule of play (Felling).

const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const TreeLooks := preload("res://src/shared/content/tree_looks.gd")

## A crown point belongs to the nearest trunk within this many cells.
const TREE_REACH := 8
## The pieces of wood lying in the woods (WorldData.tree_pieces, TreeLooks.PIECES): a log,
## a fallen trunk with its limbs, a broken trunk with a sprout. A piece is one log cell on
## the ground in its column, noted as a tree of its species; its picture (TreeSprites) lies
## along piece_dir from there.
const PIECE_LOG := 0
const PIECE_FALLEN := 1
const PIECE_BROKEN := 2
## The woods have at most one piece in each square of this many cells (WorldGen._pieces).
const PIECE_BLOCK := 8
## How thick the stem of a young tree (place_young) is, in texels.
const YOUNG_GIRTH := 2


## Whether the trunk whose foot is the log at x, `foot`, z is a young tree's: its sapling's
## record on the ground under it says so (WorldData.fields: a sapling, third field 1).
static func young_at(w, x: int, foot: int, z: int) -> bool:
	var f: Variant = w.field_at(Vector3i(x, foot - 1, z))
	return f != null and f[2] >= 1.0 and Plants.is_sapling(f[0])


## The trunk of the tree of `species` in column `col`, `k` cells above its foot, in
## texels (8 to a cell) of its cell seen from above: x west to east, y north to south.
## Each tree has its own girth within the species' range, thins by its taper going up
## and may wander a texel or two east or west on the way (crook); a thick one is wider
## than its cell. A young tree grown from a sapling (`young`, see young_at) has a stem
## YOUNG_GIRTH texels thick, whatever its species.
static func trunk_box(species: int, col: Vector2i, k: int, young := false) -> Rect2i:
	var s: Dictionary = Trees.SPECIES[species]
	var g: int = s.girth[0] + posmod(hash(col), s.girth[1] - s.girth[0] + 1)
	var width := YOUNG_GIRTH if young else maxi(4, g - floori(k * s.taper))
	var lean := 0
	var crook: int = s.crook
	for i in (k if crook > 0 else 0):
		var turn := posmod(hash(Vector3i(col.x, i, col.y)), 5)
		lean = clampi(lean + (1 if turn == 0 else (-1 if turn == 1 else 0)), -crook, crook)
	var side := 4 - width / 2
	return Rect2i(side + lean, side, width, width)


## Most cells a tree of `species` grown at `scale` takes above the ground it stands on.
static func height(species: int, scale := 1.0) -> int:
	var s: Dictionary = Trees.SPECIES[species]
	# Its largest look the scale allows, the crown's top level filled a cell over (a crown
	# of no point gets one over the trunk, see _offsets).
	var top := 0
	var size := _size_of(scale)
	var looks: Array = s.pictures.get("looks", [])
	for i in looks.size():
		if i / TreeLooks.VARIANTS == size:
			top = maxi(top, maxi(looks[i].trunk + 2, looks[i].crown[3] + 1))
	return top


## The largest scale up to 1 at which a tree of `species` fits under `room` cells, or 0
## if it does not fit even at 0.6.
static func fit(species: int, room: int) -> float:
	var scale := 1.0
	while scale >= 0.6:
		if height(species, scale) <= room:
			return scale
		scale -= 0.1
	return 0.0


## Grows a tree of `species` with its trunk on cell x, y, z (x and z odd, y the first
## cell above the ground). `scale` makes it smaller or larger than usual, about 0.6..1.3,
## for stunted or old trees.
static func place(w, x: int, y: int, z: int, species: int, scale := 1.0) -> void:
	var crown := grow(w, x, y, z, species, scale)
	fill(w, crown, 0, crown.size())


## Grows a young tree of `species` with its trunk on cell x, y, z (as `place`): a short
## trunk under a crown of one point (two, one over the other, for a tree of tiers or a
## cone), the smallest tree the crowns' lattice draws. Returns how many cells high it is.
static func place_young(w, x: int, y: int, z: int, species: int) -> int:
	var s: Dictionary = Trees.SPECIES[species]
	w.add_tree(x, z, species)
	var first := ((y + 1) & ~1) + 2
	for i in range(y, first):
		w.set_cell(x, i, z, Mat.LOG)
	var points: Array[Vector3i] = [Vector3i(x, first, z)]
	if s.tiers or s.shape == "cone":
		points.append(Vector3i(x, first + 2, z))
	fill(w, points, 0, points.size())
	return points[-1].y + 2 - y


## Notes the tree and grows its trunk, as `place` does, and gives the points of its
## crown for `fill`: the world generator fills a big crown over several steps.
static func grow(w, x: int, y: int, z: int, species: int, scale := 1.0) -> Array[Vector3i]:
	var s: Dictionary = Trees.SPECIES[species]
	w.add_tree(x, z, species)
	# Every species is drawn as pictures (Trees.check); one that is not grows nothing.
	if s.pictures.is_empty():
		return []
	return _pictured(w, x, y, z, s, scale)


## A species drawn as pictures (Trees: `pictures`): the index of the look (TreeLooks) a tree
## in column `col` grown at `scale` (see fit) takes: its variant and its turn in the world
## by the column, its size the largest the scale lets it reach, and smaller for some, so a
## wood has trees of three ages.
static func look_index(s: Dictionary, col: Vector2i, scale: float) -> int:
	var roll := posmod(hash(Vector3i(col.x, 17, col.y)), 100)
	var size := mini(_size_of(scale), 0 if roll < 20 else (1 if roll < 55 else 2))
	return size * TreeLooks.VARIANTS + variant_of(col)


## Which of its sizes (0 thin, 1 middle, 2 thick) a pictured tree grown at `scale` may reach.
static func _size_of(scale: float) -> int:
	return 2 if scale > 0.95 else (1 if scale > 0.75 else 0)


## The variant of a pictured tree in column `col`.
static func variant_of(col: Vector2i) -> int:
	return posmod(hash(Vector3i(col.x, 23, col.y)), TreeLooks.VARIANTS)


## How many eighths of a turn a pictured tree in column `col` stands turned in the world
## (TreeLooks.to_own).
static func turn_of(col: Vector2i) -> int:
	return posmod(hash(Vector3i(col.x, 29, col.y)), 8)


## The look a standing pictured tree in column `col` has, -1 for none: a species drawn as
## pictures, its trunk of logs from its foot as many cells high as its look's (a felled
## tree's stump is lower, a young tree's is no look), and the foot's level in `foot`.
static func standing_look(w, col: Vector2i, foot: Array = []) -> int:
	var species: int = w.trees.get(col, -1)
	if species < 0 or species >= Trees.SPECIES.size():
		return -1
	var s: Dictionary = Trees.SPECIES[species]
	if s.pictures.is_empty():
		return -1
	var bits: int = w.log_col(col.x, col.y)
	if bits == 0:
		return -1
	var low := bits & -bits
	var y0: int = w.level_of(low)
	var k := 0
	while bits & (low << k) != 0:
		k += 1
	if young_at(w, col.x, y0, col.y):
		return -1
	var v := variant_of(col)
	var looks: Array = s.pictures.looks
	for i in looks.size():
		if looks[i].variant != v or looks[i].trunk != k:
			continue
		# A stump cut as high as this look's trunk lost the crown over it (Felling takes
		# the leaves nearest its trunk from the cut up): the leaves over the trunk's top
		# round a few points of the look's crown nearest the trunk tell (see _probes).
		var probes := _probes(looks[i], turn_of(col), y0 & 1)
		var crowned := probes.is_empty()
		var over: int = ~((1 << (y0 + k)) - 1)
		for p in probes:
			if w.leaf_col(col.x + p.x, col.y + p.z) & (7 << maxi(y0 + p.y - 1, 0)) & over != 0:
				crowned = true
				break
		if not crowned:
			return -1
		if foot.size() == 0:
			foot.append(y0)
		else:
			foot[0] = y0
		return i
	return -1


## The stump a felled pictured tree left in column `col` (TreeLooks `stumps`), -1 for none:
## a species drawn as pictures with stumps, one cell of log on its foot with nothing over it
## (Felling leaves that much; a taller stump, cut before stumps were drawn, stays in cells),
## the foot's level in `foot`. Its size is the one the column's tree came to (look_index at
## the full scale: a stunted tree's stump may come out a size larger).
static func stump_look(w, col: Vector2i, foot: Array = []) -> int:
	var species: int = w.trees.get(col, -1)
	if species < 0 or species >= Trees.SPECIES.size():
		return -1
	var p: Dictionary = Trees.SPECIES[species].pictures
	if p.is_empty() or p.get("stumps", []).is_empty() or w.tree_pieces.has(col):
		return -1
	var bits: int = w.log_col(col.x, col.y)
	if bits == 0 or bits & (bits - 1) != 0:
		return -1
	var y0: int = w.level_of(bits)
	if young_at(w, col.x, y0, col.y):
		return -1
	if foot.size() == 0:
		foot.append(y0)
	else:
		foot[0] = y0
	return mini(look_index(Trees.SPECIES[species], col, 1.0) / TreeLooks.VARIANTS, p.stumps.size() - 1)


## The piece of wood lying in column `col` (PIECE_LOG, PIECE_FALLEN, PIECE_BROKEN), -1 for
## none: noted so (WorldData.tree_pieces), a species with that piece drawn, its one log cell
## there with nothing over it; the level of that cell in `foot`.
static func piece_look(w, col: Vector2i, foot: Array = []) -> int:
	var kind: int = w.tree_pieces.get(col, -1)
	var species: int = w.trees.get(col, -1)
	if kind < 0 or kind >= TreeLooks.PIECES.size() or species < 0 or species >= Trees.SPECIES.size():
		return -1
	if not Trees.SPECIES[species].pictures.get("pieces", {}).has(TreeLooks.PIECES[kind]):
		return -1
	var bits: int = w.log_col(col.x, col.y)
	if bits == 0 or bits & (bits - 1) != 0:
		return -1
	if foot.size() == 0:
		foot.append(w.level_of(bits))
	else:
		foot[0] = w.level_of(bits)
	return kind


## Lays a piece of wood `kind` of `species` with its log on cell x, y, z (see piece_look).
static func place_piece(w, x: int, y: int, z: int, species: int, kind: int) -> void:
	w.add_tree(x, z, species)
	w.set_cell(x, y, z, Mat.LOG)
	w.tree_pieces[Vector2i(x, z)] = kind


## The way (x, z) a piece lying in column `col` lies out from it: its drawing of turn 0
## lies along its own x (east), turned in the world as a tree is (turn_of, TreeLooks.to_own).
static func piece_dir(col: Vector2i) -> Vector2:
	return Vector2.from_angle(turn_of(col) * PI / 4.0)


## How far (cells) the pieces of `kind` of any species lie out from their column at most
## (TreeLooks `reach`).
static func piece_reach(kind: int) -> float:
	var most := 0.0
	for s: Dictionary in Trees.SPECIES:
		var d: Dictionary = s.pictures.get("pieces", {}).get(TreeLooks.PIECES[kind], {})
		most = maxf(most, float(d.get("reach", 0.0)))
	return most


## Of the trees ([column, species], WorldCells.pack_chunk) of a chunk saved at trees' looks
## `looks` (WorldCells.TREE_LOOKS) those of species drawn as pictures since later looks
## (TreeLooks `since`): they grew before their species was drawn so (see regrow).
static func outgrown(trees: Array, looks: int) -> Array:
	var out := []
	for t in trees:
		if t is Array and t.size() == 2 and t[0] is Vector2i and t[1] is int \
				and t[1] >= 0 and t[1] < Trees.SPECIES.size() and not Trees.SPECIES[t[1]].pictures.is_empty() \
				and int(Trees.SPECIES[t[1]].pictures.since) > looks:
			out.append(t)
	return out


## Grows again, as it grows now, a standing tree of a species drawn as pictures in column
## `col` that grew before its species was (its trunk and crown of the old shapes, in a
## world `size_y` high): takes away its trunk and the leaves nearer it than any other
## trunk, grows its trunk and gives the points of its crown for `fill`. Leaves a stump, a
## young tree and a column of another species alone. Only for the trees `outgrown` gives:
## an old tree's trunk may be as high as a look's, with its crown over it, so standing_look
## cannot tell it from a tree grown as its look, which this would grow again.
static func regrow(w, col: Vector2i, species: int, size_y: int) -> Array[Vector3i]:
	var none: Array[Vector3i] = []
	if w.trees.get(col, -1) != species or Trees.SPECIES[species].pictures.is_empty():
		return none
	var bits: int = w.log_col(col.x, col.y)
	if bits == 0:
		return none
	var low := bits & -bits
	var y0: int = w.level_of(low)
	var k := 0
	while bits & (low << k) != 0:
		k += 1
	if young_at(w, col.x, y0, col.y) or not _crowned(w, col, low, k):
		return none
	for i in k:
		w.set_cell(col.x, y0 + i, col.y, Mat.AIR)
	var others: Array[Vector2i] = []
	var reach := TREE_REACH + 1
	for tz in range((col.y - 2 * reach) | 1, col.y + 2 * reach + 1, 2):
		for tx in range((col.x - 2 * reach) | 1, col.x + 2 * reach + 1, 2):
			if w.trees.has(Vector2i(tx, tz)) and Vector2i(tx, tz) != col:
				others.append(Vector2i(tx, tz))
	var above: int = w.all_bits & ~(low - 1)
	for z in range(col.y - reach, col.y + reach + 1):
		for x in range(col.x - reach, col.x + reach + 1):
			var leaf: int = w.leaf_col(x, z) & above
			if leaf == 0 or not _nearest(Vector2i(x, z), col, others):
				continue
			while leaf != 0:
				var bit := leaf & -leaf
				leaf ^= bit
				w.set_cell(x, w.level_of(bit), z, Mat.AIR)
	var scale := fit(species, size_y - y0)
	if scale <= 0.0:
		return none
	return grow(w, col.x, y0, col.y, species, scale)


## Whether column `c` is no nearer any of `others` than to trunk `at`, within TREE_REACH.
static func _nearest(c: Vector2i, at: Vector2i, others: Array[Vector2i]) -> bool:
	var d := (c - at).length_squared()
	if d > TREE_REACH * TREE_REACH * 2:
		return false
	for o in others:
		if (c - o).length_squared() < d:
			return false
	return true


## Whether the trunk in column `col` whose lowest log is the bit `low` of its column and
## which is `k` logs high has leaves round its top (two levels under it to eight over it,
## in its column and the eight around): a standing tree's crown, which a stump has not
## (Felling takes the crown with the trunk).
static func _crowned(w, col: Vector2i, low: int, k: int) -> bool:
	var top: int = ((low << k) * 255) | (low << maxi(k - 2, 0)) * 3
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if w.leaf_col(col.x + dx, col.y + dz) & top != 0:
				return true
	return false


## A tree drawn as pictures: the trunk of its look's cells of logs, and the points of its
## crown (filled 3x3x3 as any crown's) on the crowns' lattice where its look has crown,
## its own frame turned as the tree stands (turn_of).
static func _pictured(w, x: int, y: int, z: int, s: Dictionary, scale: float) -> Array[Vector3i]:
	var col := Vector2i(x, z)
	var look: Dictionary = s.pictures.looks[look_index(s, col, scale)]
	for i in look.trunk:
		w.set_cell(x, y + i, z, Mat.LOG)
	var points: Array[Vector3i] = []
	for p in _offsets(look, turn_of(col), y & 1):
		points.append(Vector3i(x + p.x, y + p.y, z + p.z))
	return points


## The points of the crown of `look` as offsets from its trunk's foot, the tree standing
## turned `turn` eighths (TreeLooks.to_own) on a foot of parity `odd` (the points sit on
## even levels): worked out once for each and kept in the look ("points").
static func _offsets(look: Dictionary, turn: int, odd: int) -> Array[Vector3i]:
	var kept: Dictionary = look.get_or_add("points", {})
	var key := turn * 2 + odd
	if kept.has(key):
		return kept[key]
	var out: Array[Vector3i] = []
	var c: Array = look.crown
	if c[2] > 0:
		var reach := ceili(maxf(maxf(absf(c[0]), absf(c[0] + c[2])), maxf(absf(c[1]), absf(c[1] + c[4]))) * 1.42) + 1
		for dy in range(odd, int(c[3]), 2):
			for dz in range(-reach - (reach & 1), reach + 1, 2):
				for dx in range(-reach - (reach & 1), reach + 1, 2):
					var own := TreeLooks.to_own(dx, dz, turn)
					if TreeLooks.crown_has(look, roundi(own.x), dy, roundi(own.y)):
						out.append(Vector3i(dx, dy, dz))
	if out.is_empty():
		# A crown too small for the points' lattice: one point over the trunk, as a young
		# tree's (place_young).
		var t: int = look.trunk
		out.append(Vector3i(0, t - 1 if (t - 1) & 1 == odd else t, 0))
	kept[key] = out
	return out


## How many points of a crown standing_look looks at.
const PROBES := 4

## The points of the crown of `look` (offsets, see _offsets) that tell a standing tree from
## a stump: the PROBES nearest its trunk whose leaves reach over its top.
static func _probes(look: Dictionary, turn: int, odd: int) -> Array[Vector3i]:
	var kept: Dictionary = look.get_or_add("probes", {})
	var key := turn * 2 + odd
	if kept.has(key):
		return kept[key]
	var over: Array[Vector3i] = []
	for p in _offsets(look, turn, odd):
		if p.y + 1 >= look.trunk:
			over.append(p)
	over.sort_custom(_nearer)
	var out: Array[Vector3i] = []
	for i in mini(PROBES, over.size()):
		out.append(over[i])
	kept[key] = out
	return out


## Whether crown point `a` is nearer its trunk than `b` (across first, then up).
static func _nearer(a: Vector3i, b: Vector3i) -> bool:
	return (a.x * a.x + a.z * a.z) * 256 + a.y < (b.x * b.x + b.z * b.z) * 256 + b.y


## Cells of trunk a spruce's lowest tier hides on screen when its point in front of
## the trunk is `front` points south of it (the tier drawn shallow, see Foliage._spruce).
static func hidden_trunk(front: int) -> int:
	return maxi(1, front - 1)


## Each crown point fills the air cells of the 3x3x3 block around it with leaves: the
## `count` points from `from` on. Gives the index of the next point.
static func fill(w, points: Array[Vector3i], from: int, count: int) -> int:
	var to := mini(from + count, points.size())
	for i in range(from, to):
		var p := points[i]
		for oy in range(-1, 2):
			for oz in range(-1, 2):
				for ox in range(-1, 2):
					if w.get_cell(p.x + ox, p.y + oy, p.z + oz) == Mat.AIR:
						w.set_cell(p.x + ox, p.y + oy, p.z + oz, Mat.LEAVES)
	return to


## True when a bush can stand in cell x, y, z: air on level grass.
static func bush_fits(w, x: int, y: int, z: int) -> bool:
	return y > 0 and y < w.size_y and w.get_cell(x, y - 1, z) == Mat.GRASS and w.get_cell(x, y, z) == Mat.AIR \
		and w.slope_mask(x, y - 1, z) == w.FULL


## True when the ground round cell x, y, z is nowhere lower than under it: the
## generator grows bushes only there, since one on a lone bump or at the brink of a
## drop stands over the open air beside it and looks hung there as the camera turns.
static func bush_level(w, x: int, y: int, z: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dz != 0) and w.surface_y(x + dx, z + dz) < y:
				return false
	return true


## Grows a bush of `type` (a Bushes index) in cell x, y, z (the first cell above the ground).
static func place_bush(w, x: int, y: int, z: int, type: int) -> void:
	w.add_bush(Vector3i(x, y, z), type)
