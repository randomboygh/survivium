extends RefCounted
## Tree species: what a tree looks like is data here, where it grows is up to the world
## generator (per biome). A species gives the shape of the trunk and crown, the leaves
## (broad leaves or needles), the tints of its trees and what it does in winter.
## Trees.place grows one on the lattice the crowns use: trunks on odd cells, crown points
## two cells apart on even levels, each point a 3x3x3 block of leaf cells (see Foliage).
## Every tree is noted in WorldData.trees by its trunk's column, so the client knows
## the species of a crown; a chopped tree may stay noted, which harms nothing.

const Mat := preload("res://src/shared/content/materials.gd")
const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")

## Leaves of a species.
const BROAD := 0
const NEEDLES := 1

## Species the engine and the generator refer to; the validator demands them.
const KNOWN := {"OAK": "core:oak", "SPRUCE": "core:spruce"}

static var OAK := 0
static var SPRUCE := 0

## A crown point belongs to the nearest trunk within this many cells.
const TREE_REACH := 8

## Index -> record from `content/*/data/trees.yaml` (see Content): id, title,
## leaves (BROAD or NEEDLES), trunk [min, max], crown [3 radii], tints (Colors),
## bare (share of trees that drop their leaves in winter), seed (the item a felled
## tree drops besides logs and branches, "" none). What each means is in the data file; a tree is noted in WorldData.trees by its species index.
static var SPECIES: Array = []


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	SPECIES = []
	for r in Content.records("trees"):
		var s: Dictionary = r.duplicate()
		s.leaves = NEEDLES if r.leaves == "needles" else BROAD
		SPECIES.append(s)
	OAK = index(KNOWN.OAK)
	SPRUCE = index(KNOWN.SPRUCE)


## Index of the species with `id`, or -1.
static func index(id: String) -> int:
	for i in SPECIES.size():
		if SPECIES[i].id == id:
			return i
	return -1


## What is wrong with the loaded trees for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for name in KNOWN:
		if index(KNOWN[name]) < 0:
			out.append("trees: the engine needs `%s`" % KNOWN[name])
	for s in SPECIES:
		if s.trunk[0] > s.trunk[1]:
			out.append("trees: `%s`: trunk [min, max] has min above max" % s.id)
		if s.girth[0] > s.girth[1] or s.roots[0] > s.roots[1]:
			out.append("trees: `%s`: girth and roots [min, max] need min not above max" % s.id)
		if s.leaves == NEEDLES and s.crown[1] > s.crown[2]:
			out.append("trees: `%s`: crown [radius, min tiers, max tiers] has min above max" % s.id)
	return out


## The trunk of the tree of `species` in column `col`, `k` cells above its foot, in
## texels (8 to a cell) of its cell seen from above: x west to east, y north to south.
## Each tree has its own girth within the species' range, thins by its taper going up
## and may wander a texel or two east or west on the way (crook); a thick one is wider
## than its cell.
static func trunk_box(species: int, col: Vector2i, k: int) -> Rect2i:
	var s: Dictionary = SPECIES[species]
	var g: int = s.girth[0] + posmod(hash(col), s.girth[1] - s.girth[0] + 1)
	var width := maxi(4, g - floori(k * s.taper))
	var lean := 0
	var crook: int = s.crook
	for i in (k if crook > 0 else 0):
		var turn := posmod(hash(Vector3i(col.x, i, col.y)), 5)
		lean = clampi(lean + (1 if turn == 0 else (-1 if turn == 1 else 0)), -crook, crook)
	var side := 4 - width / 2
	return Rect2i(side + lean, side, width, width)


## Most cells a tree of `species` grown at `scale` takes above the ground it stands on.
static func height(species: int, scale := 1.0) -> int:
	var s: Dictionary = SPECIES[species]
	if s.leaves == NEEDLES:
		return _hidden_trunk(ceili((s.crown[0] + 0.2) * scale)) + s.trunk[1] + 2 * maxi(3, roundi(s.crown[2] * scale)) + 7
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


## Notes the tree and grows its trunk, as `place` does, and gives the points of its
## crown for `fill`: the world generator fills a big crown over several steps.
static func grow(w, x: int, y: int, z: int, species: int, rng: RandomNumberGenerator, scale := 1.0) -> Array[Vector3i]:
	var s: Dictionary = SPECIES[species]
	w.add_tree(x, z, species)
	if s.leaves == NEEDLES:
		return _conifer(w, x, y, z, s, rng, scale)
	return _broadleaf(w, x, y, z, s, rng, scale)


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
	var points: Array[Vector3i] = []
	var reach := ceili(maxf(rx, maxf(ry, rz)))
	for dy in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var d := Vector3(dx / rx, dy / ry, dz / rz)
				if d.length() <= 1.0 + rng.randf_range(-0.1, 0.1):
					points.append(Vector3i(x + 2 * dx, middle + 2 * dy, z + 2 * dz))
	return points


## A tall trunk in a cone of tiers: every other level of points spreads wide and the one
## above it stays narrow, so the tiers show as layers of drooping branches, widest at
## the bottom.
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
			r *= 0.68
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
	var bare := _hidden_trunk(front) + rng.randi_range(s.trunk[0], s.trunk[1])
	var low := ((y + bare) + 1) & ~1
	var top := low + 2 * (tiers - 1)
	for i in range(y, top):
		w.set_cell(x, i, z, Mat.LOG)
	var points: Array[Vector3i] = []
	for o in offsets:
		points.append(Vector3i(x + 2 * o.x, low + 2 * o.y, z + 2 * o.z))
	points.append(Vector3i(x, top + 2, z))
	return points


## Radius in points of tier `k` of `tiers` (before the narrow tiers are narrowed).
static func _tier_radius(radius: float, k: int, tiers: int) -> float:
	return radius * (1.0 - (k + 0.6) / tiers) + 0.35


## Cells of trunk a spruce's lowest tier hides on screen when its point in front of
## the trunk is `front` points south of it.
static func _hidden_trunk(front: int) -> int:
	return maxi(1, 3 * front - 1)


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


## Fells the tree whose trunk holds the log cell `cut`: that log and the trunk above it
## go, with the leaves of the crown above it (the leaves whose nearest trunk this one
## is), and the tree falls toward `away` (x, z), lying on the ground as logs along
## that line and branches and seeds where its crown lands (see WorldData.add_drop).
## What stays below the cut is a stump, still noted as the tree. Returns the cells
## made air, the cut first; empty when `cut` is no log of a noted tree.
static func fell(w, cut: Vector3i, away: Vector2) -> Array[Vector3i]:
	var gone: Array[Vector3i] = []
	var at := Vector2i(cut.x, cut.z)
	if not w.trees.has(at) or w.get_cell(cut.x, cut.y, cut.z) != Mat.LOG:
		return gone
	var s: Dictionary = SPECIES[w.trees[at]]
	var y := cut.y
	while w.get_cell(cut.x, y, cut.z) == Mat.LOG:
		gone.append(Vector3i(cut.x, y, cut.z))
		y += 1
	var logs := gone.size()
	# Trunks around, to leave the leaves of neighbouring crowns alone.
	var reach := TREE_REACH + 1
	var others: Array[Vector2i] = []
	for tz in range((cut.z - 2 * reach) | 1, cut.z + 2 * reach + 1, 2):
		for tx in range((cut.x - 2 * reach) | 1, cut.x + 2 * reach + 1, 2):
			if w.trees.has(Vector2i(tx, tz)) and Vector2i(tx, tz) != at:
				others.append(Vector2i(tx, tz))
	var above: int = w.all_bits & ~((1 << cut.y) - 1)
	var leaves := 0
	for z in range(cut.z - reach, cut.z + reach + 1):
		for x in range(cut.x - reach, cut.x + reach + 1):
			var bits: int = w.leaf_col(x, z) & above
			if bits == 0 or not _nearest(Vector2i(x, z), at, others):
				continue
			while bits != 0:
				var bit := bits & -bits
				bits ^= bit
				gone.append(Vector3i(x, w.level_of(bit), z))
				leaves += 1
	for c in gone:
		w.set_cell(c.x, c.y, c.z, Mat.AIR)
	# The things fall on the ground as it is now.
	w.refresh_shapes()
	_drops(w, cut, away, s, logs, leaves)
	return gone


## Whether column `c` is no nearer any of `others` than to trunk `at`.
static func _nearest(c: Vector2i, at: Vector2i, others: Array[Vector2i]) -> bool:
	var d := (c - at).length_squared()
	if d > TREE_REACH * TREE_REACH * 2:
		return false
	for o in others:
		if (c - o).length_squared() < d:
			return false
	return true


## Lays what a felled tree leaves on the ground: a log for every two cells of trunk,
## end to end from the stump toward `away`, and branches and seeds where the crown
## lands, more of them for a larger crown.
static func _drops(w, cut: Vector3i, away: Vector2, s: Dictionary, logs: int, leaves: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cut)
	var dir := away.normalized() if away.length() > 0.01 else Vector2.from_angle(rng.randf() * TAU)
	var side := Vector2(-dir.y, dir.x)
	var base := Vector2(cut.x + 0.5, cut.z + 0.5)
	var along := atan2(dir.y, dir.x)
	for i in maxi(1, (logs + 1) / 2):
		var p := base + dir * (2.0 + i * 1.8) + side * rng.randf_range(-0.4, 0.4)
		_drop(w, Items.LOG, p, along + rng.randf_range(-0.3, 0.3))
	if leaves == 0:
		return
	var crown: float = 2.0 * s.crown[0]
	var land := base + dir * (logs + crown)
	for i in clampi(leaves / 60, 2, 8):
		var p := land + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * crown
		_drop(w, Items.BRANCH, p, rng.randf() * TAU)
	if s.seed != "":
		for i in rng.randi_range(2, 4):
			var p := land + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * crown * 0.8
			_drop(w, s.seed, p, rng.randf() * TAU)


## One thing of `kind` lying on the ground at column point `p` (in cells), turned by
## `angle`; none over open water.
static func _drop(w, kind: String, p: Vector2, angle: float) -> void:
	var h: float = w.ground_height(p.x, p.y)
	if h < 0.0:
		return
	w.add_drop(kind, Vector3(p.x, h, p.y) * w.CELL, angle)
