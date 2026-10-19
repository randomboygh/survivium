extends RefCounted
## Grass tufts and tree crowns for one chunk, as MultiMesh instance buffers.
## Tufts stand on grass tops. A crown is drawn the way t3ssel8r draws his trees: leaf
## cluster cards cover its open faces, and each card is lit with the normal of the crown
## at that spot (away from the middle of the leaves around it), bent toward a few large
## bumps, so the light falls on the crown as one mass with some big lumps instead of on
## each card. Every exposed point of a crown also gets a flat shadow-only disc, so
## crowns cast round shadows.

const Mat := preload("res://src/shared/materials.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const Trees := preload("res://src/shared/trees.gd")
const WorldData := preload("res://src/shared/world_data.gd")

## Lush patches keep all of them, thin meadows fewer (see grass.gdshader).
const TUFTS_PER_CELL := 2
const TUFT_SIZE := 0.5
## Leaf cluster cards: size in world units (24 px, see PixelTextures.CLUMP; the bunch of
## leaves in a card is one of three sizes), cards on each open face of a crown point the
## camera sees.
const CLUMP_SIZE := 1.5
const CARDS_PER_FACE := 1
## Tint of the layer of large cards deeper in the crown, which fills the gaps between
## the outer cards: darker and cooler, as light gets less far into the leaves.
const DEEP := Color(0.7, 0.76, 0.84)
## Crown points within this many steps give the crown's middle for the light.
const CROWN_REACH := 2
## How much the bumps of a crown (a smooth wave about two units across) bend its normal.
const BUMP := 0.45
## What a tree does over the year, in the alpha of its cards' colour (see
## leaves.gdshader): keeps dry leaves under snow caps in winter, drops all of them (bare
## branches show), keeps its needles; bushes carry berries.
const KEEPS_LEAVES := 1.0
const GOES_BARE := 0.8
const EVERGREEN := 0.6
const BERRIES := 0.4
## Rows of the deep cards are offset by this, so the shader can swap them for bare
## branches in winter.
const DEEP_ROW := 8
## A crown point belongs to the nearest trunk within this many cells.
const TREE_REACH := 8
## How far the normals of a spruce's cards lean up on the top of a tier, and down under
## the tier above.
const TIER_UP := 0.8
const TIER_DOWN := -0.35
## Bushes are made of smaller clusters, this many pixels across, this many per bush.
const BUSH_CLUMP := 10
const BUSH_CARDS := 6
const BUSH_DISC := 0.9
const SHADOW_DISC := 1.6
## One pixel and one cell in world units.
const PX := 1.0 / 16.0
const CELL := WorldData.CELL
## Levels 0, 2, 4.. of a column mask.
const EVEN_LEVELS := 0x5555555555555555


## Upright quad of `size`, bottom edge (or centre when `centered`) at the origin.
static func quad_mesh(size: float, centered: bool) -> ArrayMesh:
	var h := size * 0.5
	var y0 := -h if centered else 0.0
	var y1 := y0 + size
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, y0, 0), Vector3(-h, y1, 0), Vector3(h, y1, 0), Vector3(h, y0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Flat square of `size` lying in the x-z plane, centred on the origin.
static func disc_mesh(size: float) -> ArrayMesh:
	var h := size * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Returns {"grass": [count, buffer], "clumps": [count, buffer], "shadows": [count, buffer]}
## for the cells x0..x0+size, z0..z0+size. Buffers are laid out for MultiMesh with
## 3D transforms in world units; grass has custom data, clumps colours and custom data,
## shadows custom data (what the tree does over the year, as in the clumps' alpha).
## Leaf clumps stand on a lattice two cells apart (odd x and z, even levels), where the
## generator centres its crowns.
static func build_chunk(w, x0: int, z0: int, size: int) -> Dictionary:
	w.refresh_shapes()
	var cells: PackedByteArray = w.cells
	var shapes: PackedByteArray = w.shapes
	var sx: int = w.size_x
	var sz: int = w.size_z
	var layer: int = sx * sz
	var x1 := mini(x0 + size, sx)
	var z1 := mini(z0 + size, sz)
	var grass := PackedFloat32Array()
	var clumps := PackedFloat32Array()
	var shadows := PackedFloat32Array()
	var ng := 0
	var nc := 0
	var ns := 0
	var rng := RandomNumberGenerator.new()
	var trunks := _trunks_near(w, x0, z0, x1, z1)
	for z in range(z0, z1):
		for x in range(x0, x1):
			var col := z * sx + x
			var air: int = w.air_cols[col]
			# Ground with air above.
			var tops: int = ~(air | w.water_cols[col] | w.leaf_cols[col]) & w.all_bits & ((air >> 1) | w.top_bit)
			while tops != 0:
				var bit := tops & -tops
				tops ^= bit
				var y := WorldData.level_of(bit)
				var i := y * layer + col
				if cells[i] != Mat.GRASS:
					continue
				rng.seed = hash(Vector3i(x, y, z))
				var mask := WorldData.FULL & ~(shapes[i] & 15)
				var cuts := shapes[i] >> 4
				for k in TUFTS_PER_CELL:
					var fx := rng.randi_range(1, 7) / 8.0
					var fz := rng.randi_range(1, 7) / 8.0
					var q := WorldData.corner_at(fx, fz)
					if cuts & (1 << q) and WorldData.in_corner(q, fx, fx, fz, fz):
						continue
					put(grass, Vector3(x + fx, y + WorldData.slope_height(mask, fx, fz, cuts), z + fz) * CELL)
					grass.append_array([float(rng.randi_range(0, 3)), rng.randf_range(0.88, 1.1), rng.randf(), 0.0])
					ng += 1
			if x & 1 == 0 or z & 1 == 0:
				continue
			var leaves: int = w.leaf_cols[col] & EVEN_LEVELS
			if leaves == 0:
				continue
			var tree := _tree_at(trunks, x, z)
			var looks: Dictionary = Trees.SPECIES[tree[1]]
			var needles: bool = looks.leaves == Trees.NEEDLES
			var tints: Array = looks.tints
			var base: Color = tints[tree[2] % tints.size()]
			base.a = EVERGREEN if needles else (GOES_BARE if _goes_bare(tree[2], tree[1]) else KEEPS_LEAVES)
			var first_row := PixelTextures.NEEDLE_ROW if needles else 0
			var axis := (Vector3(tree[0].x, 0, tree[0].y) + Vector3(0.5, 0.0, 0.5)) * CELL
			if needles and tree[0] == Vector2i(x, z):
				# Small sprigs in front of a spruce's trunk where the tiers are around
				# it: the trunk shows only under the lowest tier.
				var core: int = (w.log_cols[col] & w.leaf_cols[col + 1] | leaves) & EVEN_LEVELS
				while core != 0:
					var bit := core & -core
					core ^= bit
					rng.seed = hash(Vector3i(x, WorldData.level_of(bit), z))
					for up in [0.0, 0.5]:
						var at := (Vector3(x, WorldData.level_of(bit), z) + Vector3(0.5, 0.5, 0.5)) * CELL + Vector3(0.0, up, 0.45)
						_card(clumps, PixelView.snap(at), Vector3(0.0, 0.1, 1.0).normalized(), base, first_row + 1 + DEEP_ROW, rng)
						nc += 1
			while leaves != 0:
				var bit := leaves & -leaves
				leaves ^= bit
				var y := WorldData.level_of(bit)
				var faces := _open_faces(w, x, y, z)
				var mid := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * CELL
				if faces.is_empty():
					continue
				# Broad leaves take the normal from the middle of the crown nearby, needles
				# from the trunk, leaning up on top of a tier and down under the next one.
				var middle := Vector3(axis.x, mid.y, axis.z) if needles else mid + _crown_offset(w, x, y, z)
				var lean := (TIER_UP if faces[0] == Vector3i.UP else TIER_DOWN) if needles else 0.0
				rng.seed = hash(Vector3i(x, y, z))
				# Large bunches on the inside of the crown, smaller ones toward its
				# outline (points open on three or more sides), the smallest at the very
				# edge, so the middle is dense and the edge jagged.
				# Spruce tiers stay dense out to their rim, only the lone points of the
				# top take small sprigs, so the tip is pointed.
				var rows := [0, 1] if faces.size() < (4 if needles else 3) else [1, 2]
				for f in faces:
					# Cards cover each face the camera can see, poking out of it a
					# little, so no gap shows the trunk inside.
					for k in CARDS_PER_FACE:
						var c := mid + Vector3(f) * (0.4 + rng.randi_range(0, 3) * PX)
						var spread := Vector3(rng.randi_range(-4, 4), rng.randi_range(-4, 4), rng.randi_range(-4, 4)) * PX
						c += spread - Vector3(f) * Vector3(f).dot(spread)
						c = PixelView.snap(c)
						var n := _tier_normal(c, middle, lean) if needles else _card_normal(c, middle)
						_card(clumps, c, n, base, first_row + rows[rng.randi_range(0, 1)], rng)
						nc += 1
				# A deeper, darker layer behind the outer cards (a little inward and
				# north, so it is drawn behind them) fills the gaps between them.
				var deep := PixelView.snap(mid + Vector3(0.0, 0.0, -0.25) - (mid - middle).limit_length(0.3))
				var dn := _tier_normal(deep, middle, lean) if needles else _card_normal(deep, middle)
				var dark := base * DEEP
				dark.a = base.a
				_card(clumps, deep, dn, dark, first_row + DEEP_ROW, rng)
				nc += 1
				put(shadows, mid)
				shadows.append_array([base.a, 0.0, 0.0, 0.0])
				ns += 1
	return {"grass": [ng, grass], "clumps": [nc, clumps], "shadows": [ns, shadows]}


## Leaf clusters of berry bushes standing on the given cells: [count, buffer] like
## crowns, lit as one low dome per bush.
static func bushes(cells: Array[Vector3i]) -> Array:
	var buf := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	for cell in cells:
		rng.seed = hash(cell)
		for k in BUSH_CARDS:
			var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / BUSH_CARDS
			var o := Vector3(cos(a) * 0.22, rng.randf_range(0.0, 0.15), sin(a) * 0.15)
			if k == 0:
				o = Vector3(0.0, 0.2, 0.0)
			put(buf, PixelView.snap((Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL + Vector3(0.0, 0.3, 0.0) + o))
			# The alpha marks a cluster with berries (see leaves.gdshader).
			buf.append_array([0.3, 0.46, 0.22, BERRIES])
			var n := (o + Vector3(0.0, 0.25, 0.0)).normalized()
			buf.append_array([n.x, n.y, n.z, rng.randf() * 0.99])
	return [cells.size() * BUSH_CARDS, buf]


## Faces of a crown point the camera can see (top, south, east, west) whose
## neighbouring point (two cells on) is neither leaves nor a trunk.
static func _open_faces(w, x: int, y: int, z: int) -> Array[Vector3i]:
	var open: Array[Vector3i] = []
	for d in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]:
		var n: int = w.get_cell(x + 2 * d.x, y + 2 * d.y, z + 2 * d.z)
		if n != Mat.LEAVES and n != Mat.LOG:
			open.append(d)
	return open


## Appends a leaf cluster card at `c`: transform, tint (its alpha what the tree does
## in winter), and the normal `n` with the card's row of the clump texture plus a sway
## phase in the last value.
static func _card(buf: PackedFloat32Array, c: Vector3, n: Vector3, tint: Color, row: int, rng: RandomNumberGenerator) -> void:
	put(buf, c)
	buf.append_array([tint.r, tint.g, tint.b, tint.a])
	buf.append_array([n.x, n.y, n.z, row + rng.randf() * 0.99])


## Trees whose trunks stand within TREE_REACH cells of the cells x0..x1, z0..z1:
## [column, species, hash of the column] each.
static func _trunks_near(w, x0: int, z0: int, x1: int, z1: int) -> Array:
	var found := []
	var trees: Dictionary = w.trees
	if trees.is_empty():
		return found
	for z in range((z0 - TREE_REACH) | 1, z1 + TREE_REACH, 2):
		for x in range((x0 - TREE_REACH) | 1, x1 + TREE_REACH, 2):
			var at := Vector2i(x, z)
			if trees.has(at):
				found.append([at, trees[at], hash(at)])
	return found


## Whether the tree on column `at` drops all its leaves in winter (the others of a
## deciduous species keep dry leaves under snow caps).
static func goes_bare(at: Vector2i, species: int) -> bool:
	return _goes_bare(hash(at), species)


static func _goes_bare(h: int, species: int) -> bool:
	return (h >> 8) % 100 < Trees.SPECIES[species].bare * 100.0


## The tree a crown point in column x, z belongs to: the nearest trunk, or an oak where
## no tree is noted (crowns made by hand).
static func _tree_at(trunks: Array, x: int, z: int) -> Array:
	var best := [Vector2i(x, z), Trees.OAK, hash(Vector2i(x / 6, z / 6))]
	var best_d := TREE_REACH * TREE_REACH + 1
	for t in trunks:
		var d: int = (t[0] - Vector2i(x, z)).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


## Offset in world units from a crown point to the middle of the crown points within
## CROWN_REACH steps of it (a step is two cells, one world unit).
static func _crown_offset(w, x: int, y: int, z: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for dy in range(-CROWN_REACH, CROWN_REACH + 1):
		for dz in range(-CROWN_REACH, CROWN_REACH + 1):
			for dx in range(-CROWN_REACH, CROWN_REACH + 1):
				if w.get_cell(x + 2 * dx, y + 2 * dy, z + 2 * dz) == Mat.LEAVES:
					sum += Vector3(dx, dy, dz)
					n += 1
	return sum / n


## Normal for a card at `c`: away from the crown's middle, bent by a few large bumps,
## and a little up, so a lone or flat canopy faces the sky.
static func _card_normal(c: Vector3, middle: Vector3) -> Vector3:
	var bump := Vector3(sin(c.y * 2.1 + c.z * 1.3 + 1.0), sin(c.x * 1.7 + c.z * 2.3), sin(c.x * 1.1 + c.y * 1.9 + 2.0))
	var n := (c - middle).normalized() + bump * BUMP + Vector3(0.0, 0.3, 0.0)
	return n.normalized()


## Normal for a spruce card at `c`: out from the trunk (`axis` at the card's height),
## leaning up or down (`lean`), with smaller bumps than a broad crown.
static func _tier_normal(c: Vector3, axis: Vector3, lean: float) -> Vector3:
	var out := c - axis
	out.y = 0.0
	var bump := Vector3(sin(c.y * 2.1 + c.z * 1.3 + 1.0), 0.0, sin(c.x * 1.1 + c.y * 1.9 + 2.0))
	var n := (out.normalized() if out.length() > 0.2 else Vector3.ZERO) + bump * 0.2 + Vector3(0.0, lean, 0.0)
	return n.normalized() if n.length() > 0.1 else Vector3.UP


## Appends a translation-only transform in MultiMesh buffer order.
static func put(buf: PackedFloat32Array, p: Vector3) -> void:
	buf.append_array([1.0, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, 1.0, p.z])
