extends "res://src/shared/game/placed_spots.gd"
## Placed things, part 4 (see placed.gd): setting things down from the bag or a blueprint, taking
## them up, moving them in the build mode; the openings cut into walls and the blocks they took
## out (cut_of, _move_opening, _mend).

const Lang := preload("res://src/shared/content/lang.gd")
## The cells round an opening whose blocks tell what its wall is made of (cut_of): its
## sides and the one over it, not the floor under it.
const AROUND: Array[Vector3i] = [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 1, 0)]
## The land claimed (Territory): a thing that `claims` set down from a bag is a claim's
## centre; null where nobody claims (a client's copy).
var territory
## The blueprint (Plans), set by the session: an opening taken out of a wall, or moved
## off with too few blocks to fill its place, leaves ghost blocks there (take_up, move);
## null on a client's copy.
var plans


## `who` places item `id` from the bag (from bag slot `slot` when given, else the first
## that holds it) on free cells of level ground in front (its square, see sizes; stairs
## also over air), turned to face `who` (to face the camera turned `view`, 0..3, when given
## and faces_view), at or below level `top`, with a tool of its `place_tool` class in the bag; a thing that stores brings back
## what it held. True if it was placed.
func put_from_bag(who, id: String, slot: int, top: int, view := -1) -> bool:
	var item := Items.get_item(id)
	var inv = who.inventory
	if slot < 0:
		for i in inv.slots.size():
			if slot < 0 and inv.slots[i] != null and inv.slots[i][0] == item.get("id", ""):
				slot = i
	if item.get("prop", "none") == "none" or slot < 0 or slot >= inv.slots.size() or inv.slots[slot] == null \
			or inv.slots[slot][0] != item.id:
		return false
	if item.place_tool != "none" and not Tools.holds(inv, item.place_tool):
		who.nag("put", Lang.line("[to_place_it_you_need]", [Items.tool_title(item.place_tool)]))
		return false
	var turn := view if view >= 0 and faces_view(item.id) else turn_facing(who.facing_step())
	var shape := _shape_of(item.id, turn)
	var n := size_of(item.id)
	var rest := rest_of(item.id)
	var spot: Variant = _spot_in_front(who, top, n, shape.offsets, rest, shape.high)
	if spot == null:
		who.nag("put", "[there_is_no_wall_in]" if rest == ON_WALL else Lang.line("[needs_a_level_space_in]", [n, n]) if rest != ANYWHERE else "[no_room_for_stairs_in]")
		return false
	if rest == ON_WALL:
		turn = wall_turn(spot, turn)
	return _set_down(who, item, slot, spot, turn, shape.offsets)


## The build mode (Protocol.PROP_PUT_AT): `who` sets thing `id` from the bag down at cell
## `aim` (the cell tapped, within the reach of placing), its front to them or turned as
## put_spot finds best (`face`: the side of the face tapped, -1 none): on the free
## cells nearest it at that level (or one up or down). A door or a window cuts its
## opening into a wall: the blocks put there (not natural ground) where it goes are taken
## out and fall as if dug. True if it was set down.
func put_at(who, id: String, aim: Vector3i, top: int, view := -1, kept := false, face := -1) -> bool:
	var item := Items.get_item(id)
	if item.get("prop", "none") == "none":
		return false
	var slot: int = -1
	var inv = who.inventory
	for i in inv.slots.size():
		if slot < 0 and inv.slots[i] != null and inv.slots[i][0] == item.id:
			slot = i
	if slot < 0:
		who.nag("put", Lang.line("[not_in_the_bag]", [Items.title(id)]))
		return false
	if item.place_tool != "none" and not Tools.holds(inv, item.place_tool):
		who.nag("put", Lang.line("[to_place_it_you_need]", [Items.tool_title(item.place_tool)]))
		return false
	if not in_reach(who, aim):
		who.nag("put", "[too_far]")
		return false
	var found := put_spot(who, item.id, aim, top, view, kept, face)
	var spot: Variant = found[0]
	var turn: int = found[1]
	var rest := rest_of(item.id)
	var shape := _shape_of(item.id, turn)
	var cuts: bool = item.get("door", false) or item.get("window", false)
	if spot == null:
		who.nag("put", Lang.line("[no_room_here]", [Items.title(id)]))
		return false
	if not _swap_out_fences(who, item, spot, shape.offsets):
		return false
	if rest == ON_WALL:
		turn = wall_turn(spot, turn)
	var opening: Array[Vector3i] = []
	if cuts:
		opening = _opening_at(item.id, spot, turn)
	for c in opening:
		if territory != null and not territory.may(who, c, "build"):
			return false
	return _set_down(who, item, slot, spot, turn, shape.offsets, opening)


## A wicket or a gate `item` set down at `spot` filling `offsets` into a fence: the segments
## where it goes back into the bag of `who`. False when one may not be taken (the land's
## rights, a full bag); true for anything else.
func _swap_out_fences(who, item: Dictionary, spot: Vector3i, offsets: Array) -> bool:
	if not (item.get("door", false) and item.get("fence", false)):
		return true
	for o: Vector3i in offsets:
		var f: Dictionary = _fences.get(spot + o, {})
		if not f.is_empty() and is_fence(f):
			if territory != null and not territory.may(who, f.cell, "build"):
				return false
			if who.give(f.item, 1) < 1:
				who.nag("full", "[the_bag_is_full]")
				return false
			_remove(f)
	return true


## A ghost thing `t` of the blueprint (Plans.things) set down for real from the bag of `who`
## where it stands, turned as it is, when it fits there now (as put_at would set it: its
## cells free but for the blocks an opening takes out, the ground under it ready, `who` not
## in its way): Plans.build. A door or a window remembers the ghost blocks it took the
## place of as cut (its `wall`), so moved or taken it walls its place up with them. 1 set
## down, 0 not now (not in the bag, no tool, no room yet, not allowed), -1 the hands too tired.
func put_ghost(who, t: Dictionary) -> int:
	var item := Items.get_item(t.item)
	var inv = who.inventory
	var slot := -1
	for i in inv.slots.size():
		if slot < 0 and inv.slots[i] != null and inv.slots[i][0] == item.get("id", ""):
			slot = i
	if slot < 0 or item.get("prop", "none") == "none":
		return 0
	if item.place_tool != "none" and not Tools.holds(inv, item.place_tool):
		who.nag("put", Lang.line("[to_place_it_you_need]", [Items.tool_title(item.place_tool)]))
		return 0
	var spot: Vector3i = t.cell
	var turn: int = posmod(int(t.turn), 4)
	var shape := _shape_of(item.id, turn)
	var cuts: bool = item.get("door", false) or item.get("window", false)
	# Its own cells are cut, never the floor under it (a hatch: the floor it goes into).
	_swap_fences = item.get("door", false) and item.get("fence", false)
	var fits := _fits(who, spot, world.size_y, shape.offsets, rest_of(item.id), shape.high, spot.y if cuts else NO_CUT)
	_swap_fences = false
	if not fits:
		return 0
	var opening: Array[Vector3i] = []
	if cuts:
		opening = _opening_at(item.id, spot, turn)
	for c in [spot] + opening:
		if territory != null and not territory.may(who, c, "build"):
			return 0
	if item.claims and territory != null and not territory.can_claim(who, spot):
		return 0
	if not _swap_out_fences(who, item, spot, shape.offsets):
		return 0
	var had := {}
	var wall: Dictionary = t.get("wall", {})
	for o: Vector3i in wall:
		var m := Mat.index(Items.get_item(wall[o]).get("place", ""))
		if m > 0:
			had[o] = Mat.IDS[m]
	return 1 if _set_down(who, item, slot, spot, turn, shape.offsets, opening, had) else -1


## Takes the block put in cell `c` out for an opening: it falls on the ground there as if
## dug, or with `drop` false it is the caller's (_move_opening). The id of its material,
## "" where there was none.
func _cut(c: Vector3i, drop := true) -> String:
	var m: int = world.get_cell(c.x, c.y, c.z)
	if m == Mat.AIR or m == Mat.WATER:
		return ""
	var back: String = Mat.RECORDS[m].item
	world.set_cell(c.x, c.y, c.z, Mat.AIR)
	world.note_edit(c.x, c.z)
	if drop and back != "":
		world.heap_drop(back, (Vector3(c) + Vector3(0.5, 0.0, 0.5)) * CELL, 1)
	cell_changed.emit(c)
	return Mat.IDS[m]


## Sets thing `item` from bag slot `slot` of `who` down at north-west cell `spot`, turned
## `turn`, filling `offsets` from it, the blocks of `opening` taken out first (a door, a
## window), remembered by it (`cut`; and the material of `had`, offset -> material id, in a
## cell with none: a ghost door's ghost wall, put_ghost), the blueprint's ghost blocks and
## ghost things in its cells taken off: the land's rights, the hands' stamina, the ground
## under it levelled. True if it was set down.
func _set_down(who, item: Dictionary, slot: int, spot: Vector3i, turn: int, offsets: Array, opening: Array[Vector3i] = [],
		had := {}) -> bool:
	var inv = who.inventory
	if territory != null and not territory.may(who, spot, "build"):
		return false
	if item.claims and territory != null and not territory.can_claim(who, spot):
		return false
	if not who.act("place"):
		return false
	var cut := {}
	for c in opening:
		var m := _cut(c)
		if m != "":
			cut[c - spot] = m
		elif had.has(c - spot):
			cut[c - spot] = had[c - spot]
	var taken: Array = inv.take_slot(slot, 1)
	for o: Vector3i in offsets:
		if world.is_solid(spot.x + o.x, spot.y - 1, spot.z + o.z):
			_level_ground(spot + o + Vector3i(0, -1, 0))
		_remove_bush(spot + o)
	var by: Variant = who.get("id")
	# A sign taken up with words on it says them again (Inventory.text_of).
	var e := put(item.id, spot, taken[3] if taken.size() > 3 else null, true, -1.0, by if by is int else 0, turn, false,
		Inventory.text_of(taken), {}, "", cut)
	if plans != null:
		# Set into a hole the blueprint was to wall up (one left by an opening taken out),
		# it takes the ghost blocks' place; where ghost things stood it takes theirs.
		if is_opening(item.id):
			plans.drop_ghosts(_opening_at(item.id, spot, turn))
		plans.drop_things_in(_opening_at(item.id, spot, turn))
	world.note_edit(spot.x, spot.z)
	if item.claims and territory != null:
		territory.add_claim(who.get("id") if who.get("id") != null else 0, e, str(who.get("player_name") if who.get("player_name") != null else ""))
	return true


## `who` takes placed thing `e` back into the bag, a thing that stores with what it holds
## (its weight and theirs go to the bag), a sign with its words, an opening leaving ghost
## blocks in its hole; not a campfire (see put_out and destroy), and a
## fireplace only put out (is_hearth). True if it was taken.
func take_up(who, e: Dictionary) -> bool:
	if territory != null and not territory.may(who, e.cell, "build"):
		return false
	if is_light(e):
		return take_light(who, e)
	if is_grave(e):
		_remove(e)
		who.say("[cross_removed]")
		return true
	if is_fire(e) and not is_hearth(e):
		who.nag("take", Lang.line("[cant_be_carried_put_it]", [Items.title(e.item)]))
		return false
	if is_fire(e) and e.lit:
		who.nag("take", Lang.line("[is_burning_put_it_out]", [Items.title(e.item)]))
		return false
	# A thing of snow is taken up only whole (the user's pick, 2026-11-23).
	if melt_stage(e) > 0:
		who.nag("take", Lang.line("[1_is_melting_it_cant_be_taken]", [Items.title(e.item)]))
		return false
	var inv = who.inventory
	var full: bool = e.items != null and not e.items.is_empty()
	# A sign keeps its words in the bag (Inventory.text_of): set down again, it says them.
	if (inv.add(e.item, 1, 0, e.items.to_dict()) if full else who.give(e.item, 1, 0, Inventory.NORMAL, e.get("text", ""))) < 1:
		who.nag("full", "[the_bag_is_full]")
		return false
	if full:
		who.say(Lang.line("[1_with_things]", [Items.title(e.item)]))
	if e.get("wreath", "") != "":
		Inventory.give_or_lay(who, e.wreath, 1)
	# A door or a window taken out of a wall leaves ghost blocks of the wall's in its hole
	# (the user's pick, 2026-11-26, 6А): built by the action button, the wall is whole again.
	var hole := cut_of(e) if is_opening(e.item) else {}
	_remove(e)
	_leave_ghosts(hole)
	return true


## `who` moves thing `e` to `corner` (see move_spot) turned `turn` (the same cell and a
## quarter more: turned where it stands), within their reach of placing and where the land
## lets them build at both ends; what it holds, burns or says goes with it, and every copy
## hears of it as of a thing taken and placed (removed, added). An opening is only turned
## the other way round where it stands here (its own cell, its turn + 2); it goes along
## its wall by move_opening. True if it moved.
func move(who, e: Dictionary, corner: Vector3i, turn: int) -> bool:
	if is_light(e):
		return _move_light(who, e, corner, posmod(turn, 4))
	if is_opening(e.item):
		turn = posmod(turn, 4)
		return corner == e.cell and turn == (int(e.get("turn", 0)) + 2) % 4 and _move_opening(who, e, corner, turn, -1)
	if not movable(e) or territory != null and not territory.may(who, e.cell, "build"):
		return false
	turn = posmod(turn, 4)
	var spot: Variant = move_spot(who, e, corner, turn)
	if spot == null:
		who.nag("put", Lang.line("[no_room_here]", [Items.title(e.item)]))
		return false
	var p: Vector3 = who.position / CELL
	var to := center({"item": e.item, "cell": spot, "turn": turn}) / CELL
	if Vector2(to.x - p.x, to.z - p.z).length() > Tools.PLACE_REACH or absf(to.y - 0.5 - p.y) > Tools.PLACE_REACH:
		who.nag("put", "[too_far]")
		return false
	if territory != null and not territory.may(who, spot, "build"):
		return false
	if rest_of(e.item) == ON_WALL:
		turn = wall_turn(spot, turn)
	if not who.act("place"):
		return false
	var items: Variant = e.items.to_dict() if e.items != null else null
	_remove(e)
	for o: Vector3i in _shape_of(e.item, turn).offsets:
		var c: Vector3i = spot + o
		if world.is_solid(c.x, c.y - 1, c.z):
			_level_ground(c + Vector3i.DOWN)
		_remove_bush(c)
	var moved := put(e.item, spot, items, e.lit, e.get("fuel", -1.0), e.get("by"), turn, false, e.get("text", ""), e.get("grave", {}))
	if e.has("water"):
		moved.water = e.water
	if plans != null:
		plans.drop_things_in(_opening_at(e.item, spot, turn))
	world.note_edit(spot.x, spot.z)
	return true


## The build mode (Protocol.PROP_MOVE with a face): `who` moves opening `e` (a door, a
## window, a hatch) along its wall to the wall's cell `aim` pressed, `face` the side of
## that face (-1 none), its old place walled up again (_move_opening). True if it moved.
func move_opening(who, e: Dictionary, aim: Vector3i, face := -1) -> bool:
	return is_opening(e.get("item", "")) and _move_opening(who, e, aim, -1, face)


## The blocks opening `e` took out of the wall it is set into, which fill its cells again
## when it leaves them (_move_opening, take_up): world cell -> material id. One set down
## before openings remembered them (a save without `cut`) took those of the wall round
## it: the material most of the blocks put beside and over its cells are of, in each of
## its cells; none in the open.
func cut_of(e: Dictionary) -> Dictionary:
	var out := {}
	if e.has("cut"):
		for o: Vector3i in e.cut:
			out[e.cell + o] = e.cut[o]
		return out
	var cells := opening_cells(e)
	var count := {}
	for c in cells:
		for d: Vector3i in AROUND:
			var n: Vector3i = c + d
			var m: int = world.get_cell(n.x, n.y, n.z)
			if cells.has(n) or m == Mat.AIR or m == Mat.WATER or world.is_natural(n.x, n.y, n.z):
				continue
			count[m] = count.get(m, 0) + 1
	var best := -1
	for m: int in count:
		if best < 0 or count[m] > count[best]:
			best = m
	if best >= 0:
		for c in cells:
			out[c] = Mat.IDS[best]
	return out


## `who` moves opening `e` (a door, a window, a hatch) to the wall's cell `aim` pressed
## (move; `face` the side of its face, -1 none): set into the wall there as a new one is
## (opening_spot), within their reach of placing. The blocks of its new cells are cut, and
## those it had cut (cut_of) fill its old cells again, the user's pick (2026-11-26, 5А):
## the blocks just cut pay for them first, then those in the bag; a cell none is left for,
## or one they stand in, becomes a ghost block of the blueprint (plans). What was cut and
## is not put back goes to the bag, or on the ground at their feet when it is full; ghost
## blocks in its new cells are taken off the blueprint. `aim`
## its own cell and `turn` the other way round (move; -1 for none): turned where it
## stands, its front to the other side. One swing; the land's rights at both ends. True
## if it moved.
func _move_opening(who, e: Dictionary, aim: Vector3i, turn: int, face: int) -> bool:
	if territory != null and not territory.may(who, e.cell, "build"):
		return false
	var was_turn := int(e.get("turn", 0))
	var spot: Variant = null
	if aim == e.cell and turn == (was_turn + 2) % 4:
		spot = flip_spot(e, turn)
	else:
		if not in_reach(who, aim):
			who.nag("put", "[too_far]")
			return false
		var found := opening_spot(who, e, aim, face)
		spot = found[0]
		turn = found[1]
	if spot == null:
		who.nag("put", Lang.line("[no_room_here]", [Items.title(e.item)]))
		return false
	if spot == e.cell and turn == was_turn:
		return false
	var old := opening_cells(e)
	var cells := _opening_at(e.item, spot, turn)
	for c in cells:
		if territory != null and not territory.may(who, c, "build"):
			return false
	if not who.act("place"):
		return false
	var was := cut_of(e)
	var cut := {}
	# The blocks just cut and not yet put back, by material id.
	var spare := {}
	for c in cells:
		if old.has(c):
			if was.has(c):
				cut[c - spot] = was[c]
			continue
		var m := _cut(c, false)
		if m != "":
			cut[c - spot] = m
			spare[m] = spare.get(m, 0) + 1
	_remove(e)
	var ghosts := {}
	for c in old:
		if cells.has(c) or not was.has(c) or world.get_cell(c.x, c.y, c.z) != Mat.AIR:
			continue
		var id: String = was[c]
		var m := Mat.index(id)
		if m < 0:
			continue
		var item: String = Mat.RECORDS[m].item
		if who.overlaps_cell(c):
			ghosts[c] = id
		elif spare.get(id, 0) > 0:
			spare[id] -= 1
			_mend(c, m)
		elif item != "" and who.inventory.remove(item, 1) == 1:
			_mend(c, m)
		else:
			ghosts[c] = id
	put(e.item, spot, null, true, -1.0, e.get("by"), turn, false, "", {}, e.get("wreath", ""), cut)
	if plans != null:
		plans.drop_ghosts(cells)
		plans.drop_things_in(cells)
	world.note_edit(spot.x, spot.z)
	for id: String in spare:
		var item: String = Mat.RECORDS[Mat.index(id)].item
		var n: int = spare[id]
		if n > 0 and item != "":
			n -= who.give(item, n)
			if n > 0:
				world.heap_drop(item, who.position, n)
	_leave_ghosts(ghosts)
	return true


## Puts material `m` back into cell `c` as a block a player built, a cube (an opening's
## old place filled, _move_opening).
func _mend(c: Vector3i, m: int) -> void:
	world.set_cell(c.x, c.y, c.z, m)
	world.set_form(c.x, c.y, c.z, 0)
	world.note_edit(c.x, c.z)
	cell_changed.emit(c)


## Leaves ghost blocks of the blueprint (plans) in the cells of `hole` (cell -> material
## id) that stand empty, of each material a block in a bag builds (_placer).
func _leave_ghosts(hole: Dictionary) -> void:
	if plans == null or hole.is_empty():
		return
	var ghosts := {}
	for c: Vector3i in hole:
		var item := _placer(hole[c])
		if item != "" and world.get_cell(c.x, c.y, c.z) == Mat.AIR:
			ghosts[c] = item
	plans.put_ghosts(ghosts)


## Destroys campfire `e` that has been put out: nothing is left of it (a fireplace is
## taken up instead, see take_up).
func destroy(e: Dictionary) -> bool:
	if not is_fire(e) or e.lit or is_hearth(e):
		return false
	_remove(e)
	return true


## `who` moves light `e` to `cell` (see light_move_spot), within their reach of placing and
## where the land lets them build at both ends; what it has burned goes with it, and every
## copy hears of it as of a light taken and set down (removed, added); the same cell with
## another `turn` turns it. True if it moved.
func _move_light(who, e: Dictionary, cell: Vector3i, turn: int) -> bool:
	if territory != null and not territory.may(who, e.cell, "build"):
		return false
	var spot: Variant = light_move_spot(who, e, cell)
	if spot == null:
		who.nag("put", "[nowhere_to_place_it_needs]")
		return false
	var p: Vector3 = who.position / CELL
	var to := center({"item": e.item, "cell": spot, "light": true}) / CELL
	if Vector2(to.x - p.x, to.z - p.z).length() > Tools.PLACE_REACH or absf(to.y - 0.5 - p.y) > Tools.PLACE_REACH:
		who.nag("put", "[too_far]")
		return false
	if territory != null and not territory.may(who, spot, "build"):
		return false
	if spot == e.cell and turn == int(e.get("turn", 0)):
		return true
	if not who.act("place"):
		return false
	_remove(e)
	put_light(e.item, spot, float(e.burnt), turn)
	world.note_edit(spot.x, spot.z)
	return true


## `who` sets light `id` from the bag down in front (see light_spot), at or below level
## `top`: the one burning in a hand first, with what it has burned (Character.burning).
## True if it was set down.
func put_light_from_bag(who, id: String, top: int) -> bool:
	if not is_light_item(id) or who.inventory.count(id) < 1:
		return false
	var spot: Variant = light_spot(who, top)
	if spot != null and territory != null and not territory.may(who, spot, "build"):
		return false
	if spot == null:
		who.nag("put", "[nowhere_to_place_it_needs]")
		return false
	if not who.act("place"):
		return false
	var burnt := 0.0
	if "burning" in who:
		var lit: Array = who.burning.get(id, [])
		if not lit.is_empty():
			burnt = float(lit.pop_front())
	if who.inventory.remove(id, 1) < 1:
		return false
	put_light(id, spot, burnt)
	world.note_edit(spot.x, spot.z)
	return true


## `who` takes light `e` back into the bag; what it has burned goes with it (it burns
## after the ones already lit, see Character.burning). True if it was taken.
func take_light(who, e: Dictionary) -> bool:
	if who.give(e.item, 1) < 1:
		who.nag("full", "[the_bag_is_full]")
		return false
	if "burning" in who and float(e.burnt) > 0.0:
		var lit: Array = who.burning.get(e.item, [])
		lit.append(float(e.burnt))
		who.burning[e.item] = lit
		who.state_changed.emit()
	_remove(e)
	return true
