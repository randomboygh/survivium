extends "res://src/client/world/mesh_faces.gd"
## Trunks of trees and log pillars: the bark drawn as a ring of texels per level
## with roots at the foot and a cut or bark cap on top (see Trees.trunk_box).
## Called by ChunkMesher a column at a time. A species with a bark of its own
## (PixelTextures.bark_material) is drawn with that in place of the log's texture.

const PixelTextures := preload("res://src/client/view/pixel_textures.gd")


## A log with open sides that continues up into a trunk or crown is a tree trunk.
static func is_trunk(nb: PackedByteArray) -> bool:
	return not _covers(nb[0]) and not _covers(nb[1]) and not _covers(nb[4]) and not _covers(nb[5]) \
		and (nb[2] == Mat.LOG or nb[2] == LEAVES)


static func trunk_at(w, x: int, y: int, z: int) -> bool:
	var nb := PackedByteArray([w.get_cell(x + 1, y, z), w.get_cell(x - 1, y, z), w.get_cell(x, y + 1, z),
		w.get_cell(x, y - 1, z), w.get_cell(x, y, z + 1), w.get_cell(x, y, z - 1)])
	return w.get_cell(x, y, z) == Mat.LOG and is_trunk(nb)


## The trunk of a tree in its log cell at x, y, z: a column of bark of the tree's own
## girth and crook (see Trees.trunk_box) with its corners cut, so the light gives it a
## lit and a shaded side from every side, with a dark outline where it turns away. Its sides slant
## from cell to cell as it thins and bends; at the foot it flares out and sends out a
## few roots.
static func trunk_faces(buf, w, x: int, y: int, z: int, nb: PackedByteArray, base: Vector3, m: int) -> void:
	var col := Vector2i(x, z)
	var species: int = w.trees.get(col, -1)
	if species >= Trees.SPECIES.size():
		species = -1
	var k := 0
	while k < 64 and w.get_cell(x, y - k - 1, z) == Mat.LOG:
		k += 1
	var box := PILLAR if species < 0 else Trees.trunk_box(species, col, k)
	var color := Color(1, 1, 1) if species < 0 else _bark_tone(col)
	if species >= 0:
		# Which cell of the trunk this is for world.gdshader, which clears a tree's trunk
		# round the player but for its foot: eighths, 1 the foot, 2 the next and so on
		# to 5 for the fifth and above.
		color.a = (mini(k, 4) + 1) / 8.0
	if species >= 0 and species < PixelTextures.bark_material.size() and PixelTextures.bark_material[species] >= 0:
		m = PixelTextures.bark_material[species]
	var top := CAP_CUT if not _covers(nb[2]) else CAP_NONE
	# Going up into more trunk, the bark slants to where the next cell has it.
	var up := box
	if nb[2] == Mat.LOG:
		top = CAP_NONE
		if species >= 0:
			up = Trees.trunk_box(species, col, k + 1)
	var bottom := not _covers(nb[3]) and nb[3] != Mat.LOG
	if k > 0 or species < 0:
		_bark(buf, base, box, up, 0, 8, top, bottom, m, color)
		return
	# The foot flares out two texels each way, then the roots.
	_bark(buf, base, box.grow(2), box, 0, 4, CAP_NONE, bottom, m, color)
	_bark(buf, base, box, up, 4, 8, top, false, m, color)
	var foot := box.grow(2)
	var s: Dictionary = Trees.SPECIES[species]
	var roots: int = s.roots[0] + posmod(hash(col * 3 + Vector2i(1, 2)), s.roots[1] - s.roots[0] + 1)
	var first := posmod(hash(col * 5 + Vector2i(7, 3)), 4)
	for i in roots:
		var h := hash(Vector3i(col.x, i + 11, col.y))
		var side := (first + i) % 4
		var across := foot.size.y if side < 2 else foot.size.x
		var wide := 2 + (h & 1)
		var at := 2 + posmod(h >> 1, maxi(1, across - 4 - wide))
		var root := _root(foot, side, -1, 3 + posmod(h >> 5, 3), at, wide)
		_bark(buf, base, root, root, 0, 1 + (h >> 8 & 1), CAP_BARK, false, m, color)


## The part `from`..`to` texels out from the side `side` (E, W, S, N) of `foot` of a root
## `wide` texels across, `at` texels along that side.
static func _root(foot: Rect2i, side: int, from: int, to: int, at: int, wide: int) -> Rect2i:
	match side:
		0:
			return Rect2i(foot.end.x + from, foot.position.y + at, to - from, wide)
		1:
			return Rect2i(foot.position.x - to, foot.position.y + at, to - from, wide)
		2:
			return Rect2i(foot.position.x + at, foot.end.y + from, wide, to - from)
	return Rect2i(foot.position.x + at, foot.position.y - to, wide, to - from)


## The tone of the bark of the tree in column `col`: a little darker or lighter and
## warmer or greyer than the next one.
static func _bark_tone(col: Vector2i) -> Color:
	var h := hash(col * 13 + Vector2i(5, 9))
	var light := 0.86 + 0.14 * float(h & 255) / 255.0
	var warm := float(h >> 8 & 255) / 255.0
	return Color(light, light * (0.95 + 0.05 * warm), light * (0.9 + 0.1 * (1.0 - warm)))


## A column of bark from `r0` at `y0` texels up to `r1` at `y1` (texels of the cell at
## `base` seen from above, x west to east, y north to south), its corners cut by a
## quarter of its width (see _ring); with its bottom when asked and its top as `top`
## says: CAP_NONE, CAP_CUT (the end grain of a stump) or CAP_BARK (a root).
static func _bark(buf, base: Vector3, r0: Rect2i, r1: Rect2i, y0: int, y1: int, top: int, bottom: bool, m: int, color: Color) -> void:
	var c := mini(r0.size.x, r1.size.x) / 4
	var low := _ring(r0, c)
	var high := _ring(r1, c)
	var mid := Vector2(r0.get_center())
	var side := m * 3 + 1
	var around := float(NO_TILE * 0x41041)
	for i in 8:
		var a: Vector2 = low[i]
		var b: Vector2 = low[(i + 1) % 8]
		if a == b:
			continue
		var e := b - a
		var out := Vector2(e.y, -e.x).normalized()
		if out.dot((a + b) * 0.5 - mid) < 0.0:
			out = -out
		var n := Vector3(out.x, 0.0, out.y)
		if i % 2 == 0:
			var pts := [_texel(base, high[i], y1), _texel(base, high[(i + 1) % 8], y1), _texel(base, b, y0),
				_texel(base, a, y0)]
			var uvs := [Vector2(0.5, 1.0 - y1 / 8.0), Vector2(0.5, 1.0 - y1 / 8.0), Vector2(0.5, 1.0 - y0 / 8.0),
				Vector2(0.5, 1.0 - y0 / 8.0)]
			_facing(buf, pts, n, uvs, color, Vector2(pack(side, 0, 0), around))
			continue
		# A cut corner in two halves, each with an outline at its outer edge, which the
		# shader draws where the side beyond that edge turns away from the camera.
		# Texture x runs to the right seen from outside, a at 1 and b at 0.
		var ha: Vector2 = high[i]
		var hb: Vector2 = high[(i + 1) % 8]
		var halves := [[ha, (ha + hb) * 0.5, a, (a + b) * 0.5, 1.0, 1.0 - c / 16.0, DARK << EDGE_E],
			[(ha + hb) * 0.5, hb, (a + b) * 0.5, b, c / 16.0, 0.0, DARK << EDGE_W]]
		for hf: Array in halves:
			var pts := [_texel(base, hf[0], y1), _texel(base, hf[1], y1), _texel(base, hf[3], y0),
				_texel(base, hf[2], y0)]
			var uvs := [Vector2(hf[4], 1.0 - y1 / 8.0), Vector2(hf[5], 1.0 - y1 / 8.0), Vector2(hf[5], 1.0 - y0 / 8.0),
				Vector2(hf[4], 1.0 - y0 / 8.0)]
			_facing(buf, pts, n, uvs, color, Vector2(pack(side, hf[6], 0), around))
	var caps: Array = []
	if top != CAP_NONE:
		caps.append([high, y1, Vector3.UP, m * 3 + (0 if top == CAP_CUT else 1)])
	if bottom:
		caps.append([low, y0, Vector3.DOWN, m * 3 + 2])
	for cap: Array in caps:
		var ring: Array = cap[0]
		var packed := Vector2(pack(cap[3], 0, 0), around)
		var rows := [[ring[7], ring[2], ring[3], ring[6]]]
		if c > 0:
			rows.append([ring[7], ring[0], ring[1], ring[2]])
			rows.append([ring[6], ring[3], ring[4], ring[5]])
		for q: Array in rows:
			var pts := []
			var uvs := []
			for p: Vector2 in q:
				pts.append(_texel(base, p, cap[1]))
				uvs.append(Vector2(clampf(p.x / 8.0, 0.0, 1.0), clampf(p.y / 8.0, 0.0, 1.0)))
			_facing(buf, pts, cap[2], uvs, color, packed)


## The eight corners round `r`, clockwise from the north end of its north-west cut
## corner, its corners cut by `c` texels: a side between corners 0-1, 2-3, 4-5, 6-7 and a
## cut corner between the others.
static func _ring(r: Rect2i, c: int) -> Array:
	var l := r.position.x
	var e := r.end.x
	var n := r.position.y
	var s := r.end.y
	return [Vector2(l + c, n), Vector2(e - c, n), Vector2(e, n + c), Vector2(e, s - c),
		Vector2(e - c, s), Vector2(l + c, s), Vector2(l, s - c), Vector2(l, n + c)]


## The point `p` (texels across the cell at `base` from above) `up` texels up.
static func _texel(base: Vector3, p: Vector2, up: float) -> Vector3:
	return base + Vector3(p.x, up, p.y) / 8.0


## A quad with its corners turned clockwise as seen from the side `n` faces.
static func _facing(buf, pts: Array, n: Vector3, uvs: Array, color: Color, packed: Vector2) -> void:
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n) > 0.0:
		pts.reverse()
		uvs.reverse()
	buf.quad(pts, n, uvs, color, packed)
