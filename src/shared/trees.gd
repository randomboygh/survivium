extends RefCounted
## Tree species: what a tree looks like is data here, where it grows is up to the world
## generator (per biome). A species gives the shape of the trunk and crown, the leaves
## (broad leaves or needles), the tints of its trees and what it does in winter.
## Trees.place grows one on the lattice the crowns use: trunks on odd cells, crown points
## two cells apart on even levels, each point a 3x3x3 block of leaf cells (see Foliage).
## Every tree is noted in WorldData.trees by its trunk's column, so the client knows
## the species of a crown; a chopped tree may stay noted, which harms nothing.

const Mat := preload("res://src/shared/materials.gd")
const Content := preload("res://src/shared/content.gd")

## Leaves of a species.
const BROAD := 0
const NEEDLES := 1

## Species the engine and the generator refer to; the validator demands them.
const KNOWN := {"OAK": "core:oak", "SPRUCE": "core:spruce"}

static var OAK := 0
static var SPRUCE := 0

## Index -> record from `content/*/data/trees.yaml` (see Content): id, title,
## leaves (BROAD or NEEDLES), trunk [min, max], crown [3 radii], tints (Colors),
## bare (share of trees that drop their leaves in winter). What each means is in
## the data file; a tree is noted in WorldData.trees by its species index.
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
		if s.leaves == NEEDLES and s.crown[1] > s.crown[2]:
			out.append("trees: `%s`: crown [radius, min tiers, max tiers] has min above max" % s.id)
	return out


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
	var s: Dictionary = SPECIES[species]
	w.add_tree(x, z, species)
	if s.leaves == NEEDLES:
		_conifer(w, x, y, z, s, rng, scale)
	else:
		_broadleaf(w, x, y, z, s, rng, scale)


## A trunk and a crown of points in a low, wide ellipsoid: in the oblique view the top
## and the front of a crown both show, so a ball would look tall and narrow, while this
## one reads as round on screen (width about equal to height plus depth).
static func _broadleaf(w, x: int, y: int, z: int, s: Dictionary, rng: RandomNumberGenerator, scale: float) -> void:
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
	_fill(w, points)


## A tall trunk in a cone of tiers: every other level of points spreads wide and the one
## above it stays narrow, so the tiers show as layers of drooping branches, widest at
## the bottom.
static func _conifer(w, x: int, y: int, z: int, s: Dictionary, rng: RandomNumberGenerator, scale: float) -> void:
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
	_fill(w, points)


## Radius in points of tier `k` of `tiers` (before the narrow tiers are narrowed).
static func _tier_radius(radius: float, k: int, tiers: int) -> float:
	return radius * (1.0 - (k + 0.6) / tiers) + 0.35


## Cells of trunk a spruce's lowest tier hides on screen when its point in front of
## the trunk is `front` points south of it.
static func _hidden_trunk(front: int) -> int:
	return maxi(1, 3 * front - 1)


## Each crown point fills the air cells of the 3x3x3 block around it with leaves.
static func _fill(w, points: Array[Vector3i]) -> void:
	for p in points:
		for oy in range(-1, 2):
			for oz in range(-1, 2):
				for ox in range(-1, 2):
					if w.get_cell(p.x + ox, p.y + oy, p.z + oz) == Mat.AIR:
						w.set_cell(p.x + ox, p.y + oy, p.z + oz, Mat.LEAVES)
