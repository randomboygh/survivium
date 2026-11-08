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


func run() -> void:
	_test_content()
	_test_launch_sail_ashore()
	_test_two_aboard()
	_test_oars_and_save()
	_test_ice_and_death()


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
	_check(v.at == p and absf(v.turn - PI / 2.0) < 0.01, "the raft goes where its rower goes, turned that way")
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
