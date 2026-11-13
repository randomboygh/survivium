extends RefCounted
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

const Mat := preload("res://src/shared/content/materials.gd")
const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Body := preload("res://src/shared/game/body.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Lang := preload("res://src/shared/content/lang.gd")

const CELL := WorldData.CELL
## No level is cut from (`_open`): the thing goes on air only.
const NO_CUT := 1 << 30
## The campfire of the camp by the spawn of a new world (see Starts), the place to come
## back to after death.
const CAMPFIRE := "core:campfire"
## How close (in cells) a body pushing into a burning campfire, or over it, comes to be
## burnt.
const SINGE := 0.02
## How near a seat a body still gets its rest (Placed.seat_near), in cells.
const SEAT_REACH := 0.6
## The flames burn what touches the logs (FIRE_BOXES, half a cell each way of the fire's
## middle): a body whose side comes within SINGE of them, walking into them or standing
## on them, is burnt; one standing on the ring of stones round them warms (Warmth).
const FLAMES_HALF := 0.5
## A fire burning under the open sky goes out after this many seconds of a heavy rain
## (of strength RAIN_HEAVY or more: a downpour, a storm; a light rain does not), and dries
## as fast once it stops.
const RAIN_OUT := 60.0
const RAIN_HEAVY := 0.9
## A fire is not fed while it has room for less than this many seconds.
const FUEL_ROOM := 30.0
## Those who copy the world learn what a fire has left this often, in seconds of it
## (fuel_changed), besides when it is fed.
const FUEL_TELL := 10.0
## How far (cells) from its own spot a thing of the start's camp is set down when that
## spot is taken, and how many levels above or below the spawn it may stand (see camp_spot).
const CAMP_REACH := 12
const CAMP_RISE := 3
## How many levels over the camp's spot must be open (_open_above).
const CAMP_SKY := 24
## How high a fence, a wicket or a gate is solid, in cells over its floor: over the
## jump of a body (Body.JUMP_SPEED, about 1.45 cells), so nothing jumps it.
const FENCE_TOP := 2.0
## The steps to the sides a fence joins, by the bit of `join` (1 << i): north, east,
## south, west, as Placed.turn_voxels turns the north rail of its model.
const SIDES: Array[Vector3i] = [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
## How a thing set down rests (see _fits): on solid ground; anywhere, over air too, as
## blocks are laid (stairs); on the ground or on a ladder under it (a ladder); in a floor,
## a solid cell beside it (a hatch); against a wall, a solid cell beside it at its level
## (a sign hung on a wall, turned its back to it, see wall_turn).
const ON_GROUND := 0
const ANYWHERE := 1
const ON_LADDER := 2
const IN_FLOOR := 3
const ON_WALL := 4
## How near (cells, from the sign's middle) the text of a sign is shown over it.
const SIGN_READ := 3.0
## How far (cells) from a sack gone a cross is set down when its own cell is taken.
const GRAVE_REACH := 3
## The longest name a cross keeps, and the most counts of a life (Character.grave_of).
const GRAVE_NAME := 32
const GRAVE_COUNTS := 16

## Thing `e` (see things) was placed, as the save had it or anew.
signal added(e: Dictionary)
## Thing `e` was taken out of the world.
signal removed(e: Dictionary)
## Campfire `e` was put out or lit again (its `lit`).
signal lit_changed(e: Dictionary)
## What campfire `e` has left to burn (its `fuel`) changed: it was fed, or another
## FUEL_TELL seconds of it burned.
signal fuel_changed(e: Dictionary)
## Door `e` was opened or shut (its `open`).
signal opened(e: Dictionary)
## A cell under a thing was levelled or a bush there taken away: its chunks change.
signal cell_changed(cell: Vector3i)
## Fence `e` joins its neighbours anew (its `join` changed): drawn again.
signal joined(e: Dictionary)

var world
## The land claimed (Territory): a thing that `claims` set down from a bag is a claim's
## centre; null where nobody claims (a client's copy).
var territory
## Each light set down: {"item": id, "cell": Vector3i (the cell it stands in), "burnt":
## seconds it has burned, "light": true, "items": null, "lit": true}. Saved with the
## things (to_list).
var lights: Array = []
## Each thing placed: {"item": id, "cell": Vector3i (the north-west of its square of
## cells), "turn": quarters it is turned (see sizes), "items": what a thing that stores holds (an Inventory, else null), "lit": false
## for a fire put out, and for a fire "fuel": the seconds it has left to burn, "wet": the
## seconds it has stood in the rain}, and "by": the number of the player who put it
## from their bag (Player.id, 0 in a single game; none for the start's camp), "text": what a
## sign says (see write); a fire is a
## place its maker and their team come back to after death (Character.find_respawns).
## Saved with the world (to_list).
var things: Array = []
## What the chest by the spawn holds (the first thing that stores placed).
var chest_items = null
## The solid boxes of a thing of a prop kind, not turned, in each of its cells (see
## WorldData.blockers): kind -> one per cell of its square, row by row from the
## north-west ([north-west, north-east, south-west, south-east] for two by two), each in
## cell units from that cell's corner, with no size where the cell stays empty, or for a
## thing with `steps` an Array of the boxes of its steps. The shapes are the models'
## (read_footprints); a kind not given fills its four cells.
var footprints := {}
## The same for each turn: kind -> [turn 0, 1, 2, 3].
var turned := {}
## The boxes of a door open, for each turn: kind -> [turn 0, 1, 2, 3]: none, an open door
## is drawn swung back (open_voxels) but bodies pass it.
var opened_boxes := {}
## The fences, wickets and gates by each cell they fill: what a fence joins (joins).
var _fences := {}
## While a wicket or a gate is being set down (put_at): the fences in its way may go.
var _swap_fences := false
## The cells a side of the square a thing of a prop kind takes (see read_footprints):
## kind -> n; 2 for a kind not read.
static var sizes := {}
## The middle of the cells a thing of a prop kind fills, shut, for each turn, in cells from
## the north-west corner of its square across the ground: kind -> [Vector2 for turn 0, 1,
## 2, 3] (see center: a window three cells wide in the north row of its square is tapped
## and heard there, not in the square's middle); the square's middle for a kind not read.
static var middles := {}
## The items that are seats (`seat` over 1) by id, with their `seat`: seat_near looks no
## further when there are none, every body every step.
static var seats := {}
## The boxes of a kind whose item has no model: the plain crate VoxelProps draws for
## it, its walls a voxel in from the edges of its cells.
const CRATE_BOX := AABB(Vector3(0.125, 0.0, 0.125), Vector3(0.75, 1.0, 0.75))
## The boxes of a fire: only the logs in its middle, a cell square across its four
## cells, a cell high so no step climbs it; the ring of stones round them is walked
## over, so a body comes right up to the flames to warm and cook.
const FIRE_BOXES := [
	AABB(Vector3(0.5, 0.0, 0.5), Vector3(0.5, 1.0, 0.5)),
	AABB(Vector3(0.0, 0.0, 0.5), Vector3(0.5, 1.0, 0.5)),
	AABB(Vector3(0.5, 0.0, 0.0), Vector3(0.5, 1.0, 0.5)),
	AABB(Vector3(0.0, 0.0, 0.0), Vector3(0.5, 1.0, 0.5)),
]


## Reads the solid boxes of every kind of thing placed from its model, so bodies go
## round the things as they are drawn: the model of the first item with that `prop`
## (its `model` PNG in its bundle, read as VoxelModel.from_image reads it, the slice's
## corner at the cell's). A fire takes only its middle (FIRE_BOXES); a kind without a
## model gets the crate's boxes. Called once the mods are loaded, and again when they
## are read anew.
func read_footprints() -> void:
	footprints = {}
	turned = {}
	sizes = {}
	middles = {}
	seats = {}
	for id in Items.IDS:
		var rec := Items.get_item(id)
		var kind: String = rec.get("prop", "none")
		if rec.get("seat", 1.0) > 1.0:
			seats[id] = rec.seat
		if kind == "none" or footprints.has(kind):
			continue
		if rec.get("fire", false) and rec.get("model", "") == "":
			footprints[kind] = FIRE_BOXES
			turned[kind] = [FIRE_BOXES, FIRE_BOXES, FIRE_BOXES, FIRE_BOXES]
			sizes[kind] = 2
			continue
		var name: String = rec.get("model", "")
		var path := Content.asset(rec, "models/%s.png" % name) if name != "" else ""
		var img: Image = Content.picture(path) if path != "" else null
		if img != null:
			var n := maxi(1, ceili(img.get_height() / 8.0))
			var voxels := voxels_of_image(img)
			sizes[kind] = n
			var all := []
			for t in 4:
				var boxes := footprint(turn_voxels(voxels, n * 8, t), n, rec.get("steps", false))
				if rec.get("fence", false):
					boxes = _fenced(boxes)
				all.append(boxes)
			footprints[kind] = all[0]
			turned[kind] = all
			var mids := []
			for t in 4:
				mids.append(_middle(all[t], n))
			middles[kind] = mids
			if rec.get("door", false):
				# An open door is solid nowhere: its leaf, swung back, would take a quarter of
				# a doorway a body only just fits through, and swing into the body opening it.
				var none := []
				for i in n * n:
					none.append(AABB())
				opened_boxes[kind] = [none, none, none, none]
		else:
			footprints[kind] = [CRATE_BOX, CRATE_BOX, CRATE_BOX, CRATE_BOX]
			turned[kind] = [footprints[kind], footprints[kind], footprints[kind], footprints[kind]]
			sizes[kind] = 2


## Boxes `boxes` (one per cell, see footprint) raised to FENCE_TOP: a fence's or a gate's.
static func _fenced(boxes: Array) -> Array:
	var out := []
	for b in boxes:
		if b is AABB and b.has_volume():
			b = AABB(b.position, Vector3(b.size.x, FENCE_TOP, b.size.z))
		out.append(b)
	return out


## The solid boxes of a fence joining the sides of bits `join` (see SIDES): its post in
## the middle and a rail to each side joined, FENCE_TOP high, in cell units.
static func fence_boxes(join: int) -> Array:
	var lo := 3.0 / 8.0
	var hi := 5.0 / 8.0
	var out: Array[AABB] = [AABB(Vector3(lo, 0.0, lo), Vector3(hi - lo, FENCE_TOP, hi - lo))]
	if join & 1:
		out.append(AABB(Vector3(lo, 0.0, 0.0), Vector3(hi - lo, FENCE_TOP, hi)))
	if join & 2:
		out.append(AABB(Vector3(lo, 0.0, lo), Vector3(1.0 - lo, FENCE_TOP, hi - lo)))
	if join & 4:
		out.append(AABB(Vector3(lo, 0.0, lo), Vector3(hi - lo, FENCE_TOP, 1.0 - lo)))
	if join & 8:
		out.append(AABB(Vector3(0.0, 0.0, lo), Vector3(hi, FENCE_TOP, hi - lo)))
	return out


## The sides fence `e` joins (bits of SIDES): each beside it on its level where a fence, a
## wicket or a gate stands; one alone has rails both ways across its front (along the
## line it was set down in).
func joins(e: Dictionary) -> int:
	var join := 0
	for i in 4:
		if _fences.has(e.cell + SIDES[i]):
			join |= 1 << i
	if join == 0:
		join = 10 if e.get("turn", 0) % 2 == 0 else 5
	return join


## The fences beside `cell` join their sides anew (one came or went there).
func _rejoin_around(cell: Vector3i) -> void:
	for d: Vector3i in SIDES:
		var n: Dictionary = _fences.get(cell + d, {})
		if n.is_empty() or not is_fence(n) or n.cell != cell + d:
			continue
		var join := joins(n)
		if join == n.get("join", -1):
			continue
		n.join = join
		world.blockers[n.cell] = boxes_of(n)[0]
		joined.emit(n)


## True for a fence (an item with `fence` that is no door): it joins those beside it.
static func is_fence(e: Dictionary) -> bool:
	if is_light(e):
		return false
	var item := Items.get_item(e.item)
	return item.get("fence", false) and not item.get("door", false)


## True for a ladder (an item with `ladder`): not solid, climbed (WorldData.ladders).
static func is_ladder(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("ladder", false)


## How item `id` rests when set down (ON_GROUND, ANYWHERE, ON_LADDER, IN_FLOOR).
static func rest_of(id: String) -> int:
	var item := Items.get_item(id)
	if item.get("steps", false):
		return ANYWHERE
	if item.get("ladder", false):
		return ON_LADDER
	if item.get("hatch", false):
		return IN_FLOOR
	if item.get("wall", false):
		return ON_WALL
	return ON_GROUND


## The cells a side of the square thing `item` (an item id with a `prop`) takes.
static func size_of(item: String) -> int:
	return sizes.get(Items.get_item(item).get("prop", "none"), 2)


## Voxels `voxels` of a model on a square `side` voxels across turned `turn` quarters
## clockwise seen from above (see sizes), in the same square.
static func turn_voxels(voxels, side: int, turn: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for p: Vector3i in voxels:
		var q := p
		for i in posmod(turn, 4):
			q = Vector3i(side - 1 - q.z, q.y, q.x)
		out.append(q)
	return out


## Voxels `voxels` of a door's model on a square `side` voxels across swung open: its
## leaf, standing along the north edge of its square when shut, turned on the hinge at
## its north-west corner to stand along the west edge (x and z swap). A door two cells
## wide or more has two leaves, each half its width: the west one swings so, the east one
## on the hinge at the north-east corner to stand along the east edge.
static func open_voxels(voxels, side := 8) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for p: Vector3i in voxels:
		if side >= 16 and p.x >= side / 2:
			out.append(Vector3i(side - 1 - p.z, p.y, side - 1 - p.x))
		else:
			out.append(Vector3i(p.z, p.y, p.x))
	return out


## Voxels `voxels` of the model of a door of item `id` on a square `side` voxels across
## swung open (see open_voxels): a wicket's or a gate's leaf (`fence`), shut in the middle
## of the depth of its cells, turned on the hinge at its outer end out to the south, into
## the cell before it (open, it is solid nowhere); a hatch's lid (`hatch`), lying at the
## top of its cell, stood up on the hinge at its north edge into the cell over it.
static func swung_voxels(id: String, voxels, side := 8) -> Array[Vector3i]:
	var item := Items.get_item(id)
	if not item.get("fence", false) and not item.get("hatch", false):
		return open_voxels(voxels, side)
	var out: Array[Vector3i] = []
	for p: Vector3i in voxels:
		if item.get("hatch", false):
			out.append(Vector3i(p.x, 8 + p.z, 7 - p.y))
		elif side >= 16 and p.x >= side / 2:
			out.append(Vector3i(side - 1 - (p.z - 3), p.y, 4 + (side - 1 - p.x)))
		else:
			out.append(Vector3i(p.z - 3, p.y, 4 + p.x))
	return out


## The middle of the cells boxes `boxes` (one per cell of a square `n` across, see
## footprint) fill, in cells from the square's north-west corner across the ground.
static func _middle(boxes: Array, n: int) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for i in boxes.size():
		if boxes[i] is Array or boxes[i].has_volume():
			sum += Vector2(i % n, i / n) + Vector2(0.5, 0.5)
			count += 1
	return sum / count if count > 0 else Vector2(n, n) * 0.5


## The turn of a thing set down by one looking along `step` (a facing step): its front
## to them.
static func turn_facing(step: Vector2i) -> int:
	if absi(step.x) > absi(step.y):
		return 1 if step.x > 0 else 3
	return 2 if step.y > 0 else 0


## The boxes of thing `e` in each cell of its square (see footprints), by its turn, a
## door's by whether it is open.
func boxes_of(e: Dictionary) -> Array:
	var kind: String = Items.get_item(e.item).prop
	if e.has("join"):
		return [fence_boxes(e.join)]
	if e.get("open", false) and opened_boxes.has(kind):
		return opened_boxes[kind][e.get("turn", 0)]
	if turned.has(kind):
		return turned[kind][e.get("turn", 0)]
	var whole := AABB(Vector3.ZERO, Vector3.ONE)
	return [whole, whole, whole, whole]


## Makes the cells thing `e` fills solid by its boxes (WorldData.blockers); a ladder's
## are climbed instead (WorldData.ladders: its turn by cell), a fence's join those beside.
func _block(e: Dictionary) -> void:
	if is_ladder(e):
		world.ladders[e.cell] = e.get("turn", 0)
		return
	if is_fence(e):
		e.join = joins(e)
	var boxes := boxes_of(e)
	var n := size_of(e.item)
	for i in boxes.size():
		if boxes[i] is Array or boxes[i].has_volume():
			world.blockers[e.cell + Vector3i(i % n, 0, i / n)] = boxes[i]


## Lets go of the cells thing `e` fills.
func _unblock(e: Dictionary) -> void:
	if is_ladder(e):
		world.ladders.erase(e.cell)
		return
	for c: Vector3i in cells_of(e):
		world.blockers.erase(c)


## The cells thing `e` fills (its boxes there), from its north-west cell.
func cells_of(e: Dictionary) -> Array[Vector3i]:
	var n := size_of(e.item)
	var boxes := boxes_of(e)
	var out: Array[Vector3i] = []
	for i in boxes.size():
		if boxes[i] is Array or boxes[i].has_volume():
			out.append(e.cell + Vector3i(i % n, 0, i / n))
	return out


## The boxes of the model in `img`, a row of square slices (the image's height wide),
## one per level from the ground up, a pixel of any alpha the voxel at its x and z (z
## down the slice), the slice's corner at the thing's north-west cell.
static func footprint_of_image(img: Image) -> Array:
	return footprint(voxels_of_image(img), maxi(1, ceili(img.get_height() / 8.0)))


## The voxels of the model in `img` (see footprint_of_image).
static func voxels_of_image(img: Image) -> Array[Vector3i]:
	var voxels: Array[Vector3i] = []
	var size := img.get_height()
	if size > 0 and img.get_width() % size == 0:
		for y in img.get_width() / size:
			for z in size:
				for x in size:
					if img.get_pixel(y * size + x, z).a > 0.0:
						voxels.append(Vector3i(x, y, z))
	return voxels


## The boxes a thing on `n` by `n` cells of the voxels `voxels` (Vector3i each, an Array
## or the keys of a Dictionary, 8 voxels a cell, from the north-west cell's corner) takes
## in each of its cells, for WorldData.blockers: row by row from the north-west
## ([north-west, north-east, south-west, south-east] for two by two), each in cell units
## from that cell's corner, with no size where it leaves the cell empty. A layer much
## smaller than the one under it (a flint lying on a workbench) is left out of the box's
## top, so it does not lift the player off the planks. With `steps` a cell's box is an
## Array of a box for each quarter of it the voxels fill, as high as they stand there:
## the steps of stairs that a body walks up.
static func footprint(voxels, n := 2, steps := false) -> Array:
	var per := 4 if steps else 1
	var parts := []
	for i in n * n * per:
		parts.append([])
	for p: Vector3i in voxels:
		if p.x < 0 or p.z < 0 or p.x >= n * 8 or p.z >= n * 8:
			continue
		var i := ((p.z >> 3) * n + (p.x >> 3)) * per
		if steps:
			i += ((p.z >> 2) & 1) * 2 + ((p.x >> 2) & 1)
		parts[i].append(p)
	var out := []
	for i in n * n:
		if not steps:
			out.append(_box_of(parts[i]))
			continue
		var boxes: Array[AABB] = []
		for k in 4:
			var box := _box_of(parts[i * 4 + k])
			if box.has_volume():
				boxes.append(box)
		out.append(boxes if not boxes.is_empty() else AABB())
	return out


## The box of voxels `voxels` all in one cell, in cell units from its corner (see
## footprint); no size for none.
static func _box_of(voxels: Array) -> AABB:
	if voxels.is_empty():
		return AABB()
	var lo := Vector3i(8, 0, 8)
	var hi := Vector3i.ZERO
	var layers := {}
	for p: Vector3i in voxels:
		var q := Vector3i(p.x & 7, 0, p.z & 7)
		lo = lo.min(q)
		hi = hi.max(q + Vector3i(1, 0, 1))
		layers[p.y] = layers.get(p.y, 0) + 1
	var size := (hi - lo).max(Vector3i.ZERO)
	var top := 0
	for y: int in layers:
		if y + 1 > top and layers[y] * 4 >= layers.get(y - 1, 0):
			top = y + 1
	return AABB(Vector3(lo.x, 0, lo.z) / 8.0, Vector3(size.x, top, size.z) / 8.0)


## True for a fire (its item's `fire`: what burns, see put_out and light).
static func is_fire(e: Dictionary) -> bool:
	return Items.get_item(e.item).get("fire", false)


## True for a fire in a hearth of its own (a fire whose item has a `model`: a fireplace):
## solid by its model, its flames inside it burn nobody, and put out it is taken up
## whole as the other things are (see take_up); a campfire is drawn by the client and
## only destroyed.
static func is_hearth(e: Dictionary) -> bool:
	var item := Items.get_item(e.item)
	return item.get("fire", false) and item.get("model", "") != ""


## The cells round a thing's square of `n` by `n` cells, from its north-west one, where
## a body coming back to it is set: east first, as by the start's campfire.
static func beside(n: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for z in n:
		out.append(Vector3i(n, 0, z))
	for x in n:
		out.append(Vector3i(x, 0, n))
	for z in n:
		out.append(Vector3i(-1, 0, z))
	for x in n:
		out.append(Vector3i(x, 0, -1))
	return out


## Where a body stands beside thing `e` (world units): the first cell of `beside` with air
## for a body two cells tall on solid ground, else the first of them (the body climbs out).
func stand_by(e: Dictionary) -> Vector3:
	var c: Vector3i = e.cell
	var around := beside(size_of(e.item))
	var spot: Vector3i = c + around[0]
	for d: Vector3i in around:
		var p: Vector3i = c + d
		if world.get_cell(p.x, p.y, p.z) == Mat.AIR and world.get_cell(p.x, p.y + 1, p.z) == Mat.AIR \
				and world.is_solid(p.x, p.y - 1, p.z) and not world.blockers.has(p):
			spot = p
			break
	return (Vector3(spot) + Vector3(0.5, 0.0, 0.5)) * CELL


## Places thing `item` (an item with a `prop`) with its north-west cell at `cell`;
## `items` is what a thing that stores holds, as Inventory.to_dict() gave it; `lit` false
## puts a fire there cold; `fuel` is the seconds a fire has left (below 0: a new one's
## `fuel_start`); `grave` who died there for a cross (see put_grave).
func put(item: String, cell: Vector3i, items: Variant = null, lit := true, fuel := -1.0, by: Variant = null, turn := 0, open := false, text := "", grave := {}) -> Dictionary:
	var rec := Items.get_item(item)
	var e := {"item": item, "cell": cell, "items": null, "lit": lit or not rec.fire, "turn": posmod(turn, 4)}
	if rec.get("sign_lines", 0) > 0:
		e.text = sign_text(item, text)
	if rec.get("grave", false):
		e.grave = grave_record(grave)
	if rec.get("door", false):
		e.open = open
	if by is int:
		e.by = by
	if rec.fire:
		e.fuel = clampf(fuel, 0.0, rec.fuel_max) if fuel >= 0.0 else rec.fuel_start
		e.wet = 0.0
		# One with nothing to burn (a fireplace set down, its `fuel_start` 0) stands cold.
		if e.fuel <= 0.0 and rec.fuel_max > 0.0:
			e.lit = false
	_block(e)
	if rec.storage > 0:
		e.items = Inventory.new(rec.storage)
		e.items.nests = false
		if items is Dictionary:
			e.items.from_dict(items)
		if chest_items == null:
			chest_items = e.items
	things.append(e)
	if rec.get("fence", false):
		for c: Vector3i in cells_of(e):
			_fences[c] = e
		_rejoin_around(e.cell)
		for c: Vector3i in cells_of(e):
			_rejoin_around(c)
	added.emit(e)
	return e


## Places what a world's plan sets down (TestGround.plan_things): [item, north-west cell,
## turn (0 when left out), the seconds a fire has to burn (its `fuel_start` when left
## out)], a light on its cell (see put_light).
func put_plan(t: Array) -> void:
	if is_light_item(t[0]):
		put_light(t[0], t[1])
	else:
		put(t[0], t[1], null, true, float(t[3]) if t.size() > 3 else -1.0, null, t[2] if t.size() > 2 else 0)


## Puts back the things of a save (see to_list).
func from_list(list: Array) -> void:
	for d in list:
		if d is Dictionary and Items.has(Items.canon(d.get("item", ""))) and d.get("cell") is Array and d.cell.size() == 3:
			var id: String = Items.get_item(Items.canon(d.item)).id
			if is_light_item(id):
				put_light(id, Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), float(d.get("burnt", 0.0)))
				continue
			put(id, Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), d.get("items"),
				not d.get("out", false), float(d.get("fuel", -1.0)), int(d.by) if d.get("by") is float or d.get("by") is int else null,
				int(d.get("turn", 0)), bool(d.get("open", false)), str(d.get("text", "")),
				d.get("grave") if d.get("grave") is Dictionary else {})


## The placed things as plain data for the save.
func to_list() -> Array:
	var out := []
	for e in things:
		out.append(record(e))
	for e in lights:
		out.append(record(e))
	return out


## Thing `e` as plain data (one of to_list): {"item", "cell": [x, y, z], "items" what it
## holds (Inventory.to_dict) if it stores, "out" true for a fire put out, "fuel" the
## seconds a fire has left, "by" who put it from their bag, "turn" when it is turned,
## "open" for a door open, "text" for a sign written, "grave" for a cross}.
static func record(e: Dictionary) -> Dictionary:
	var c: Vector3i = e.cell
	var d := {"item": e.item, "cell": [c.x, c.y, c.z]}
	if is_light(e):
		d.burnt = e.burnt
		return d
	if e.items != null:
		d.items = e.items.to_dict()
	if not e.lit:
		d.out = true
	if e.has("fuel"):
		d.fuel = snappedf(e.fuel, 0.1)
	if e.has("by"):
		d.by = e.by
	if e.get("turn", 0) != 0:
		d.turn = e.turn
	if e.get("open", false):
		d.open = true
	if e.get("text", "") != "":
		d.text = e.text
	if e.has("grave"):
		d.grave = e.grave.duplicate(true)
	return d


## Puts the camp of the start (Starts.START: the campfire, the chest when its bundle is
## loaded) next to world point `at` (the spawn), each thing its cells east and south of
## it, or at the nearest free level spot round there when that one is taken (a tree, a
## slope, water, the other thing): every thing of the camp stands by the spawn, under the
## open sky where there is such a spot (not under a crown or behind one, where the player
## would not see it: _open_above). The chunks there are made by then, so the ground under them is known.
func start_camp(at: Vector3) -> void:
	var home := Vector3i((at / CELL).floor())
	for e: Dictionary in Starts.START.camp:
		var spot := camp_spot(home, Vector2i(home.x + int(e.at[0]), home.z + int(e.at[1])))
		if spot.y >= 0:
			put(e.item, spot)


## The north-west cell of the free level two by two cells nearest to column `want`
## within CAMP_REACH of it and off the spawn `home`: at the spawn's level if
## there is one, else within CAMP_RISE levels, else at any level; the ground under them
## levelled. y = -1 when there is none.
func camp_spot(home: Vector3i, want: Vector2i) -> Vector3i:
	for open in [true, false]:
		var spot := _camp_spot(home, want, open)
		if spot.y >= 0:
			return spot
	return Vector3i(0, -1, 0)


## camp_spot's search, with `open`: only where nothing hangs over the spot (_open_above).
func _camp_spot(home: Vector3i, want: Vector2i, open: bool) -> Vector3i:
	for rise in [0, CAMP_RISE, -1]:
		for r in CAMP_REACH + 1:
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) != r:
						continue
					var x := want.x + dx
					var z := want.y + dz
					# The spawn's cell and those round it stay free for the body.
					if x <= home.x + 1 and x + 1 >= home.x - 1 and z <= home.z + 1 and z + 1 >= home.z - 1:
						continue
					var y := _free_at(x, z)
					if y >= 0 and (rise < 0 or absi(y - home.y) <= rise) and (not open or _open_above(x, y, z)):
						_clear(Vector3i(x, y, z))
						return Vector3i(x, y, z)
	return Vector3i(0, -1, 0)


## The cell of the first thing placed of `item`, or null.
func cell_of(item: String) -> Variant:
	for e in things:
		if e.item == item:
			return e.cell
	return null


## The thing placed with its north-west cell at `cell`, or {}: how a request names a
## thing (Requests).
func at(cell: Vector3i) -> Dictionary:
	for e in things:
		if e.cell == cell:
			return e
	for e in lights:
		if e.cell == cell:
			return e
	return {}


## The middle of placed thing `e` in world units: of the cells it fills (see middles), half
## a cell up; for a fire, where its flames burn.
static func center(e: Dictionary) -> Vector3:
	if is_light(e):
		return (Vector3(e.cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	var kind: String = Items.get_item(e.item).get("prop", "none")
	var mid: Vector2 = Vector2.ONE * size_of(e.item) * 0.5
	if middles.has(kind):
		mid = middles[kind][e.get("turn", 0)]
	return (Vector3(e.cell) + Vector3(mid.x, 0.5, mid.y)) * CELL


## The stations (things that store nothing; a fire while it burns) within `reach` world
## units of world point `p`, and those they serve: item id -> true.
func stations_near(p: Vector3, reach: float) -> Dictionary:
	var out := {}
	for e in things:
		if e.items == null and e.lit and center(e).distance_to(p) <= reach:
			out[e.item] = true
			for s: String in Items.get_item(e.item).serves:
				out[s] = true
	return out


## True when a body with its feet at `p` (world units) touches a burning campfire (see
## burning).
func burns(p: Vector3) -> bool:
	return not burning(p).is_empty()


## The burning campfire a body with its feet at `p` (world units) touches the flames
## of, {} for none: its box against or over the logs (FLAMES_HALF, the same box bodies
## stop at), at the fire's height or on top of it; standing on its stones warms (Warmth)
## without burning.
func burning(p: Vector3) -> Dictionary:
	var c := p / CELL
	for e in things:
		if not e.lit or not is_fire(e) or is_hearth(e):
			continue
		var at: Vector3i = e.cell
		if c.y < at.y - Body.HEIGHT or c.y > at.y + 1.0 + SINGE:
			continue
		var reach_x := FLAMES_HALF + Body.HALF_WIDTH + SINGE
		var reach_z := FLAMES_HALF + Body.HALF_DEPTH + SINGE
		if absf(c.x - (at.x + 1.0)) <= reach_x and absf(c.z - (at.z + 1.0)) <= reach_z:
			return e
	return {}


## True for a door (an item with `door`): a tap opens and shuts it (see swing).
static func is_door(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("door", false)


## `who` opens door `e` or shuts it, where the land lets them open doors (Territory); a
## door is not shut on a body in its way. True if it swung.
func swing(who, e: Dictionary) -> bool:
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


## True for stairs (an item with `steps`): taken up at a tap, as a light is.
static func is_steps(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("steps", false)


## True for a thing the light of the sun, the moon and the fires shines through: a window
## (an item with `window`), glass in a frame. A shut door, like a wall, keeps it out.
static func lets_light(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("window", false)


## True for a part of a building taken up at a tap (in the build mode): stairs, a window,
## a fence, a ladder, furniture that stores nothing (a table, a stool, a rug).
static func is_part(e: Dictionary) -> bool:
	var item := Items.get_item(e.item)
	return not is_light(e) and (item.get("steps", false) or item.get("window", false)
		or item.get("ladder", false) or item.get("fence", false) and not item.get("door", false)
		or item.get("furniture", false) and item.get("storage", 0) == 0)


## True for a sign (an item with `sign_lines`): its text is written at a tap (write).
static func is_sign(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("sign_lines", 0) > 0


## Text `text` as sign `item` holds it: each line a player typed made safe
## (Protocol.clean_text's rules: no control or hiding marks) and cut to its `sign_width`
## letters, at most `sign_lines` lines, the empty lines at the end dropped.
static func sign_text(item: String, text: String) -> String:
	var rec := Items.get_item(item)
	var most: int = rec.get("sign_lines", 0)
	var width: int = rec.get("sign_width", 20)
	var lines: Array[String] = []
	for line in text.left(most * (width * 4 + 1)).split("\n"):
		if lines.size() >= most:
			break
		lines.append(Protocol.clean_text(line, width))
	while not lines.is_empty() and lines[-1] == "":
		lines.pop_back()
	return "\n".join(lines)


## The turn of a thing hung on a wall at `cell` (ON_WALL): `turn` (facing who set it down)
## when the cell behind it is solid, else the first turn with a solid cell behind (SIDES,
## the back of turn `t` toward SIDES[t]: its front faces away from the wall).
func wall_turn(cell: Vector3i, turn: int) -> int:
	for k in 4:
		var t := (turn + k) % 4
		var back: Vector3i = cell + SIDES[t]
		if world.is_solid(back.x, back.y, back.z):
			return t
	return turn


## True for a cross (an item with `grave`): it tells who died there (see put_grave).
static func is_grave(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("grave", false)


## Who died at a cross as the cross keeps it (Character.grave_of), whatever a save or the
## server gave: a name of at most GRAVE_NAME letters made safe, a cause, the day, the days
## lived and at most GRAVE_COUNTS counts of that life, numbers only.
static func grave_record(g: Dictionary) -> Dictionary:
	var counts := {}
	var life: Variant = g.get("life")
	if life is Dictionary:
		for k: Variant in life:
			if counts.size() < GRAVE_COUNTS and k is String and (life[k] is float or life[k] is int):
				counts[k.left(GRAVE_NAME)] = maxf(0.0, float(life[k]))
	var day: Variant = g.get("day", 0)
	var days: Variant = g.get("days", 0.0)
	return {"name": Protocol.clean_text(str(g.get("name", "")), GRAVE_NAME), "cause": str(g.get("cause", "")).left(64),
		"day": maxi(0, int(day)) if day is float or day is int else 0,
		"days": maxf(0.0, float(days)) if days is float or days is int else 0.0, "life": counts}


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


## Whether a cross can stand in cell `c` (see put_grave).
func _grave_fits(c: Vector3i, people: Array) -> bool:
	if world.get_cell(c.x, c.y, c.z) != Mat.AIR or not world.is_solid(c.x, c.y - 1, c.z) \
			or world.blockers.has(c) or world.ladders.has(c) or not light_at(c).is_empty() or _in_open_door(c):
		return false
	for who in people:
		if who.has_method("overlaps_cell") and who.overlaps_cell(c):
			return false
	return true


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
	put(e.item, e.cell, null, e.lit, e.get("fuel", -1.0), e.get("by"), turn, e.get("open", false), text)
	world.note_edit(e.cell.x, e.cell.z)


## True for a bed (its item's `bedding`: a mat, a bedroll, slept in, see Character.sleep_rate).
static func is_bed(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("bedding", 1.0) > 1.0


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


## Where a body lies in bed `e` (world units): over its middle, on top of it.
func lying_spot(e: Dictionary) -> Vector3:
	var top := 0.0
	for box in boxes_of(e):
		for b: AABB in (box if box is Array else [box]):
			top = maxf(top, b.end.y)
	var half := size_of(e.item) * 0.5
	return (Vector3(e.cell) + Vector3(half, top, half)) * CELL


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


## The cells thing `item` turned `turn` fills from its north-west cell ({"offsets"}) and
## how many levels high it stands ({"high"}).
func _shape_of(item: String, turn: int) -> Dictionary:
	var probe := {"item": item, "cell": Vector3i.ZERO, "turn": turn}
	var high := 1
	for box in boxes_of(probe):
		for b: AABB in (box if box is Array else [box]):
			high = maxi(high, ceili(b.end.y - 0.01))
	return {"offsets": cells_of(probe), "high": high}


## The build mode (Протокол PROP_PUT_AT): `who` sets thing `id` from the bag down at cell
## `aim` (the cell tapped, within the reach of placing), its front to them: on the free
## cells nearest it at that level (or one up or down). A door or a window cuts its
## opening into a wall: the blocks put there (not natural ground) where it goes are taken
## out and fall as if dug. True if it was set down.
func put_at(who, id: String, aim: Vector3i, top: int, view := -1) -> bool:
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
	var p: Vector3 = who.position / CELL
	if Vector2(aim.x + 0.5 - p.x, aim.z + 0.5 - p.z).length() > Tools.PLACE_REACH or absf(aim.y - p.y) > Tools.PLACE_REACH:
		who.nag("put", "[too_far]")
		return false
	var turn := view if view >= 0 and faces_view(item.id) else turn_facing(Tools.step_of(Vector2(aim.x + 0.5 - p.x, aim.z + 0.5 - p.z)))
	var rest := rest_of(item.id)
	if rest == ON_LADDER:
		# A ladder goes on with the one under it, turned as it is.
		for dy in [1, 2]:
			if world.ladders.has(aim - Vector3i(0, dy, 0)) and not world.ladders.has(aim - Vector3i(0, dy - 1, 0)):
				turn = world.ladders[aim - Vector3i(0, dy, 0)]
	var shape := _shape_of(item.id, turn)
	var n := size_of(item.id)
	var cuts: bool = item.get("door", false) or item.get("window", false)
	# An opening is cut from the level of their feet up: never into the floor they stand on;
	# a hatch's into the floor or the ceiling tapped.
	var cut_from: int = floori(p.y + 0.25) if cuts else NO_CUT
	if rest == IN_FLOOR:
		cut_from = aim.y
	_swap_fences = item.get("door", false) and item.get("fence", false)
	var spot: Variant = _spot_at(who, Vector2(aim.x + 0.5, aim.z + 0.5), aim.y, top, n, shape.offsets, rest, shape.high, cut_from)
	_swap_fences = false
	if spot == null:
		who.nag("put", Lang.line("[no_room_here]", [Items.title(id)]))
		return false
	if item.get("door", false) and item.get("fence", false):
		# A wicket or a gate set into a fence: the segments where it goes back into the bag.
		for o: Vector3i in shape.offsets:
			var f: Dictionary = _fences.get(spot + o, {})
			if not f.is_empty() and is_fence(f):
				if territory != null and not territory.may(who, f.cell, "build"):
					return false
				if who.give(f.item, 1) < 1:
					who.nag("full", "[the_bag_is_full]")
					return false
				_remove(f)
	if rest == ON_WALL:
		turn = wall_turn(spot, turn)
	var opening: Array[Vector3i] = []
	if cuts:
		for o: Vector3i in shape.offsets:
			for k in shape.high:
				var c: Vector3i = spot + o + Vector3i(0, k, 0)
				if territory != null and not territory.may(who, c, "build"):
					return false
				opening.append(c)
	return _set_down(who, item, slot, spot, turn, shape.offsets, opening)


## Takes the block put in cell `c` out for an opening: it falls on the ground there as if dug.
func _cut(c: Vector3i) -> void:
	var m: int = world.get_cell(c.x, c.y, c.z)
	if m == Mat.AIR or m == Mat.WATER:
		return
	var back: String = Mat.RECORDS[m].item
	world.set_cell(c.x, c.y, c.z, Mat.AIR)
	world.note_edit(c.x, c.z)
	if back != "":
		world.heap_drop(back, (Vector3(c) + Vector3(0.5, 0.0, 0.5)) * CELL, 1)
	cell_changed.emit(c)


## Sets thing `item` from bag slot `slot` of `who` down at north-west cell `spot`, turned
## `turn`, filling `offsets` from it, the blocks of `opening` taken out first (a door, a
## window): the land's rights, the hands' stamina, the ground under it levelled. True if
## it was set down.
func _set_down(who, item: Dictionary, slot: int, spot: Vector3i, turn: int, offsets: Array, opening: Array[Vector3i] = []) -> bool:
	var inv = who.inventory
	if territory != null and not territory.may(who, spot, "build"):
		return false
	if item.claims and territory != null and not territory.can_claim(who, spot):
		return false
	if not who.act("place"):
		return false
	for c in opening:
		_cut(c)
	var taken: Array = inv.take_slot(slot, 1)
	for o: Vector3i in offsets:
		if world.is_solid(spot.x + o.x, spot.y - 1, spot.z + o.z):
			_level_ground(spot + o + Vector3i(0, -1, 0))
		_remove_bush(spot + o)
	var by: Variant = who.get("id")
	# A sign taken up with words on it says them again (Inventory.text_of).
	var e := put(item.id, spot, taken[3] if taken.size() > 3 else null, true, -1.0, by if by is int else 0, turn, false, Inventory.text_of(taken))
	world.note_edit(spot.x, spot.z)
	if item.claims and territory != null:
		territory.add_claim(who.get("id") if who.get("id") != null else 0, e, str(who.get("player_name") if who.get("player_name") != null else ""))
	return true


## `who` takes placed thing `e` back into the bag, a thing that stores with what it holds
## (its weight and theirs go to the bag), a sign with its words; not a campfire (see put_out and destroy), and a
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
	var inv = who.inventory
	var full: bool = e.items != null and not e.items.is_empty()
	# A sign keeps its words in the bag (Inventory.text_of): set down again, it says them.
	if (inv.add(e.item, 1, 0, e.items.to_dict()) if full else who.give(e.item, 1, 0, Inventory.NORMAL, e.get("text", ""))) < 1:
		who.nag("full", "[the_bag_is_full]")
		return false
	if full:
		who.say(Lang.line("[1_with_things]", [Items.title(e.item)]))
	_remove(e)
	return true


## True for a thing moved and turned where it stands in the build mode (move): a station,
## a chest, furniture, a sign, a fireplace; not what is set into a building (a door, a
## window, a hatch, stairs, a fence, a ladder), a campfire, a cross or a boundary post.
static func movable(e: Dictionary) -> bool:
	if e.is_empty() or is_light(e) or is_grave(e) or is_fire(e) and not is_hearth(e):
		return false
	var item := Items.get_item(e.item)
	for flag in ["door", "window", "steps", "fence", "ladder", "claims"]:
		if item.get(flag, false):
			return false
	return true


## True for thing `id` set down facing the camera when the client names the view's turn
## (put_from_bag, put_at; the user, 2026-11-13): a station, a chest, furniture, a sign;
## not what is set into a building or against a wall by where the player stands (a door,
## a window, a hatch, stairs, a fence, a ladder, a board on a wall).
static func faces_view(id: String) -> bool:
	var item := Items.get_item(id)
	for flag in ["door", "window", "steps", "fence", "ladder", "wall"]:
		if item.get(flag, false):
			return false
	return item.get("prop", "none") != "none"


## The north-west cell where thing `e` would stand moved to `corner` turned `turn` (see
## move): that cell, or the free one nearest to it at its level, one down or one up, its
## own cells counted free; null when there is none.
func move_spot(who, e: Dictionary, corner: Vector3i, turn: int) -> Variant:
	if not movable(e):
		return null
	var shape := _shape_of(e.item, posmod(turn, 4))
	var offsets: Array[Vector3i] = shape.offsets
	var mid := Vector2.ZERO
	for o: Vector3i in offsets:
		mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
	mid /= maxi(offsets.size(), 1)
	_unblock(e)
	var spot: Variant = _spot_at(who, Vector2(corner.x, corner.z) + mid, corner.y, NO_CUT, size_of(e.item),
		offsets, rest_of(e.item), shape.high)
	_block(e)
	return spot


## `who` moves thing `e` to `corner` (see move_spot) turned `turn` (the same cell and a
## quarter more: turned where it stands), within their reach of placing and where the land
## lets them build at both ends; what it holds, burns or says goes with it, and every copy
## hears of it as of a thing taken and placed (removed, added). True if it moved.
func move(who, e: Dictionary, corner: Vector3i, turn: int) -> bool:
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
	put(e.item, spot, items, e.lit, e.get("fuel", -1.0), e.get("by"), turn, false, e.get("text", ""), e.get("grave", {}))
	world.note_edit(spot.x, spot.z)
	return true


## Puts out campfire `e`: it no longer burns, warms or lets anything be made at it.
func put_out(e: Dictionary) -> void:
	if not is_fire(e) or not e.lit:
		return
	e.lit = false
	lit_changed.emit(e)
	world.note_edit(e.cell.x, e.cell.z)


## `who` lights campfire `e` again for one piece of fuel from the bag (an item with
## `fuel`, a branch), which it then burns on, with what it had left; true if it burns.
func light(who, e: Dictionary) -> bool:
	if not is_fire(e) or e.lit:
		return e.lit
	var fuel := fuel_for(who.inventory)
	if fuel == "" or who.inventory.remove(fuel, 1) < 1:
		who.nag("light", "[to_light_it_you_need]")
		return false
	_add_fuel(e, fuel)
	e.wet = 0.0
	e.lit = true
	lit_changed.emit(e)
	world.note_edit(e.cell.x, e.cell.z)
	return true


## `who` puts one piece of fuel from the bag on campfire `e` that burns (see fuel_for):
## it burns that much longer, up to its `fuel_max`; true if it was fed. One put out is
## lit (see light).
func feed(who, e: Dictionary) -> bool:
	if not is_fire(e):
		return false
	if not e.lit:
		return light(who, e)
	var most: float = Items.get_item(e.item).fuel_max
	if most <= 0.0:
		return false
	if most - e.fuel < FUEL_ROOM:
		who.nag("fuel", "[the_campfire_is_already_burning]")
		return false
	var fuel := fuel_for(who.inventory)
	if fuel == "" or who.inventory.remove(fuel, 1) < 1:
		who.nag("fuel", "[nothing_to_add_needs_a]")
		return false
	_add_fuel(e, fuel)
	world.note_edit(e.cell.x, e.cell.z)
	return true


## The fuel in bag `inv` to put on a fire: the shortest burning (a branch before a log,
## which is worth more as timber); "" when the bag holds none.
static func fuel_for(inv) -> String:
	var shortest := ""
	for id: String in Items.IDS:
		var t := Items.fuel_time(id)
		if t > 0.0 and inv.count(id) > 0 and (shortest == "" or t < Items.fuel_time(shortest)):
			shortest = id
	return shortest


func _add_fuel(e: Dictionary, fuel: String) -> void:
	var most: float = Items.get_item(e.item).fuel_max
	if most > 0.0:
		e.fuel = minf(most, float(e.get("fuel", 0.0)) + Items.fuel_time(fuel))
		fuel_changed.emit(e)


## The share of what fire `e` holds that it has left to burn, 0..1 (1 for one that burns
## for ever).
static func fuel_share(e: Dictionary) -> float:
	var most: float = Items.get_item(e.item).get("fuel_max", 0.0)
	return 1.0 if most <= 0.0 else clampf(float(e.get("fuel", 0.0)) / most, 0.0, 1.0)


## True when nothing keeps the rain off fire `e`: a column of its cells has no roof above
## it (WorldData.roof_level), its chunk in memory.
func _in_rain(e: Dictionary) -> bool:
	var c: Vector3i = e.cell
	if world.chunk_at(c.x, c.z) == null:
		return false
	for k: Vector3i in cells_of(e):
		if world.roof_level(k.x, k.z) < c.y:
			return true
	return false


## Destroys campfire `e` that has been put out: nothing is left of it (a fireplace is
## taken up instead, see take_up).
func destroy(e: Dictionary) -> bool:
	if not is_fire(e) or e.lit or is_hearth(e):
		return false
	_remove(e)
	return true


## Takes placed thing `e` out of the world.
func _remove(e: Dictionary) -> void:
	_forget(e)
	world.note_edit(e.cell.x, e.cell.z)


## Lets go of thing `e`: its cells are free again, it is told gone (removed).
func _forget(e: Dictionary) -> void:
	if is_light(e):
		lights.erase(e)
		removed.emit(e)
		return
	_unblock(e)
	if e.items == chest_items:
		chest_items = null
	things.erase(e)
	var fenced: Array[Vector3i] = []
	if Items.get_item(e.item).get("fence", false):
		for c: Vector3i in _fences.keys():
			if _fences[c] == e:
				_fences.erase(c)
				fenced.append(c)
	removed.emit(e)
	for c in fenced:
		_rejoin_around(c)


## The north-west cell of a thing's square of `n` by `n` cells in front of `who` where it
## can be placed (see _fits; `offsets` the cells it fills from there, `steps` for stairs),
## the nearest to a cell beyond its middle ahead, at the feet's level or a cell below or
## above; null if none.
func _spot_in_front(who, top: int, n := 2, offsets: Array[Vector3i] = [], rest := ON_GROUND, high := 1) -> Variant:
	if offsets.is_empty():
		for dz in n:
			for dx in n:
				offsets.append(Vector3i(dx, 0, dz))
	var feet: Vector3i = who.feet()
	var s: Vector2i = who.facing_step()
	# The cells it fills are aimed at, not its square: a door or a window two or three
	# cells wide fills only a row of it, set into a wall a step ahead.
	var mid := Vector2.ZERO
	var lo := Vector2i(n, n)
	var hi := Vector2i(-1, -1)
	for o: Vector3i in offsets:
		mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
		lo = lo.min(Vector2i(o.x, o.z))
		hi = hi.max(Vector2i(o.x, o.z))
	mid /= offsets.size()
	# Aimed at the cells right in front: their middle as deep ahead as half of them, and a
	# half cell more from the feet's middle.
	var deep := (hi.x - lo.x + 1) if s.x != 0 else (hi.y - lo.y + 1)
	var ahead := deep * 0.5 + 0.5
	var aim := Vector2(feet.x + 0.5 + s.x * ahead, feet.z + 0.5 + s.y * ahead)
	return _spot_at(who, aim, feet.y, top, n, offsets, rest, high)


## The north-west cell of the free spot for a thing filling `offsets` (see
## _spot_in_front) whose filled cells' middle is nearest column point `aim` (cells), at
## level `level`, one down or one up; blocks put there at level `cut_from` or higher may
## be taken out for it (a door, a window, see put_at). Null for none.
func _spot_at(who, aim: Vector2, level: int, top: int, n: int, offsets: Array[Vector3i], rest: int, high: int, cut_from := NO_CUT) -> Variant:
	var mid := Vector2.ZERO
	for o: Vector3i in offsets:
		mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
	mid /= maxi(offsets.size(), 1)
	var base := Vector2i(floori(aim.x), floori(aim.y))
	var corners: Array[Vector2i] = []
	for dz in range(-n - 1, 3):
		for dx in range(-n - 1, 3):
			corners.append(base + Vector2i(dx, dz))
	corners.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + mid).distance_squared_to(aim) < (Vector2(b) + mid).distance_squared_to(aim))
	# A hatch goes only into the floor or the ceiling tapped.
	var levels: Array = [0] if rest == IN_FLOOR else [0, -1, 1]
	for c in corners.slice(0, 6):
		for dy: int in levels:
			var corner := Vector3i(c.x, level + dy, c.y)
			if _fits(who, corner, top, offsets, rest, high, cut_from):
				return corner
	return null


## Whether the cells `offsets` from `corner` (two by two when none are given) are free
## (no cell, no other thing, ladder or light, not `who`), at or below level `top`, and rest
## as `rest` says (ON_GROUND on solid ground, see ON_GROUND), with air over them for a
## thing `high` cells tall (a door); stairs may stand on air, as blocks are laid.
func _fits(who, corner: Vector3i, top: int, offsets: Array[Vector3i] = [], rest := ON_GROUND, high := 1, cut_from := NO_CUT) -> bool:
	if offsets.is_empty():
		offsets = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)]
	for o: Vector3i in offsets:
		var c := corner + o
		if not _open(c, cut_from) or not _rests(c, rest) \
				or who.overlaps_cell(c) or c.y > top or world.blockers.has(c) and not _swappable(c) or world.ladders.has(c) \
				or not light_at(c).is_empty() or _in_open_door(c):
			return false
		for k in range(1, high):
			if not _open(c + Vector3i(0, k, 0), cut_from) or world.blockers.has(c + Vector3i(0, k, 0)):
				return false
	return true


## Whether the thing in cell `c` is a fence a wicket or a gate set down now takes the
## place of (see put_at).
func _swappable(c: Vector3i) -> bool:
	return _swap_fences and _fences.has(c) and is_fence(_fences[c])


## Whether a thing resting as `rest` (ON_GROUND…) can stand in cell `c`: on solid ground
## (for a ladder on a ladder too), anywhere, or in a floor (a solid cell beside it).
func _rests(c: Vector3i, rest: int) -> bool:
	match rest:
		ANYWHERE:
			return true
		ON_LADDER:
			return world.is_solid(c.x, c.y - 1, c.z) or world.ladders.has(c + Vector3i.DOWN)
		IN_FLOOR, ON_WALL:
			for d: Vector3i in SIDES:
				if world.is_solid(c.x + d.x, c.y, c.z + d.z):
					return true
			return false
	return world.is_solid(c.x, c.y - 1, c.z)


## Whether cell `c` is air, or a block put there that an opening takes out (at level
## `cut_from` or higher: an opening is cut into walls, not into the floor under it).
func _open(c: Vector3i, cut_from: int) -> bool:
	var m: int = world.get_cell(c.x, c.y, c.z)
	return m == Mat.AIR or c.y >= cut_from and m != Mat.WATER and not world.is_natural(c.x, c.y, c.z)


## True when cell `c` is one of those a door standing open fills when shut (it frees them
## while open, see opened_boxes): nothing is set down in a doorway.
func _in_open_door(c: Vector3i) -> bool:
	for e: Dictionary in things:
		if e.get("open", false) and e.cell.y == c.y:
			var shut := e.duplicate()
			shut.open = false
			if cells_of(shut).has(c):
				return true
	return false


## The north-west cell of two by two free cells on ground at one level near the world
## point `p`, the ground under them levelled; y = -1 when there is no such spot.
func spot_near(p: Vector3) -> Vector3i:
	var x := floori(p.x / CELL)
	var z := floori(p.z / CELL)
	var y := _free_at(x, z)
	if y < 0:
		return Vector3i(0, -1, 0)
	_clear(Vector3i(x, y, z))
	return Vector3i(x, y, z)


## The level of the ground of the two by two cells from column x, z when they are free
## (air on solid ground at one level, no other thing there), else -1.
func _free_at(x: int, z: int) -> int:
	var y: int = world.surface_y(x, z)
	if y <= 0:
		return -1
	for dz in 2:
		for dx in 2:
			if world.get_cell(x + dx, y, z + dz) != Mat.AIR or not world.is_solid(x + dx, y - 1, z + dz) \
					or world.blockers.has(Vector3i(x + dx, y, z + dz)):
				return -1
	return y


## Whether nothing hangs over the two by two cells at (x, y, z) or stands between them
## and the camera: no leaves, trunk or rock CAMP_SKY levels up, with a cell round them,
## straight over them (from two levels up) and along the line the view looks down by at
## 3/4 (a level up is a cell south, PixelView.VIEW_DIR, the turn at the start). A thing
## there is seen from the start.
func _open_above(x: int, y: int, z: int) -> bool:
	for dy in range(1, CAMP_SKY + 1):
		var yy := y + dy
		if yy >= world.size_y:
			break
		for dx in range(-1, 3):
			for dz in range(-1, 3):
				if world.get_cell(x + dx, yy, z + dz + dy) != Mat.AIR:
					return false
				if dy >= 2 and world.get_cell(x + dx, yy, z + dz) != Mat.AIR:
					return false
	return true


## Levels the ground under the two by two cells from `corner` and takes the bushes off them.
func _clear(corner: Vector3i) -> void:
	for dz in 2:
		for dx in 2:
			_level_ground(corner + Vector3i(dx, -1, dz))
			_remove_bush(corner + Vector3i(dx, 0, dz))


## Things stand on level ground: a slope under them becomes a whole cube.
func _level_ground(cell: Vector3i) -> void:
	if world.slope_mask(cell.x, cell.y, cell.z) != WorldData.FULL:
		world.set_natural(cell.x, cell.y, cell.z, false)
		cell_changed.emit(cell)


## Takes the bush on `cell` out of the world.
func _remove_bush(cell: Vector3i) -> void:
	if not world.bushes.has(cell):
		return
	world.remove_bush(cell)
	cell_changed.emit(cell)


# --- Lights set down --------------------------------------------------------------------

## True for item `id` that is set down as a light on a cell of its own: it gives light
## (`light`) and is no thing placed on cells (`prop`).
static func is_light_item(id: String) -> bool:
	var item := Items.get_item(id)
	return item.get("light", 0.0) > 0.0 and item.get("prop", "none") == "none"


## True for a light set down (see lights).
static func is_light(e: Dictionary) -> bool:
	return e.get("light", false)


## Sets light `item` down on `cell`, burned `burnt` seconds already.
func put_light(item: String, cell: Vector3i, burnt := 0.0) -> Dictionary:
	var e := {"item": item, "cell": cell, "burnt": burnt, "light": true, "items": null, "lit": true}
	lights.append(e)
	added.emit(e)
	return e


## The light standing in `cell`, {} for none.
func light_at(cell: Vector3i) -> Dictionary:
	for e in lights:
		if e.cell == cell:
			return e
	return {}


## The cell in front of `who` a light can stand in (see _light_fits): one step ahead,
## else two, at the feet's level or a cell below or above; null if none.
func light_spot(who, top: int) -> Variant:
	var feet: Vector3i = who.feet()
	var s: Vector2i = who.facing_step()
	for ahead: int in [1, 2]:
		for dy: int in [0, -1, 1]:
			var c := Vector3i(feet.x + s.x * ahead, feet.y + dy, feet.z + s.y * ahead)
			if _light_fits(who, c, top):
				return c
	return null


## Whether a light can stand in `cell`: air over solid ground, no higher than `top`,
## clear of `who`, of the things and of the other lights.
func _light_fits(who, cell: Vector3i, top: int) -> bool:
	if cell.y > top or world.get_cell(cell.x, cell.y, cell.z) != Mat.AIR or not world.is_solid(cell.x, cell.y - 1, cell.z):
		return false
	if who.overlaps_cell(cell) or world.blockers.has(cell) or world.ladders.has(cell) or not light_at(cell).is_empty():
		return false
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


## The lights and the fires burn `delta` seconds in a rain of strength `rain` (0 for
## none, 1 a downpour; Clock.WEATHERS): a light that has burned its Items.burns is gone,
## and so is one whose cell was filled or the ground under it dug (it goes out); a fire
## goes out once its fuel has burned, or after RAIN_OUT seconds in the rain under the
## open sky in a heavy rain (see _in_rain). The session's step (only where the chunk is in memory are
## cells asked).
func step(delta: float, rain := 0.0) -> void:
	for e: Dictionary in things:
		if e.lit and e.has("fuel"):
			_burn_fire(e, delta, rain)
	for e: Dictionary in lights.duplicate():
		e.burnt += delta
		var lasts := Items.burns(e.item)
		var c: Vector3i = e.cell
		if lasts > 0.0 and e.burnt >= lasts:
			_remove(e)
			continue
		# Only a chunk made whole is asked: one still being generated reads air under it.
		var chunk = world.chunk_at(c.x, c.z)
		if chunk != null and chunk.final and (world.get_cell(c.x, c.y, c.z) != Mat.AIR or not world.is_solid(c.x, c.y - 1, c.z)):
			_remove(e)


## What the things that store hold spoils `days` of game time (Inventory.spoil), slower
## in winter and under a roof: a chest in a cellar or a cave keeps food longest. The
## session's step.
func spoil(days: float, winter: bool) -> void:
	for e: Dictionary in things:
		if e.items != null:
			var c: Vector3i = e.cell
			var roofed: bool = world.chunk_at(c.x, c.z) != null and world.roof_level(c.x, c.z) > c.y
			e.items.spoil(days, Inventory.spoil_rate(winter, roofed) * Items.get_item(e.item).get("keeps", 1.0))


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


func _burn_fire(e: Dictionary, delta: float, rain: float) -> void:
	if Items.get_item(e.item).fuel_max <= 0.0:
		return
	var was: float = e.fuel
	e.fuel = maxf(0.0, was - delta)
	if rain >= RAIN_HEAVY and _in_rain(e):
		e.wet += delta
	else:
		e.wet = maxf(0.0, e.wet - delta)
	if e.fuel <= 0.0 or e.wet >= RAIN_OUT:
		e.wet = 0.0
		put_out(e)
		fuel_changed.emit(e)
	elif floori(e.fuel / FUEL_TELL) != floori(was / FUEL_TELL):
		fuel_changed.emit(e)
