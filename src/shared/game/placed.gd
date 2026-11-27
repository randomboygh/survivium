extends "res://src/shared/game/placed_fires.gd"
## Things standing on cells that are not cells (an item's `prop`): chests
## with what they hold, workbenches, kilns and campfires, placed from the bag, and the
## camp a new world starts with next to the spawn (Starts: a campfire, a chest). What a
## thing does goes by its item's flags, not its class: `storage` (it holds things, a
## chest), `fire` (a campfire), `serves` (the stations it stands in for), `place_tool` (the
## tool it is set down with). They are solid (WorldData.blockers): bodies go round them
## or jump on them, and a burning fire burns a body that touches it (see burns). A thing
## that stores is taken up with what it holds; a fire cannot be carried, but it can be put
## out, lit again for a branch, and destroyed without a trace. A fire burns on fuel (its
## item's `fuel_max`, see step): fed with branches, logs and the like, it goes out once
## they have burned, or in a downpour under the open sky; put out, it keeps what it has
## left. The rules take the one acting as `who` (see WorldActions) and tell what changed through signals: the
## client draws the things (Props) and rebuilds the chunks.
##
## A thing takes the square of cells its model's slices cover (`sizes`: two by two for a
## slice of 16 voxels, one cell for 8) and is turned to face the one who set it down
## (`turn`, quarters clockwise seen from above: 0 its front to the south, 1 west, 2
## north, 3 east); only the cells its voxels fill are solid and taken. A thing whose item
## has `steps` (stairs) is solid by the steps of its model, a quarter of a cell each, so
## a body walks up them.
##
## A fence (an item with `fence`, stage 1 building) stands in the middle of its cell and
## joins the fences, wickets and gates beside it on its level with rails (`join`, see
## joins), solid up to FENCE_TOP, over any jump; a wicket or a gate is a door with
## `fence`, its leaf in the middle of its cells and as high. A hatch (`hatch` with `door`)
## lies in a floor, solid shut, its lid swung up open. A ladder (`ladder`) is not solid:
## its cells are WorldData.ladders, where a body climbs (Body).
##
## A door, a window or a hatch (is_opening) set into the blocks of a building cuts its
## opening out of them (put_at) and remembers what it cut (`cut`, cut_of). In the build
## mode it is moved along the wall (move: its new cells cut, its old ones filled again
## with the blocks it took out, the user's pick, 2026-11-26) or taken back into the bag,
## which leaves ghost blocks of the blueprint in its hole (take_up).
##
## A sign (an item with `sign_lines`, decision 183) holds text (`text`, lines joined by
## "\n") whoever may build there writes (write) and those near read over it (SignLabels);
## one hung on a wall (`wall`, ON_WALL) rests by a solid cell beside it, its back to that
## cell; one on a post is turned a quarter at a time (turn_sign).
##
## A cross (an item with `grave`, core) is set down by the world, not from a bag, where a
## death's sack was once its days are up (put_grave): it holds who died there (`grave`,
## Character.grave_of), shown over it like a sign's text to those near (SignLabels); it is
## not written on, and taken up in the build mode it is gone, nothing goes into the bag.
##
## Lights (an item with `light` and no `prop`: a torch, a candle, a lantern) are set down
## on one cell of their own (`lights`, see put_light_from_bag): not solid, they burn out
## their Items.burns seconds where they stand (step) and are gone, as in a hand (also when
## their cell is filled or the ground under it dug); taken
## back, what has burned goes with them. They come and go by the same signals as the
## things, their records marked `light`.
##
## The file is a chain of parts, each calling only itself and those before it: placed_kinds.gd
## (kinds, shapes) ← placed_store.gd (the things, their index, saving) ← placed_spots.gd (where a
## thing fits) ← placed_build.gd (setting down, taking up, moving, openings) ← placed_fires.gd
## (fires, rain, melting, step) ← placed.gd (doors, signs, crosses, beds, seats).

## How near a seat a body still gets its rest (Placed.seat_near), in cells.
const SEAT_REACH := 0.6
## How far (cells) from a sack gone a cross is set down when its own cell is taken.
const GRAVE_REACH := 3


## `who` opens door `e` or shuts it, where the land lets them open doors (Territory); a
## door is not shut on a body in its way. True if it swung.
func swing(who, e: Dictionary) -> bool:
	if is_door(e) and e.get("wreath", "") == "" and who != null and who.has_method("held") and Items.get_item(who.held()).get("wreath", false):
		return hang_wreath(who, e)
	if not is_door(e) or territory != null and not territory.may(who, e.cell, "doors"):
		return false
	var closing: bool = e.open
	_unblock(e)
	e.open = not e.open
	if closing:
		for c: Vector3i in cells_of(e):
			if who.overlaps_cell(c) or who.overlaps_cell(c + Vector3i(0, 1, 0)):
				e.open = true
				break
	_block(e)
	if e.open == closing:
		return false
	opened.emit(e)
	world.note_edit(e.cell.x, e.cell.z)
	return true


## The farthest (cells) the point a step of a body stopped short at (Body.bumped) is from
## the body's feet for a door there to open as it walks into it (walk_open): a client
## sends that point and is not believed further.
const WALK_OPEN_REACH := 1.5


## `who` walks into a shut door set in a wall (is_wall_door) and it opens by itself (user
## 2026-11-27), where the land lets them open doors (Territory "doors"); a tap shuts it
## again (swing) and it stays shut until walked into again. `who.body.bumped` is where
## their last step stopped short (world units). True if a door opened.
func walk_open(who) -> bool:
	if who == null or who.body == null or world == null or who.is_dead() or who.riding != "":
		return false
	var hit: Vector3 = who.body.bumped
	if not hit.is_finite() or hit.distance_to(who.position) > WALK_OPEN_REACH * CELL:
		return false
	var p := hit / CELL
	for y in range(floori(p.y + 0.001), floori(p.y + Body.HEIGHT) + 1):
		for x in range(floori(p.x - Body.HALF_WIDTH), floori(p.x + Body.HALF_WIDTH) + 1):
			for z in range(floori(p.z - Body.HALF_DEPTH), floori(p.z + Body.HALF_DEPTH) + 1):
				var c := Vector3i(x, y, z)
				if not world.blockers.has(c):
					continue
				var e := _shut_door_on(c)
				if e.is_empty():
					continue
				if territory != null and not territory.may(who, e.cell, "doors"):
					return false
				_unblock(e)
				e.open = true
				_block(e)
				opened.emit(e)
				world.note_edit(e.cell.x, e.cell.z)
				return true
	return false


## The shut door in a wall (is_wall_door) whose cells hold cell `c`, {} for none.
func _shut_door_on(c: Vector3i) -> Dictionary:
	for e: Dictionary in things:
		if e.cell.y == c.y and not e.get("open", true) and is_door(e) and is_wall_door(Items.get_item(e.item)) \
				and cells_of(e).has(c):
			return e
	return {}


## `who` hangs the wreath in the hand in use (an item with `wreath`) on door `e`, where the
## land lets them build: a door holds one, drawn on its front and swinging with it (Props),
## given back with the door when it is taken up. True if it was hung.
func hang_wreath(who, e: Dictionary) -> bool:
	if not is_door(e) or e.get("wreath", "") != "" or territory != null and not territory.may(who, e.cell, "build"):
		return false
	var held: String = who.held()
	if held == "" or not Items.get_item(held).get("wreath", false) or who.inventory.remove(held, 1) < 1:
		return false
	e.wreath = held
	_renew(e, e.turn, e.get("text", ""))
	return true


## Sets a cross (the first item with `grave`; none without one) down where a death's sack
## lay at `at` (world units), saying who died there (`grave`, Character.grave_of): in the
## sack's cell, or the nearest free one within GRAVE_REACH (at its level, one up, one
## down) that is air on solid ground, no other thing or light there and none of the bodies
## of `people` in it; nowhere when there is none. Returns the cross, or {}.
func put_grave(at: Vector3, grave: Dictionary, people: Array = []) -> Dictionary:
	var item := Items.grave()
	if item == "":
		return {}
	var home := Vector3i((at / CELL).floor())
	for r in GRAVE_REACH + 1:
		for dy: int in [0, 1, -1]:
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) != r:
						continue
					var c := home + Vector3i(dx, dy, dz)
					if _grave_fits(c, people):
						var e := put(item, c, null, true, -1.0, null, randi() % 4, false, "", grave)
						world.note_edit(c.x, c.z)
						return e
	return {}


## `who` writes `text` on sign `e` (lines joined by "\n", see sign_text), where the land
## lets them build: the sign is set down anew with it, so every copy hears of it as of a
## thing placed (removed, added). True if it was written.
func write(who, e: Dictionary, text: String) -> bool:
	if not is_sign(e) or territory != null and not territory.may(who, e.cell, "build"):
		return false
	var clean := sign_text(e.item, text)
	if clean == e.get("text", ""):
		return true
	_renew(e, e.turn, clean)
	return true


## `who` turns sign `e` a quarter clockwise seen from above (a signpost's arrow points
## another way), where the land lets them build; one hung on a wall is not turned. True
## if it turned.
func turn_sign(who, e: Dictionary) -> bool:
	if not is_sign(e) or Items.get_item(e.item).get("wall", false) \
			or territory != null and not territory.may(who, e.cell, "build"):
		return false
	_renew(e, e.turn + 1, e.get("text", ""))
	return true


## Sets thing `e` down anew where it stands, turned `turn`, saying `text` (a sign changed).
func _renew(e: Dictionary, turn: int, text: String) -> void:
	_forget(e)
	put(e.item, e.cell, null, e.lit, e.get("fuel", -1.0), e.get("by"), turn, e.get("open", false), text, {}, e.get("wreath", ""))
	world.note_edit(e.cell.x, e.cell.z)


## The bed a body with its feet at `p` (world units) lies on, {} for none: its feet over
## the bed's square of cells, no higher than a level above them.
func bed_under(p: Vector3) -> Dictionary:
	var c := p / CELL
	for e in things:
		var at: Vector3i = e.cell
		var n := size_of(e.item)
		if is_bed(e) and c.x >= at.x and c.x < at.x + n and c.z >= at.z and c.z < at.z + n \
				and c.y >= at.y - SINGE and c.y <= at.y + 1.0:
			return e
	return {}


## The bed nearest to a body with its feet at `p` (world units) whose middle is within
## `reach` cells of it across the ground and that stands on its level or one above or
## below, {} for none.
func nearest_bed(p: Vector3, reach: float) -> Dictionary:
	var c := p / CELL
	var best := {}
	var best_d := reach
	for e in things:
		if not is_bed(e) or absf(float(e.cell.y) - c.y) > 1.0 + SINGE:
			continue
		var half := size_of(e.item) * 0.5
		var d := Vector2(e.cell.x + half - c.x, e.cell.z + half - c.z).length()
		if d <= best_d:
			best_d = d
			best = e
	return best


## Where a body lies in bed `e` (or sits on a seat, world units): over its middle, on
## the top of its widest box (the mattress, not the posts of a headboard).
func lying_spot(e: Dictionary) -> Vector3:
	var top := 0.0
	var widest := -1.0
	for box in boxes_of(e):
		for b: AABB in (box if box is Array else [box]):
			var area := b.size.x * b.size.z
			if area > widest + 0.0001 or absf(area - widest) <= 0.0001 and b.end.y > top:
				widest = area
				top = b.end.y
	var half := size_of(e.item) * 0.5
	return (Vector3(e.cell) + Vector3(half, top, half)) * CELL


## How much faster a body with its feet at `p` (world units) gets its stamina back by the
## seats round it: the best `seat` of a thing it stands on or within SEAT_REACH cells of,
## on its level; 1 for none.
func seat_near(p: Vector3) -> float:
	var best := 1.0
	if seats.is_empty():
		return best
	var c := p / CELL
	for e in things:
		var seat: float = seats.get(e.item, 1.0)
		if seat <= best or absf(float(e.cell.y) - c.y) > 1.0:
			continue
		var n := size_of(e.item)
		var dx := maxf(maxf(e.cell.x - c.x, c.x - (e.cell.x + n)), 0.0)
		var dz := maxf(maxf(e.cell.z - c.z, c.z - (e.cell.z + n)), 0.0)
		if dx <= SEAT_REACH and dz <= SEAT_REACH:
			best = seat
	return best
