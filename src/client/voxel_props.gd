extends RefCounted
## Voxel models of the prototype props. Placeholder until the voxel editor exists.

const VoxelModel := preload("res://src/client/voxel_model.gd")
const RES := VoxelModel.RES


static func chest() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.55, 0.36, 0.2)
	var band := Color(0.35, 0.22, 0.12)
	var metal := Color(0.8, 0.68, 0.35)
	for y in range(0, 10):
		for z in range(4, 12):
			for x in range(2, 14):
				var c := wood
				if x == 2 or x == 13 or y == 0 or y == 9 or y == 6 or z == 4 or z == 11:
					c = band
				if (y + x) % 5 == 0 and c == wood:
					c = wood * 0.9
				m.set_voxel(Vector3i(x, y, z), c)
	for y in range(4, 8):
		for x in range(7, 9):
			m.set_voxel(Vector3i(x, y, 12), metal)
	return m
