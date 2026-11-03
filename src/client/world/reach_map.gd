extends RefCounted
## The open cells the player can reach round them, for the view in a sphere (setting
## «Вид в пещере» → «сфера», CaveSphere): only the cave they stand in opens inside the
## sphere; another cave behind solid rock stays rock. A flood of the open cells (air,
## water, leaves) from the player's feet and head, within REACH_SCALE times the
## sphere's radius. One texel per column of a SIZE square: 32 bits, eight in each of r,
## g, b, a, for the levels from the corner's up; the shader global reach_origin =
## (x, base level, z) of its corner (reached_cell in common.gdshaderinc). Made again a
## few rows, then a few hundred columns of the flood, a frame, when the player steps to
## another cell or a cell in it changes; the old one shows meanwhile.

const SIZE := 32
const LEVELS := 32
const ROWS_PER_FRAME := 8
## Columns of the flood worked a frame.
const FLOOD_PER_FRAME := 400
## The sphere is round on the screen; in the world it leans along the view and reaches
## about this much farther.
const REACH_SCALE := 1.5

var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
var texture: ImageTexture
## The corner in force: (x, base level, z).
var origin := Vector3i(0, -1000, 0)
## The player's feet cell and the radius in cells the map in force (or being made) is
## for; a change starts it again.
var _for := Vector3i(0, -1000, 0)
var _radius := 0
var _dirty := true
var _next := Vector3i.ZERO
## The open levels of each column, within the reach, and those reached.
var _open := PackedInt64Array()
var _reached := PackedInt64Array()
var _queue: Array[int] = []
## The next row being read, SIZE once the flood runs, -1 when nothing is being made.
var _row := -1


func _init() -> void:
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("reach_map", texture)
	RenderingServer.global_shader_parameter_set("reach_origin", Vector3(origin))
	_open.resize(SIZE * SIZE)
	_reached.resize(SIZE * SIZE)


## Called every frame the sphere is on, with the player's feet cell and the sphere's
## radius in cells.
func update(w, feet: Vector3i, radius: int) -> void:
	# A changed cell waits for the map being made (cells change often: plants grow).
	if feet != _for or radius != _radius or (_dirty and _row < 0):
		_for = feet
		_radius = radius
		_dirty = false
		_next = Vector3i(feet.x - SIZE / 2, feet.y + 1 - LEVELS / 2, feet.z - SIZE / 2)
		_row = 0
	if _row < 0:
		return
	if _row < SIZE:
		_read_rows(w)
		if _row == SIZE:
			_seed()
		return
	_flood()


## A cell changed: the map is made again if it holds it.
func touch(cell: Vector3i) -> void:
	var d := cell - _for
	if absi(d.x) <= SIZE / 2 and absi(d.z) <= SIZE / 2 and absi(d.y) <= LEVELS / 2:
		_dirty = true


func _read_rows(w) -> void:
	var reach: float = _radius * REACH_SCALE + 1.0
	var mid := _for - _next + Vector3i(0, 1, 0)
	var end := mini(_row + ROWS_PER_FRAME, SIZE)
	for r in range(_row, end):
		for c in SIZE:
			var x := _next.x + c
			var z := _next.z + r
			var h2 := float((c - mid.x) * (c - mid.x) + (r - mid.z) * (r - mid.z))
			var bits := 0
			if h2 <= reach * reach:
				var half := floori(sqrt(reach * reach - h2))
				var lo := maxi(mid.y - half, 0)
				var hi := mini(mid.y + half, LEVELS - 1)
				if hi >= lo:
					var span := ((1 << (hi - lo + 1)) - 1) << lo
					var open: int = w.air_col(x, z) | w.water_col(x, z) | w.leaf_col(x, z)
					open = (open >> _next.y) if _next.y >= 0 else (open << -_next.y)
					bits = open & span
			_open[r * SIZE + c] = bits
			_reached[r * SIZE + c] = 0
	_row = end


## The flood starts from the player's feet and head.
func _seed() -> void:
	_queue.clear()
	var k := (_for.z - _next.z) * SIZE + (_for.x - _next.x)
	var y := _for.y - _next.y
	var start := ((1 << y) | (1 << (y + 1))) & _open[k]
	if start == 0:
		# Standing in a cell the map counts as closed (a slope, a step): its open
		# neighbour above starts it.
		start = (1 << (y + 1)) & _open[k]
	_reached[k] = start
	if start != 0:
		_queue.append(k)


func _flood() -> void:
	var n := 0
	while not _queue.is_empty() and n < FLOOD_PER_FRAME:
		n += 1
		var k: int = _queue.pop_back()
		var open: int = _open[k]
		var x: int = _reached[k]
		# Up and down the column through open cells.
		while true:
			var grown := x | (((x << 1) | (x >> 1)) & open)
			if grown == x:
				break
			x = grown
		_reached[k] = x
		var c := k % SIZE
		var r := k / SIZE
		for nb: int in [k - 1 if c > 0 else -1, k + 1 if c < SIZE - 1 else -1,
				k - SIZE if r > 0 else -1, k + SIZE if r < SIZE - 1 else -1]:
			if nb < 0:
				continue
			var add := x & _open[nb] & ~_reached[nb]
			if add != 0:
				_reached[nb] |= add
				_queue.append(nb)
	if not _queue.is_empty():
		return
	_row = -1
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 4)
	for k in SIZE * SIZE:
		var b: int = _reached[k]
		data[k * 4] = b & 255
		data[k * 4 + 1] = (b >> 8) & 255
		data[k * 4 + 2] = (b >> 16) & 255
		data[k * 4 + 3] = (b >> 24) & 255
	image.set_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	texture.update(image)
	origin = _next
	RenderingServer.global_shader_parameter_set("reach_origin", Vector3(origin))


## Whether `cell` was reached by the map in force.
func reached(cell: Vector3i) -> bool:
	var d := cell - origin
	if d.x < 0 or d.z < 0 or d.x >= SIZE or d.z >= SIZE or d.y < 0 or d.y >= LEVELS:
		return false
	return (_texel(d.x, d.z) >> d.y) & 1 != 0


func _texel(c: int, r: int) -> int:
	var col := image.get_pixel(c, r)
	return col.r8 | (col.g8 << 8) | (col.b8 << 16) | (col.a8 << 24)
