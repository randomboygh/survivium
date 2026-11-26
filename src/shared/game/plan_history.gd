extends RefCounted
## One player's undo and redo of the blueprint (the build mode's ↶ ↷, Ctrl+Z / Ctrl+Y; the
## user's picks of 2026-11-26, 1А 2А): each request of theirs that changed the blueprint
## (Requests.RECORDED: a shape drawn or erased, a slope turned, «clear», a ghost thing set,
## moved, turned or taken off) is one step, MAX steps at most, the oldest let go. A step
## keeps what each ghost cell it touched held before and after (the block's item, "" none;
## its form) and the ghost things that went and came (as records: item, cell, turn, cells,
## wall). Undo puts «before» back only where a cell is still as the step left it, redo
## puts «after» back where it is still «before»: a ghost built meanwhile, or changed by
## someone else, is left alone, and built blocks are never touched. Only within PLAN_REACH
## of the player and where they may build. A new step lets the steps undone go. Not saved:
## the player's link (PlayerLink) keeps it while they are in the world.

const Plans := preload("res://src/shared/game/plans.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")

## Steps kept each way at most.
const MAX := 50

var plans
## The steps that can be undone, the last on top, and those undone that can be redone.
var undos: Array = []
var redos: Array = []
## The step being recorded (begin … end): its cells and the blueprint's before it.
var _step: Dictionary = {}
var _before_cells := {}
var _before_forms := {}


func _init(p) -> void:
	plans = p


## Starts recording a request that may change the blueprint.
func begin() -> void:
	_step = {"cells": {}, "came": [], "gone": []}
	_before_cells = plans.cells.duplicate()
	_before_forms = plans.forms.duplicate()
	# A request cut short by an error left them on.
	if not plans.changed.is_connected(_on_changed):
		plans.changed.connect(_on_changed)
		plans.thing_changed.connect(_on_thing)


## Ends the recording: a step that changed something is kept (the oldest past MAX let go)
## and the steps undone are let go. Whether one was kept.
func end() -> bool:
	plans.changed.disconnect(_on_changed)
	plans.thing_changed.disconnect(_on_thing)
	var touched: Dictionary = _step.cells
	var out := {}
	for c: Vector3i in touched:
		var was := [_before_cells.get(c, ""), _before_forms.get(c, 0)]
		var now := [plans.cells.get(c, ""), plans.forms.get(c, 0)]
		if was != now:
			out[c] = was + now
	var step := {"cells": out, "came": _step.came, "gone": _step.gone}
	_step = {}
	_before_cells = {}
	_before_forms = {}
	if out.is_empty() and step.came.is_empty() and step.gone.is_empty():
		return false
	undos.append(step)
	if undos.size() > MAX:
		undos.pop_front()
	redos.clear()
	return true


func _on_changed(list: Array, _item: String) -> void:
	for c: Variant in list:
		_step.cells[c] = true


func _on_thing(t: Dictionary, came: bool) -> void:
	var rec := _record(t)
	if came:
		_step.came.append(rec)
		return
	# A thing set and taken off in the same request (moved: taken off its old place and set
	# anew) was never there before it.
	for i in _step.came.size():
		if _step.came[i] == rec:
			_step.came.remove_at(i)
			return
	_step.gone.append(rec)


static func _record(t: Dictionary) -> Dictionary:
	return {"item": t.item, "cell": t.cell, "turn": t.turn, "cells": t.cells.duplicate(), "wall": t.wall.duplicate()}


## Undoes the last step of `who` (the world's rules `actions`, see Plans.draw). How many
## cells and things changed back; a step with nothing of it within reach stays, with a
## line to the player, -1.
func undo(actions, who) -> int:
	return _apply(actions, who, undos, redos, false)


## Does the last step undone again. As undo.
func redo(actions, who) -> int:
	return _apply(actions, who, redos, undos, true)


func _apply(actions, who, from: Array, to: Array, forward: bool) -> int:
	if from.is_empty():
		return 0
	var step: Dictionary = from.back()
	if not _within(who, step):
		who.nag("plan_far", "[come_closer_to_undo_that]")
		return -1
	from.pop_back()
	to.append(step)
	var count := 0
	# The things of the state left go first, so the cells they filled are free.
	for rec: Dictionary in step.came if not forward else step.gone:
		var t := _live(rec)
		if not t.is_empty() and _may(actions, who, t.cell):
			plans.drop_thing(t)
			count += 1
	var put := {}
	for c: Vector3i in step.cells:
		var e: Array = step.cells[c]
		var src := [e[2], e[3]] if not forward else [e[0], e[1]]
		var dst := [e[0], e[1]] if not forward else [e[2], e[3]]
		if [plans.cells.get(c, ""), plans.forms.get(c, 0)] != src or not _may(actions, who, c):
			continue
		if src[0] == "" and (not plans.thing_at(c).is_empty() or plans.cells.size() + put.size() >= Plans.MAX_CELLS
				or not _fits(actions, c, dst[0])):
			continue
		put[c] = dst
	count += plans.set_ghosts(put)
	for rec: Dictionary in step.gone if not forward else step.came:
		if plans.things.size() >= Plans.MAX_THINGS or not _may(actions, who, rec.cell) or not _live(rec).is_empty():
			continue
		var free := true
		for c: Vector3i in rec.cells:
			if not plans.thing_at(c).is_empty() or plans.block_at(c) or not _may(actions, who, c):
				free = false
				break
		if free:
			plans.add_thing(rec.item, rec.cell, rec.turn, rec.cells, rec.wall)
			count += 1
	return count


## The ghost thing of record `rec` in the blueprint now, {} for none.
func _live(rec: Dictionary) -> Dictionary:
	for t: Dictionary in plans.things:
		if t.cell == rec.cell and t.item == rec.item and t.turn == rec.turn:
			return t
	return {}


## Whether a ghost of `item` (a block, a fence, ground to dig out: Plans.CUT) could go in cell
## `c` of the world now: none on a block built meanwhile.
func _fits(actions, c: Vector3i, item: String) -> bool:
	if actions == null:
		return true
	if item == Plans.CUT:
		return actions.world.is_solid(c.x, c.y, c.z)
	var block := Mat.index(Items.get_item(item).get("place", ""))
	return plans.fits(actions, c, block, true)


## Whether `who` may change the blueprint at `c`: within PLAN_REACH, where they may build.
static func _may(actions, who, c: Vector3i) -> bool:
	return Plans.within_reach(who, c) and (actions == null or actions.territory_allows(who, c, "build"))


## Whether anything of `step` lies within PLAN_REACH of `who`.
static func _within(who, step: Dictionary) -> bool:
	for c: Vector3i in step.cells:
		if Plans.within_reach(who, c):
			return true
	for rec: Dictionary in step.came + step.gone:
		if Plans.within_reach(who, rec.cell):
			return true
	return false
