extends "res://tests/unit/test_case.gd"
## Building decay (Decay, decision 186): built cells nobody tends crack at the pace of
## their material, the ground and what the generator left never; a player near or a
## claim keeps a chunk tended; a crack stays when someone comes back and goes when the
## cell changes; the save keeps it all; switched off, nothing decays; the session runs it;
## the clients are told the cracks of their chunks; a cracked cell breaks in half the time
## and is drawn with the crack mark, never merged.

const Decay := preload("res://src/shared/game/decay.gd")
const Territory := preload("res://src/shared/game/territory.gd")
const Teams := preload("res://src/shared/game/teams.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const LocalHost := preload("res://src/client/net/local_host.gd")


func run() -> void:
	_test_paces()
	_test_session()
	_test_sent_and_dug()
	_test_ruins()


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
	w.set_cell(far_planks.x, 1, far_planks.z, Mat.AIR)
	_check(not d.is_cracked(far_planks), "a cell dug out is not cracked any more")
	w.set_cell(far_wattle.x, 1, far_wattle.z, planks)
	_check(not d.is_cracked(far_wattle), "a cell built anew over a crack is whole")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var back := Decay.new()
	var w_back := _world()
	back.world = w_back
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
	var flat := w.cracks_of(Vector2i(2, 2))
	_check(flat == PackedInt32Array([40, 1, 40]), "the world lists a chunk's cracks")
	var copy := _world()
	copy.take_cracks(Vector2i(2, 2), flat)
	_check(copy.is_cracked(40, 1, 40) and not copy.is_cracked(41, 1, 40), "a client's copy takes them")


## A client is told a chunk's cracks: the list over a socket, which chunk over the loop;
## a cracked cell is dug in half the time; the mesher marks its faces.
func _test_sent_and_dug() -> void:
	var w := _world()
	var planks := Mat.index("materials:planks")
	var cell := Vector3i(40, 1, 40)
	w.set_cell(cell.x, cell.y, cell.z, planks)
	w.set_cell(cell.x + 2, cell.y, cell.z, planks)
	var s := Session.new(w, null, Clock.new(), Rules.of({}), Placed.new())
	var host := LocalHost.new(s)
	var net := host.join()
	host.link.send_world = true
	for cz in 4:
		for cx in 4:
			host.link._sent[Vector2i(cx, cz)] = true
	host.flush(net)
	var got: Array = []
	net.event.connect(func(kind: String, args: Variant) -> void:
		if kind == Protocol.CRACKS:
			got.append(args))
	w.crack(cell, planks)
	var one: Array[Vector3i] = [cell]
	s.decay.cracks_changed.emit(one, true)
	host.flush(net)
	_check(got == [[Vector2i(2, 2), PackedInt32Array([40, 1, 40])]], "over a socket the chunk's cracks are sent")
	got.clear()
	host.link.send_world = false
	s.decay.cracks_changed.emit(one, true)
	host.flush(net)
	_check(got == [[Vector2i(2, 2)]], "over the loop only which chunk")
	var hand := Tools.of("")
	_check(is_equal_approx(s.actions.cell_swing(hand, cell), s.actions.cell_swing(hand, cell + Vector3i(2, 0, 0)) * 0.5),
		"a cracked cell breaks in half the time")
	var meshes: Array = ChunkMesher.build_chunk(w, 32, 32, 16)
	var cols: PackedColorArray = (meshes[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var marked := 0
	for c in cols:
		if c.r > 0.9 and absf(c.g - ChunkMesher.CRACKED.g) < 0.01:
			marked += 1
	_check(marked == 5 * 4, "the cracked cell's five open faces are drawn marked, the other block's not")

## A wall nobody tends loses a row a stage from the top, its lowest row left cracked (the
## ruin); a roof over air falls; a fence falls apart, a chest stays; a cracked cell dug
## gives its item about half the time; the clients hear of what fell.
func _test_ruins() -> void:
	var w := _world()
	var planks := Mat.index("materials:planks")
	for y in range(1, 5):
		w.set_cell(40, y, 40, planks)
	w.set_cell(44, 3, 40, planks)
	var s := Session.new(w, null, Clock.new(), Rules.of({"building_decay_days": 1.0}), Placed.new())
	s.placed.world = w
	var fence: Dictionary = s.placed.put("tools:fence", Vector3i(42, 1, 44))
	var chest: Dictionary = s.placed.put("tools:chest", Vector3i(46, 1, 44))
	_check(not fence.is_empty() and not chest.is_empty(), "a fence and a chest set down")
	var fell: Array = []
	s.decay.crumbled.connect(func(cells: Array[Vector3i], mats: PackedInt32Array) -> void:
		for k in cells.size():
			fell.append([cells[k], mats[k]]))
	var a := _Who.new(1)
	a.position = Vector3(4.5, 1.0, 4.5) * WorldData.CELL
	_run(s.decay, [a], 1.1)
	_check(s.decay.is_cracked(Vector3i(40, 4, 40)) and w.get_cell(40, 4, 40) == planks, "first the wall cracks")
	_run(s.decay, [a], 1.0)
	_check(w.get_cell(40, 4, 40) == Mat.AIR and w.get_cell(40, 3, 40) == planks, "then its top row falls")
	_check(w.get_cell(44, 3, 40) == Mat.AIR, "a roof over air falls")
	_check(not s.placed.things.has(fence) and s.placed.things.has(chest), "a fence falls apart, a chest stays")
	_check(fell.has([Vector3i(40, 4, 40), planks]) and fell.has([Vector3i(42, 1, 44), -1]), "what fell is told")
	_run(s.decay, [a], 5.0)
	_check(w.get_cell(40, 3, 40) == Mat.AIR and w.get_cell(40, 2, 40) == Mat.AIR and w.get_cell(40, 1, 40) == planks
		and s.decay.is_cracked(Vector3i(40, 1, 40)), "row by row, the lowest stays, cracked: the ruin")
	# A long neglect at once (a server long without players near) takes the rows it owes.
	for y in range(1, 5):
		w.set_cell(50, y, 40, planks)
	# (Built with its builder there: the chunk is tended then.)
	var builder := _Who.new(2)
	builder.position = Vector3(50.5, 1.0, 40.5) * WorldData.CELL
	s.decay.step(0.0, [builder], Decay.LOOK_EVERY + 0.01)
	for i in 200:
		s.decay.step(4.2 if i == 0 else 0.0, [], Decay.LOOK_EVERY + 0.01)
	_check(w.get_cell(50, 1, 40) == planks and w.get_cell(50, 2, 40) == Mat.AIR and w.get_cell(50, 4, 40) == Mat.AIR,
		"a long neglect at once takes every row it owes")
	# Digging rubble: about half the cells give their plank back.
	var host := LocalHost.new(s)
	host.join()
	var who = host.player
	who.vitals.fatigue = false
	who.teleport(Vector3(20.5, 2.0, 21.5) * WorldData.CELL)
	w.drops.clear()
	var got := 0
	for k in 40:
		var c := Vector3i(k % 8 + 17, 1 + k / 8, 20)
		w.set_cell(c.x, c.y, c.z, planks)
		w.crack(c, planks)
		var one: Array[Vector3i] = [c]
		s.actions.dig(who, one, 0.1)
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			if str(d[0]).ends_with("planks"):
				got += int(d[3]) if d[3] is int else int(d[3].get("n", 1))
	_check(got >= 8 and got <= 32, "a cracked cell dug gives its item about half the time (%d of 40)" % got)

class _Who:
	var id := 0
	var position := Vector3.ZERO

	func _init(i: int) -> void:
		id = i

	func is_dead() -> bool:
		return false
