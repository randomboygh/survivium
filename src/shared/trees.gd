extends RefCounted
## Tree species: what a tree looks like is data here, where it grows is up to the world
## generator (per biome). A species gives the shape of the trunk and crown, the leaves
## (broad leaves or needles), the tints of its trees and what it does in winter.
## Trees.place grows one on the lattice the crowns use: trunks on odd cells, crown points
## two cells apart on even levels, each point a 3x3x3 block of leaf cells (see Foliage).
## Every tree is noted in WorldData.trees by its trunk's column, so the client knows
## the species of a crown; a chopped tree may stay noted, which harms nothing.

const Mat := preload("res://src/shared/materials.gd")

const OAK := 0
const SPRUCE := 1

## Leaves of a species.
const BROAD := 0
const NEEDLES := 1

## name: id for content files; title: shown to players.
## leaves: BROAD or NEEDLES. trunk: [min, max] cells of trunk under the crown's middle
## (oak) or under the lowest tier (spruce). crown: radii across x, up, across z in
## points of the crown lattice (oak), or [radius of the lowest tier, min tiers, max
## tiers] (spruce). tints: leaf colours, one picked per tree. bare: share of trees that
## drop all their leaves in winter (branches show, with snow on them); the others keep
## dry leaves with snow caps on top. Evergreens keep their needles and take snow on
## each tier.
const SPECIES := [
	{
		"name": "oak", "title": "Дуб", "leaves": BROAD,
		"trunk": [6, 8], "crown": [2.2, 1.5, 1.8],
		"tints": [Color(0.27, 0.43, 0.25), Color(0.3, 0.46, 0.22), Color(0.25, 0.41, 0.27)],
		"bare": 0.6,
	},
	{
		"name": "spruce", "title": "Ель", "leaves": NEEDLES,
		"trunk": [7, 8], "crown": [2.3, 5, 7],
		"tints": [Color(0.18, 0.34, 0.22), Color(0.2, 0.36, 0.21), Color(0.17, 0.32, 0.24)],
		"bare": 0.0,
	},
]


## Most cells a tree of `species` grown at `scale` takes above the ground it stands on.
static func height(species: int, scale := 1.0) -> int:
	var s: Dictionary = SPECIES[species]
	if s.leaves == NEEDLES:
		return roundi(s.trunk[1] * scale) + 2 * maxi(3, roundi(s.crown[2] * scale)) + 7
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
	w.trees[Vector2i(x, z)] = species
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
	var bare := maxi(1, roundi(rng.randi_range(s.trunk[0], s.trunk[1]) * scale))
	var tiers := maxi(3, roundi(rng.randi_range(s.crown[1], s.crown[2]) * scale))
	var radius: float = (s.crown[0] + rng.randf_range(-0.2, 0.2)) * scale
	var low := ((y + bare) + 1) & ~1
	var top := low + 2 * (tiers - 1)
	for i in range(y, top):
		w.set_cell(x, i, z, Mat.LOG)
	var points: Array[Vector3i] = []
	var reach := ceili(radius)
	for k in tiers:
		var t := (k + 0.6) / tiers
		var r := radius * (1.0 - t) + 0.35
		if k % 2 == 1:
			r *= 0.68
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				# A little narrower across z, as the top and front of a tier both show.
				if Vector2(dx, dz / 0.85).length() <= r + rng.randf_range(-0.15, 0.15):
					points.append(Vector3i(x + 2 * dx, low + 2 * k, z + 2 * dz))
	points.append(Vector3i(x, top + 2, z))
	_fill(w, points)


## Each crown point fills the air cells of the 3x3x3 block around it with leaves.
static func _fill(w, points: Array[Vector3i]) -> void:
	for p in points:
		for oy in range(-1, 2):
			for oz in range(-1, 2):
				for ox in range(-1, 2):
					if w.get_cell(p.x + ox, p.y + oy, p.z + oz) == Mat.AIR:
						w.set_cell(p.x + ox, p.y + oy, p.z + oz, Mat.LEAVES)
