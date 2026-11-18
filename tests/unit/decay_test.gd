extends "res://tests/unit/test_case.gd"
## Building decay (Decay, decision 186): built cells nobody tends crack at the pace of
## their material, the ground and what the generator left never; a player near or a
## claim keeps a chunk tended; a crack stays when someone comes back and goes when the
## cell changes; the save keeps it all; switched off, nothing decays; the session runs it.

const Decay := preload("res://src/shared/game/decay.gd")
const Territory := preload("res://src/shared/game/territory.gd")
const Teams := preload("res://src/shared/game/teams.gd")


func run() -> void:
	_test_paces()
	_test_session()


## A world of 4 by 4 chunks with a stone floor and walls of each material far from the
## player, one wall near them and one in a claim.
func _world() -> WorldData:
	var w := WorldData.new(8, Vector2i(64, 64))
	for z in 64:
		for x in 64:
			w.set_cell(x, 0, z, Mat.STONE)
	return w


## Steps `d` with `days` game days spread over enough steps for every look and scan.
func _run(d: Decay, players: Array, days: float) -> void:
	var n := 1000
	for i in n:
		d.step(days / n, players, Decay.LOOK_EVERY + 0.01)


func _test_paces() -> void:
	var w := _world()
	var planks := Mat.index("materials:planks")
	var wattle := Mat.index("materials:wattle")
	var brick := Mat.index("materials:brick")
	_check(planks >= 0 and wattle >= 0 and brick >= 0, "the building materials are there")
	_check(Mat.decays[wattle] > Mat.decays[planks] and Mat.decays[planks] > Mat.decays[brick]
		and Mat.decays[Mat.DIRT] == 0.0 and Mat.decays[Mat.STONE] == 0.0,
		"wattle decays faster than wood, wood faster than brick; the ground never")
	var far_planks := Vector3i(40, 1, 40)
	var far_wattle := Vector3i(41, 1, 40)
	var far_brick := Vector3i(42, 1, 40)
	var far_dirt := Vector3i(43, 1, 40)
	var wild := Vector3i(44, 1, 40)
	var near := Vector3i(8, 1, 8)
	var claimed := Vector3i(56, 1, 8)
	w.set_cell(far_planks.x, 1, far_planks.z, planks)
	w.set_cell(far_wattle.x, 1, far_wattle.z, wattle)
	w.set_cell(far_brick.x, 1, far_brick.z, brick)
	w.set_cell(far_dirt.x, 1, far_dirt.z, Mat.DIRT)
	w.set_cell(wild.x, 1, wild.z, planks)
	w.set_natural(wild.x, 1, wild.z, true)
	w.set_cell(near.x, 1, near.z, planks)
	w.set_cell(claimed.x, 1, claimed.z, planks)
	var rules = Rules.of({"building_decay_days": 1.0, "territory_start": 100})
	var t := Territory.new()
	t.rules = rules
	t.teams = Teams.new()
	t.add_claim(1, {"cell": claimed}, "Аня")
	var d := Decay.new()
	d.world = w
	d.rules = rules
	d.territory = t
	var told: Array = []
	d.cracks_changed.connect(func(cells: Array[Vector3i], on: bool) -> void: told.append([cells.size(), on]))
	var a := _Who.new(1)
	a.position = (Vector3(near) + Vector3(0.5, 0.0, 0.5)) * WorldData.CELL
	_run(d, [a], 0.6)
	_check(d.is_cracked(far_wattle) and not d.is_cracked(far_planks) and not d.is_cracked(far_brick),
		"wattle cracks first (half the days of wood)")
	_run(d, [a], 0.5)
	_check(d.is_cracked(far_planks) and not d.is_cracked(far_brick), "then wood, after the days of the rules")
	_run(d, [a], 1.0)
	_check(d.is_cracked(far_brick), "brick and stone at half the pace of wood")
	_run(d, [a], 3.0)
	_check(not d.is_cracked(far_dirt) and not d.is_cracked(wild) and not d.is_cracked(Vector3i(40, 0, 40)),
		"the ground, filled in or not, and what the generator left never crack")
	_check(not d.is_cracked(near), "a wall near a player is tended and stays whole")
	_check(not d.is_cracked(claimed), "a wall in a claim stays whole")
	_check(not told.is_empty() and told.all(func(e: Array) -> bool: return e[1]), "the cracks are told")
	a.position = (Vector3(far_planks) + Vector3(0.5, 0.0, 0.5)) * WorldData.CELL
	_run(d, [a], 0.1)
	_check(d.passed[WorldData.chunk_key(far_planks.x, far_planks.z)] == 0.0 and d.is_cracked(far_planks),
		"a player coming back stops the clock, the cracks stay")
	told.clear()
	w.set_cell(far_planks.x, 1, far_planks.z, Mat.AIR)
	d.cell_changed(far_planks)
	_check(not d.is_cracked(far_planks) and told == [[1, false]], "a cell dug out is not cracked any more, and that is told")
	w.set_cell(far_wattle.x, 1, far_wattle.z, planks)
	_check(not d.is_cracked(far_wattle), "a cell built anew over a crack is whole")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var back := Decay.new()
	back.world = w
	back.rules = rules
	back.from_dict(saved)
	_check(back.time == snappedf(d.time, 0.001) and back.is_cracked(far_brick) and not back.is_cracked(far_planks)
		and back.tended.size() == d.tended.size(), "the save keeps the time, the tended chunks and the cracks through JSON")
	var off := Decay.new()
	off.from_dict({"on": false})
	_check(not off.on and not saved.has("off") and bool(saved.on), "a world keeps its switch")
	var w2 := _world()
	w2.set_cell(far_planks.x, 1, far_planks.z, planks)
	var d2 := Decay.new()
	d2.world = w2
	d2.rules = Rules.of({"building_decay_days": 1.0, "building_decay": false})
	_run(d2, [a], 5.0)
	_check(not d2.is_cracked(far_planks), "with the server's rule off nothing decays")
	d2.rules.building_decay = true
	d2.on = false
	_run(d2, [a], 5.0)
	_check(not d2.is_cracked(far_planks), "nor with the world's switch off")


## The session steps it with the things: a wall far from the one player cracks.
func _test_session() -> void:
	var w := _world()
	var planks := Mat.index("materials:planks")
	w.set_cell(40, 1, 40, planks)
	var s := Session.new(w, null, Clock.new(), Rules.of({"building_decay_days": 0.01}), Placed.new())
	var a := _Who.new(1)
	a.position = Vector3(4.5, 1.0, 4.5) * WorldData.CELL
	s.players.append(a)
	for i in 400:
		s.decay.step(0.001, s.players, Decay.LOOK_EVERY + 0.01)
	_check(s.decay.is_cracked(Vector3i(40, 1, 40)), "the session's decay cracks a wall nobody tends")
	s.actions.cell_changed.emit(Vector3i(40, 1, 40))
	_check(not s.decay.is_cracked(Vector3i(40, 1, 40)), "and hears of a cell changed by the rules")


class _Who:
	var id := 0
	var position := Vector3.ZERO

	func _init(i: int) -> void:
		id = i

	func is_dead() -> bool:
		return false
