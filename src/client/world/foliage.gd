extends RefCounted
## Grass tufts and tree crowns for one chunk, as MultiMesh instance buffers.
## Tufts stand on grass tops. A crown is drawn the way t3ssel8r draws his trees: leaf
## cluster cards cover its open faces, and each card is lit with the normal of the crown
## at that spot (away from the middle of the leaves around it), bent toward a few large
## bumps, so the light falls on the crown as one mass with some big lumps instead of on
## each card. Under the crown lie flat shadow-only discs, one per level of a tree's
## crown, so a crown casts one round shadow.

const Bushes := preload("res://src/shared/content/bushes.gd")
const Drifts := preload("res://src/client/world/drifts.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## Ground plants (see Grass, PixelTextures.build_plants and grass.gdshader): the size
## of their cards.
const PLANT_W := PixelTextures.PLANT_W / 16.0
const PLANT_H := PixelTextures.PLANT_H / 16.0
## The glow about the glowing mushrooms is drawn on a card this much larger (grass.gdshader).
const HALO_SCALE := 2.5
## Leaf cluster cards: size in world units (24 px, see PixelTextures.CLUMP; the bunch of
## leaves in a card is one of three sizes), cards on each open face of a crown point the
## camera sees.
const CLUMP_SIZE := 2.0
const CARDS_PER_FACE := 1
## Tint of the layer of large cards deeper in the crown, which fills the gaps between
## the outer cards: darker and cooler, as light gets less far into the leaves.
const DEEP := Color(0.7, 0.76, 0.84)
## Crown points within this many steps give the crown's middle for the light.
const CROWN_REACH := 2
## How much the bumps of a crown (a smooth wave about two units across) bend its normal.
const BUMP := 0.25
## What a tree does over the year, in the alpha of its cards' colour (see
## leaves.gdshader): keeps dry leaves under snow caps in winter, drops all of them (bare
## branches show), keeps its needles; bushes are below 0.5 (see bush_kind).
const KEEPS_LEAVES := 1.0
const GOES_BARE := 0.8
const EVERGREEN := 0.6
## A dead tree: bare branches all year, no leaves and no shadow.
const DEAD := 0.9
## A blossoming species' cards have its blossom slot (Trees) times this added to their row.
const BLOSSOM_ROW := 32
## Rows of the deep cards are offset by this, so the shader can swap them for bare
## branches in winter, and draw a tree's ones a little behind the rest from whichever
## side the camera looks (leaves.gdshader).
const DEEP_ROW := 16
## A crown point belongs to the nearest trunk within this many cells.
const TREE_REACH := Trees.TREE_REACH
## How far the normals of a spruce's cards lean up on the top of a tier, and down under
## the tier above.
const TIER_UP := 0.8
const TIER_DOWN := -0.35
## Bushes are made of smaller clusters, this many pixels across (see Bushes).
const BUSH_CLUMP := 12
const BUSH_DISC := 0.9
const SHADOW_DISC := 1.6
## One pixel and one cell in world units.
const PX := 1.0 / 16.0
## A card's normal is this long when it lies flat (see _layer_cards, leaves.gdshader).
const FLAT := 2.0
## A broad crown's bundles (see _broad): how far from a point of the crown they lie and
## how far apart, in cells.
const BUNDLE_REACH := 1.2
const BUNDLE_STEP := 2.0
## How far round a point of a crown of lobes its layer reaches, in cells.
const LOBE_REACH := 2.2
## A willow's strands: how far apart round the rim and how far apart their bundles one
## under another, in cells (see _strands).
const STRAND_STEP := 1.4
const STRAND_DROP := 0.8
## How far round its trunk a cone's crown is looked for, in cells (see _spruce).
const SPRUCE_REACH := 8
const CELL := WorldData.CELL
## Levels 0, 2, 4.. of a column mask.
const EVEN_LEVELS := 0x5555555555555555
## Cells of a conifer's trunk under the lowest disc of its shadow (see _tree_shadows).
const CONIFER_BARE := 2


## Upright quad of `size`, bottom edge (or centre when `centered`) at the origin.
static func quad_mesh(size: float, centered: bool) -> ArrayMesh:
	return plant_mesh(size, size, centered)


## Upright quad `width` by `height`, bottom edge (or centre when `centered`) at the
## origin.
static func plant_mesh(width: float, height: float, centered := false) -> ArrayMesh:
	var h := width * 0.5
	var y0 := -height * 0.5 if centered else 0.0
	var y1 := y0 + height
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, y0, 0), Vector3(-h, y1, 0), Vector3(h, y1, 0), Vector3(h, y0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A node drawing `mesh` with `material` as many times as its multimesh is filled.
static func multimesh(mesh: Mesh, material: Material, colors: bool, custom: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	return node


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
## The state of a chunk's plants being built column by column (see `start`, `step`, `finish`).
class Job extends RefCounted:
	var w
	var x0: int
	var z0: int
	var x1: int
	var z1: int
	var z: int
	var x: int
	var grass := PackedFloat32Array()
	var clumps := PackedFloat32Array()
	var shadows := PackedFloat32Array()
	var ng := 0
	var nc := 0
	var ns := 0
	var rng := RandomNumberGenerator.new()
	var trunks: Array
	## The trees around the chunk, to tell which crown points belong to a trunk, and
	## how many trunks have cast their shadow.
	var wide: Array
	var tree := 0


static func build_chunk(w, x0: int, z0: int, size: int) -> Dictionary:
	var job := start(w, x0, z0, size)
	while not step(job, 1 << 30):
		pass
	return finish(job)


## Begins building the plants of a chunk; `step` then does a few columns at a time.
static func start(w, x0: int, z0: int, size: int) -> Job:
	w.refresh_shapes()
	var job := Job.new()
	job.w = w
	job.x0 = x0
	job.z0 = z0
	job.z = z0
	job.x = x0
	job.x1 = x0 + size
	job.z1 = z0 + size
	job.trunks = _trunks_near(w, x0, z0, job.x1, job.z1)
	job.wide = _trunks_near(w, x0 - TREE_REACH, z0 - TREE_REACH, job.x1 + TREE_REACH, job.z1 + TREE_REACH)
	return job


## Builds the plants of the next `columns` columns of cells, then the shadow of one
## tree per column (a forest chunk has dozens, each as costly as a few columns).
## Returns true once every column is built and every tree has its shadow.
static func step(job: Job, columns: int) -> bool:
	while columns > 0 and job.z < job.z1:
		_column(job, job.x, job.z)
		columns -= 1
		job.x += 1
		if job.x >= job.x1:
			job.x = job.x0
			job.z += 1
	# Trees whose trunks stand in this chunk cast one shadow per level of their crown.
	while columns > 0 and job.z >= job.z1 and job.tree < job.trunks.size():
		var t: Array = job.trunks[job.tree]
		job.tree += 1
		columns -= 1
		var at: Vector2i = t[0]
		if at.x >= job.x0 and at.x < job.x1 and at.y >= job.z0 and at.y < job.z1:
			job.ns += _tree_shadows(job.w, t, job.wide, job.shadows)
	return job.z >= job.z1 and job.tree >= job.trunks.size()


static func _column(job: Job, x: int, z: int) -> void:
	var w = job.w
	var ch: WorldData.Chunk = w.chunk_at(x, z)
	if ch == null:
		return
	var cells := ch.cells
	var shapes := ch.shapes
	var layer := WorldData.LAYER
	var grass := job.grass
	var clumps := job.clumps
	var shadows := job.shadows
	var rng := job.rng
	var trunks := job.trunks
	var col := WorldData.col_of(x, z)
	var turf: Dictionary = w.turf.get(ch.key, {})
	var air: int = ch.air[col]
	# Ground with air above.
	var tops: int = ~(air | ch.water[col] | ch.leaf[col]) & w.all_bits & ((air >> 1) | w.top_bit)
	while tops != 0:
		var bit := tops & -tops
		tops ^= bit
		var y := WorldData.level_of(bit)
		var i := y * layer + col
		var m := cells[i]
		if not Mat.can_slope(m):
			continue
		rng.seed = hash(Vector3i(x, y, z))
		var mask := WorldData.FULL & ~(shapes[i] & 15)
		var cuts := shapes[i] >> 4
		var kinds := Grass.kinds(w, x, y, z, m, mask == WorldData.FULL and cuts == 0, rng)
		if not turf.is_empty() and turf.has(Vector3i(x, y, z)):
			kinds = Grass.turf_kinds(kinds, turf[Vector3i(x, y, z)], rng)
		for kind in kinds:
			var fx := rng.randi_range(1, 7) / 8.0
			var fz := rng.randi_range(1, 7) / 8.0
			var q := WorldData.corner_at(fx, fz)
			if cuts & (1 << q) and WorldData.in_corner(q, fx, fx, fz, fz):
				continue
			var h: float = 1.0 if mask == WorldData.FULL else w.surface_height(x, y, z, fx, fz)
			put(grass, Vector3(x + fx, y + h, z + fz) * CELL)
			grass.append_array([float(kind), rng.randf_range(0.88, 1.1), rng.randf(), 0.0])
			job.ng += 1
			if kind >= Grass.GLOW and kind < Grass.SPORE:
				# Spores rise from the glowing mushrooms at night, in a glow of their
				# own (grass.gdshader; the glow's card is HALO_SCALE times larger).
				var p := Vector3(x + fx, y + h, z + fz) * CELL
				grass.append_array([HALO_SCALE, 0.0, 0.0, p.x, 0.0, HALO_SCALE, 0.0, p.y, 0.0, 0.0, 1.0, p.z - 0.01])
				grass.append_array([float(Grass.HALO), rng.randf_range(0.8, 1.1), rng.randf(), 0.0])
				job.ng += 1
				for k in 2:
					var sx := clampf(fx + rng.randf_range(-0.25, 0.25), 0.05, 0.95)
					var sz := clampf(fz + rng.randf_range(-0.25, 0.25), 0.05, 0.95)
					put(grass, Vector3(x + sx, y + h, z + sz) * CELL)
					grass.append_array([float(Grass.SPORE), rng.randf_range(0.7, 1.2), rng.randf(), 0.0])
					job.ng += 1
	if x & 1 == 0 or z & 1 == 0:
		return
	var leaves: int = ch.leaf[col] & EVEN_LEVELS
	# Where a trunk runs up into its crown (leaves beside it), a bundle covers it like
	# a point of the crown, drawn in front of it: the thick trunk of a broad-leaved tree
	# must not poke through between the bundles.
	var around: int = w.leaf_col(x + 1, z) | w.leaf_col(x - 1, z) | w.leaf_col(x, z + 1) | w.leaf_col(x, z - 1)
	# So does its top, where it ends in the crown: seen from above at 3/4 the flat top of
	# a thick trunk would show as a dark disc under the crown.
	var crown_bits: int = ch.leaf[col]
	var collar: int = ch.logs[col] & (around | (crown_bits >> 1) | (crown_bits >> 2)) & EVEN_LEVELS
	if (leaves | collar) == 0:
		return
	var tree := _tree_at(trunks, x, z)
	if tree.is_empty():
		return
	# Crowns of noted trees cast their shadow as a whole (see _tree_shadows),
	# others one disc per point.
	var grown: bool = w.trees.has(tree[0])
	var looks: Dictionary = Trees.SPECIES[tree[1]]
	# A cone of tiers (spruce) is built round its trunk; other crowns, needles or not,
	# round the middle of their leaves.
	var needles: bool = looks.tiers
	if not needles and tree[0] == Vector2i(x, z):
		# The trunk of a crown of lobes runs up through the gaps between them: covered
		# with bundles from the lowest leaves of the crown up, it never shows inside it.
		var crown_any := 0
		for dz in range(-6, 7, 2):
			for dx in range(-6, 7, 2):
				crown_any |= w.leaf_col(x + dx, z + dz)
		if crown_any != 0:
			var lowest := crown_any & -crown_any
			collar |= ch.logs[col] & ~(lowest - 1) & EVEN_LEVELS
	leaves |= collar
	if leaves == 0:
		return
	var tints: Array = looks.tints
	var base: Color = tints[tree[2] % tints.size()]
	base.a = _year_kind(looks, tree[2], tree[1])
	var first_row: int = PixelTextures.LEAF_ROWS[looks.leaf] + BLOSSOM_ROW * looks.blossom_slot
	var dead: bool = looks.dead
	var axis := (Vector3(tree[0].x, 0, tree[0].y) + Vector3(0.5, 0.0, 0.5)) * CELL
	if needles and not dead:
		# A cone is drawn whole from its trunk's column (see _spruce).
		if tree[0] == Vector2i(x, z):
			_spruce(job, w, x, z, base, first_row, looks, rng)
		return
	if grown and not needles and not dead:
		# So is a broad crown, in layers (see _broad).
		if tree[0] == Vector2i(x, z):
			_broad(job, w, tree, trunks, base, first_row, looks, rng)
		return
	if needles and dead and tree[0] == Vector2i(x, z):
		# Small sprigs in front of a spruce's trunk where the tiers are around
		# it: the trunk shows only under the lowest tier. Put in the trunk, they
		# are drawn on the side of it the camera looks from (leaves.gdshader).
		var core: int = (ch.logs[col] & w.leaf_col(x + 1, z) | leaves) & EVEN_LEVELS
		while core != 0:
			var bit := core & -core
			core ^= bit
			rng.seed = hash(Vector3i(x, WorldData.level_of(bit), z))
			for up in [0.0, 0.5]:
				var at := (Vector3(x, WorldData.level_of(bit), z) + Vector3(0.5, 0.5, 0.5)) * CELL + Vector3(0.0, up, 0.0)
				_card(clumps, PixelView.snap(at), Vector3(0.0, 0.1, 1.0).normalized(), base, first_row + 1 + DEEP_ROW, rng, true)
				job.nc += 1
	while leaves != 0:
		var bit := leaves & -leaves
		leaves ^= bit
		var y := WorldData.level_of(bit)
		var faces := _open_faces(w, x, y, z)
		# A trunk in its crown takes the bundles of a point lying on it (see collar).
		if faces.is_empty() and not dead and cells[y * layer + col] == Mat.LOG:
			faces.append(Vector3i.UP)
		# A bundle over a trunk (see collar) is drawn in front of it, or the near half
		# of the trunk's top would show through.
		var over_trunk: bool = cells[y * layer + col] == Mat.LOG
		var mid := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * CELL
		if not dead:
			if not faces.is_empty() or needles:
				_layer_cards(job, w, x, y, z, faces, mid, axis, needles, base, first_row, rng)
				if not grown:
					put(shadows, mid)
					shadows.append_array([base.a, 0.0, 0.0, 0.0])
					job.ns += 1
			continue
		if faces.is_empty():
			# Inside a spruce a dark sprig fills the room between the tiers, so
			# the ground never shows through.
			if needles:
				rng.seed = hash(Vector3i(x, y, z))
				var inner := base * DEEP
				inner.a = base.a
				_card(clumps, PixelView.snap(mid), _tier_normal(mid, Vector3(axis.x, mid.y, axis.z), TIER_DOWN), inner, first_row + DEEP_ROW, rng)
				job.nc += 1
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
		var small: bool = faces.size() >= 4 and tree[0] == Vector2i(x, z) if needles else faces.size() >= 3
		var rows := ([1, 2] if small else [0, 1]) if needles else ([0, 1] if small else [0, 0])
		# A dead tree has only the deep layer, which shows its branches.
		# Broad leaves take one bundle per point, out toward its open faces: a
		# bundle is as wide as two points (SLYNYRD's bundles overlap by about half),
		# more of them only cover each other and turn the crown to noise. Needles
		# cover each open face with a sprig.
		var outs: Array[Vector3] = []
		if not dead and not needles:
			var sum := Vector3.ZERO
			for f in faces:
				sum += Vector3(f)
			outs.append(sum.normalized() if sum.length() > 0.1 else Vector3.UP)
		elif not dead:
			for f in faces:
				outs.append(Vector3(f))
		for f in outs:
			for k in CARDS_PER_FACE:
				var c := mid + f * (0.4 + rng.randi_range(0, 3) * PX)
				var spread := Vector3(rng.randi_range(-4, 4), rng.randi_range(-4, 4), rng.randi_range(-4, 4)) * PX
				c += spread - f * f.dot(spread)
				c = PixelView.snap(c)
				var n := _tier_normal(c, middle, lean) if needles else _card_normal(c, middle)
				_card(clumps, c, n, base, first_row + rows[rng.randi_range(0, 1)], rng, over_trunk)
				job.nc += 1
		# A deeper, darker layer behind the outer cards (a little inward, and
		# drawn a little farther from the camera, see leaves.gdshader) fills the
		# gaps between them.
		var deep := PixelView.snap(mid - (mid - middle).limit_length(0.3))
		var dn := _tier_normal(deep, middle, lean) if needles else _card_normal(deep, middle)
		var dark := base * DEEP
		dark.a = base.a
		_card(clumps, deep, dn, dark, first_row + DEEP_ROW, rng)
		job.nc += 1
		if not grown:
			put(shadows, mid)
			shadows.append_array([base.a, 0.0, 0.0, 0.0])
			job.ns += 1

## A cone of tiers drawn as SLYNYRD builds a conifer: round the trunk, on every level of
## its crown, branches lying flat and pointing away from it (the shader turns each the
## way its normal leans, drooping), as many as the tier is wide times the species'
## `branches` of `looks` (trees.yaml), at its rim; each with a
## darker copy a cell lower and a little aside, the drop shadow on the branches under
## it; and a dark tuft at the trunk that fills the middle of the tier. A tuft crowns the
## top. The branches face up and out, so the light of the sun makes them light, middle
## or dark by the side of the tree they are on.
static func _spruce(job: Job, w, x: int, z: int, base: Color, first_row: int, looks: Dictionary, rng: RandomNumberGenerator) -> void:
	var density: float = looks.branches
	var axis := (Vector3(x, 0, z) + Vector3(0.5, 0.0, 0.5)) * CELL
	var dark := base * DEEP
	dark.a = base.a
	var shade := dark * DEEP
	shade.a = base.a
	# The levels of the crown and how far each reaches from the trunk, in cells.
	var crown := 0
	for dz in range(-SPRUCE_REACH, SPRUCE_REACH + 1, 2):
		for dx in range(-SPRUCE_REACH, SPRUCE_REACH + 1, 2):
			crown |= w.leaf_col(x + dx, z + dz)
	crown &= EVEN_LEVELS
	if crown == 0:
		return
	var top := WorldData.level_of(_top_bit(crown))
	var low := WorldData.level_of(crown & -crown)
	var widest := 0.0
	var bits := crown
	while bits != 0:
		var bit := bits & -bits
		bits ^= bit
		var y := WorldData.level_of(bit)
		var reach := 0.0
		for dz in range(-SPRUCE_REACH, SPRUCE_REACH + 1, 2):
			for dx in range(-SPRUCE_REACH, SPRUCE_REACH + 1, 2):
				if w.get_cell(x + dx, y, z + dz) == Mat.LEAVES:
					reach = maxf(reach, Vector2(dx, dz).length())
		rng.seed = hash(Vector3i(x, y, z))
		var mid := axis + Vector3(0.0, (y + 0.5) * CELL, 0.0)
		for k in 2:
			_card(job.clumps, PixelView.snap(mid - Vector3(0.0, k * CELL, 0.0)), Vector3.UP * FLAT, shade, first_row + 2, rng)
		job.nc += 2
		# The branches narrow evenly from the widest tier to the tip, whatever the
		# lattice of points rounds each level's reach to, so the cone is straight-sided
		# and the tip pointed.
		var t := float(y - low) / maxf(1.0, top - low)
		if y == low:
			widest = _widest_tier(reach, looks)
		reach = widest * (1.0 - t) + 0.5
		# Small branches on the top of the cone, large ones on its bottom, so the tiers
		# meet.
		var row := first_row - PixelTextures.NEEDLE_ROW + (PixelTextures.SMALL_BRANCH_ROW if t > 0.7
			else (PixelTextures.LARGE_BRANCH_ROW if t < 0.35 else PixelTextures.NEEDLE_ROW))
		# An outer ring of branches at the rim and an inner one between them.
		var count := clampi(roundi(reach * 2.2 * density), 3, 14)
		var turn := rng.randf() * TAU
		for i in count + count / 2:
			var outer := i < count
			var a: float = turn + TAU * ((i if outer else i - count + 0.5) * (1.0 if outer else 2.0) + rng.randf_range(-0.2, 0.2)) / count
			var out := Vector3(cos(a), 0.0, sin(a))
			var spread := reach * CELL * (rng.randf_range(0.65, 0.85) if outer else rng.randf_range(0.3, 0.45))
			var c := mid + out * spread
			# The length beyond FLAT says how far out from the trunk (leaves.gdshader).
			var n := (out + Vector3.UP * 0.45).normalized() * (FLAT + spread)
			_card(job.clumps, PixelView.snap(c), n, base, row, rng)
			job.nc += 1
			# The inner ring lies under the outer one of the tier above: its drop shadow
			# would not show.
			if outer:
				_card(job.clumps, PixelView.snap(c - Vector3(2.0 * PX, CELL, 0.0)), n, dark, row + DEEP_ROW, rng)
				job.nc += 1
	# The tip: a tuft and over it a small branch pointing straight up the screen.
	rng.seed = hash(Vector3i(x, top + 2, z))
	var tip := axis + Vector3(0.0, (top + 1.0) * CELL, 0.0)
	_card(job.clumps, PixelView.snap(tip), Vector3.UP * FLAT, base, first_row + 2, rng)
	_card(job.clumps, PixelView.snap(tip + Vector3(0.0, CELL * 0.5, 0.0)), Vector3.UP * FLAT, base,
		first_row - PixelTextures.NEEDLE_ROW + PixelTextures.UP_BRANCH_ROW, rng)
	job.nc += 2


## How far the lowest tier of a conifer `looks` reaches from the trunk, in cells, its
## crown points `reach` cells out: the lattice of points, two cells apart, rounds a
## narrow crown out as far as a broad one, so the species' radius (in points) holds it in.
static func _widest_tier(reach: float, looks: Dictionary) -> float:
	return clampf(reach, 1.5, maxf(1.5, looks.crown[0] * 1.8))


## A broad crown drawn whole from its trunk's column, as SLYNYRD layers bundles of
## leaves: each level of its points a flat layer of bundles packed over their shape, the
## bundles leaning out from the middle of the crown so the sun lights it as one mass,
## light on its sunny side and dark on the other; under every bundle its dark copy a
## cell lower and a little aside, the shade a layer casts on the one below, which also
## fills the crown so nothing shows through. The bundles a layer above covers whichever
## way the camera looks are left out.
static func _broad(job: Job, w, tree: Array, trunks: Array, base: Color, first_row: int, looks: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var at: Vector2i = tree[0]
	var levels := _crown_levels(w, at, trunks)
	if levels.is_empty():
		return
	var shape: String = looks.shape
	if shape == "palm":
		_fronds(job, at, levels, base, first_row, rng)
		return
	# Needles not in tiers (a pine's) take tufts, here and in the shade under them.
	var row := first_row + 2 if looks.leaf == "needles" else first_row
	var dark := base * DEEP
	dark.a = base.a
	var ys: Array = levels.keys()
	ys.sort()
	var low: int = ys[0]
	var top: int = ys[-1]
	# A weeping crown is a dome of layers over the trunk with strands hanging from its
	# rim (see _strands): the points hanging round the trunk (Trees._curtain) take no
	# layers of their own.
	var hang_to := low
	var dome := 0.0
	if shape == "weeping":
		# A dome of three layers, its widest the lowest, as wide as the crown reaches.
		for y: int in ys:
			for p: Vector2i in levels[y]:
				dome = maxf(dome, Vector2(p - at).length())
		low = maxi(low, top - 4)
		ys = ys.filter(func(y: int) -> bool: return y >= low)
	# The middle of the crown, in cells.
	var middle := Vector2.ZERO
	var count := 0
	for y: int in ys:
		for p: Vector2i in levels[y]:
			middle += Vector2(p)
			count += 1
	middle = middle / count + Vector2(0.5, 0.5)
	# Each level a layer, round and as wide as its points reach, or for a crown of lobes
	# a disc round each of its points, so the gaps between the lobes show: the cells it
	# covers.
	var lobes := shape == "lobed" or shape == "umbrella"
	var covers := {}
	var reach := {}
	for y: int in ys:
		var far := 0.0
		for p: Vector2i in levels[y]:
			far = maxf(far, (Vector2(p) + Vector2(0.5, 0.5) - middle).length())
		# A column's bundles keep close to its points, so it stays slender.
		var r := far * 0.8 + 0.8 if shape == "column" else far + BUNDLE_REACH
		if dome > 0.0:
			r = (dome + BUNDLE_REACH) * (1.0 - 0.35 * (y - low) / 4.0)
		var cells := {}
		for dz in range(-ceili(r), ceili(r) + 1):
			for dx in range(-ceili(r), ceili(r) + 1):
				var cell := Vector2i(floori(middle.x) + dx, floori(middle.y) + dz)
				var spot := Vector2(cell) + Vector2(0.5, 0.5)
				if (spot - middle).length() > r:
					continue
				if lobes and not levels[y].any(func(p: Vector2i) -> bool:
						return (Vector2(p) + Vector2(0.5, 0.5) - spot).length() <= LOBE_REACH):
					continue
				cells[cell] = true
		covers[y] = cells
		reach[y] = r
	# A column (birch, poplar) takes a layer between every two, as narrow as the upper
	# one, so its sides run up smooth instead of in tiers.
	if shape == "column":
		for y: int in ys.duplicate():
			if covers.has(y + 2):
				covers[y + 1] = covers[y + 2]
				reach[y + 1] = reach[y + 2]
				ys.append(y + 1)
		ys.sort()
	for y: int in ys:
		var cells: Dictionary = covers[y]
		var above: Dictionary = covers.get(y + 2, {})
		var t := float(y - low) / maxf(1.0, top - low)
		var r: float = reach[y]
		# The lower a layer, the more the ones above shade it.
		var tint := base.lerp(base * DEEP, 1.0 - t)
		tint.a = base.a
		rng.seed = hash(Vector3i(at.x, y, at.y))
		var lo := middle - Vector2(r, r)
		var rows := ceili(2.0 * r / BUNDLE_STEP) + 1
		for j in rows:
			for i in rows:
				# A lattice of triangles, every other row half a step aside.
				var q := lo + Vector2((i + 0.5 * (j & 1)) * BUNDLE_STEP, j * BUNDLE_STEP * 0.87)
				q += Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				var cell := Vector2i(floori(q.x), floori(q.y))
				if not cells.has(cell) or _covered(above, cell):
					continue
				var off := (q - middle) / r
				# The length beyond FLAT says how far out from the middle (leaves.gdshader
				# draws the layer shallower along the view, as it does a cone's tier).
				var n := (Vector3(off.x, 0.0, off.y) * 2.2 + Vector3.UP * (0.2 + 0.8 * t)).normalized() \
					* (FLAT + (q - middle).length() * CELL)
				var c := Vector3(q.x, y + 1.0, q.y) * CELL
				_card(job.clumps, PixelView.snap(c), n, tint, row, rng)
				job.nc += 1
				# The shade under a bundle shows at the rim of its layer; inside it the
				# bundles round it hide most of it, so only one in three is drawn there,
				# enough to darken the gaps.
				if _inside(cells, q) and (i + j) % 3 != 0:
					continue
				_card(job.clumps, PixelView.snap(c - Vector3(2.0 * PX, CELL, 0.0)), n, dark * DEEP, row + DEEP_ROW, rng)
				job.nc += 1
	if shape == "weeping":
		_strands(job, at, middle, reach[low], low, hang_to, base, row, rng)


## The strands of a weeping crown (willow): upright bundles one under another hanging
## from under the rim of its lowest layer `y_from` (radius `r` round `middle`, in cells)
## down to the level `y_to` its hanging points reach.
static func _strands(job: Job, at: Vector2i, middle: Vector2, r: float, y_from: int, y_to: int, base: Color, row: int,
		rng: RandomNumberGenerator) -> void:
	rng.seed = hash(Vector3i(at.x, y_from, at.y) + Vector3i(7, 7, 7))
	var radius := r * 0.85
	var count := maxi(6, roundi(TAU * radius / STRAND_STEP))
	var turn := rng.randf() * TAU
	for i in count:
		var a := turn + TAU * (i + rng.randf_range(-0.25, 0.25)) / count
		var out := Vector3(cos(a), 0.0, sin(a))
		var foot := Vector3(middle.x, 0.0, middle.y) + out * radius
		var bottom := y_to - rng.randf_range(0.0, 1.5)
		var n := (out + Vector3.UP * 0.3).normalized()
		var y := float(y_from) - 0.3
		while y > bottom:
			var c := (foot + Vector3(rng.randf_range(-0.15, 0.15), y, rng.randf_range(-0.15, 0.15))) * CELL
			_card(job.clumps, PixelView.snap(c), n, base, row + 1, rng)
			job.nc += 1
			y -= STRAND_DROP


## The fronds of a palm whose trunk stands on column `at`, its crown points `levels`
## (see _crown_levels, Trees._palm): a tuft of bundles on the top point and a line of
## branches out along each frond, from the top through each of its points and on a little
## past the last, sinking as it goes.
static func _fronds(job: Job, at: Vector2i, levels: Dictionary, base: Color, row: int, rng: RandomNumberGenerator) -> void:
	row = PixelTextures.NEEDLE_ROW + 2
	var top: int = levels.keys().max()
	var hub := Vector3(at.x + 0.5, top + 1.0, at.y + 0.5)
	var dark := base * DEEP * DEEP
	dark.a = base.a
	rng.seed = hash(Vector3i(at.x, top, at.y))
	# The tuft over the trunk.
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf() * 0.5
		var off := Vector3(cos(a), 0.0, sin(a)) * 0.4
		_card(job.clumps, PixelView.snap((hub + off) * CELL), (off * 2.0 + Vector3.UP).normalized() * FLAT, base, row, rng)
		job.nc += 1
	# Each frond's points, outward from the trunk: the farthest point on a line gives
	# the frond, the nearer ones on it its bend.
	var fronds := {}
	for y: int in levels:
		for p: Vector2i in levels[y]:
			var d := p - at
			if d == Vector2i.ZERO:
				continue
			var dir := Vector2(d).normalized()
			var key := Vector2i(roundi(dir.x * 8.0), roundi(dir.y * 8.0))
			if not fronds.has(key) or Vector2(d).length() > fronds[key].x:
				fronds[key] = Vector3(Vector2(d).length(), y, 0.0)
	# Each frond is drawn as spruce branches (leaves.gdshader turns them the way the card
	# points on the screen): a large one near the trunk, a middle one and a small one at
	# the tip, sinking as the square of the way out and darker toward the tip.
	var rows := [PixelTextures.LARGE_BRANCH_ROW, PixelTextures.NEEDLE_ROW, PixelTextures.SMALL_BRANCH_ROW]
	for key: Vector2i in fronds:
		var far: float = fronds[key].x
		var low: float = fronds[key].y
		var out := Vector3(key.x, 0.0, key.y).normalized()
		var length := far + 1.0
		var drop := (top - low + 1.0) * pow(length / far, 2.0) if far > 0.0 else 0.0
		for k in 3:
			var t := (k + 0.8) / 3.0
			var step := length * t
			var c := hub + out * step * 0.8 - Vector3.UP * drop * t * t
			var n := (out + Vector3.UP * (0.45 - 0.6 * t)).normalized() * (FLAT + step * CELL)
			_card(job.clumps, PixelView.snap(c * CELL), n, base.lerp(dark, 0.3 * t), rows[k], rng)
			job.nc += 1


## Whether the bundles of a layer of cells `cells` lie all round the spot `q` (in cells).
static func _inside(cells: Dictionary, q: Vector2) -> bool:
	for k in 6:
		var p := q + Vector2.from_angle(k * TAU / 6.0) * BUNDLE_STEP
		if not cells.has(Vector2i(floori(p.x), floori(p.y))):
			return false
	return true


## Whether the cells `cells` of a layer cover `cell` and the cells two round it, so the
## layer hides what lies under `cell` whichever way the camera looks.
static func _covered(cells: Dictionary, cell: Vector2i) -> bool:
	if cells.is_empty():
		return false
	for dz in [-2, 0, 2]:
		for dx in [-2, 0, 2]:
			if not cells.has(cell + Vector2i(dx, dz)):
				return false
	return true


## The points of the crown of the tree on column `at`, per even level: {level: [column]};
## `trunks` are the trees around, to tell which points belong to it.
static func _crown_levels(w, at: Vector2i, trunks: Array) -> Dictionary:
	var levels := {}
	for dz in range(-TREE_REACH, TREE_REACH + 1, 2):
		for dx in range(-TREE_REACH, TREE_REACH + 1, 2):
			var x := at.x + dx
			var z := at.y + dz
			var leaves: int = w.leaf_col(x, z) & EVEN_LEVELS
			if leaves == 0 or _tree_at(trunks, x, z)[0] != at:
				continue
			while leaves != 0:
				var bit := leaves & -leaves
				leaves ^= bit
				var y := WorldData.level_of(bit)
				if not levels.has(y):
					levels[y] = []
				levels[y].append(Vector2i(x, z))
	return levels


## The highest set bit of `bits` (not 0).
static func _top_bit(bits: int) -> int:
	var top := bits
	while bits != 0:
		top = bits & -bits
		bits ^= top
	return top


## A crown is layers parallel to the ground (SLYNYRD): every other level of points is a
## layer whose points take a bundle lying flat on the top of their leaves, a little out
## from the trunk, and a darker one a cell under it that shades the edge of the layer.
## The levels between show as the shade under the layer above: a point there takes a
## dark upright bundle where it is open to the side, or a flat lit one where nothing
## lies on it. The bundles lean their normal out from the trunk and less up the lower
## they lie in the crown, so each layer is lit on its sunny side and the lower ones are
## darker.
static func _layer_cards(job: Job, w, x: int, y: int, z: int, faces: Array[Vector3i], mid: Vector3, axis: Vector3,
		needles: bool, base: Color, first_row: int, rng: RandomNumberGenerator) -> void:
	var looks_needles := first_row % BLOSSOM_ROW == PixelTextures.NEEDLE_ROW
	rng.seed = hash(Vector3i(x, y, z))
	var top := mid
	var out := Vector3(top.x - axis.x, 0.0, top.z - axis.z)
	var outward := out.normalized() if out.length() > 0.2 else Vector3.ZERO
	var middle := mid + _crown_offset(w, x, y, z)
	# The tiers of a cone face the sky alike, their branches lit on the sunny side.
	var rise := 1.0 if needles else clampf(0.75 + 0.3 * (mid.y - middle.y) / CELL, 0.15, 1.6)
	var n := (outward * 0.8 + Vector3(0.0, rise, 0.0)).normalized()
	var dark := base * DEEP
	dark.a = base.a
	if faces.is_empty():
		# Inside a cone a dark tuft fills the room between the branches, so the
		# trunk and the ground never show through.
		_card(job.clumps, PixelView.snap(mid), n * FLAT, dark, first_row + 2, rng)
		job.nc += 1
		return
	# Each tier of a cone is a layer of its own.
	var layer := needles or (y >> 1) & 1 == 0
	if layer or faces[0] == Vector3i.UP:
		var c := top + outward * rng.randi_range(1, 4) * PX + Vector3(rng.randi_range(-3, 3), 0.0, rng.randi_range(-3, 3)) * PX
		# The rim of a layer takes smaller bundles, so its edge is scalloped and the
		# shade under it shows between them.
		var rim := faces.size() >= 3 if not needles else outward == Vector3.ZERO and faces.size() >= 4
		var row := first_row + (1 if rim else 0)
		# Needles not in tiers (a pine's) take the tufts of the tips.
		if looks_needles and not needles:
			row = first_row + 2
		if needles and outward != Vector3.ZERO:
			# A cone's tier is spruce branches (the shader turns each the way its
			# normal leans): two per point, fanned either side of straight out.
			for turn in [rng.randf_range(0.25, 0.6), -rng.randf_range(0.25, 0.6)]:
				var way := outward.rotated(Vector3.UP, turn)
				var bn := (way * 0.8 + Vector3(0.0, rise, 0.0)).normalized()
				var bc := c + way * 2.0 * PX
				_card(job.clumps, PixelView.snap(bc), bn * FLAT, base, row, rng)
				_card(job.clumps, PixelView.snap(bc - Vector3(0.0, CELL, 0.0)), bn * FLAT, dark, first_row + DEEP_ROW, rng)
				job.nc += 2
			return
		_card(job.clumps, PixelView.snap(c), n * FLAT, base, row, rng)
		_card(job.clumps, PixelView.snap(c - Vector3(0.0, CELL, 0.0)), n * FLAT, dark, first_row + DEEP_ROW, rng)
		job.nc += 2
	else:
		var side := Vector3(outward.x, -0.5, outward.z).normalized()
		var shade := dark * DEEP
		shade.a = base.a
		_card(job.clumps, PixelView.snap(mid + outward * 4.0 * PX), side, shade, first_row, rng)
		job.nc += 1


## The plants once every column is built (see build_chunk), with the bushes of the
## chunk (their shadows go with the trees') and its snowdrifts.
static func finish(job: Job) -> Dictionary:
	var out := {}
	for i in FINISH_PARTS:
		finish_part(job, i, out)
	return out


## Finishing takes longer than a column, so ChunkStreamer does it a part a frame into
## `out`: part 0 the bushes and the buffers of the columns, part 1 the snowdrifts.
const FINISH_PARTS := 2


static func finish_part(job: Job, i: int, out: Dictionary) -> void:
	var w = job.w
	if i == 1:
		out.drifts = Drifts.build(w, job.x0, job.z0, job.x1 - job.x0)
		return
	var cells: Array[Vector3i] = w.bushes_in(job.x0, job.z0)
	out.bushes = bushes(cells, w.bushes, w.bush_picked)
	var s := BUSH_DISC / SHADOW_DISC
	for cell in cells:
		# The disc lies as high as the middle of the bush, so its shadow starts at its
		# foot and the bush stands on the ground instead of hanging over its shadow.
		var type: int = w.bushes.get(cell, 0)
		var rise: float = Bushes.TYPES[type].rise if type < Bushes.TYPES.size() else 0.5
		var p := (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL + Vector3(0.0, rise, 0.0)
		job.shadows.append_array([s, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, s, p.z])
		job.shadows.append_array([bush_kind(w.bushes.get(cell, 0)), 0.0, 0.0, 0.0])
		job.ns += 1
	out.grass = [job.ng, job.grass]
	out.clumps = [job.nc, job.clumps]
	out.shadows = [job.ns, job.shadows]


## Leaf clusters of berry bushes standing on the given cells: [count, buffer] like
## crowns, lit as one low dome per bush. `types` notes the type of each by its cell
## (see Bushes); a bush in `picked` shows no berries. Bushes go bare in winter like
## some trees.
static func bushes(cells: Array[Vector3i], types: Dictionary, picked := {}) -> Array:
	var buf := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	var count := 0
	for cell in cells:
		var type: int = types.get(cell, 0)
		if type >= Bushes.TYPES.size():
			continue
		var b: Dictionary = Bushes.TYPES[type]
		var spread: Vector3 = b.spread
		var cards: int = b.cards
		var berries: float = 0.0 if picked.has(cell) else b.berry_cards
		rng.seed = hash(cell)
		for k in cards:
			# Clusters around the middle, the first one on top, the others in a ring
			# and up its height.
			var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / (cards - 1)
			var o := Vector3(cos(a) * spread.x, rng.randf_range(-0.3, 1.0) * spread.y, sin(a) * spread.z)
			if k == 0:
				o = Vector3(0.0, spread.y + 0.12, 0.0)
			put(buf, PixelView.snap((Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL + Vector3(0.0, b.rise, 0.0) + o))
			var tint: Color = b.tint
			buf.append_array([tint.r, tint.g, tint.b, bush_kind(type)])
			var n := (o + Vector3(0.0, 0.25, 0.0)).normalized()
			var row := (1 if b.small else 0) + (PixelTextures.BERRY_ROW if rng.randf() < berries else 0)
			# Every other cluster shows bare twigs in winter, the others fall.
			if k % 2 == 1:
				row += DEEP_ROW
			buf.append_array([n.x, n.y, n.z, row + rng.randf() * 0.99])
		count += cards
	return [count, buf]


## What a bush of `type` does over the year, in the alpha of its colour: below 0.5 for
## every bush, which also names the type for its berries (see leaves.gdshader).
static func bush_kind(type: int) -> float:
	return 0.1 * (type + 1)


## Faces of a crown point the camera can see from one side or another (top and the
## four sides) whose neighbouring point (two cells on) is neither leaves nor a trunk.
static func _open_faces(w, x: int, y: int, z: int) -> Array[Vector3i]:
	var open: Array[Vector3i] = []
	for d in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		var n: int = w.get_cell(x + 2 * d.x, y + 2 * d.y, z + 2 * d.z)
		if n != Mat.LEAVES and n != Mat.LOG:
			open.append(d)
	return open


## Appends a leaf cluster card at `c`: transform, tint (its alpha what the tree does
## in winter), and the normal `n` with the card's row of the clump texture plus a sway
## phase in the last value, negative for a card drawn in front of `c` (`ahead`).
static func _card(buf: PackedFloat32Array, c: Vector3, n: Vector3, tint: Color, row: int, rng: RandomNumberGenerator,
		ahead := false) -> void:
	put(buf, c)
	buf.append_array([tint.r, tint.g, tint.b, tint.a])
	var w := row + rng.randf() * 0.99
	buf.append_array([n.x, n.y, n.z, -w if ahead else w])


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


## Appends flat shadow discs for the crown of tree `t` ([column, species, hash], see
## _trunks_near), one per level of its crown, each an ellipse around the points of
## that level, so the crown casts one shadow instead of a cluster of circles.
## `trunks` are the trees around, to tell which points belong to `t`. Returns the
## number of discs.
static func _tree_shadows(w, t: Array, trunks: Array, buf: PackedFloat32Array) -> int:
	var at: Vector2i = t[0]
	var looks: Dictionary = Trees.SPECIES[t[1]]
	var kind := _year_kind(looks, t[2], t[1])
	if kind == DEAD:
		return 0
	# Per level: the columns of the points there.
	var levels := _crown_levels(w, at, trunks)
	if levels.is_empty():
		return 0
	# A conifer's lowest tier hangs on screen over the trunk below it (see
	# Trees.hidden_trunk), so the tree looks green further down than its tiers are; its
	# shadow falls from the crown where it shows, the discs lowered by the trunk the
	# tier hides (bar CONIFER_BARE - 1 cells). The trunk that shows below the tier, short
	# on a spruce and long on a larch, stays lit, its shadow from the trunk itself.
	var lower := 0
	if looks.tiers:
		var low: int = levels.keys().min()
		var front := 0
		for p: Vector2i in levels[low]:
			if p.x == at.x:
				front = maxi(front, (p.y - at.y) / 2)
		lower = maxi(0, Trees.hidden_trunk(front) - (CONIFER_BARE - 1))
	if looks.tiers:
		return _cone_shadow(at, looks, levels, lower, kind, buf)
	# A disc round all the points of each level, and one on every level between them
	# (odd ones too, and those a gap between lobes leaves empty) grown from the levels
	# above and below: discs a level apart overlap into one shadow of the crown, two or
	# more apart a narrow crown (a column, the tip of a cone, a lobe on its own) casts a
	# string of balls.
	var ys: Array = levels.keys()
	ys.sort()
	var boxes := {}
	for y: int in ys:
		var box := Vector4(INF, -INF, INF, -INF)
		for p: Vector2i in levels[y]:
			box = Vector4(minf(box.x, p.x), maxf(box.y, p.x), minf(box.z, p.y), maxf(box.w, p.y))
		boxes[y] = box
	var discs := 0
	for i in ys.size():
		var y0: int = ys[i]
		var y1: int = ys[i + 1] if i + 1 < ys.size() else y0 + 1
		for y in range(y0, y1):
			var b: Vector4 = boxes[y0].lerp(boxes[y1], float(y - y0) / (y1 - y0)) if y > y0 else boxes[y0]
			# Each point fills the cells around it, one on either side.
			var c := Vector3((b.x + b.y) * 0.5 + 0.5, y - lower + 0.5, (b.z + b.w) * 0.5 + 0.5) * CELL
			var wx: float = (b.y - b.x + 3) * CELL * 1.05 / SHADOW_DISC
			var wz: float = (b.w - b.z + 3) * CELL * 1.05 / SHADOW_DISC
			buf.append_array([wx, 0.0, 0.0, c.x, 0.0, 1.0, 0.0, c.y, 0.0, 0.0, wz, c.z])
			buf.append_array([kind, 0.0, 0.0, 0.0])
			discs += 1
	return discs


## The shadow of a conifer drawn by _spruce: discs round its trunk every half level
## from its lowest tier to its tip, as wide as the branches there, so the cone casts
## one straight-sided shadow with a point, not a string of balls.
static func _cone_shadow(at: Vector2i, looks: Dictionary, levels: Dictionary, lower: int, kind: float, buf: PackedFloat32Array) -> int:
	var low: int = levels.keys().min()
	var top: int = levels.keys().max()
	var reach := 0.0
	for p: Vector2i in levels[low]:
		reach = maxf(reach, Vector2(p - at).length())
	var widest := _widest_tier(reach, looks)
	var discs := 0
	for s in (top - low) * 2 + 4:
		var y := low + s * 0.5
		var t := (y - low) / maxf(1.0, top - low)
		# The branches reach widest * (1 - t) + 0.5 and a little more with their leaves.
		var r := maxf(widest * (1.0 - t) + 1.1, 0.4)
		var c := Vector3(at.x + 0.5, y - lower + 0.5, at.y + 0.5) * CELL
		var d := 2.0 * r * CELL / SHADOW_DISC
		buf.append_array([d, 0.0, 0.0, c.x, 0.0, 1.0, 0.0, c.y, 0.0, 0.0, d, c.z])
		buf.append_array([kind, 0.0, 0.0, 0.0])
		discs += 1
	return discs


## What a tree of species `looks` (index `species`, its column's hash `h`) does over the
## year: the alpha of its cards' colour.
static func _year_kind(looks: Dictionary, h: int, species: int) -> float:
	if looks.dead:
		return DEAD
	if looks.leaves == Trees.NEEDLES and looks.bare == 0.0:
		return EVERGREEN
	return GOES_BARE if _goes_bare(h, species) else KEEPS_LEAVES


## Whether the tree on column `at` drops all its leaves in winter (the others of a
## deciduous species keep dry leaves under snow caps).
static func goes_bare(at: Vector2i, species: int) -> bool:
	return _goes_bare(hash(at), species)


static func _goes_bare(h: int, species: int) -> bool:
	return (h >> 8) % 100 < Trees.SPECIES[species].bare * 100.0


## The tree a crown point in column x, z belongs to: the nearest trunk, or the first
## species where no tree is noted (crowns made by hand); [] with no species loaded.
static func _tree_at(trunks: Array, x: int, z: int) -> Array:
	if Trees.SPECIES.is_empty():
		return []
	var best := [Vector2i(x, z), 0, hash(Vector2i(x / 6, z / 6))]
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
