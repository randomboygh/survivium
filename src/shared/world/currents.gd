extends RefCounted
## The currents of the rivers (decision 178, answer 5А): the water of a river column
## runs along the river (across the slope of its distance from the river's middle,
## `side` of the layout) and down to the sea or the lake it flows into (the way the
## distance to the nearest of them falls). A lake and the sea stand still; so does a
## world without a layout of rivers (the test world: its rivers are none). The bodies in
## a river are carried by it (Body.flow), so are the things lying in its water
## (ActionsBoat.step_drift). Asked column by column, each laid out once (LandLayout.lay_out
## of the three columns across it each way) and kept.

const LandLayout := preload("res://src/shared/world/land_layout.gd")

## How fast a river runs in its middle, in cells a second, and the share of that at a
## bank, BANK cells from the middle or more.
const SPEED := 2.0
const AT_BANK := 0.5
const BANK := 6.0
## How far up and down the river the way to its mouth is looked for, in cells.
const LOOK := 128.0
## Columns kept at most; then the cache starts again.
const KEEP := 4096

## The world's generator (a LandLayout), null for none: no currents.
var gen
var _kept := {}


func _init(g = null) -> void:
	gen = g


## The current at column x, z, in cells a second (x east, y south): zero off a river.
func at(x: int, z: int) -> Vector2:
	var col := Vector2i(x, z)
	if _kept.has(col):
		return _kept[col]
	if _kept.size() >= KEEP:
		_kept.clear()
	var v := _lay(x, z)
	_kept[col] = v
	return v


## The current at world point `p` (world units), in cells a second.
func at_point(p: Vector3, cell: float) -> Vector2:
	return at(floori(p.x / cell), floori(p.z / cell))


func _lay(x: int, z: int) -> Vector2:
	if gen == null:
		return Vector2.ZERO
	var row: Dictionary = gen.lay_out(x - 1, z, 3, 1)
	if row.feature[1] != LandLayout.RIVER:
		return Vector2.ZERO
	var col: Dictionary = gen.lay_out(x, z - 1, 1, 3)
	for s: float in [row.side[0], row.side[2], col.side[0], col.side[2]]:
		if absf(s) >= 1e5:
			# The river noise is flat here: no way to tell which way it runs.
			return Vector2.ZERO
	# Along the river: across the slope of the distance from its middle.
	var across := Vector2(row.side[2] - row.side[0], col.side[2] - col.side[0])
	if across.length() < 1e-4:
		return Vector2.ZERO
	var along := Vector2(-across.y, across.x).normalized()
	# Downstream: the way the distance to the sea or a lake falls, looked at LOOK cells
	# up and down the river, so a bend does not turn it back. (Where a river comes near
	# the sea and turns away again it may run two ways from there, or meet itself:
	# what it carries then stays at that spot.)
	var ahead := Vector2(x + 0.5, z + 0.5) + along * LOOK
	var behind := Vector2(x + 0.5, z + 0.5) - along * LOOK
	if _mouth_at(floori(ahead.x), floori(ahead.y)) > _mouth_at(floori(behind.x), floori(behind.y)):
		along = -along
	var share := lerpf(1.0, AT_BANK, clampf(float(row.river[1]) / BANK, 0.0, 1.0))
	return along * SPEED * share


## How far column x, z is from the sea or a lake, in cells (only the slow noises of the
## layout: LandLayout._lattice_row).
func _mouth_at(x: int, z: int) -> float:
	var lay: Dictionary = gen._window(x, z, 1, 1)
	gen._lattice(lay)
	gen._lattice_row(lay, 0)
	return _mouth(lay, 0)


## How far column j of laid-out window `lay` is from the sea or a lake, in cells.
static func _mouth(lay: Dictionary, j: int) -> float:
	return minf(lay.coast[j], -lay.lake[j])
