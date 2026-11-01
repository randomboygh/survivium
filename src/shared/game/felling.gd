extends RefCounted
## Felling a tree: a rule of play (WorldActions chops, the session's world changes). The
## tree's shape is Growth's, its species Trees'.

const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Growth := preload("res://src/shared/world/growth.gd")


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
	var s: Dictionary = Trees.SPECIES[w.trees[at]]
	var y := cut.y
	while w.get_cell(cut.x, y, cut.z) == Mat.LOG:
		gone.append(Vector3i(cut.x, y, cut.z))
		y += 1
	var logs := gone.size()
	# Trunks around, to leave the leaves of neighbouring crowns alone.
	var reach := Growth.TREE_REACH + 1
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
	if d > Growth.TREE_REACH * Growth.TREE_REACH * 2:
		return false
	for o in others:
		if (c - o).length_squared() < d:
			return false
	return true


## Lays what a felled tree leaves on the ground (the species' `log`, `twig` and `seed`,
## each when the species names one): a log for every two cells of trunk, end to end from
## the stump toward `away`, and twigs and seeds where the crown lands, more of them for a
## larger crown.
static func _drops(w, cut: Vector3i, away: Vector2, s: Dictionary, logs: int, leaves: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cut)
	var dir := away.normalized() if away.length() > 0.01 else Vector2.from_angle(rng.randf() * TAU)
	var side := Vector2(-dir.y, dir.x)
	var base := Vector2(cut.x + 0.5, cut.z + 0.5)
	var along := atan2(dir.y, dir.x)
	for i in (maxi(1, (logs + 1) / 2) if s.log != "" else 0):
		var p := base + dir * (2.0 + i * 1.8) + side * rng.randf_range(-0.4, 0.4)
		_drop(w, s.log, p, along + rng.randf_range(-0.3, 0.3))
	if leaves == 0:
		return
	var crown: float = 2.0 * s.crown[0]
	var land := base + dir * (logs + crown)
	for i in (clampi(leaves / 60, 2, 8) if s.twig != "" else 0):
		var p := land + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * crown
		_drop(w, s.twig, p, rng.randf() * TAU)
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
