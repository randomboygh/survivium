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
## branches show), keeps its needles; bushes are below 0.5 (see bush_kind).
const KEEPS_LEAVES := 1.0
const GOES_BARE := 0.8
const EVERGREEN := 0.6
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
	if leaves == 0:
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
	var tints: Array = looks.tints
	var base: Color = tints[tree[2] % tints.size()]
	base.a = EVERGREEN if looks.leaves == Trees.NEEDLES and looks.bare == 0.0 else (GOES_BARE if _goes_bare(tree[2], tree[1]) else KEEPS_LEAVES)
	var first_row: int = PixelTextures.LEAF_ROWS[looks.leaf]
	var axis := (Vector3(tree[0].x, 0, tree[0].y) + Vector3(0.5, 0.0, 0.5)) * CELL
	if needles and tree[0] == Vector2i(x, z):
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
		var mid := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * CELL
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
		var rows := [1, 2] if small else [0, 1]
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
		var p := (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL + Vector3(0.0, 0.5, 0.0)
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
## _trunks_near), one per level of its points, each an ellipse around the points of
## that level, so the crown casts one round shadow instead of a cluster of circles.
## `trunks` are the trees around, to tell which points belong to `t`. Returns the
## number of discs.
static func _tree_shadows(w, t: Array, trunks: Array, buf: PackedFloat32Array) -> int:
	var at: Vector2i = t[0]
	var looks: Dictionary = Trees.SPECIES[t[1]]
	var kind := EVERGREEN if looks.leaves == Trees.NEEDLES and looks.bare == 0.0 else (GOES_BARE if _goes_bare(t[2], t[1]) else KEEPS_LEAVES)
	# Per level: min x, max x, min z, max z of the points.
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
				if levels.has(y):
					var b: Array = levels[y]
					levels[y] = [mini(b[0], x), maxi(b[1], x), mini(b[2], z), maxi(b[3], z)]
				else:
					levels[y] = [x, x, z, z]
	# A conifer's lowest tier hangs on screen over the trunk below it (see
	# Trees._hidden_trunk), so the tree looks green down to near its foot; its shadow
	# falls from the crown where it shows, the discs lowered to start CONIFER_BARE cells
	# above the foot.
	var lower := 0
	if looks.tiers and not levels.is_empty():
		var low: int = levels.keys().min()
		var foot := low
		while foot > 0 and w.get_cell(at.x, foot - 1, at.y) == Mat.LOG:
			foot -= 1
		lower = maxi(0, low - foot - CONIFER_BARE)
	for y in levels:
		var b: Array = levels[y]
		# Each point fills the cells around it, one on either side.
		var c := Vector3((b[0] + b[1]) * 0.5 + 0.5, y - lower + 0.5, (b[2] + b[3]) * 0.5 + 0.5) * CELL
		var wx: float = (b[1] - b[0] + 3) * CELL * 1.05 / SHADOW_DISC
		var wz: float = (b[3] - b[2] + 3) * CELL * 1.05 / SHADOW_DISC
		buf.append_array([wx, 0.0, 0.0, c.x, 0.0, 1.0, 0.0, c.y, 0.0, 0.0, wz, c.z])
		buf.append_array([kind, 0.0, 0.0, 0.0])
	return levels.size()


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
