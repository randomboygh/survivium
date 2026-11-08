extends RefCounted
## The first part of the rules of the hands (world_actions.gd, which says what `who`
## gives and what a swing returns): the state they work on, the signals that tell the views
## what changed, and the helpers every other part uses: reach, where a thing let go comes
## to lie, a block put as a player builds it, the time a skilled hand takes, what the land's
## owner allows, and the skill learnt from a work.
##
## The rules are one script split by topic (decision 168, as decision 145): actions_base.gd
## <- actions_gather.gd <- actions_fight.gd <- actions_water.gd <- actions_dig.gd <-
## actions_build.gd <- actions_farm.gd <- world_actions.gd; each part extends the one before and calls only
## what it or an earlier part defines, and callers know only world_actions.gd.

const Tools := preload("res://src/shared/content/tools.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Quality := preload("res://src/shared/game/quality.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const CELL := WorldData.CELL
## How far from the body a thing on the ground or a placed thing is taken or used, in
## world units (ten cells, as Tools.PLACE_REACH; Gathering.REACH), and what the rules
## let pass over it and over a tool's reach: the body the server knows lags a step
## behind the player's (С6, plan/architecture/server.md).
const HAND_REACH := 5.0
const REACH_SLACK := 1.5
## Cell `cell` changed (dug, filled, cut down to another material, a tree fell through it,
## a bush on it went): what is drawn around it is built again.
signal cell_changed(cell: Vector3i)
var world
## The clock: `season` (0 spring .. 3 winter) and `day`.
var clock
## The rules of play (Rules): `free_build` (building takes nothing from the bag; digging
## gives as ever).
var rules
## The land claimed (Territory): what a player may do in another's; none in tests that
## have no claims.
var territory
## The cells players built, and those of them dug out again: digging a block a player
## built teaches nothing, nor building again where one was dug (the same block put and
## dug over and over is no useful work). Not kept in the save.
var _built := {}
var _undone := {}


func _init(w, c, r) -> void:
	world = w
	clock = c
	rules = r


## What the hands did: they swing again in `seconds`, the body plays work `kind` ("" for
## the tool's own) toward `at` (world units), and bits of material `stuff` fly off there
## (-1 for none; see Effects.burst).
static func _work(seconds: float, kind: String, at: Vector3, stuff := -1) -> Dictionary:
	return {"swing": seconds, "work": kind, "time": seconds, "at": at, "stuff": stuff}


## Whether `cell` is farther than `reach` cells from `who`.
func too_far(who, cell: Vector3i, reach: int) -> bool:
	var center := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	var at: Vector3 = who.position
	return center.distance_to(at + Vector3(0.0, 0.5, 0.0)) > reach * CELL


## Whether world point `at` is within the hand's reach of `who` (HAND_REACH with the
## slack): a thing on the ground, a placed thing, a chest.
static func within_hand(who, at: Vector3) -> bool:
	var from: Vector3 = who.position
	return at.distance_to(from + Vector3(0.0, 0.5, 0.0)) <= HAND_REACH + REACH_SLACK


## Where a thing let go in `cell` comes to lie: on the ground under it, in world units.
func floor_under(cell: Vector3i) -> Vector3:
	var y := cell.y
	while y > 1 and y > cell.y - 64 and not world.is_solid(cell.x, y - 1, cell.z):
		y -= 1
	var h: float = world.ground_height(cell.x + 0.5, cell.z + 0.5)
	var at := Vector3(cell.x + 0.5, h if h >= y - 1 and h <= y else float(y), cell.z + 0.5)
	return at * CELL


## A bush disappears when its cell is filled or the ground under it is dug.
static func bushes_lose_ground(w, cell: Vector3i) -> void:
	for c in [cell, cell + Vector3i.UP]:
		if w.bushes.has(c):
			w.remove_bush(c)


## Puts `block` in `cell` (a block placed, a ghost cell of the blueprint built).
func put_block(cell: Vector3i, block: int) -> void:
	world.set_cell(cell.x, cell.y, cell.z, block)
	_changed(cell)


## Puts `block` into `cell` as a player builds it, of `form` (WorldData.forms: a slope or
## stairs; 0 a cube); true when it is new work for the skill of building: not where a
## block a player built was dug out (see _built).
func build_cell(cell: Vector3i, block: int, form := 0) -> bool:
	world.set_cell(cell.x, cell.y, cell.z, block)
	world.set_form(cell.x, cell.y, cell.z, form)
	_changed(cell)
	_built[cell] = true
	return not _undone.has(cell)


## The seconds a work of `role` (SkillSet) by `who` takes that would take `seconds` with no
## skill; `learn` of them go to the skill as points (0 for work that taught nothing).
func skilled(who, role: String, seconds: float, learn := 1.0) -> float:
	var sk = who.get("skills")
	if sk == null:
		return seconds
	sk.gain(role, seconds * learn)
	return seconds * sk.pace(role)


## What the hands did (_work), for the rules of other modules.
func work(seconds: float, kind: String, at: Vector3, stuff := -1) -> Dictionary:
	return _work(seconds, kind, at, stuff)


func _changed(cell: Vector3i) -> void:
	bushes_lose_ground(world, cell)
	cell_changed.emit(cell)


# --- Trees -------------------------------------------------------------------------


## Whether `who` may do `action` (Territory.ACTIONS) at `cell` (a word to them if not).
func territory_allows(who, cell: Vector3i, action: String) -> bool:
	return _may(who, cell, action)


func _may(who, cell: Vector3i, action: String) -> bool:
	return territory == null or territory.may(who, cell, action)


## The cells of `cells` where `who` may do `action`.
func _allowed(who, cells: Array[Vector3i], action: String) -> Array[Vector3i]:
	if territory == null:
		return cells
	var out: Array[Vector3i] = []
	for c in cells:
		if territory.may(who, c, action):
			out.append(c)
	return out


## The points of a whole thing done (a beast killed, a fish caught) to the skill of work
## `role` of `who`.
static func _learn_each(who, role: String) -> void:
	var sk = who.get("skills")
	if sk != null:
		sk.gain_each(role)


## Whether the skill of work `role` of `who` gives one more this time (SkillSet.extra).
static func _extra(who, role: String) -> bool:
	var sk = who.get("skills")
	return sk != null and sk.extra(role)


## The blow a tool of `power` deals in the hands of `who` at work `role`: the power,
## more only where the skill says so (SkillSet.blow: hunting's `might`).
static func _blow(who, role: String, power: int) -> int:
	var sk = who.get("skills")
	return maxi(1, power) if sk == null else sk.blow(role, power)


## The quality of what `who` gets from the world by work `role` now (Quality.by_hand_of:
## the tool in hand and the skill).
static func _got(who, role: String) -> int:
	return Quality.by_hand_of(who, role)


## The skill a tree or a bush worked with tool `t` teaches (see gather): an axe fells,
## a shovel digs out, hands and the rest gather.
static func _gather_role(t: Dictionary) -> String:
	if Tools.can_gather(t):
		return "gather"
	if Tools.can_chop(t):
		return "chop"
	if Tools.can_dig_out(t):
		return "dig"
	return "gather"
