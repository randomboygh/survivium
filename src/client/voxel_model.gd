extends RefCounted
## Small voxel model for furniture and details. A cell is 16x16x16 voxels and one
## voxel matches one texel of the terrain, so models look like pixel art from above.

const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const MeshBuffers := preload("res://src/client/mesh_buffers.gd")

const RES := 16

## Vector3i -> Color
var voxels := {}
## Vector3i -> true for voxels tinted by the season (leaves).
var foliage := {}


func set_voxel(p: Vector3i, c: Color, is_foliage := false) -> void:
	voxels[p] = c
	if is_foliage:
		foliage[p] = true


## Mesh in voxel units (0..16); scale the instance by 1/16 to fit a cell.
func build_mesh() -> ArrayMesh:
	var faces := ChunkMesher.face_table()
	var buf := MeshBuffers.new()
	var zero_uv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
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
			buf.quad(pts, face.normal, zero_uv, voxels[p], 1.0 if foliage.has(p) else 0.0)
	return buf.to_mesh()

