extends "res://tests/unit/test_case.gd"
## Rafts and boats (WorldActions part actions_boat.gd, Body.vessel): a vessel in the hand
## is launched on the water in front and ridden, afloat it keeps to the water at its pace,
## it puts its rider ashore back in the bag, a boat without oars barely goes, ice puts the
## rider on the shore, a death leaves it in the sack, and the save keeps who rides what.

const RAFT := "tools:raft"
const BOAT := "tools:boat"
const OARS := "tools:oars"


func run() -> void:
	_test_content()
	_test_launch_sail_ashore()
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


func _rower(w: WorldData, item: String) -> Rower:
	var ch := Rower.new()
	ch.world = w
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.body.world = w
	ch.vitals.thirst = false
	ch.at = Vector3(2.5, 3.0, 8.5) * WorldData.CELL
	if item != "":
		ch.give(item, 1)
		ch.hands = [item, ""]
	return ch


func _test_content() -> void:
	_check(WorldActions.vessel_of(RAFT) > 0.0 and WorldActions.vessel_of(BOAT) > WorldActions.vessel_of(RAFT)
		and Items.get_item(BOAT).oars == OARS and WorldActions.vessel_of(OARS) == 0.0,
		"a raft and a faster boat are vessels, the boat rowed with oars")


func _test_launch_sail_ashore() -> void:
	var w := _lake()
	var actions := WorldActions.new(w, Clock.new(), Rules.new())
	var ch := _rower(w, RAFT)
	ch.facing = Vector2i(0, 1)
	_check(actions.boat_kind(ch) == "", "no launching with no water in front")
	ch.facing = Vector2i(1, 0)
	ch.hands = ["", ""]
	_check(actions.boat_kind(ch) == "", "no launching with no vessel in the hand")
	ch.hands = [RAFT, ""]
	_check(actions.boat_kind(ch) == "launch", "a raft in the hand facing the water is launched")
	var done := actions.boat(ch)
	var surface := 2.0 + WorldData.WATER_TOP
	_check(not done.is_empty() and ch.riding == RAFT and ch.inventory.count(RAFT) == 0, "launched, the raft leaves the bag and is ridden")
	_check(is_equal_approx(ch.at.y / WorldData.CELL, surface - Body.DECK) and ch.at.x / WorldData.CELL > 4.0,
		"the rider sits on the water in front: %s" % ch.at)
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
	for i in 100:
		p = body.step(p, 0.05, false)
	_check(p.z / WorldData.CELL <= 16.0 - Body.HULL + 0.01 and body.afloat, "the hull keeps to the water")
	ch.at = Vector3(p.x, p.y, 8.5 * WorldData.CELL)
	ch.facing = Vector2i(1, 0)
	_check(actions.boat_kind(ch) == "ashore", "the bank in front: the rider can step ashore")
	actions.boat(ch)
	_check(ch.riding == "" and ch.inventory.count(RAFT) == 1 and is_equal_approx(ch.at.y / WorldData.CELL, 3.0)
		and ch.at.x / WorldData.CELL >= 18.0, "ashore on the bank, the raft back in the bag: %s" % (ch.at / WorldData.CELL))
	ch.update(0.1)
	_check(body.vessel == 0.0, "on foot again")


func _test_oars_and_save() -> void:
	var w := _lake()
	var actions := WorldActions.new(w, Clock.new(), Rules.new())
	var ch := _rower(w, BOAT)
	actions.boat(ch)
	_check(ch.riding == BOAT, "a boat is launched like a raft")
	_check(is_equal_approx(ch.vessel_pace(), WorldActions.vessel_of(BOAT) * ch.OARLESS), "without oars a boat barely goes")
	ch.give(OARS, 1)
	_check(is_equal_approx(ch.vessel_pace(), WorldActions.vessel_of(BOAT)), "with oars in the bag it goes at its pace")
	var copy := Rower.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())))
	_check(copy.riding == BOAT, "the save keeps the vessel ridden")


func _test_ice_and_death() -> void:
	var w := _lake()
	var actions := WorldActions.new(w, Clock.new(), Rules.new())
	var ch := _rower(w, RAFT)
	actions.boat(ch)
	actions.step_boats(1.0, [ch])
	_check(ch.riding == RAFT, "on open water the rider stays afloat")
	w.water_frozen = true
	actions.step_boats(1.0, [ch])
	_check(ch.riding == "" and ch.inventory.count(RAFT) == 1 and ch.at.x / WorldData.CELL < 4.0,
		"the water frozen, the rider is put on the shore near with the raft: %s" % (ch.at / WorldData.CELL))
	w.water_frozen = false
	ch.hands = [RAFT, ""]
	actions.boat(ch)
	ch.die()
	_check(ch.riding == "" and ch.death.lost.any(func(st: Array) -> bool: return st[0] == RAFT),
		"a death leaves the vessel in the sack")
