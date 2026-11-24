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

## Tiers of lobes of an umbrella crown (pine), see _lobed.
const UMBRELLA_TIERS := 3
## How high over the crown's middle an umbrella's top lobe stands, in its heights.
const UMBRELLA_TOP := 1.65
## The lowest a crown point of a broad-leaved tree sits above its trunk's foot, in cells.
const LOWEST_POINT := 3
## How much narrower the levels between the layers of a broad crown are than the layers.
const INSET := 0.72
## A crown point belongs to the nearest trunk within this many cells.
const TREE_REACH := 8
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
	if not s.pictures.is_empty():
		# Its largest look the scale allows, the crown's top level filled a cell over.
		var top := 0
		var size := _size_of(scale)
		var looks: Array = s.pictures.looks
		for i in looks.size():
			if i / TreeLooks.VARIANTS == size:
				top = maxi(top, maxi(looks[i].trunk, looks[i].crown[3]) + 1)
		return top
	if s.tiers:
		return hidden_trunk(ceili((s.crown[0] + 0.2) * scale)) + s.trunk[1] + 2 * maxi(3, roundi(s.crown[2] * scale)) + 7
	if s.shape == "palm":
		# The trunk up to the tuft, the tuft a point (three cells) over it.
		return roundi(s.trunk[1] * scale) + 6
	if s.shape == "umbrella":
		# Tiers up from just over the trunk to the top lobe (see _lobed).
		return roundi(s.trunk[1] * scale) + 2 * ceili(UMBRELLA_TOP * (s.crown[1] + 0.2) * scale + 0.6) + 5
	return roundi(s.trunk[1] * scale) + 2 * floori((s.crown[1] + 0.3) * scale * 1.1) + 4


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
static func place(w, x: int, y: int, z: int, species: int, rng: RandomNumberGenerator, scale := 1.0) -> void:
	var crown := grow(w, x, y, z, species, rng, scale)
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
static func grow(w, x: int, y: int, z: int, species: int, rng: RandomNumberGenerator, scale := 1.0) -> Array[Vector3i]:
	var s: Dictionary = Trees.SPECIES[species]
	w.add_tree(x, z, species)
	if not s.pictures.is_empty():
		return _pictured(w, x, y, z, s, scale)
	match s.shape:
		"cone":
			return _conifer(w, x, y, z, s, rng, scale)
		"lobed", "umbrella":
			return _lobed(w, x, y, z, s, rng, scale)
		"palm":
			return _palm(w, x, y, z, s, rng, scale)
	return _broadleaf(w, x, y, z, s, rng, scale)


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
		if looks[i].variant == v and looks[i].trunk == k:
			if foot.size() == 0:
				foot.append(y0)
			else:
				foot[0] = y0
			return i
	return -1


## Of a saved chunk's trees ([column, species], WorldCells.pack_chunk) those of species
## drawn as pictures, which may have grown before they were (see regrow).
static func outgrown(trees: Array) -> Array:
	var out := []
	for t in trees:
		if t is Array and t.size() == 2 and t[0] is Vector2i and t[1] is int \
				and t[1] >= 0 and t[1] < Trees.SPECIES.size() and not Trees.SPECIES[t[1]].pictures.is_empty():
			out.append(t)
	return out


## Grows again, as it grows now, a standing tree of a species drawn as pictures in column
## `col` that grew before its species was (its trunk and crown of the old shapes, in a
## world `size_y` high): takes away its trunk and the leaves nearer it than any other
## trunk, grows its trunk and gives the points of its crown for `fill`. Leaves a tree
## already of its look, a stump, a young tree and a column of another species alone.
static func regrow(w, col: Vector2i, species: int, size_y: int) -> Array[Vector3i]:
	var none: Array[Vector3i] = []
	if w.trees.get(col, -1) != species or Trees.SPECIES[species].pictures.is_empty() or standing_look(w, col) >= 0:
		return none
	var bits: int = w.log_col(col.x, col.y)
	if bits == 0:
		return none
	var low := bits & -bits
	var y0: int = w.level_of(low)
	var k := 0
	while bits & (low << k) != 0:
		k += 1
	# A stump keeps no crown at its top (Felling takes the crown with the trunk).
	var top: int = ((low << k) * 255) | (low << maxi(k - 2, 0)) * 3
	var crowned := false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			crowned = crowned or w.leaf_col(col.x + dx, col.y + dz) & top != 0
	if young_at(w, col.x, y0, col.y) or not crowned:
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
	return grow(w, col.x, y0, col.y, species, null, scale)


## Whether column `c` is no nearer any of `others` than to trunk `at`, within TREE_REACH.
static func _nearest(c: Vector2i, at: Vector2i, others: Array[Vector2i]) -> bool:
	var d := (c - at).length_squared()
	if d > TREE_REACH * TREE_REACH * 2:
		return false
	for o in others:
		if (c - o).length_squared() < d:
			return false
	return true


## A tree drawn as pictures: the trunk of its look's cells of logs, and the points of its
## crown (filled 3x3x3 as any crown's) on the crowns' lattice where its look has crown,
## its own frame turned as the tree stands (turn_of).
static func _pictured(w, x: int, y: int, z: int, s: Dictionary, scale: float) -> Array[Vector3i]:
	var col := Vector2i(x, z)
	var look: Dictionary = s.pictures.looks[look_index(s, col, scale)]
	for i in look.trunk:
		w.set_cell(x, y + i, z, Mat.LOG)
	var points: Array[Vector3i] = []
	var c: Array = look.crown
	if c[2] == 0:
		return points
	var reach := ceili(maxf(maxf(absf(c[0]), absf(c[0] + c[2])), maxf(absf(c[1]), absf(c[1] + c[4]))) * 1.42) + 1
	var turn := turn_of(col)
	for level in range(y + (y & 1), y + int(c[3]), 2):
		for dz in range(-reach - (reach & 1), reach + 1, 2):
			for dx in range(-reach - (reach & 1), reach + 1, 2):
				var own := TreeLooks.to_own(dx, dz, turn)
				if TreeLooks.crown_has(look, roundi(own.x), level - y, roundi(own.y)):
					points.append(Vector3i(x + dx, level, z + dz))
	return points


## A trunk and a crown of points in a low, wide ellipsoid: in the oblique view the top
## and the front of a crown both show, so a ball would look tall and narrow, while this
## one reads as round on screen (width about equal to height plus depth).
static func _broadleaf(w, x: int, y: int, z: int, s: Dictionary, rng: RandomNumberGenerator, scale: float) -> Array[Vector3i]:
	var trunk := maxi(2, roundi(rng.randi_range(s.trunk[0], s.trunk[1]) * scale))
	for i in trunk:
		w.set_cell(x, y + i, z, Mat.LOG)
	var rx: float = (s.crown[0] + rng.randf_range(-0.2, 0.3)) * scale
	var ry: float = (s.crown[1] + rng.randf_range(-0.1, 0.3)) * scale
	var rz: float = (s.crown[2] + rng.randf_range(-0.2, 0.2)) * scale
	# Points sit on even levels, the middle one just above the trunk.
	var middle := ((y + trunk - 1) & ~1) + 2
	# A short trunk on an even foot would put the middle under LOWEST_POINT, and a small
	# crown then loses all its points: the middle goes a level up (the trunk follows it).
	if middle < y + LOWEST_POINT:
		middle += 2
	var points: Array[Vector3i] = []
	var reach := ceili(maxf(rx, maxf(ry, rz)))
	var column: bool = s.shape == "column"
	for dy in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var d := Vector3(dx / rx, dy / ry, dz / rz)
				# A column narrows above its middle to a point.
				if column and dy > 0:
					d.x /= 1.0 - 0.45 * dy / ry
					d.z /= 1.0 - 0.45 * dy / ry
				# The crown is layers (Foliage._layer_cards): every other level of points
				# a layer, the levels between them drawn in, so a band of shade shows
				# under each layer.
				if (middle + 2 * dy) >> 1 & 1 == 1:
					d.x /= INSET
					d.z /= INSET
				# A crown hanging low over a short trunk stays a little above the ground
				# (the point fills the cells round it, one on either side).
				if d.length() <= 1.0 + rng.randf_range(-0.1, 0.1) and middle + 2 * dy >= y + LOWEST_POINT:
					points.append(Vector3i(x + 2 * dx, middle + 2 * dy, z + 2 * dz))
	if s.shape == "weeping":
		_curtain(points, x, z, y + 1, rng)
	# A short trunk whose crown's lowest points were held up by LOWEST_POINT goes on up
	# to the crown (whose leaves reach a cell below its lowest point): else the crown
	# hangs over an empty cell and the trunk's top log shows as a stump under it.
	var low := y + trunk + 1
	if not points.is_empty():
		low = points[0].y
	for p in points:
		low = mini(low, p.y)
	for i in range(y + trunk, low - 1):
		w.set_cell(x, i, z, Mat.LOG)
	return points


## The rim of a weeping crown hangs down: under each point of the outer ring of a
## level that has no point below it, one or two more hang, not below `floor`.
static func _curtain(points: Array[Vector3i], x: int, z: int, floor: int, rng: RandomNumberGenerator) -> void:
	var have := {}
	for p in points:
		have[p] = true
	var hang: Array[Vector3i] = []
	for p in points:
		var out := Vector2(p.x - x, p.z - z).length()
		if out < 3.0 or have.has(p + Vector3i(0, -2, 0)):
			continue
		var drop := rng.randi_range(1, 2) + (1 if out > 4.0 else 0)
		for k in range(1, drop + 1):
			var q := p + Vector3i(0, -2 * k, 0)
			if q.y - 1 < floor:
				break
			hang.append(q)
	points.append_array(hang)


## A crown of round lobes: one over the trunk and a ring of three to five round it,
## each its own small ellipsoid at a height of its own, so the outline is bumpy and dark
## gaps show between the lobes. An umbrella crown has its lobes flat and wide, high on
## the trunk.
static func _lobed(w, x: int, y: int, z: int, s: Dictionary, rng: RandomNumberGenerator, scale: float) -> Array[Vector3i]:
	var umbrella: bool = s.shape == "umbrella"
	var trunk := maxi(2, roundi(rng.randi_range(s.trunk[0], s.trunk[1]) * scale))
	for i in trunk:
		w.set_cell(x, y + i, z, Mat.LOG)
	var rx: float = (s.crown[0] + rng.randf_range(-0.2, 0.3)) * scale
	var ry: float = (s.crown[1] + rng.randf_range(-0.1, 0.2)) * scale
	var rz: float = (s.crown[2] + rng.randf_range(-0.2, 0.2)) * scale
	var middle := ((y + trunk - 1) & ~1) + 2
	# Lobes: centre (in points, from the crown's middle) and radii.
	var lobes := []
	var count := rng.randi_range(6, 8) if umbrella else rng.randi_range(3, 5)
	var turn := rng.randf() * TAU
	var lobe := 0.55 if umbrella else 0.5
	lobes.append([Vector3(0.0, ry * (UMBRELLA_TOP if umbrella else 0.45), 0.0), Vector3(rx, ry * (0.3 if umbrella else 0.6), rz) * lobe])
	for k in count:
		var a := turn + TAU * (k + rng.randf_range(-0.2, 0.2)) / count
		var out := rng.randf_range(0.5, 0.65)
		var up := rng.randf_range(-0.6, 0.25) * ry
		var size := Vector3(rx, ry * 0.55, rz) * (lobe + rng.randf_range(-0.05, 0.1))
		if umbrella:
			# An umbrella (pine) stands in tiers of flat lobes, none hanging down the
			# trunk: the lower tiers wider and farther out, the top one small.
			var tier := k % UMBRELLA_TIERS
			var t := float(tier) / (UMBRELLA_TIERS - 1)
			up = (t * 2.0 - 0.35) * ry
			out *= 1.3 - 0.7 * t
			size = Vector3(rx, ry * 0.25, rz) * (lobe + rng.randf_range(-0.05, 0.1)) * (1.2 - 0.5 * t)
		lobes.append([Vector3(cos(a) * rx * out, up, sin(a) * rz * out), size])
	var points: Array[Vector3i] = []
	var have := {}
	for l in lobes:
		var c: Vector3 = l[0]
		var r: Vector3 = l[1]
		r = r.max(Vector3(0.75, 0.6, 0.75))
		for dy in range(floori(c.y - r.y), ceili(c.y + r.y) + 1):
			for dz in range(floori(c.z - r.z), ceili(c.z + r.z) + 1):
				for dx in range(floori(c.x - r.x), ceili(c.x + r.x) + 1):
					var d := Vector3((dx - c.x) / r.x, (dy - c.y) / r.y, (dz - c.z) / r.z)
					if d.length() <= 1.0 + rng.randf_range(-0.1, 0.1):
						var p := Vector3i(x + 2 * dx, middle + 2 * dy, z + 2 * dz)
						if p.y - 1 > y + 1 and not have.has(p):
							have[p] = true
							points.append(p)
	# The trunk goes on up into the lowest point over it: a trunk with air round it in a
	# gap between the lobes would show as a block of log standing in the crown.
	var into := -1
	for p in points:
		if p.x == x and p.z == z and p.y > y + trunk - 1 and (into < 0 or p.y < into):
			into = p.y
	if into < 0:
		into = middle
		points.append(Vector3i(x, middle, z))
	# A ring of points round the trunk from the lowest level of the crown up to there
	# hides it in front lobes' gaps too, from every side the camera looks.
	# An umbrella's (pine's) trunk shows between its tiers: no ring.
	var lowest := into
	for p in points:
		lowest = mini(lowest, p.y)
	if umbrella:
		lowest = into
	for level in range(lowest, into + 1, 2):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var p := Vector3i(x + 2 * dx, level, z + 2 * dz)
				if (level < into or dx != 0 or dz != 0) and not have.has(p):
					have[p] = true
					points.append(p)
	for i in range(y + trunk, into):
		w.set_cell(x, i, z, Mat.LOG)
	return points


## A palm: a tall bare trunk and on its top a tuft of fronds, each a line of points
## going out level from the top, one flat round tier (no leaves hanging lower); `crown`
## [length of a frond in points, fewest fronds, most fronds]. The client draws the fronds
## over these points (Foliage._fronds).
static func _palm(w, x: int, y: int, z: int, s: Dictionary, rng: RandomNumberGenerator, scale: float) -> Array[Vector3i]:
	var trunk := maxi(3, roundi(rng.randi_range(s.trunk[0], s.trunk[1]) * scale))
	var top := ((y + trunk) & ~1) + 2
	for i in range(y, top - 1):
		w.set_cell(x, i, z, Mat.LOG)
	var points: Array[Vector3i] = [Vector3i(x, top, z)]
	var have := {points[0]: true}
	var length := maxi(1, roundi(s.crown[0] * scale))
	var count := rng.randi_range(roundi(s.crown[1]), roundi(s.crown[2]))
	var turn := rng.randf() * TAU
	for k in count:
		var a := turn + TAU * (k + rng.randf_range(-0.2, 0.2)) / count
		for d in range(1, length + 1):
			var p := Vector3i(x + 2 * roundi(cos(a) * d), top, z + 2 * roundi(sin(a) * d))
			if p.y - 1 > y + 1 and not have.has(p):
				have[p] = true
				points.append(p)
	return points


## A tall trunk in a cone of tiers, widest at the bottom and narrowing evenly to a
## point: every other level of points stays a little narrower than the one under it,
## so the tiers show as layers of drooping branches.
static func _conifer(w, x: int, y: int, z: int, s: Dictionary, rng: RandomNumberGenerator, scale: float) -> Array[Vector3i]:
	var tiers := maxi(3, roundi(rng.randi_range(s.crown[1], s.crown[2]) * scale))
	var radius: float = (s.crown[0] + rng.randf_range(-0.2, 0.2)) * scale
	var reach := ceili(radius)
	# Offsets of the points: dx, tier, dz.
	var offsets: Array[Vector3i] = []
	var front := 0
	for k in tiers:
		var r := _tier_radius(radius, k, tiers)
		if k % 2 == 1:
			r *= 0.85
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				# A little narrower across z, as the top and front of a tier both show.
				if Vector2(dx, dz / 0.85).length() <= r + rng.randf_range(-0.15, 0.15):
					offsets.append(Vector3i(dx, k, dz))
					if k == 0 and dx == 0:
						front = maxi(front, dz)
	# In the oblique view the front of the lowest tier hangs over the trunk by its
	# depth and the sprigs below it, so the trunk below the tier is that long plus the
	# bit that should show.
	var bare := hidden_trunk(front) + rng.randi_range(s.trunk[0], s.trunk[1])
	var low := ((y + bare) + 1) & ~1
	var top := low + 2 * (tiers - 1)
	# The trunk ends a tier under the top, inside the narrow tiers there.
	for i in range(y, top - 2):
		w.set_cell(x, i, z, Mat.LOG)
	var points: Array[Vector3i] = []
	for o in offsets:
		points.append(Vector3i(x + 2 * o.x, low + 2 * o.y, z + 2 * o.z))
	points.append(Vector3i(x, top + 2, z))
	return points


## Radius in points of tier `k` of `tiers` (before the narrow tiers are narrowed).
static func _tier_radius(radius: float, k: int, tiers: int) -> float:
	return radius * (1.0 - (k + 0.5) / tiers) + 0.6


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
