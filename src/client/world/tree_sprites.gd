extends RefCounted
## Trees drawn as pictures (a species with `pictures`, see TreeLooks): each standing tree
## of such a species is one upright picture at its trunk, the approved drawing of the
## tree from the side the camera looks at (8 sides, the tree standing turned in the world
## as Growth.turn_of says), lit by the sun in tree.gdshader: the pictures keep, per pixel,
## what the light needs (the leaf's facing, its bundle's normal, the bark's steps under 8
## suns of the day), not colours. Young trees, stumps and the species drawn in leaf
## clusters stay with Foliage and the trunk mesher.
##
## Every pictured species' frames are packed into one atlas at the start (setup), with a
## row of ramps a species under them (the colours its steps take, RAMP_W), and its snow
## pictures into a second (`snow`), so a
## chunk draws its trees in one MultiMesh: an instance per tree, its foot the origin, its
## colour (anchor x, anchor y, turn, what the tree does over the year as Foliage's cards'
## alpha) and custom data (the look's cell of turn 0 in the atlas: x, y, w, h).

const Content := preload("res://src/shared/content/content.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Growth := preload("res://src/shared/world/growth.gd")
const WorldCells := preload("res://src/shared/world/world_cells.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const TreeLooks := preload("res://src/shared/content/tree_looks.gd")

const CELL := WorldCells.CELL
## The atlas is at most this wide, its places even (the instance data goes as half floats
## on some GPUs: whole even numbers up to 4096 come through exactly).
const ATLAS_W := 4096
## Texels of a ramp row: the leaves' 7 steps, then the bark's 4, then the rule its leaves
## are lit by (TreeLooks.MODULES, FRONDS, HANGING or PALMS, in red: a third a rule), the 7
## steps of the dry leaves kept in winter (DRY_AT) and of the blossom (BLOSSOM_AT: alpha 0
## where the species has none), and where its snow pictures lie in the snow atlas from its
## frames in the frames atlas (SNOW_AT: the winter look's, then the dry crown's; x, y as
## two bytes each, low first, a negative one less 65536; x 32768 where it has none), then
## the colours of its stumps' cut wood (WOOD_AT: 6 steps, then the resin's).
const RAMP_W := 36
const DRY_AT := 12
const BLOSSOM_AT := 19
const SNOW_AT := 26
const WOOD_AT := 28
## What the instance's colour alpha says of a stump (tree.gdshader): a stump, a stump with
## winter's pictures (snow on its cut).
const STUMP := -1.0
const STUMP_SNOW := -2.0
const NO_SNOW := 32768
## Texels of the pictures a world unit (tree.gdshader's TEXELS).
const TEXELS := 16.0

## Species index -> the place of its frames in the atlas (Vector2i), for species drawn so.
static var places := {}
## Species index -> the place of its stumps' frames in the atlas.
static var stump_places := {}
## The atlas of the frames (and the ramps, a row a species from `ramps_at`: one texture
## unit less, the web has few) and of the bare trees' frames (two bytes a texel: half the
## memory of the frames, 14 species' atlases are some 40 MB).
static var frames: ImageTexture
static var bare: ImageTexture
static var ramps_at := Vector2i.ZERO
## Species index -> its row of ramps.
static var ramp_rows := {}
## The atlas of the snow on the trees (two bytes a texel, tree.gdshader's snow codes), the
## species' snow pictures packed as the frames are.
static var snow: ImageTexture
## How high over its foot the tallest look of the species drawn reaches (world units, at
## least the 12 of the first pictures): the height of quad_mesh's box.
static var tallest := 12.0


## Packs the pictured species' frames into the atlases; false when no species has any.
static func setup() -> bool:
	places.clear()
	stump_places.clear()
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
		var snows := []
		for k in ["snow", "snow_dry"]:
			var sn: Image = Content.picture(p[k]) if p.get(k, "") != "" else null
			if sn != null and sn.get_size() != top.get_size():
				push_warning("tree pictures: %s of %s is not the frames' size" % [k, Trees.SPECIES[i].id])
				sn = null
			if sn != null:
				sn.convert(Image.FORMAT_LA8)
			snows.append(sn)
		var stumps: Image = Content.picture(p.stump_frames) if p.get("stump_frames", "") != "" else null
		if stumps != null:
			stumps.convert(Image.FORMAT_RGBA8)
		pics.append([i, top, under, snows, stumps])
		for look: Dictionary in p.looks:
			tallest = maxf(tallest, (float(look.ay) + 1.0) / TEXELS)
	if pics.is_empty():
		frames = null
		return false
	# Shelves, tallest first.
	pics.sort_custom(func(a: Array, b: Array) -> bool: return a[1].get_height() > b[1].get_height())
	var sizes := []
	for p: Array in pics:
		sizes.append(p[1].get_size())
	# The stumps' frames after all the trees' (no bare frames: the bare atlas has no wood there).
	var stumps := []
	for p: Array in pics:
		if p[4] != null:
			stumps.append(p)
	stumps.sort_custom(func(a: Array, b: Array) -> bool: return a[4].get_height() > b[4].get_height())
	for p: Array in stumps:
		sizes.append(p[4].get_size())
	var at := _shelves(sizes)
	var width: int = maxi(at.pop_back().x, RAMP_W)
	var h: int = at.pop_back().y
	ramps_at = Vector2i(0, h)
	var a := Image.create_empty(width, h + ((pics.size() + 1) & ~1), false, Image.FORMAT_RGBA8)
	# No wood: both bytes 255 (see tree.gdshader).
	var b := Image.create_empty(width, h, false, Image.FORMAT_LA8)
	b.fill(Color(1, 1, 1, 1))
	var r := Image.create_empty(RAMP_W, pics.size(), false, Image.FORMAT_RGBA8)
	r.fill(Color(0, 0, 0, 0))
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
		r.set_pixel(11, k, Color(float(s.get("rule", 0)) / 3.0, 0.0, 0.0, 1.0))
		var wood: Array = s.get("wood", [])
		for j in 7:
			if not wood.is_empty():
				r.set_pixel(WOOD_AT + j, k, wood[mini(j, wood.size() - 1)])
		for j in 7:
			for d in [[DRY_AT, s.get("dry", [])], [BLOSSOM_AT, s.get("blossom", [])]]:
				var cs: Array = d[1]
				if not cs.is_empty():
					r.set_pixel(d[0] + j, k, cs[mini(j, cs.size() - 1)])
	for n in stumps.size():
		var img: Image = stumps[n][4]
		var to: Vector2i = at[pics.size() + n]
		a.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), to)
		stump_places[stumps[n][0]] = to
	_pack_snow(pics, at, r)
	a.blit_rect(r, Rect2i(Vector2i.ZERO, r.get_size()), ramps_at)
	frames = ImageTexture.create_from_image(a)
	bare = ImageTexture.create_from_image(b)
	return true


## Places for pictures of `sizes` on shelves ATLAS_W wide (even places), then the height
## and width they take (as the last two entries: (0, height), (width, 0)).
static func _shelves(sizes: Array) -> Array:
	var x := 0
	var y := 0
	var shelf := 0
	var at := []
	var width := 0
	for sz: Vector2i in sizes:
		if x + sz.x > ATLAS_W:
			x = 0
			y += shelf
			shelf = 0
		at.append(Vector2i(x, y))
		width = maxi(width, x + sz.x)
		x += (sz.x + 1) & ~1
		shelf = maxi(shelf, (sz.y + 1) & ~1)
	at.append(Vector2i(0, maxi(y + shelf, 2)))
	at.append(Vector2i(maxi(width, 2), 0))
	return at


## Packs the snow pictures of `pics` (setup's: [species, frames, bare, [snow, snow_dry]]
## at `at` in the frames atlas) into the snow atlas, writing where each lies into the ramps
## `r` (SNOW_AT).
static func _pack_snow(pics: Array, at: Array, r: Image) -> void:
	var items := []
	for k in pics.size():
		for j in 2:
			r.set_pixel(SNOW_AT + j, k, _offset_colour(Vector2i(NO_SNOW, 0)))
			if pics[k][3][j] != null:
				items.append([k, j, pics[k][3][j]])
	items.sort_custom(func(p: Array, q: Array) -> bool: return p[2].get_height() > q[2].get_height())
	var sizes := []
	for it: Array in items:
		sizes.append(it[2].get_size())
	var places := _shelves(sizes)
	var width: int = places.pop_back().x
	var h: int = places.pop_back().y
	var img := Image.create_empty(width, h, false, Image.FORMAT_LA8)
	for n in items.size():
		var it: Array = items[n]
		img.blit_rect(it[2], Rect2i(Vector2i.ZERO, it[2].get_size()), places[n])
		r.set_pixel(SNOW_AT + it[1], it[0], _offset_colour(places[n] - at[it[0]]))
	snow = ImageTexture.create_from_image(img)


## An offset as a ramp texel (see RAMP_W): x and y as two bytes each.
static func _offset_colour(d: Vector2i) -> Color:
	var x := d.x & 0xffff
	var y := d.y & 0xffff
	return Color8(x & 255, x >> 8, y & 255, y >> 8)


## Sets the atlases on `mat` (tree.gdshader, tree_shadow.gdshader).
static func dress(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("frames", frames)
	mat.set_shader_parameter("bare_frames", bare)
	mat.set_shader_parameter("ramps_at", ramps_at)
	mat.set_shader_parameter("snow_frames", snow)


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
## with colours and custom data (see the top), then the standing trees' instances by
## column (a felled one falls, TreeHits.fall).
static func build(w, x0: int, z0: int) -> Array:
	var buf := PackedFloat32Array()
	var count := 0
	var standing := {}
	if frames == null:
		return [0, buf, standing]
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
			_year_kind(s, col, species)])
		buf.append_array([float(place.x + look.x), float(place.y + look.y), float(look.w), float(look.h)])
		standing[col] = buf.slice(count * 20, count * 20 + 20)
		count += 1
	# The stumps felled trees left (Growth.stump_look), drawn as the trees are.
	for col: Vector2i in w.tree_chunks.get(WorldCells.chunk_key(x0, z0), {}):
		var i := Growth.stump_look(w, col, foot)
		if i < 0:
			continue
		var species: int = w.trees[col]
		if not stump_places.has(species):
			continue
		var s: Dictionary = Trees.SPECIES[species]
		var st: Dictionary = s.pictures.stumps[i]
		var p := Vector3(col.x + 0.5, foot[0], col.y + 0.5) * CELL
		var place: Vector2i = stump_places[species]
		buf.append_array([1.0, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, 1.0, p.z])
		buf.append_array([float(st.ax), float(st.ay), float(Growth.turn_of(col) + 8 * ramp_rows[species]),
			STUMP_SNOW if s.pictures.get("stump_snow", false) else STUMP])
		buf.append_array([float(place.x + st.x), float(place.y + st.y), float(st.w), float(st.h)])
		count += 1
	return [count, buf, standing]


## What the tree on column `col` does over the year (Foliage.year_kind), but a palm drawn
## so keeps all its leaves (TreeLooks.PALMS: its frames hold the leaves' light where the
## others keep the bare tree, see tree.gdshader), and so does a tree of the hot zones
## (`evergreen`: no snow, no dry leaves; user 2026-11-24).
static func _year_kind(s: Dictionary, col: Vector2i, species: int) -> float:
	if (int(s.pictures.get("rule", 0)) == TreeLooks.PALMS or s.pictures.get("evergreen", false)) and not s.dead:
		return Foliage.EVERGREEN
	return Foliage.year_kind(s, hash(col), species)
