extends "res://tests/unit/test_case.gd"
## Rafts and boats (WorldActions part actions_boat.gd, Vessels, Body.vessel): a vessel in
## the hand is launched on the water in front and rowed, afloat it keeps to the water at
## its pace, a second boards it and is carried, the shore is stepped onto and the vessel
## stays moored there until taken up into the bag, a boat without oars barely goes, ice
## puts the riders ashore, and the saves keep who rides what and where the vessels float.

const RAFT := "tools:raft"
const BOAT := "tools:boat"
const OARS := "tools:oars"
const Vessels := preload("res://src/shared/game/vessels.gd")
const Currents := preload("res://src/shared/world/currents.gd")


func run() -> void:
	_test_content()
	_test_launch_sail_ashore()
	_test_launch_from_bag()
	_test_rowing_feel()
	_test_wind_and_bump()
	_test_two_aboard()
	_test_oars_and_save()
	_test_ice_and_death()
	_test_currents()


## A character who looks where it is told and is put where a rule puts it.
class Rower extends Survivor:
	var facing := Vector2i(1, 0)

	func facing_step() -> Vector2i:
		return facing

	func _came_back(to: Vector3) -> void:
		back_at = to
		at = to


## A lake along x on a stone floor: water in levels 1..2 (open surface at 2.5) over x
## 4..17, banks of stone up to level 2 (the feet at 3) at x <= 3 and x >= 18.
func _lake() -> WorldData:
	var w := WorldData.new(8, Vector2i(24, 16))
	for z in 16:
		for x in 24:
			w.set_cell(x, 0, z, Mat.STONE)
			for y in range(1, 3):
				w.set_cell(x, y, z, Mat.WATER if x >= 4 and x <= 17 else Mat.STONE)
	return w


func _rower(w: WorldData, item: String, z := 8.5) -> Rower:
	var ch := Rower.new()
	ch.world = w
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.body.world = w
	ch.vitals.thirst = false
	ch.at = Vector3(2.5, 3.0, z) * WorldData.CELL
	if item != "":
		ch.give(item, 1)
		ch.hands = [item, ""]
	return ch


func _actions(w: WorldData, people: Array) -> WorldActions:
	var actions := WorldActions.new(w, Clock.new(), Rules.new())
	actions.people = people
	return actions


func _test_content() -> void:
	_check(WorldActions.vessel_of(RAFT) > 0.0 and WorldActions.vessel_of(BOAT) > WorldActions.vessel_of(RAFT)
		and Items.get_item(BOAT).oars == OARS and WorldActions.vessel_of(OARS) == 0.0,
		"a raft and a faster boat are vessels, the boat rowed with oars")


func _test_launch_sail_ashore() -> void:
	var w := _lake()
	var ch := _rower(w, RAFT)
	var actions := _actions(w, [ch])
	ch.facing = Vector2i(0, 1)
	_check(actions.boat_kind(ch) == "", "no launching with no water in front")
	ch.facing = Vector2i(1, 0)
	ch.hands = ["", ""]
	_check(actions.boat_kind(ch) == "", "no launching with no vessel in the hand")
	ch.hands = [RAFT, ""]
	_check(actions.boat_kind(ch) == "launch", "a raft in the hand facing the water is launched")
	var done := actions.boat(ch)
	var surface := 2.0 + WorldData.WATER_TOP
	_check(not done.is_empty() and ch.riding == RAFT and ch.vessel != 0 and ch.seat == 0 and ch.inventory.count(RAFT) == 0
		and actions.vessels.list.size() == 1, "launched, the raft leaves the bag, floats and is rowed")
	_check(is_equal_approx(ch.at.y / WorldData.CELL, surface - Body.DECK) and ch.at.x / WorldData.CELL > 4.0,
		"the rower sits on the water in front: %s" % ch.at)
	# Afloat the body goes at the raft's pace along the water and stops at the far bank.
	ch.update(0.1)
	var body: Body = ch.body
	_check(is_equal_approx(body.vessel, WorldActions.vessel_of(RAFT)), "the body rides at the raft's pace")
	_check(is_equal_approx(body.speed_at(ch.at), Body.SPEED * WorldActions.vessel_of(RAFT)), "its pace on water is the raft's share of walking")
	body.move_input = Vector2(1.0, 0.0)
	var p := ch.at
	var low := INF
	for i in 200:
		p = body.step(p, 0.05, true)
		low = minf(low, p.y)
	_check(body.afloat and not body.swimming and is_equal_approx(low / WorldData.CELL, surface - Body.DECK),
		"afloat it neither swims, sinks nor jumps")
	_check(p.x / WorldData.CELL > 16.0 and p.x / WorldData.CELL <= 18.0 - Body.HULL + 0.01,
		"it goes the length of the lake and stops at the bank: %s" % (p / WorldData.CELL))
	body.move_input = Vector2(0.0, 1.0)
	var q := p
	for i in 100:
		q = body.step(q, 0.05, false)
	_check(q.z / WorldData.CELL <= 16.0 - Body.HULL + 0.01 and body.afloat, "the hull keeps to the water")
	ch.at = p
	actions.step_boats(0.1, [ch])
	var v: Dictionary = actions.vessels.of(ch.vessel)
	_check(v.at == p and absf(v.turn - body.heading) < 0.01 and absf(body.heading) < 0.01,
		"the raft goes where its rower goes, pointing the way it was last rowed (south)")
	_check(actions.boat_kind(ch) == "ashore", "the bank in front: the rower can step ashore")
	actions.boat(ch)
	_check(ch.riding == "" and ch.vessel == 0 and is_equal_approx(ch.at.y / WorldData.CELL, 3.0)
		and ch.at.x / WorldData.CELL >= 18.0, "ashore on the bank: %s" % (ch.at / WorldData.CELL))
	_check(ch.inventory.count(RAFT) == 0 and actions.vessels.list.size() == 1 and v.at == p, "the raft stays moored where it floats")
	ch.update(0.1)
	_check(body.vessel == 0.0, "on foot again")
	ch.facing = Vector2i(-1, 0)
	_check(actions.boat_kind(ch) == "board", "the raft in front can be boarded again")
	_check(actions.take_vessel(ch, v.id) and ch.inventory.count(RAFT) == 1 and actions.vessels.list.is_empty(),
		"a moored raft is taken back up into the bag")
	_check(not actions.take_vessel(ch, v.id), "and only once")


## Counts what a character tells of its state (Character.state_changed).
class Told extends RefCounted:
	var n := 0

	func count() -> void:
		n += 1


## The bag's button launches a vessel on the water nearest round the character, whichever
## way it faces, and tells the client at once that it sits in it, and again ashore.
func _test_launch_from_bag() -> void:
	var w := _lake()
	var ch := _rower(w, RAFT)
	ch.hands = ["", ""]
	var actions := _actions(w, [ch])
	var told := Told.new()
	ch.state_changed.connect(told.count)
	ch.facing = Vector2i(0, 1)
	var near := actions.launch_near(ch)
	_check(near.size() == 2 and near[1] == Vector2(1, 0), "the water is found to the east, though it faces south: %s" % [near])
	_check(not actions.launch_from_bag(ch, OARS), "oars are not launched")
	_check(actions.launch_from_bag(ch, RAFT) and ch.riding == RAFT and ch.seat == 0 and ch.inventory.count(RAFT) == 0,
		"the raft in the bag is launched and boarded")
	_check(told.n > 0, "the client is told it sits afloat")
	_check(not actions.launch_from_bag(ch, RAFT), "not twice")
	var dry := _rower(w, BOAT)
	dry.at = Vector3(0.5, 3.0, 8.5) * WorldData.CELL
	dry.hands = ["", ""]
	actions.people = [ch, dry]
	_check(actions.launch_near(dry).is_empty() and not actions.launch_from_bag(dry, BOAT) and dry.inventory.count(BOAT) == 1,
		"no water near: nothing launched, the boat stays in the bag")
	# Ashore again: told at once, so the client stops drawing it in the raft.
	ch.at = Vector3(17.5, 2.0 + WorldData.WATER_TOP - Body.DECK, 8.5) * WorldData.CELL
	actions.step_boats(0.1, [ch])
	ch.facing = Vector2i(1, 0)
	var before := told.n
	actions.boat(ch)
	_check(ch.riding == "" and told.n > before, "stepping ashore is told at once")


## A vessel speeds up rowed, coasts on let go, turns gradually and carves its turn; an
## overloaded bag slows it, less than it slows walking.
func _test_rowing_feel() -> void:
	var w := _lake()
	var b := Body.new()
	b.world = w
	b.vessel = WorldActions.vessel_of(BOAT)
	b.heading = PI / 2.0
	var pace := Body.SPEED * b.vessel
	var p := Vector3(5.5, 2.0 + WorldData.WATER_TOP - Body.DECK, 8.5) * WorldData.CELL
	p = _went(b, p, Vector2(1.0, 0.0), 0.3)
	_check(b.afloat and b.glide.x > 0.0 and b.glide.x < pace * 0.5, "it picks up speed gradually: %.2f of %.2f" % [b.glide.x, pace])
	p = _went(b, p, Vector2(1.0, 0.0), 1.5)
	_check(b.glide.x > pace * 0.95, "and soon goes at its pace: %.2f" % b.glide.x)
	p = _went(b, p, Vector2.ZERO, 0.5)
	_check(b.glide.x > pace * 0.5, "let go, it coasts on: %.2f" % b.glide.x)
	p = _went(b, p, Vector2.ZERO, 3.0)
	_check(b.glide.length() < 0.01, "then comes to rest")
	b.heading = PI / 2.0
	b.glide = Vector2(pace, 0.0)
	p = Vector3(5.5, p.y / WorldData.CELL, 4.5) * WorldData.CELL
	_went(b, p, Vector2(0.0, 1.0), 0.25)
	_check(b.heading < PI / 2.0 - 0.2 and b.heading > 0.5, "it turns towards the stick gradually: %.2f" % b.heading)
	_check(absf(b.glide.angle_to(Vector2(sin(b.heading), cos(b.heading)))) < 0.3, "and goes the way it points, not sliding sideways")
	var ch := _rower(w, BOAT)
	ch.give(OARS, 1)
	ch.riding = BOAT
	var light := ch.vessel_pace()
	ch.give("resources:stone", ceili(Inventory.WEIGHT_LIMIT * 1.25 / Items.weight("resources:stone")))
	var slow := ch.inventory.speed_factor()
	_check(slow < 1.0 and ch.vessel_pace() < light and ch.vessel_pace() > light * slow,
		"overloaded it goes slower, less so than on foot: %.2f of %.2f (walking %.2f)" % [ch.vessel_pace(), light, slow])


## The wind drives a raft along it, a boat less, a breeze a little; a hull rowed fast into
## the bank bumps back off it and tells how hard, one coming slowly just stops.
func _test_wind_and_bump() -> void:
	var w := _lake()
	var clock := Clock.new()
	var deck := Vector3(10.5, 2.0 + WorldData.WATER_TOP - Body.DECK, 8.5) * WorldData.CELL
	var drift := {}
	for item: String in [RAFT, BOAT]:
		for wind: float in [0.0, Body.WIND_FELT * 0.5, Body.WIND_FULL]:
			clock.storm_wind = wind
			var b := Body.new()
			b.world = w
			b.clock = clock
			b.vessel = WorldActions.vessel_of(item)
			b.windage = float(Items.get_item(item).windage)
			drift["%s %s" % [item, wind]] = _went(b, deck, Vector2.ZERO, 1.0).distance_to(deck) / WorldData.CELL
	var still: float = drift["%s %s" % [RAFT, 0.0]]
	var breeze: float = drift["%s %s" % [RAFT, Body.WIND_FELT * 0.5]]
	var gale: float = drift["%s %s" % [RAFT, Body.WIND_FULL]]
	var boat: float = drift["%s %s" % [BOAT, Body.WIND_FULL]]
	_check(still < 0.001 and breeze > 0.05 and gale > breeze * 2.0 and boat > 0.0 and boat < gale * 0.6,
		"the wind drives a raft, a breeze a little, a boat less: %s" % drift)
	var b := Body.new()
	b.world = w
	b.vessel = WorldActions.vessel_of(BOAT)
	b.heading = PI / 2.0
	var p := _went(b, Vector3(14.5, deck.y / WorldData.CELL, 8.5) * WorldData.CELL, Vector2(1.0, 0.0), 3.0)
	_check(b.bump > Body.SAIL_BUMP, "rowed fast into the bank, the boat bumps: %.2f" % b.bump)
	b.bump = 0.0
	b.move_input = Vector2.ZERO
	b.glide = Vector2(Body.SAIL_BUMP * 2.0, 0.0)
	b.step(p, 0.05, false)
	_check(b.bump > 0.0 and b.glide.x < 0.0, "and bounces back off it: %s" % b.glide)
	b.bump = 0.0
	b.glide = Vector2(Body.SAIL_BUMP * 0.5, 0.0)
	b.step(p, 0.05, false)
	_check(b.bump == 0.0 and b.glide.x <= 0.0, "drifting slowly into it, it just stops")


func _test_two_aboard() -> void:
	var w := _lake()
	var a := _rower(w, RAFT)
	var b := _rower(w, "", 9.5)
	var c := _rower(w, "", 7.5)
	var actions := _actions(w, [a, b, c])
	actions.boat(a)
	var v: Dictionary = actions.vessels.of(a.vessel)
	b.at = a.at - Vector3(1.0, 0.0, 0.0) * WorldData.CELL
	b.at = Vector3(3.0, 3.0, a.at.z / WorldData.CELL) * WorldData.CELL
	_check(actions.boat_kind(b) == "board", "a second one facing the raft can board it")
	actions.boat(b)
	_check(b.vessel == v.id and b.seat == 1 and b.riding == RAFT, "and is carried, the rower rowing")
	_check(b.at.distance_to(WorldActions.seat_at(v, 1)) < 0.001, "sitting behind the rower")
	c.at = b.at - Vector3(1.0, 0.0, 0.0) * WorldData.CELL
	c.at.y = 3.0 * WorldData.CELL
	_check(actions.boat_kind(c) != "board", "a third finds no seat")
	_check(is_equal_approx(b.vessel_pace(), WorldActions.vessel_of(RAFT)), "the one carried goes at the vessel's pace")
	a.facing = Vector2i(-1, 0)
	a.at = Vector3(4.5, 2.5, a.at.z / WorldData.CELL) * WorldData.CELL
	_check(actions.boat_kind(a) == "ashore", "the rower near the bank can step ashore")
	actions.boat(a)
	_check(a.vessel == 0 and b.vessel == v.id and b.seat == 0, "the rower ashore, the one carried rows now")
	_check(not actions.take_vessel(a, v.id), "a vessel someone sits in is not taken up")


func _test_oars_and_save() -> void:
	var w := _lake()
	var ch := _rower(w, BOAT)
	var actions := _actions(w, [ch])
	actions.boat(ch)
	_check(ch.riding == BOAT, "a boat is launched like a raft")
	_check(is_equal_approx(ch.vessel_pace(), WorldActions.vessel_of(BOAT) * ch.OARLESS), "without oars a boat barely goes")
	ch.give(OARS, 1)
	_check(is_equal_approx(ch.vessel_pace(), WorldActions.vessel_of(BOAT)), "with oars in the bag it goes at its pace")
	var copy := Rower.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())))
	_check(copy.riding == BOAT and copy.vessel == ch.vessel and copy.seat == 0, "the save keeps the vessel ridden")
	var again := Vessels.new()
	again.from_list(JSON.parse_string(JSON.stringify(actions.vessels.to_list())))
	var v: Dictionary = again.of(ch.vessel)
	_check(not v.is_empty() and v.item == BOAT and v.at.distance_to(ch.at) < 0.001, "the world's save keeps where the boats float")
	_check(again.launch(RAFT, Vector3.ZERO, 0.0).id > ch.vessel, "a new one gets a new number")


func _test_ice_and_death() -> void:
	var w := _lake()
	var ch := _rower(w, RAFT)
	var actions := _actions(w, [ch])
	actions.boat(ch)
	var id := ch.vessel
	actions.step_boats(1.0, [ch])
	_check(ch.vessel == id, "on open water the rower stays afloat")
	w.water_frozen = true
	actions.step_boats(1.0, [ch])
	_check(ch.vessel == 0 and ch.at.x / WorldData.CELL < 4.0 and actions.vessels.list.has(id),
		"the water frozen, the rower is put on the shore near, the raft stays: %s" % (ch.at / WorldData.CELL))
	w.water_frozen = false
	ch.facing = Vector2i(1, 0)
	actions.boat(ch)
	_check(ch.vessel == id, "boarded again")
	ch.die()
	_check(ch.vessel == 0 and actions.vessels.list.has(id), "a death leaves the vessel where it floats")
	ch.vessel = 999
	ch.riding = RAFT
	ch.death = {}
	actions.step_boats(1.0, [ch])
	_check(ch.vessel == 0 and ch.riding == "", "one in a vessel that is gone is in the water")


## A river running one way at `speed` cells a second everywhere (for Currents).
class Stream:
	var v := Vector2.ZERO

	func _init(to: Vector2) -> void:
		v = to

	func at(_x: int, _z: int) -> Vector2:
		return v

	func at_point(_p: Vector3, _cell: float) -> Vector2:
		return v


## Where `body` gets from `from` in `seconds` with the stick at `stick`.
func _went(body: Body, from: Vector3, stick: Vector2, seconds: float) -> Vector3:
	body.move_input = stick
	var p := from
	for i in int(seconds / 0.05):
		p = body.step(p, 0.05, false)
	return p


func _test_currents() -> void:
	# A world laid out has rivers that run, and the sea and dry land stand still.
	var gen := WorldGen.new(12345)
	var flows := Currents.new(gen)
	var river: Vector2i = gen.find_place("river", Vector2i.ZERO)
	var v := flows.at(river.x, river.y)
	_check(v.length() >= Currents.SPEED * Currents.AT_BANK - 0.01 and v.length() <= Currents.SPEED + 0.01,
		"a river runs: %s at %s" % [v, river])
	_check(flows.at(river.x, river.y) == v and Currents.new().at(river.x, river.y) == Vector2.ZERO,
		"the same each time asked; no layout, no current")
	var far := gen.lay_out(river.x + 200, river.y + 200, 1, 1)
	_check(far.feature[0] == WorldGen.RIVER or flows.at(river.x + 200, river.y + 200) == Vector2.ZERO, "off a river the water stands")
	# The current carries a swimmer and a vessel; a raft rows up it slowly, a boat with oars well.
	var w := _lake()
	var ch := _rower(w, RAFT)
	var actions := _actions(w, [ch])
	actions.currents = Stream.new(Vector2(-3.0, 0.0))
	var swim := Body.new()
	swim.world = w
	swim.flow = Vector2(2.0, 0.0)
	var start := Vector3(8.5, 1.0, 8.5) * WorldData.CELL
	var p := _went(swim, start, Vector2.ZERO, 1.0)
	_check(p.x - start.x > 1.5 * WorldData.CELL, "a swimmer is carried along: %.2f cells" % ((p.x - start.x) / WorldData.CELL))
	var dry := Body.new()
	dry.world = w
	dry.flow = Vector2(2.0, 0.0)
	var bank := Vector3(1.5, 3.0, 8.5) * WorldData.CELL
	_check(_went(dry, bank, Vector2.ZERO, 0.5).distance_to(bank) < 0.01, "on dry ground nothing carries the body")
	actions.boat(ch)
	actions.step_boats(0.1, [ch])
	_check(ch.flow == Vector2(-3.0, 0.0) and ch.body.flow == ch.flow, "afloat, the rower feels the river: %s" % ch.flow)
	var deck := ch.at
	var raft := Body.new()
	raft.world = w
	raft.vessel = WorldActions.vessel_of(RAFT)
	raft.flow = Vector2(-3.0, 0.0)
	raft.heading = PI / 2.0
	var up_raft := _went(raft, deck, Vector2(1.0, 0.0), 2.0).x - deck.x
	var boat := Body.new()
	boat.world = w
	boat.vessel = WorldActions.vessel_of(BOAT)
	boat.flow = Vector2(-3.0, 0.0)
	boat.heading = PI / 2.0
	var up_boat := _went(boat, deck, Vector2(1.0, 0.0), 2.0).x - deck.x
	boat.vessel = WorldActions.vessel_of(BOAT) * ch.OARLESS
	boat.glide = Vector2.ZERO
	var up_bare := _went(boat, deck + Vector3(4.0, 0.0, 0.0) * WorldData.CELL, Vector2(1.0, 0.0), 0.5).x - deck.x - 4.0 * WorldData.CELL
	_check(up_raft > 0.0 and up_boat > up_raft * 2.0 and up_bare < 0.0,
		"upstream a raft rows slowly, a boat with oars well, one without is carried back: %.2f, %.2f, %.2f"
			% [up_raft / WorldData.CELL, up_boat / WorldData.CELL, up_bare / WorldData.CELL])
	ch.at = Vector3(1.5, 3.0, 8.5) * WorldData.CELL
	ch.vessel = 0
	ch.riding = ""
	ch.body.vessel = 0.0
	ch.body.afloat = false
	ch.body.water_depth = 0.0
	actions.step_boats(0.1, [ch])
	_check(ch.flow == Vector2.ZERO, "ashore, no current")
	# The server's own player (over the loop) moves on the client: its body here is never
	# stepped, yet in the river it is carried all the same.
	ch.at = Vector3(8.5, 1.0, 8.5) * WorldData.CELL
	actions.step_boats(0.1, [ch])
	_check(ch.flow == Vector2(-3.0, 0.0) and ch.body.flow == ch.flow,
		"a swimmer whose body was not stepped feels the river: %s" % ch.flow)
	ch.at = Vector3(1.5, 3.0, 8.5) * WorldData.CELL
	actions.step_boats(0.1, [ch])
	_check(ch.flow == Vector2.ZERO, "out of it again, no current")
	# The things lying in the river's water drift; on the bank, and against it, they stay.
	ch.at = Vector3(8.5, 3.0, 8.5) * WorldData.CELL
	actions.currents = Stream.new(Vector2(2.0, 0.0))
	w.add_drop("resources:stone", Vector3(8.5, 1.0, 8.5) * WorldData.CELL, 0.0, 3)
	w.add_drop("resources:stone", Vector3(2.5, 3.0, 8.5) * WorldData.CELL, 0.0, 1)
	w.add_drop("resources:stone", Vector3(17.7, 1.0, 6.5) * WorldData.CELL, 0.0, 2)
	var told := []
	actions.drops_changed.connect(func(k: Vector2i) -> void: told.append(k))
	actions.step_drift(WorldActions.DRIFT_EVERY, [ch])
	var at := {}
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			at[d[3]] = d[1] / WorldData.CELL
	_check(is_equal_approx(at[3].x, 9.5) and is_equal_approx(at[3].y, 1.0), "a heap in the river drifts a cell downstream: %s" % at[3])
	_check(at[1] == Vector3(2.5, 3.0, 8.5) and is_equal_approx(at[2].x, 17.7), "on the bank and against it nothing drifts: %s, %s" % [at[1], at[2]])
	_check(not told.is_empty(), "the clients are told")
	w.water_frozen = true
	actions.step_drift(WorldActions.DRIFT_EVERY, [ch])
	var still := Vector3.INF
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			if d[3] == 3:
				still = d[1] / WorldData.CELL
	_check(is_equal_approx(still.x, 9.5), "ice holds them")

