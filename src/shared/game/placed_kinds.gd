extends RefCounted
## Placed things, part 1 of a chain (placed_kinds ← placed_store ← placed_spots ← placed_build ←
## placed_fires ← placed; callers preload placed.gd, see it for the whole): what a kind of thing
## is by its item (is_fire, is_door, is_opening, ...), the shapes of the models (footprints,
## voxels turned, opened, shut) and the records saved. Static, read from the content; a part calls
## only itself and the parts before it.

const Mat := preload("res://src/shared/content/materials.gd")
const Items := preload("res://src/shared/content/items.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const CELL := WorldData.CELL
## The campfire of the camp by the spawn of a new world (see Starts), the place to come
## back to after death.
const CAMPFIRE := "core:campfire"
const MELT_STAGES := 4
## How high a fence, a wicket or a gate is solid, in cells over its floor: over the
## jump of a body (Body.JUMP_SPEED, about 1.45 cells), so nothing jumps it.
const FENCE_TOP := 2.0
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
## The longest name a cross keeps, and the most counts of a life (Character.grave_of).
const GRAVE_NAME := 32
const GRAVE_COUNTS := 16
## How far from its north-west cell (cells, each way) the blocks an opening remembers it
## cut may lie (cut_from_list): the biggest door or window is three cells across.
const CUT_REACH := 4
## Thing `e` (see things) was placed, as the save had it or anew.
signal added(e: Dictionary)
## Thing `e` was taken out of the world.
signal removed(e: Dictionary)
## Campfire `e` was put out or lit again (its `lit`).
signal lit_changed(e: Dictionary)
## What campfire `e` has left to burn (its `fuel`) changed: it was fed, or another
## FUEL_TELL seconds of it burned.
signal fuel_changed(e: Dictionary)
## The water rain catcher `e` holds (its `water`) changed: it was drawn from, or another
## WATER_TELL of rain ran in.
signal water_changed(e: Dictionary)
## Thing of snow `e` melted down to a new stage (melt_stage; see melt).
signal melt_changed(e: Dictionary)
## Thing of snow `e` melted away: gone (removed), its item's `melts_to` left on its cell
## (WorldActions.leave_melted).
signal melted(e: Dictionary)
## Campfire `e` burnt down to its end (not put out): it leaves its `ashes`
## (WorldActions.leave_ashes).
signal burnt_down(e: Dictionary)
## Door `e` was opened or shut (its `open`).
signal opened(e: Dictionary)
## A cell under a thing was levelled or a bush there taken away: its chunks change.
signal cell_changed(cell: Vector3i)
## Fence `e` joins its neighbours anew (its `join` changed): drawn again.
signal joined(e: Dictionary)
## The cells a side of the square a thing of a prop kind takes (see read_footprints):
## kind -> n; 2 for a kind not read.
static var sizes := {}
## The middle of the cells a thing of a prop kind fills, shut, for each turn, in cells from
## the north-west corner of its square across the ground: kind -> [Vector2 for turn 0, 1,
## 2, 3] (see center: a window three cells wide in the north row of its square is tapped
## and heard there, not in the square's middle); the square's middle for a kind not read.
static var middles := {}
## Voxels a door's leaf is moved south shut (shut_voxels), from the north edge of its cells
## to the middle of their depth.
const DOOR_SHUT := 3


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


## The boxes of the model in `img`, a row of square slices (the image's height wide),
## one per level from the ground up, a pixel of any alpha the voxel at its x and z (z
## down the slice), the slice's corner at the thing's north-west cell.
static func footprint_of_image(img: Image) -> Array:
	return footprint(voxels_of_image(img), maxi(1, ceili(img.get_height() / 8.0)))


## The voxels of the model in `img` (see footprint_of_image).
## Voxels `voxels` of the model of item `rec` as it stands shut: a door's leaf, drawn at the
## north edge of its row of cells (z 0, 1; open_voxels swings it from there against the
## jamb), moves DOOR_SHUT voxels south, to the middle between the faces of the wall it stands
## in, as a window's is drawn (user 2026-11-27). A hatch, a wicket and a gate as drawn.
static func shut_voxels(rec: Dictionary, voxels: Array[Vector3i]) -> Array[Vector3i]:
	if not is_wall_door(rec):
		return voxels
	var out: Array[Vector3i] = []
	for p: Vector3i in voxels:
		out.append(p + Vector3i(0, 0, DOOR_SHUT))
	return out


## Whether item `rec` is a door set into a wall (not a hatch, a wicket or a gate).
static func is_wall_door(rec: Dictionary) -> bool:
	return rec.get("door", false) and not rec.get("hatch", false) and not rec.get("fence", false)


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


## Thing `e` as plain data (one of to_list): {"item", "cell": [x, y, z], "items" what it
## holds (Inventory.to_dict) if it stores, "out" true for a fire put out, "fuel" the
## seconds a fire has left, "water" a rain catcher holds, "melt" how far a thing of snow has melted (0..1), "by" who put it from their bag, "turn" when it is turned,
## "open" for a door open, "wreath" the wreath hung on a door, "text" for a sign written, "grave" for a cross,
## "cut" for an opening: the blocks it took out, see cut_from_list}.
static func record(e: Dictionary) -> Dictionary:
	var c: Vector3i = e.cell
	var d := {"item": e.item, "cell": [c.x, c.y, c.z]}
	if is_light(e):
		d.burnt = e.burnt
		if e.get("turn", 0) != 0:
			d.turn = e.turn
		return d
	if e.items != null:
		d.items = e.items.to_dict()
	if not e.lit:
		d.out = true
	if e.has("fuel"):
		d.fuel = snappedf(e.fuel, 0.1)
	if e.has("water"):
		d.water = snappedf(e.water, 0.1)
	if e.has("melt"):
		d.melt = snappedf(e.melt, 0.001)
	if e.has("by"):
		d.by = e.by
	if e.get("turn", 0) != 0:
		d.turn = e.turn
	if e.get("open", false):
		d.open = true
	if e.get("wreath", "") != "":
		d.wreath = e.wreath
	if e.get("text", "") != "":
		d.text = e.text
	if e.has("grave"):
		d.grave = e.grave.duplicate(true)
	if e.has("cut"):
		var cut: Array = []
		for o: Vector3i in e.cut:
			cut.append([o.x, o.y, o.z, e.cut[o]])
		d.cut = cut
	return d


## The blocks an opening took out (`cut`, see record: [[x, y, z, material id], …]) as a
## save or a copy keeps them: offset -> material id; those of materials no longer known,
## or out of its cells' reach, left out.
static func cut_from_list(list: Array) -> Dictionary:
	var out := {}
	for c in list:
		if not (c is Array and c.size() == 4 and c[3] is String and Mat.index(c[3]) >= 0):
			continue
		var o := Vector3i.ZERO
		var ok := true
		for k in 3:
			if (c[k] is int or c[k] is float and is_finite(c[k])) and absf(c[k]) <= CUT_REACH:
				o[k] = int(c[k])
			else:
				ok = false
		if ok:
			out[o] = c[3]
	return out


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


## True for a door (an item with `door`): a tap opens and shuts it (see swing).
static func is_door(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("door", false)


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


## True for a bed (its item's `bedding`: a mat, a bedroll, slept in, see Character.sleep_rate).
static func is_bed(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("bedding", 1.0) > 1.0


## True for a seat (its item's `seat` over 1: a stool, sat on at a tap, Character.sit_on).
static func is_seat(e: Dictionary) -> bool:
	return not is_light(e) and Items.get_item(e.item).get("seat", 1.0) > 1.0


## The way thing `e` faces across the ground (a column step): its front, towards the
## one who set it down (turn_facing); a seat is sat on facing so, its back behind.
static func front_of(e: Dictionary) -> Vector2i:
	return _turned(Vector2i(0, 1), e.get("turn", 0))


## The way the head of bed `e` lies across the ground (a column step): west as its
## model is drawn (turn 0), turned with it.
static func head_of(e: Dictionary) -> Vector2i:
	return _turned(Vector2i(-1, 0), e.get("turn", 0))


## Step `v` turned `turn` quarters clockwise seen from above, as turn_voxels turns.
static func _turned(v: Vector2i, turn: int) -> Vector2i:
	for i in posmod(turn, 4):
		v = Vector2i(-v.y, v.x)
	return v


## Whether cell `aim` is within the reach of placing of `who` (Tools.PLACE_REACH): a thing
## is set down there or an opening moved there (put_at, _move_opening); the build mode shows
## none held up farther.
static func in_reach(who, aim: Vector3i) -> bool:
	var p: Vector3 = who.position / CELL
	return Vector2(aim.x + 0.5 - p.x, aim.z + 0.5 - p.z).length() <= Tools.PLACE_REACH and absf(aim.y - p.y) <= Tools.PLACE_REACH


## True for a thing moved and turned where it stands in the build mode (move): a station,
## a chest, furniture, a sign, a fireplace, a light set down, and a door, a window or a
## hatch along its wall (is_opening); not stairs, a fence, a wicket, a gate, a ladder, a
## campfire, a cross or a boundary post.
static func movable(e: Dictionary) -> bool:
	if e.is_empty() or is_grave(e) or is_fire(e) and not is_hearth(e):
		return false
	if is_light(e) or is_opening(e.item):
		return true
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


## True for item `id` set into the blocks of a building, which cuts its opening out of
## them (put_at) and remembers what it cut (`cut`, cut_of): a door, a window, a hatch; not
## a wicket or a gate (set into a fence).
static func is_opening(id: String) -> bool:
	var item := Items.get_item(id)
	return (item.get("door", false) or item.get("window", false)) and not item.get("fence", false)


## The item that builds material `id` (the material's `item`, when that places it), ""
## for none.
static func _placer(id: String) -> String:
	var m := Mat.index(id)
	if m < 0:
		return ""
	var item: String = Mat.RECORDS[m].item
	return item if item != "" and Mat.index(Items.get_item(item).get("place", "")) == m else ""


## The fuel in bag `inv` to put on a fire: the shortest burning (a branch before a log,
## which is worth more as timber); "" when the bag holds none.
static func fuel_for(inv) -> String:
	var shortest := ""
	for id: String in Items.IDS:
		var t := Items.fuel_time(id)
		if t > 0.0 and inv.count(id) > 0 and (shortest == "" or t < Items.fuel_time(shortest)):
			shortest = id
	return shortest


## The share of what fire `e` holds that it has left to burn, 0..1 (1 for one that burns
## for ever).
static func fuel_share(e: Dictionary) -> float:
	var most: float = Items.get_item(e.item).get("fuel_max", 0.0)
	return 1.0 if most <= 0.0 else clampf(float(e.get("fuel", 0.0)) / most, 0.0, 1.0)


## True for item `id` that is set down as a light on a cell of its own: it gives light
## (`light`) and is no thing placed on cells (`prop`).
static func is_light_item(id: String) -> bool:
	var item := Items.get_item(id)
	return item.get("light", 0.0) > 0.0 and item.get("prop", "none") == "none"


## True for a light set down (see lights).
static func is_light(e: Dictionary) -> bool:
	return e.get("light", false)


## The stage thing of snow `e` is drawn in, 0 (whole) to MELT_STAGES - 1; 0 for a thing
## that does not melt.
static func melt_stage(e: Dictionary) -> int:
	return mini(MELT_STAGES - 1, floori(clampf(float(e.get("melt", 0.0)), 0.0, 1.0) * MELT_STAGES))


## Whether `e` is a rain catcher (its item's `rain_water`).
static func is_catcher(e: Dictionary) -> bool:
	return e.has("water")


## The share of its `rain_water` rain catcher `e` holds, 0..1.
static func water_share(e: Dictionary) -> float:
	var most: float = Items.get_item(e.item).get("rain_water", 0.0)
	return 0.0 if most <= 0.0 else clampf(float(e.get("water", 0.0)) / most, 0.0, 1.0)
