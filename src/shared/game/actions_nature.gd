extends "res://src/shared/game/actions_farm.gd"
## Nature on its own (plan/backlog.md; decision 178, answers 1В and 2Б): day by day in the
## warm seasons (not in winter) each chunk the server holds grows back and spreads a
## little, the same on claimed land as anywhere. Bare natural ground beside grass grows
## over (where its biome lays grass); a bush now and then puts a new one of its kind
## beside it; a grown tree's seed now and then takes root on open ground near it, a
## sapling (ActionsFarm) that grows into the same species. So a felled wood comes back
## from the trees left at its edge, a dug-out bush from its neighbours. The chances are
## a year's (GRASS_BACK, BUSH_SEED, TREE_SEED), shared out over its warm days.
##
## A chunk keeps the count of warm days it has grown for (Chunk.grown, saved with it): one
## the clock has passed a warm day since (Clock.warm_days) is worked again, a row of
## columns at a time, one chunk after another (step_nature), with the chances of all the
## days it missed (at most CATCH_UP_DAYS), so a chunk made again after a long time away
## catches up at once. A chunk first made, or saved before this, starts from today.

const BiomesData := preload("res://src/shared/content/biomes.gd")
const ClockScript := preload("res://src/shared/game/clock.gd")

## Seconds between two rows of columns worked (each NATURE_ROWS rows of a chunk).
const NATURE_EVERY := 0.1
## The chance a bare natural ground cell beside grass grows over in a year.
const GRASS_BACK := 0.6
## The chance a bush puts a new one beside it in a year, and how far, in cells.
const BUSH_SEED := 0.15
const BUSH_REACH := 3
## The chance a grown tree's seed takes root near it in a year, how far (in cells), and
## how many columns round the spot must be free of trunks.
const TREE_SEED := 0.12
const TREE_REACH := 7
const TREE_ROOM := 3
## Tries to find a spot for a bush's or a tree's seed.
const SEED_TRIES := 4
## A level no ground has (see _ground_top).
const NO_GROUND := -(1 << 20)
## The warm days of a year (spring, summer and autumn), over which its chances are
## shared, and the most days a chunk catches up at once.
const WARM_DAYS := ClockScript.DAYS_PER_SEASON * 3.0
const CATCH_UP_DAYS := WARM_DAYS

## The chunk being worked and its next row (see step_nature); the chunks still to look at.
var _nature_key := Vector2i.ZERO
var _nature_row := -1
var _nature_keys: Array = []
var _nature_wait := 0.0
## The share of a year the chunk being worked grows for (its warm days missed / WARM_DAYS).
var _nature_share := 0.0


## Works on the year of nature for `seconds` of play: a row of the chunk being worked
## every NATURE_EVERY, then the next chunk due (see the top).
func step_nature(seconds: float) -> void:
	_nature_wait -= seconds
	if _nature_wait > 0.0:
		return
	_nature_wait = NATURE_EVERY
	if _nature_row < 0:
		_nature_row = 0 if _next_due() else -1
		return
	if not world.chunks.has(_nature_key):
		_nature_row = -1
		return
	regrow_row(_nature_key, _nature_row, _nature_share)
	_nature_row += 1
	if _nature_row >= WorldData.CHUNK:
		_nature_row = -1


## Picks the next chunk due a warm day (see the top) as the one to work, true when there
## is one; looks through the chunks held a few at a time.
func _next_due() -> bool:
	if _nature_keys.is_empty():
		_nature_keys = world.chunks.keys()
	var today: int = clock.warm_days
	var looked := 0
	while not _nature_keys.is_empty() and looked < 64:
		var key: Vector2i = _nature_keys.pop_back()
		looked += 1
		var c = world.chunks.get(key)
		if c == null or not c.final:
			continue
		if c.grown < 0:
			# Made now (or saved before warm days were counted): it starts from today.
			c.grown = today
			continue
		if c.grown < today:
			_nature_share = minf(today - c.grown, CATCH_UP_DAYS) / WARM_DAYS
			c.grown = today
			_nature_key = key
			return true
	return false


## The chance of a thing that happens with chance `year` in a year, over the share of a
## year `share`.
static func chance_over(year: float, share: float) -> float:
	return 1.0 - pow(1.0 - year, share)


## Works `share` of a year (see _nature_share) on row `row` (z within the chunk) of chunk
## `key`: each column's ground on top (see the top of the file).
func regrow_row(key: Vector2i, row: int, share := 1.0) -> void:
	var grass_back := chance_over(GRASS_BACK, share)
	var bush_seed := chance_over(BUSH_SEED, share)
	var tree_seed := chance_over(TREE_SEED, share)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, row, clock.warm_days, clock.day])
	var z := key.y * WorldData.CHUNK + row
	var looks := {}
	for lx in WorldData.CHUNK:
		var x := key.x * WorldData.CHUNK + lx
		var y := _ground_top(x, z)
		if y == NO_GROUND:
			continue
		var cell := Vector3i(x, y, z)
		var m: int = world.get_cell(x, y, z)
		if m == Mat.DIRT and world.is_natural(x, y, z) and _grass_biome(x, z) and _grass_beside(cell) \
				and rng.randf() < grass_back:
			world.set_turf(cell, null)
			world.set_material(x, y, z, Mat.GRASS)
			_changed(cell)
		var up := cell + Vector3i.UP
		if world.bushes.has(up) and rng.randf() < bush_seed:
			var spot: Variant = _bush_spot(up, rng)
			if spot != null:
				Growth.place_bush(world, spot.x, spot.y, spot.z, world.bushes[up])
				world.note_bush(spot)
				looks[WorldData.chunk_key(spot.x, spot.z)] = true
	# The trees whose trunk stands in the row.
	for col: Vector2i in world.tree_chunks.get(key, {}).keys():
		if col.y != z or rng.randf() >= tree_seed:
			continue
		var s: Dictionary = Trees.SPECIES[world.trees[col]] if world.trees[col] < Trees.SPECIES.size() else {}
		if s.is_empty() or s.get("dead", false) or _young_ground(col.x, col.y) != null \
				or world.get_cell(col.x, _ground_top(col.x, col.y) + 1, col.y) != Mat.LOG:
			continue
		var sapling := sapling_of(s.id)
		if sapling == "":
			continue
		var spot: Variant = _tree_spot(col, rng)
		if spot != null:
			world.set_field(spot, [sapling, 0.0, 0.0, s.id])
			world.note_edit(spot.x, spot.z)
			looks[WorldData.chunk_key(spot.x, spot.z)] = true
	for k in looks:
		looks_changed.emit(k)


## The sapling plant a seed of tree species `tree` sprouts as: its own (a sapling whose
## `tree` it is), else one of a species with the same leaves (it looks alike while small);
## "" for none.
static func sapling_of(tree: String) -> String:
	var t := Trees.index(tree)
	if t < 0:
		return ""
	var alike := ""
	for id: String in Plants.BY_ID:
		if not Plants.is_sapling(id):
			continue
		var of: String = Plants.BY_ID[id].get("tree", "")
		if of == tree:
			return id
		var o := Trees.index(of)
		if alike == "" and o >= 0 and Trees.SPECIES[o].leaves == Trees.SPECIES[t].leaves:
			alike = id
	return alike


## The level of the ground on top of column x, z (under the air, leaves and trunks over
## it), NO_GROUND for water there or no ground at all.
func _ground_top(x: int, z: int) -> int:
	var c = world.chunk_at(x, z)
	if c == null:
		return NO_GROUND
	# From the highest cell that is not air (the column's air mask), down.
	var solid: int = ~c.air[world.col_of(x, z)] & world.all_bits
	if solid == 0:
		return NO_GROUND
	var y: int = world.size_y - 1
	while y > 0 and solid & (1 << y) == 0:
		y -= 1
	while y >= 0:
		var m: int = world.get_cell(x, y, z)
		if m == Mat.WATER:
			return NO_GROUND
		if m != Mat.AIR and m != Mat.LEAVES and m != Mat.LOG:
			return y
		y -= 1
	return NO_GROUND


## True where the biome of column x, z lays grass on top (or is not known).
func _grass_biome(x: int, z: int) -> bool:
	var b: int = world.biome_at(x, z)
	return b == WorldData.NO_BIOME or BiomesData.of(b).get("top", "grass") == "grass"


## True when a grass cell is beside ground cell `cell` (a level up or down at most).
func _grass_beside(cell: Vector3i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for dy in [0, 1, -1]:
			if world.get_cell(cell.x + d.x, cell.y + dy, cell.z + d.y) == Mat.GRASS:
				return true
	return false


## An air cell near bush cell `at` where a new bush fits: on grass a level up or down at
## most, with no bush beside it; null for none found.
func _bush_spot(at: Vector3i, rng: RandomNumberGenerator) -> Variant:
	for i in SEED_TRIES:
		var x := at.x + rng.randi_range(-BUSH_REACH, BUSH_REACH)
		var z := at.z + rng.randi_range(-BUSH_REACH, BUSH_REACH)
		var y := _ground_top(x, z)
		if y == NO_GROUND or absi(y + 1 - at.y) > 1 or world.get_cell(x, y, z) != Mat.GRASS:
			continue
		var spot := Vector3i(x, y + 1, z)
		if not Growth.bush_fits(world, spot.x, spot.y, spot.z) or _bush_beside(spot):
			continue
		return spot
	return null


## True when a bush stands in or beside cell `at`.
func _bush_beside(at: Vector3i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if world.bushes.has(at + Vector3i(dx, 0, dz)):
				return true
	return false


## A ground cell near the trunk in column `col` where its seed takes root (see can_root):
## on the trees' lattice, with no trunk within TREE_ROOM columns; null for none found.
func _tree_spot(col: Vector2i, rng: RandomNumberGenerator) -> Variant:
	for i in SEED_TRIES:
		var x := (col.x + rng.randi_range(-TREE_REACH, TREE_REACH)) | 1
		var z := (col.y + rng.randi_range(-TREE_REACH, TREE_REACH)) | 1
		if Vector2i(x, z) == col:
			continue
		var y := _ground_top(x, z)
		if y == NO_GROUND:
			continue
		var cell := Vector3i(x, y, z)
		if Mat.is_bed(world.get_cell(x, y, z)) or not can_root(cell) or _trunk_near(x, z):
			continue
		return cell
	return null


## True when a trunk stands within TREE_ROOM columns of column x, z.
func _trunk_near(x: int, z: int) -> bool:
	for dz in range(-TREE_ROOM, TREE_ROOM + 1):
		for dx in range(-TREE_ROOM, TREE_ROOM + 1):
			if world.trees.has(Vector2i(x + dx, z + dz)):
				return true
	return false
