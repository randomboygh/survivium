extends RefCounted
## The currents of the rivers (decision 178, answer 5А): the water of a river column
## runs along the river (across the slope of its distance from the river's middle,
## `side` of the layout) one way from its source to its mouth, the same all along it,
## downhill from the mountains to the sea (_way). A lake and the sea stand still; so does
## a world without a layout of rivers (the test world: its rivers are none). The bodies
## in a river are carried by it (Body.flow), so are the things lying in its water
## (ActionsBoat.step_drift). Asked column by column, each laid out once (LandLayout.lay_out
## of the three columns across it each way) and kept.
##
## Which way a river runs is found once for the whole river: from the column asked, its
## middle line (where `side` is zero) is followed both ways, STEP cells at a time, to its
## ends (_trace), through the lakes on its way and over gaps shorter than DRY_GAP steps:
## the sea, or where it dries up (its source, or a dead end of it). It runs towards the
## sea; between two ends of a kind, down from the one where its water stands higher, else
## by where they are: only by its ends, so the same from anywhere on it. The way found is
## kept for every BLOCK of cells the line went through, so the next columns of that river
## ask nothing more. The search takes a few layouts a step, so it runs BUDGET_US a frame
## (_follow), one river at a time; till it ends that river stands still (a second or so
## on a phone for a long one).

const LandLayout := preload("res://src/shared/world/land_layout.gd")

## How fast a river runs in its middle, in cells a second, and the share of that at a
## bank, BANK cells from the middle or more.
const SPEED := 2.0
const AT_BANK := 0.5
const BANK := 6.0
## How far up and down the river the way to its mouth is looked for where its ends are
## too far to find (see _way), in cells.
const LOOK := 128.0
## Columns kept at most; then the cache starts again.
const KEEP := 4096
## Following a river's middle line to its ends (_trace): cells a step, steps at most each
## way; the way found is kept by squares of BLOCK cells, at most KEEP_WAYS of them.
const STEP := 32.0
const TRACE := 40
const BLOCK := 16
const KEEP_WAYS := 8192
## Steps in a row with no water there that end a river: a shorter gap is bridged.
const DRY_GAP := 3
## Microseconds a frame spent looking for the ends of rivers (a step is a few layouts of
## two by two columns: about 0.2 ms on a desktop, ten times that in a phone's browser).
const BUDGET_US := 1500
## What a river's end is, by how much its water wants to go there (_trace).
const DRIES := 0
const UNKNOWN := 1
const INTO_SEA := 2

## The world's generator (a LandLayout), null for none: no currents.
var gen
## Microseconds a frame the ends of rivers may be looked for (see _way); tests and tools
## that ask in one frame give more.
var budget_us := BUDGET_US
var _kept := {}
## Which way the river runs (see _way) by squares of BLOCK cells on its middle line.
var _ways := {}
## Columns of a river whose way is being found: [along, its current that way, the square
## of the river's line its way is kept by, the probe there (_probe)].
var _waiting := {}
## The river being followed to its ends: {"key", "ahead", "behind"} (traces, see
## _trace_step), {} for none.
var _job := {}
## The frame the budget was last spent in, and how much of it.
var _frame := -1
var _spent := 0


func _init(g = null) -> void:
	gen = g


## The current at column x, z, in cells a second (x east, y south): zero off a river, and
## for a moment on one whose ends are still being looked for.
func at(x: int, z: int) -> Vector2:
	var col := Vector2i(x, z)
	if _kept.has(col):
		return _kept[col]
	var v := Vector2.ZERO
	if _waiting.has(col):
		var w: Array = _waiting[col]
		if not _ways.has(w[2]):
			_follow(w[2], w[3])
			if not _ways.has(w[2]):
				return Vector2.ZERO
		_waiting.erase(col)
		v = _aimed(w[0], w[1], _ways[w[2]], col)
	else:
		v = _lay(x, z)
		if _waiting.has(col):
			return Vector2.ZERO
	if _kept.size() >= KEEP:
		_kept.clear()
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
	var speed := SPEED * lerpf(1.0, AT_BANK, clampf(float(row.river[1]) / BANK, 0.0, 1.0))
	var here := _probe(Vector2(x + 0.5, z + 0.5))
	if here.is_empty():
		return _aimed(along, speed, 0, Vector2i(x, z))
	var key := _block(here.at)
	if not _ways.has(key):
		_follow(key, here)
		if not _ways.has(key):
			_waiting[Vector2i(x, z)] = [along, speed, key, here]
			return Vector2.ZERO
	return _aimed(along, speed, _ways[key], Vector2i(x, z))


## The current `speed` along `along` the way `way` (1 along, -1 against); with way 0 (its
## ends not found) downstream is the way the distance to the sea or a lake falls, looked
## at LOOK cells up and down the river from column `col`.
func _aimed(along: Vector2, speed: float, way: int, col: Vector2i) -> Vector2:
	if way == 0:
		var mid := Vector2(col) + Vector2(0.5, 0.5)
		var ahead := mid + along * LOOK
		var behind := mid - along * LOOK
		way = -1 if _mouth_at(floori(ahead.x), floori(ahead.y)) > _mouth_at(floori(behind.x), floori(behind.y)) else 1
	return along * way * speed


## Follows the river of square `key` (its line there probe `here`) to its ends, or goes
## on with the one being followed, within the frame's budget: one river at a time, the
## others wait their turn. Once both ends are found the way (_way) is kept for every
## square its line went through.
func _follow(key: Vector2i, here: Dictionary) -> void:
	if _job.is_empty():
		_job = {"key": key, "ahead": _trace_start(here, 1.0), "behind": _trace_start(here, -1.0)}
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_spent = 0
	var t0 := Time.get_ticks_usec()
	while _spent + (Time.get_ticks_usec() - t0) < budget_us:
		var trace: Dictionary = _job.ahead if not _job.ahead.done else _job.behind
		if trace.done:
			break
		_trace_step(trace)
	_spent += Time.get_ticks_usec() - t0
	if not (_job.ahead.done and _job.behind.done):
		return
	var way: int = _job.ahead.get("found", _job.behind.get("found", _way(_job.ahead, _job.behind)))
	if _ways.size() >= KEEP_WAYS:
		_ways.clear()
	_ways[_job.key] = way
	for q: Vector2 in _job.ahead.path + _job.behind.path:
		_ways[_block(q)] = way
	_job = {}


## Which way the river runs from its two ends found, `ahead` along its tangent (_probe)
## and `behind` against it: 1 along, -1 against, 0 when it cannot be told.
func _way(ahead: Dictionary, behind: Dictionary) -> int:
	var a: Vector2 = ahead.last
	var b: Vector2 = behind.last
	if ahead.end != behind.end:
		return 1 if ahead.end > behind.end else -1
	if ahead.level != behind.level:
		return 1 if ahead.level < behind.level else -1
	if ahead.end == UNKNOWN:
		# Its ends too far to find: the way the distance to the sea or a lake falls
		# between the farthest points reached.
		var fa := _mouth_at(floori(a.x), floori(a.y))
		var fb := _mouth_at(floori(b.x), floori(b.y))
		if fa == fb:
			return 0
		return 1 if fa < fb else -1
	# Two ends alike at one height: by where they are, the same from anywhere on it.
	return 1 if a.x < b.x or (a.x == b.x and a.y < b.y) else -1


## A trace of the middle line of the river from probe `from` the way `dir` (1 along its
## tangent, -1 against it), stepped by _trace_step to its end: {"end": INTO_SEA, DRIES
## (its water gone) or UNKNOWN (not reached in TRACE steps, or the line lost where the
## river's noise is flat), "last": the last point with water, "level": its water's level
## there, "path": the points passed, "done"; "found": the way kept for a stretch of the
## river followed before, where it came to one}.
func _trace_start(from: Dictionary, dir: float) -> Dictionary:
	return {"p": from.at, "t": from.tangent * dir, "dir": dir, "dry": 0, "steps": 0, "done": false,
		"end": UNKNOWN, "last": from.at, "level": int(from.water), "path": []}


## One step of trace `tr` (see _trace_start), STEP cells on along the line, through the
## lakes on the way and over gaps of less than DRY_GAP steps.
func _trace_step(tr: Dictionary) -> void:
	var t: Vector2 = tr.t
	var next := _probe(tr.p + t * STEP)
	tr.steps += 1
	if next.is_empty() or (next.tangent as Vector2).dot(t) * tr.dir < 0.0:
		tr.done = true
		return
	tr.p = next.at
	tr.t = next.tangent * tr.dir
	var key := _block(next.at)
	if _ways.has(key):
		# A stretch of the river already followed: its way, so the river runs one way.
		tr.found = _ways[key]
		tr.done = true
		return
	tr.path.append(next.at)
	if int(next.feature) == LandLayout.OCEAN:
		tr.end = INTO_SEA
		tr.last = next.at
		tr.level = int(next.water)
		tr.done = true
		return
	if int(next.water) < 0:
		tr.dry += 1
		if tr.dry >= DRY_GAP:
			tr.end = DRIES
			tr.done = true
	else:
		tr.dry = 0
		tr.last = next.at
		tr.level = int(next.water)
	if tr.steps >= TRACE:
		tr.done = true


## The river's middle line near point `p`: {"at": the point on it, "tangent": the way
## along it (across the slope of `side`, the same way all along one river), "feature":
## OCEAN where any of the two by two columns there is the sea, "water": the highest
## water of a river or a lake on them (-1 for none)}; {} where the river's noise is flat.
## Laid out again on the line when `p` is off it by more than a cell.
func _probe(p: Vector2) -> Dictionary:
	var out := {}
	for i in 2:
		var lay: Dictionary = gen.lay_out(floori(p.x), floori(p.y), 2, 2)
		var side: PackedFloat32Array = lay.side
		if absf(side[0]) >= 1e5 or absf(side[1]) >= 1e5 or absf(side[2]) >= 1e5:
			return {}
		var g := Vector2(side[1] - side[0], side[2] - side[0])
		if g.length_squared() < 1e-8:
			return {}
		var on := Vector2(floori(p.x) + 0.5, floori(p.y) + 0.5) - g * side[0] / g.length_squared()
		var feature := LandLayout.DRY
		var water := -1
		for j in 4:
			match int(lay.feature[j]):
				LandLayout.OCEAN:
					feature = LandLayout.OCEAN
				LandLayout.RIVER, LandLayout.LAKE:
					water = maxi(water, lay.water[j])
		out = {"at": on, "tangent": Vector2(-g.y, g.x).normalized(), "feature": feature, "water": water}
		if absf(side[0]) <= 1.0:
			return out
		p = on
	return out


func _block(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / BLOCK), floori(p.y / BLOCK))


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
