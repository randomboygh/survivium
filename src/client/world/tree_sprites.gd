extends RefCounted
## Trees drawn as pictures (a species with `pictures`, see TreeLooks): each standing tree
## of such a species is one upright picture at its trunk, the approved drawing of the
## tree from the side the camera looks at (8 sides, the tree standing turned in the world
## as Growth.turn_of says), lit by the sun in tree.gdshader: the pictures keep, per pixel,
## what the light needs (the leaf's facing, its bundle's normal, the bark's steps under 8
## suns of the day), not colours. Young trees, stumps and the species drawn in leaf
## clusters stay with Foliage and the trunk mesher.
##
## Every pictured species' frames are packed into one atlas at the start (setup), so a
## chunk draws its trees in one MultiMesh: an instance per tree, its foot the origin, its
## colour (anchor x, anchor y, turn, what the tree does over the year as Foliage's cards'
## alpha) and custom data (the look's cell of turn 0 in the atlas: x, y, w, h).

const Content := preload("res://src/shared/content/content.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Growth := preload("res://src/shared/world/growth.gd")
const WorldCells := preload("res://src/shared/world/world_cells.gd")
const Foliage := preload("res://src/client/world/foliage.gd")

const CELL := WorldCells.CELL
## The atlas is at most this wide, its places even (the instance data goes as half floats
## on some GPUs: whole even numbers up to 4096 come through exactly).
const ATLAS_W := 4096
## Texels of a ramp row: the leaves' 7 steps, then the bark's 4, then the rule its leaves
## are lit by (TreeLooks.MODULES or FRONDS, in red).
const RAMP_W := 12
## Texels of the pictures a world unit (tree.gdshader's TEXELS).
const TEXELS := 16.0

## Species index -> the place of its frames in the atlas (Vector2i), for species drawn so.
static var places := {}
## The atlas of the frames, of the bare trees' frames (two bytes a texel: half the
## memory of the frames, 14 species' atlases are some 40 MB) and the ramps (a row a species).
static var frames: ImageTexture
static var bare: ImageTexture
static var ramps: ImageTexture
## Species index -> its row in ramps.
static var ramp_rows := {}
## How high over its foot the tallest look of the species drawn reaches (world units, at
## least the 12 of the first pictures): the height of quad_mesh's box.
static var tallest := 12.0


## Packs the pictured species' frames into the atlases; false when no species has any.
static func setup() -> bool:
	places.clear()
	ramp_rows.clear()
	tallest = 12.0
	var pics := []
	for i in Trees.SPECIES.size():
		var p: Dictionary = Trees.SPECIES[i].pictures
		if p.is_empty():
			continue
		var top := Content.picture(p.frames)
		var under := Content.picture(p.bare)
		if top == null or under == null or top.get_size() != under.get_size():
			push_warning("tree pictures: no frames for %s" % Trees.SPECIES[i].id)
			continue
		top.convert(Image.FORMAT_RGBA8)
		under.convert(Image.FORMAT_LA8)
		pics.append([i, top, under])
		for look: Dictionary in p.looks:
			tallest = maxf(tallest, (float(look.ay) + 1.0) / TEXELS)
	if pics.is_empty():
		frames = null
		return false
	# Shelves, tallest first.
	pics.sort_custom(func(a: Array, b: Array) -> bool: return a[1].get_height() > b[1].get_height())
	var x := 0
	var y := 0
	var shelf := 0
	var at := []
	for p: Array in pics:
		var sz: Vector2i = p[1].get_size()
		if x + sz.x > ATLAS_W:
			x = 0
			y += shelf
			shelf = 0
		at.append(Vector2i(x, y))
		x += (sz.x + 1) & ~1
		shelf = maxi(shelf, (sz.y + 1) & ~1)
	var h := y + shelf
	var width := 0
	for k in pics.size():
		width = maxi(width, at[k].x + pics[k][1].get_width())
	var a := Image.create_empty(width, h, false, Image.FORMAT_RGBA8)
	# No wood: both bytes 255 (see tree.gdshader).
	var b := Image.create_empty(width, h, false, Image.FORMAT_LA8)
	b.fill(Color(1, 1, 1, 1))
	var r := Image.create_empty(RAMP_W, pics.size(), false, Image.FORMAT_RGBA8)
	for k in pics.size():
		var p: Array = pics[k]
		var sz: Vector2i = p[1].get_size()
		a.blit_rect(p[1], Rect2i(Vector2i.ZERO, sz), at[k])
		b.blit_rect(p[2], Rect2i(Vector2i.ZERO, sz), at[k])
		places[p[0]] = at[k]
		ramp_rows[p[0]] = k
		var s: Dictionary = Trees.SPECIES[p[0]].pictures
		for j in 7:
			r.set_pixel(j, k, s.leaves[mini(j, s.leaves.size() - 1)])
		for j in 4:
			r.set_pixel(7 + j, k, s.bark[mini(j, s.bark.size() - 1)])
		r.set_pixel(11, k, Color(float(s.get("rule", 0)), 0.0, 0.0, 1.0))
	frames = ImageTexture.create_from_image(a)
	bare = ImageTexture.create_from_image(b)
	ramps = ImageTexture.create_from_image(r)
	return true


## Sets the atlases on `mat` (tree.gdshader, tree_shadow.gdshader).
static func dress(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("frames", frames)
	mat.set_shader_parameter("bare_frames", bare)
	mat.set_shader_parameter("ramps", ramps)


## The quad a picture is drawn on: x across 0..1, y -1 (the lowest row, lying on the
## ground toward the camera), 0 (the ground under the trunk) and 1 (the top row);
## tree.gdshader sizes it to the look's cell. tree_shadow.gdshader stands only the upright
## part, its rows the foot, a knee and the top.
static func quad_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, -1, 0), Vector3(1, -1, 0), Vector3(0, 0, 0),
		Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK,
		Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3, 2, 4, 3, 3, 4, 5])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The picture reaches far past the unit quad (tree.gdshader): a box as big as the
	# tallest look, so a chunk's trees are culled by what they draw.
	m.custom_aabb = AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, tallest + 1.0, 12.0))
	return m


## The trees of the chunk at x0, z0 drawn as pictures: [count, buffer] for a MultiMesh
## with colours and custom data (see the top).
static func build(w, x0: int, z0: int) -> Array:
	var buf := PackedFloat32Array()
	var count := 0
	if frames == null:
		return [0, buf]
	var foot := [0]
	for col: Vector2i in w.tree_chunks.get(WorldCells.chunk_key(x0, z0), {}):
		var i := Growth.standing_look(w, col, foot)
		if i < 0:
			continue
		var species: int = w.trees[col]
		if not places.has(species):
			continue
		var s: Dictionary = Trees.SPECIES[species]
		var look: Dictionary = s.pictures.looks[i]
		var p := Vector3(col.x + 0.5, foot[0], col.y + 0.5) * CELL
		var place: Vector2i = places[species]
		buf.append_array([1.0, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, 1.0, p.z])
		buf.append_array([float(look.ax), float(look.ay), float(Growth.turn_of(col) + 8 * ramp_rows[species]),
			Foliage.year_kind(s, hash(col), species)])
		buf.append_array([float(place.x + look.x), float(place.y + look.y), float(look.w), float(look.h)])
		count += 1
	return [count, buf]
