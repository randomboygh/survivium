extends "res://tests/unit/test_case.gd"
## The index of the things set down (Placed: `_at`, `_chunks`, `fires`, `beds`, `seated`,
## GAME-2): after things come and go (set down, taken up, moved, burnt down, fallen apart,
## a save read back, the mods read anew) what stands at a cell or near a point is the same
## as a look over every thing of the world finds.

const Warmth := preload("res://src/shared/game/warmth.gd")

## The kinds set down, spread over several chunks of the index.
const KINDS := ["tools:fence", "core:campfire", "tools:workbench", "tools:stool", "tools:wooden_bed",
	"tools:grass_mat", "tools:chest", "tools:door", "tools:wooden_bench", "tools:fur_bedroll", "tools:door_2x2",
	"tools:door_2x3", "tools:gate"]


func run() -> void:
	var w := _flat()
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	var rng := RandomNumberGenerator.new()
	rng.seed = 952
	var taken := {}
	for i in 140:
		var item: String = KINDS[i % KINDS.size()]
		var n := Placed.size_of(item)
		var cell := Vector3i(rng.randi_range(0, 60 - n), 1, rng.randi_range(0, 60 - n))
		if _overlaps(taken, cell, n):
			continue
		for dz in n:
			for dx in n:
				taken[cell + Vector3i(dx, 0, dz)] = true
		placed.put(item, cell, null, true, -1.0, null, rng.randi_range(0, 3), Items.get_item(item).get("door", false) and rng.randf() < 0.5)
	for i in 20:
		var cell := Vector3i(rng.randi_range(0, 63), 1, rng.randi_range(0, 63))
		if not taken.has(cell):
			taken[cell] = true
			placed.put_light("tools:torch", cell)
	_check(placed.things.size() > 60 and not placed.fires.is_empty() and not placed.beds.is_empty()
		and not placed.seated.is_empty(), "things of every kind are set down: %d" % placed.things.size())
	_compare(placed, rng, "set down")

	# Some go: burnt down, fallen apart, taken out; a light burns out.
	for i in range(placed.things.size() - 1, -1, -3):
		placed._remove(placed.things[i])
	placed.fall_apart(placed.things[0])
	placed._remove(placed.lights[0])
	_compare(placed, rng, "some taken out")

	# Read back from the save, into a new copy.
	var copy := Placed.new()
	copy.world = _flat()
	copy.read_footprints()
	copy.from_list(placed.to_list())
	_check(copy.things.size() == placed.things.size() and copy.fires.size() == placed.fires.size()
		and copy.beds.size() == placed.beds.size(), "a save read back has the same index")
	_compare(copy, rng, "read back")

	# The mods read anew: the index is built again from the things.
	copy.read_footprints()
	_compare(copy, rng, "the mods read anew")

	# Moved: a thing set down somewhere else is found there, not where it stood.
	var e: Dictionary = copy.things[-1]
	var item: String = e.item
	copy._remove(e)
	var moved := copy.put(item, Vector3i(70, 1, 70))
	_check(copy.at(Vector3i(70, 1, 70)) == moved and not copy.things.has(e),
		"a thing moved is found where it stands now")
	_compare(copy, rng, "moved")
	_check(copy.at(Vector3i(79, 1, 79)).is_empty() and copy.near(Vector2i(78, 78), Vector2i(79, 79)).is_empty(),
		"nothing is found where nothing stands")


func _flat() -> WorldData:
	var w := WorldData.new(40, Vector2i(80, 80))
	for z in 80:
		for x in 80:
			w.set_cell(x, 0, z, Mat.STONE)
	return w


func _overlaps(taken: Dictionary, cell: Vector3i, n: int) -> bool:
	for dz in n:
		for dx in n:
			if taken.has(cell + Vector3i(dx, 0, dz)):
				return true
	return false


## The questions the rules ask, by the index and by a look over every thing, at many cells
## and points: the answers must be the same.
func _compare(placed: Placed, rng: RandomNumberGenerator, when: String) -> void:
	var bad := []
	var doors := 0
	for e: Dictionary in placed.things + placed.lights:
		if placed.at(e.cell) != _at(placed, e.cell):
			bad.append(["at", e.cell])
		if Placed.is_light(e):
			continue
		# Every cell of its square, and the points round its middle.
		var n := Placed.size_of(e.item)
		for dz in n:
			for dx in n:
				var cell: Vector3i = e.cell + Vector3i(dx, 0, dz)
				if placed._shut_door_on(cell) != _shut_door_on(placed, cell):
					bad.append(["_shut_door_on", cell])
				if placed._in_open_door(cell) != _in_open_door(placed, cell):
					bad.append(["_in_open_door", cell])
				if placed._in_open_door(cell) or not placed._shut_door_on(cell).is_empty():
					doors += 1
		for o: Vector3 in [Vector3.ZERO, Vector3(0.9, 0.0, 0.3), Vector3(-1.2, 0.4, 0.8), Vector3(0.2, 0.0, -2.5)]:
			var p := Placed.center(e) + o * WorldData.CELL
			p.y = (e.cell.y + o.y) * WorldData.CELL
			for reach: float in [0.6, 1.5, 3.0]:
				if placed.stations_near(p, reach * WorldData.CELL) != _stations_near(placed, p, reach * WorldData.CELL):
					bad.append(["stations_near", p, reach])
			if placed.burning(p) != _burning(placed, p):
				bad.append(["burning", p])
			if placed.seat_near(p) != _seat_near(placed, p):
				bad.append(["seat_near", p])
			if placed.bed_under(p) != _bed_under(placed, p):
				bad.append(["bed_under", p])
	_check(doors > 0, "%s: doors open and shut are asked of: %d cells" % [when, doors])
	for i in 400:
		var cell := Vector3i(rng.randi_range(-2, 81), 1, rng.randi_range(-2, 81))
		if placed.at(cell) != _at(placed, cell):
			bad.append(["at", cell])
		if placed.light_at(cell) != _light_at(placed, cell):
			bad.append(["light_at", cell])
		var shut_door := placed._shut_door_on(cell)
		if shut_door != _shut_door_on(placed, cell):
			bad.append(["_shut_door_on", cell])
		if placed._in_open_door(cell) != _in_open_door(placed, cell):
			bad.append(["_in_open_door", cell])
		var p := Vector3(rng.randf_range(-2.0, 82.0), 1.0 + rng.randf_range(-0.5, 1.5), rng.randf_range(-2.0, 82.0)) * WorldData.CELL
		var reach := rng.randf_range(0.5, 6.0) * WorldData.CELL
		if placed.stations_near(p, reach) != _stations_near(placed, p, reach):
			bad.append(["stations_near", p, reach])
		if placed.burning(p) != _burning(placed, p):
			bad.append(["burning", p])
		if not is_equal_approx(Warmth.fire_heat(placed, p), _fire_heat(placed, p)):
			bad.append(["fire_heat", p])
		if placed.seat_near(p) != _seat_near(placed, p):
			bad.append(["seat_near", p])
		if placed.bed_under(p) != _bed_under(placed, p):
			bad.append(["bed_under", p])
		if placed.nearest_bed(p, 3.0) != _nearest_bed(placed, p, 3.0):
			bad.append(["nearest_bed", p])
	_check(bad.is_empty(), "%s: the index answers as a look over every thing: %s" % [when, bad.slice(0, 5)])


# The rules as they were before the index: over every thing of the world.

func _at(placed: Placed, cell: Vector3i) -> Dictionary:
	for e in placed.things:
		if e.cell == cell:
			return e
	return _light_at(placed, cell)


func _light_at(placed: Placed, cell: Vector3i) -> Dictionary:
	for e in placed.lights:
		if e.cell == cell:
			return e
	return {}


func _shut_door_on(placed: Placed, c: Vector3i) -> Dictionary:
	for e: Dictionary in placed.things:
		if e.cell.y == c.y and not e.get("open", true) and Placed.is_door(e) \
				and Placed.is_wall_door(Items.get_item(e.item)) and placed.cells_of(e).has(c):
			return e
	return {}


func _in_open_door(placed: Placed, c: Vector3i) -> bool:
	for e: Dictionary in placed.things:
		if e.get("open", false) and e.cell.y == c.y:
			var shut := e.duplicate()
			shut.open = false
			if placed.cells_of(shut).has(c):
				return true
	return false


func _stations_near(placed: Placed, p: Vector3, reach: float) -> Dictionary:
	var out := {}
	for e in placed.things:
		if e.items == null and e.lit and Placed.center(e).distance_to(p) <= reach:
			out[e.item] = true
			for s: String in Items.get_item(e.item).serves:
				out[s] = true
	return out


func _burning(placed: Placed, p: Vector3) -> Dictionary:
	var c := p / WorldData.CELL
	for e in placed.things:
		if not e.lit or not Placed.is_fire(e) or Placed.is_hearth(e):
			continue
		var at: Vector3i = e.cell
		if c.y < at.y - Body.HEIGHT or c.y > at.y + 1.0 + Placed.SINGE:
			continue
		var reach_x := Placed.FLAMES_HALF + Body.HALF_WIDTH + Placed.SINGE
		var reach_z := Placed.FLAMES_HALF + Body.HALF_DEPTH + Placed.SINGE
		if absf(c.x - (at.x + 1.0)) <= reach_x and absf(c.z - (at.z + 1.0)) <= reach_z:
			return e
	return {}


func _fire_heat(placed: Placed, p: Vector3) -> float:
	var best := 0.0
	for e: Dictionary in placed.things:
		if not e.lit or not Placed.is_fire(e):
			continue
		var d: float = Placed.center(e).distance_to(p)
		if d < Warmth.FIRE_REACH:
			var strength := lerpf(Warmth.FIRE_LOW, 1.0, Placed.fuel_share(e))
			best = maxf(best, Warmth.FIRE_HEAT * strength * (1.0 - d / Warmth.FIRE_REACH))
	return best


func _seat_near(placed: Placed, p: Vector3) -> float:
	var best := 1.0
	var c := p / WorldData.CELL
	for e in placed.things:
		var seat: float = Placed.seats.get(e.item, 1.0)
		if seat <= best or absf(float(e.cell.y) - c.y) > 1.0:
			continue
		var n := Placed.size_of(e.item)
		var dx := maxf(maxf(e.cell.x - c.x, c.x - (e.cell.x + n)), 0.0)
		var dz := maxf(maxf(e.cell.z - c.z, c.z - (e.cell.z + n)), 0.0)
		if dx <= Placed.SEAT_REACH and dz <= Placed.SEAT_REACH:
			best = seat
	return best


func _bed_under(placed: Placed, p: Vector3) -> Dictionary:
	var c := p / WorldData.CELL
	for e in placed.things:
		var at: Vector3i = e.cell
		var n := Placed.size_of(e.item)
		if Placed.is_bed(e) and c.x >= at.x and c.x < at.x + n and c.z >= at.z and c.z < at.z + n \
				and c.y >= at.y - Placed.SINGE and c.y <= at.y + 1.0:
			return e
	return {}


func _nearest_bed(placed: Placed, p: Vector3, reach: float) -> Dictionary:
	var c := p / WorldData.CELL
	var best := {}
	var best_d := reach
	for e in placed.things:
		if not Placed.is_bed(e) or absf(float(e.cell.y) - c.y) > 1.0 + Placed.SINGE:
			continue
		var half := Placed.size_of(e.item) * 0.5
		var d := Vector2(e.cell.x + half - c.x, e.cell.z + half - c.z).length()
		if d <= best_d:
			best_d = d
			best = e
	return best
