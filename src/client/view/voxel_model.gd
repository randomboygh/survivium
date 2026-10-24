extends RefCounted
## Small voxel model for furniture and details. A cell is 16x16x16 voxels and one
## voxel matches one texel of the terrain, so models look like pixel art from above.

const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const MeshBuffers := preload("res://src/client/world/mesh_buffers.gd")

const RES := 16

## Vector3i -> Color
var voxels := {}
## Vector3i -> true for voxels tinted by the season (leaves).
var foliage := {}


## In a model's PNG a voxel tinted by the season has this alpha (opaque voxels 255).
const FOLIAGE_ALPHA := 128


func set_voxel(p: Vector3i, c: Color, is_foliage := false) -> void:
	voxels[p] = c
	if is_foliage:
		foliage[p] = true


## The model in `img`, a row of square slices (the image's height wide), one per level
## from the ground up: a pixel is the voxel at its x and z (z down the slice), its
## colour the voxel's, transparent for none, FOLIAGE_ALPHA for a leaf. `centred` puts the
## slice's middle at the origin (things lying on the ground); otherwise the slice's
## corner is (things placed on cells).
static func from_image(img: Image, centred: bool):
	var m = new()
	var size := img.get_height()
	if size == 0 or img.get_width() % size != 0:
		return m
	var shift := Vector3i(size / 2, 0, size / 2) if centred else Vector3i.ZERO
	for y in img.get_width() / size:
		for z in size:
			for x in size:
				var c := img.get_pixel(y * size + x, z)
				if c.a == 0.0:
					continue
				var leaf := c.a8 <= FOLIAGE_ALPHA
				c.a = 1.0
				m.set_voxel(Vector3i(x, y, z) - shift, c, leaf)
	return m


## The model as the image `from_image` reads (see there): slices of the smallest even
## size that holds every voxel (16 at least).
func to_image(centred: bool) -> Image:
	var size := 16
	var top := 0
	for p: Vector3i in voxels:
		top = maxi(top, p.y + 1)
		if centred:
			size = maxi(size, 2 * maxi(maxi(-p.x, p.x + 1), maxi(-p.z, p.z + 1)))
		else:
			size = maxi(size, maxi(p.x, p.z) + 1)
	size += size & 1
	var img := Image.create(size * maxi(top, 1), size, false, Image.FORMAT_RGBA8)
	var shift := Vector3i(size / 2, 0, size / 2) if centred else Vector3i.ZERO
	for p: Vector3i in voxels:
		var q: Vector3i = p + shift
		var c: Color = voxels[p]
		c = Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), 1.0)
		if foliage.has(p):
			c.a8 = FOLIAGE_ALPHA
		img.set_pixel(q.y * size + q.x, q.z, c)
	return img


## Mesh in voxel units (0..16); scale the instance by 1/16 to fit a cell.
func build_mesh() -> ArrayMesh:
	var faces := ChunkMesher.face_table()
	var buf := MeshBuffers.new()
	var zero_uv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var no_tiles := float(ChunkMesher.NO_TILE * 0x41041)
	for key in voxels:
		var p: Vector3i = key
		var base := Vector3(p.x, p.y, p.z)
		for d in 6:
			var dir: Vector3i = ChunkMesher.DIRS[d]
			if voxels.has(p + dir):
				continue
			var face: Dictionary = faces[d]
			var pts := []
			for c in face.corners:
				pts.append(base + c)
			var flag := ChunkMesher.FOLIAGE_VOXEL if foliage.has(p) else 0
			# The world shader doubles the colour by its alpha (a snowdrift's relief shade,
			# see world.gdshader): half alpha keeps the voxel's own colour.
			var col: Color = voxels[p]
			col.a = 0.5
			buf.quad(pts, face.normal, zero_uv, col, Vector2(ChunkMesher.pack(ChunkMesher.NO_TILE, 0, flag), no_tiles))
	return buf.to_mesh()

