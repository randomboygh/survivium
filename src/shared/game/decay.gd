extends RefCounted
## Buildings outside anyone's land decay where nobody comes (plan/mvp.md stage 2 item 5,
## decision 186; the user's picks of 2026-11-19). The world is tended by chunks: a chunk
## within TEND_REACH cells of a living player, or holding a square of any claim
## (Territory), is tended now (`tended`, game days of `time`); a claim let go to nobody
## leaves its chunks to decay from then on. In a chunk left alone, each built cell (one
## the player set, not the generator's: not WILD) of a material with `decay` (its YAML
## field: wattle faster, wood as is, stone and brick at half the pace; the ground, trees
## and ores never) goes a stage further for every Rules.building_decay_days / decay game
## days of neglect: first it cracks (`cracked`), then it falls to a ruin (`crumble`, a
## later step of the work). A player coming back stops the clock but leaves the cracks:
## those are mended by hand. The cells are worked through a chunk at a time, a few
## columns a step (SCAN_COLUMNS), only the edited chunks (WorldData's `edited`, kept in
## memory however far), so nothing chunk-sized runs in one step. Time is the world's
## running (game days of the clock, `step`): a stopped server decays nothing. The world's
## own switch is `on` (single player: the «New game» screen's row), the server's
## Rules.building_decay.

const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")

## Cells that cracked (true) or were mended or are gone (false), for the clients.
signal cracks_changed(cells: Array[Vector3i], on: bool)

const CELL := WorldData.CELL
const CHUNK := WorldData.CHUNK
## Cells round a living player within which the chunks are tended.
const TEND_REACH := 16
## Seconds between looks at the players, the claims and the chunks due.
const LOOK_EVERY := 2.0
## Edited chunks looked at in one look for one whose stage is due.
const CHUNKS_PER_LOOK := 32
## Columns of a chunk worked through in a step.
const SCAN_COLUMNS := 32

## The world's own switch (a world made with building decay off keeps it off).
var on := true
var world
var rules
var territory
## Game days the world has run while decay was on.
var time := 0.0
## Chunk (Vector2i) -> the day (`time`) it was last tended.
var tended := {}
## Chunk -> the neglect (days) it was worked through for last, 0 when tended since.
var passed := {}
## Cracked cell (Vector3i) -> its material then, -1 when not known yet (from a save,
## before its chunk is there): a cell built anew in its place is not cracked.
var cracked := {}
var _wait := 0.0
var _order: Array[Vector2i] = []
var _next := 0
## Chunks worked through and found with nothing that decays: passed by until a player
## is near again (who else builds there).
var bare := {}
## The chunk being worked through: {key, col, age, prev}; empty for none.
var _job := {}
## The paces of decay of the materials (Mat.decays, those above 0), to see a stage due.
var _paces: PackedFloat32Array = []


## `days` of the game and `seconds` of the world's running go by: the chunks near the
## living players and in the claims are tended, a chunk whose stage is due is worked
## through a few columns at a time.
func step(days: float, players: Array, seconds: float) -> void:
	if not active():
		return
	time += days
	_wait -= seconds
	if _wait <= 0.0:
		_wait = LOOK_EVERY
		tend(players)
		if _job.is_empty():
			_look()
	if not _job.is_empty():
		_scan()


## Whether buildings decay in this world now.
func active() -> bool:
	return on and world != null and rules != null and rules.building_decay


## The chunks near the living players of `players`, and those holding a claim's square,
## are tended now.
func tend(players: Array) -> void:
	for p in players:
		if p.is_dead():
			continue
		var at: Vector3 = p.position / CELL
		var lo := WorldData.chunk_key(floori(at.x) - TEND_REACH, floori(at.z) - TEND_REACH)
		var hi := WorldData.chunk_key(floori(at.x) + TEND_REACH, floori(at.z) + TEND_REACH)
		for cz in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				_tend(Vector2i(cx, cz))
	if territory != null:
		var seen := {}
		for sq: Vector2i in territory.squares:
			# A square is 2 by 2 cells, a chunk 8 by 8 squares.
			var key := Vector2i(sq.x >> 3, sq.y >> 3)
			if not seen.has(key):
				seen[key] = true
				_tend(key)


func _tend(key: Vector2i) -> void:
	# Only built-on chunks are kept: one built on later is seen first with its builder there.
	var c = world.chunks.get(key)
	if c == null or not c.edited:
		return
	tended[key] = time
	passed[key] = 0.0
	bare.erase(key)
	if not _job.is_empty() and _job.key == key:
		_job = {}


## Looks at a few edited chunks in turn for one whose stage is due, and starts working
## it through. A chunk first seen starts its neglect now.
func _look() -> void:
	if _next >= _order.size():
		_order.clear()
		for key: Vector2i in world.chunks:
			if world.chunks[key].edited:
				_order.append(key)
		_next = 0
		_paces = PackedFloat32Array()
		for pace in Mat.decays:
			if pace > 0.0 and not _paces.has(pace):
				_paces.append(pace)
	var stop := mini(_next + CHUNKS_PER_LOOK, _order.size())
	while _next < stop:
		var key := _order[_next]
		_next += 1
		var c = world.chunks.get(key)
		if c == null or not c.edited or bare.has(key):
			continue
		if not tended.has(key):
			tended[key] = time
			passed[key] = 0.0
			continue
		var age := time - float(tended[key])
		var prev := float(passed.get(key, 0.0))
		if _due(age, prev):
			_job = {"key": key, "col": 0, "age": age, "prev": prev, "some": false}
			return


## Whether a material of any pace goes a stage further between neglect `prev` and `age`.
func _due(age: float, prev: float) -> bool:
	var each: float = rules.building_decay_days
	for pace in _paces:
		if floori(age * pace / each) > floori(prev * pace / each):
			return true
	return false


## Stages a cell of `pace` goes further between neglect `prev` and `age`.
func stages(pace: float, age: float, prev: float) -> int:
	if pace <= 0.0:
		return 0
	var each: float = rules.building_decay_days
	return floori(age * pace / each) - floori(prev * pace / each)


## Works SCAN_COLUMNS columns of the job's chunk through: each built cell of a material
## that decays goes its stages further (an intact one cracks; a cracked one is due to
## fall, the step of the ruins).
func _scan() -> void:
	var key: Vector2i = _job.key
	var c = world.chunks.get(key)
	if c == null:
		_job = {}
		return
	var age: float = _job.age
	var prev: float = _job.prev
	var from: int = _job.col
	var to := mini(from + SCAN_COLUMNS, CHUNK * CHUNK)
	var top: int = world.size_y
	var all_levels := (1 << top) - 1 if top < 63 else -1
	var cracks: Array[Vector3i] = []
	for col in range(from, to):
		# Built: not air, not water, not left by the generator.
		var bits: int = ~(c.air[col] | c.water[col] | c.wild[col]) & all_levels
		while bits != 0:
			var low := bits & -bits
			bits &= ~low
			var y := _level(low)
			var m: int = c.cells[(y << 8) | col]
			if m >= Mat.decays.size():
				continue
			if Mat.decays[m] <= 0.0:
				continue
			_job.some = true
			var n := stages(Mat.decays[m], age, prev)
			if n <= 0:
				continue
			var cell := Vector3i(key.x * CHUNK + (col & (CHUNK - 1)), y, key.y * CHUNK + (col >> WorldData.SHIFT))
			if territory != null and not territory.claim_at(cell).is_empty():
				continue
			var was: int = cracked.get(cell, -2)
			if was != m and was != -1:
				cracked[cell] = m
				cracks.append(cell)
				n -= 1
			elif was == -1:
				cracked[cell] = m
			# What is left of `n` is the cell falling to a ruin: the next step of the work.
	if not cracks.is_empty():
		cracks_changed.emit(cracks, true)
	if to >= CHUNK * CHUNK:
		passed[key] = age
		if not _job.some:
			bare[key] = true
		_job = {}
	else:
		_job.col = to


## The level of the one bit set in `bit`.
static func _level(bit: int) -> int:
	var y := 0
	if bit & 0xFFFFFFFF == 0:
		y += 32
		bit >>= 32
	if bit & 0xFFFF == 0:
		y += 16
		bit >>= 16
	if bit & 0xFF == 0:
		y += 8
		bit >>= 8
	if bit & 0xF == 0:
		y += 4
		bit >>= 4
	if bit & 0x3 == 0:
		y += 2
		bit >>= 2
	if bit & 0x1 == 0:
		y += 1
	return y


## Whether cell `cell` is cracked now (its material the one that cracked).
func is_cracked(cell: Vector3i) -> bool:
	var was: int = cracked.get(cell, -2)
	if was == -2:
		return false
	return was == -1 or world == null or world.get_cell(cell.x, cell.y, cell.z) == was


## Cell `cell` changed (dug, built over, mended): its crack is gone.
func cell_changed(cell: Vector3i) -> void:
	if cracked.erase(cell):
		var one: Array[Vector3i] = [cell]
		cracks_changed.emit(one, false)


## Cells `cells` changed at once (a blueprint, a felled tree).
func cells_set(cells: Array[Vector3i]) -> void:
	var gone: Array[Vector3i] = []
	for cell in cells:
		if cracked.erase(cell):
			gone.append(cell)
	if not gone.is_empty():
		cracks_changed.emit(gone, false)


## What the save keeps (world.json "decay").
func to_dict() -> Dictionary:
	var t: Array = []
	for key: Vector2i in tended:
		t.append([key.x, key.y, snappedf(float(tended[key]), 0.001), snappedf(float(passed.get(key, 0.0)), 0.001)])
	var cells: Array = []
	for cell: Vector3i in cracked:
		if is_cracked(cell):
			cells.append_array([cell.x, cell.y, cell.z])
	return {"on": on, "time": snappedf(time, 0.001), "tended": t, "cracked": cells}


func from_dict(d: Dictionary) -> void:
	on = bool(d.get("on", true))
	time = float(d.get("time", 0.0))
	tended.clear()
	passed.clear()
	bare.clear()
	cracked.clear()
	_job = {}
	_order.clear()
	_next = 0
	var t: Variant = d.get("tended")
	if t is Array:
		for e: Variant in t:
			if e is Array and e.size() >= 4:
				var key := Vector2i(int(e[0]), int(e[1]))
				tended[key] = float(e[2])
				passed[key] = float(e[3])
	var cells: Variant = d.get("cracked")
	if cells is Array:
		for i in range(0, cells.size() - 2, 3):
			cracked[Vector3i(int(cells[i]), int(cells[i + 1]), int(cells[i + 2]))] = -1
