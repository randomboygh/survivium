extends RefCounted
## What a character's hands do to the world (plan/design/character.md, "Взаимодействие с
## миром"): digging cells, cutting the grass, chopping and felling trees, placing blocks,
## the action button's work in front of the body, taking things off the ground, berries
## and branches off bushes and trees, planting, and the spring that gives them back. What
## each tool can do is Tools; these are the rules the server will run.
##
## `who` is the one acting (Character on the client) and gives: `inventory` (Inventory),
## `position` (the body, in world units), `held_back` (where it threw things away),
## `feet()` (the cell of its feet), `facing_step()` (the column step it faces),
## `moving()`, `overlaps_cell(cell)`, `held()` (the item in the hand in use), `tool()`
## (that item's record as a tool, Tools.of), `brush()` (one of Tools.BRUSHES), `act(action)`
## (pays the stamina, false when too tired), `give(id, n, worn)` (into the bag, returns how
## many fit), `use_tool()` (wears the tool in use), `nag(reason, text)` and `say(text)`
## (messages to the player).
##
## A swing that did something returns {"swing": seconds until the hands can swing again,
## "work": the work to play (see Player.work), "time": its seconds, "at": what it is done
## to, in world units}; one that did nothing returns {}, or only {"swing"} for a short
## wait. What changes in the world is told through the signals, for the views (the
## chunks, the things on the ground) and later the network.

const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Seconds between two placings of a stroke, and of the action button (slower, so a
## bridge grows a cell at a time while walking).
const PLACE_SWING := 0.1
const FRONT_PLACE_SWING := 0.25
## The wait after the action button found nothing to do, in seconds.
const IDLE_SWING := 0.3
## Things lying this close to the one taken (world units) come along with it.
const PILE := 0.8
## Things lying this close to the feet (world units) are taken by themselves.
const PICKUP := 1.6
## How far from the body a thing on the ground or a placed thing is taken or used, in
## world units (ten cells, as Tools.PLACE_REACH; Gathering.REACH), and what the rules
## let pass over it and over a tool's reach: the body the server knows lags a step
## behind the player's (С6, plan/architecture/server.md).
const HAND_REACH := 5.0
const REACH_SLACK := 1.5
## Cells a crown spreads round its trunk at most, with the slack (gathering from a tree).
const TREE_SPREAD := 6
## What is taken by themselves (the setting «Автоподбор»): everything, only things the
## bag already has, only food, nothing. The sack of a death is taken in all but the last.
enum { PICKUP_ALL, PICKUP_KNOWN, PICKUP_FOOD, PICKUP_NONE }
## Berries and branches knocked off a bush land this far from it at most (world units).
const SCATTER := 0.45
## What the action button gathers first (see front_choice): food, then seeds, then the
## rest, and only then it digs.
const FOOD_RANK := 0
const SEED_RANK := 1
const OTHER_RANK := 2
const DIG_RANK := 3
const SPRING := 0
const AUTUMN := 2
const WINTER := 3

## Cell `cell` changed (dug, filled, cut down to another material, a tree fell through it,
## a bush on it went): what is drawn around it is built again.
signal cell_changed(cell: Vector3i)
## What is drawn on chunk `key` changed while its cells did not (berries picked, grass
## cut short, a bush planted).
signal looks_changed(key: Vector2i)
## The things lying on the ground in chunk `key` (WorldData.drops) changed.
signal drops_changed(key: Vector2i)
## A thing lying at `from` flew into the bag by itself (see pick_up_near).
signal taken(id: String, from: Vector3)

var world
## The clock: `season` (0 spring .. 3 winter) and `day`.
var clock
## The rules of play (Rules): `free_build` (building takes nothing from the bag, digging
## gives nothing).
var rules
## Damage each tree being chopped has taken, by its trunk's column (not saved).
var chops := {}
## The animals (Wildlife) blows land on; null where there are none (a client's copy of
## the rules), and then no blow lands.
var wildlife


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


func _changed(cell: Vector3i) -> void:
	bushes_lose_ground(world, cell)
	cell_changed.emit(cell)


# --- Trees -------------------------------------------------------------------------

func _is_trunk(cell: Vector3i) -> bool:
	return world.get_cell(cell.x, cell.y, cell.z) == Mat.LOG and world.trees.has(Vector2i(cell.x, cell.z))


## The trunk's column of the tree that `cell` is part of: a log of its trunk, or leaves
## of its crown (whose nearest trunk it is); null for anything else.
func tree_of(cell: Vector3i) -> Variant:
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	if m == Mat.LOG:
		return Vector2i(cell.x, cell.z) if world.trees.has(Vector2i(cell.x, cell.z)) else null
	if m != Mat.LEAVES:
		return null
	var best: Variant = null
	var best_d := Trees.TREE_REACH * Trees.TREE_REACH * 2 + 1
	var r := Trees.TREE_REACH
	for tz in range(cell.z - r, cell.z + r + 1):
		for tx in range(cell.x - r, cell.x + r + 1):
			var at := Vector2i(tx, tz)
			var d := (at - Vector2i(cell.x, cell.z)).length_squared()
			if d < best_d and world.trees.has(at) and world.log_col(tx, tz) != 0:
				best_d = d
				best = at
	return best


## The cell of tree `col`'s trunk an axe of `who` hits: the lowest log at the level of
## its feet or above, else the lowest.
func trunk_cell(who, col: Vector2i) -> Vector3i:
	var logs: int = world.log_col(col.x, col.y)
	var feet: Vector3i = who.feet()
	var from := maxi(0, feet.y - 1)
	var above := logs & ~((1 << from) - 1)
	var bits := above if above != 0 else logs
	return Vector3i(col.x, WorldData.level_of(bits & -bits), col.y)


## A hit with the axe at the tree whose trunk holds `cell`; it falls when the hits add
## up to its species' `hits`.
func chop(who, cell: Vector3i) -> Dictionary:
	var t: Dictionary = who.tool()
	if not Tools.can_chop(t):
		who.nag("tool", "Дерево рубят топором")
		return {}
	if not _is_trunk(cell) or not who.act("chop"):
		return {}
	who.use_tool()
	var col := Vector2i(cell.x, cell.z)
	var s: Dictionary = Trees.SPECIES[world.trees[col]]
	chops[col] = chops.get(col, 0) + maxi(1, t.power)
	var done := _work(Tools.swing_time(t, Mat.LOG), "", (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL, Mat.LOG)
	if chops[col] < s.hits:
		who.say("%s: осталось ударов %d" % [s.title, ceili((s.hits - chops[col]) / float(maxi(1, t.power)))])
		return done
	chops.erase(col)
	fell(who, cell)
	return done


## Fells the tree whose trunk holds `cell`, away from `who`; false if it is no trunk of
## a tree.
func fell(who, cell: Vector3i) -> bool:
	var at: Vector3 = who.position
	var away := Vector2(cell.x + 0.5, cell.z + 0.5) * CELL - Vector2(at.x, at.z)
	var before := {}
	for key in world.drops:
		before[key] = world.drops[key].size()
	var gone: Array[Vector3i] = Trees.fell(world, cell, away)
	if gone.is_empty():
		return false
	who.note("trees")
	# Each column once, at its lowest changed cell, is enough for the chunks, the roof
	# map and the minimap.
	var cols := {}
	for c in gone:
		var col := Vector2i(c.x, c.z)
		if not cols.has(col) or c.y < cols[col].y:
			cols[col] = c
	for col in cols:
		_changed(cols[col])
	for key in world.drops:
		if world.drops[key].size() != before.get(key, 0):
			drops_changed.emit(key)
	return true


# --- Digging and cutting the grass ----------------------------------------------------

## Works at `cell`, tapped on its face `normal`, with the hand in use: an axe chops the
## tree whose trunk or crown it is, bare hands gather from that tree, hands, a sword or a
## scythe cut the grass on top of it, else the tool digs as many cells around it as it
## takes in a swing.
func dig_at(who, cell: Vector3i, normal: Vector3i) -> Dictionary:
	if Tools.shoots(Tools.weapon(who.held())):
		return shoot(who, (Vector3(cell) + Vector3(0.5, 1.0, 0.5)) * CELL)
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	if cell.y == 0 or m == Mat.AIR:
		return {}
	var t: Dictionary = who.tool()
	if too_far(who, cell, t.reach):
		who.nag("far", "Слишком далеко")
		return {}
	var tree: Variant = tree_of(cell)
	if tree != null:
		if Tools.can_chop(t):
			return chop(who, trunk_cell(who, tree))
		if Tools.can_gather(t):
			if gather(who, {"tree": tree}):
				return _work(t.swing, "", (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL, Mat.LEAVES)
			return {}
		if m == Mat.LOG:
			who.nag("tool", "Дерево рубят топором")
			return {}
	if Tools.mows(t) and can_mow(cell, t):
		return mow_swing(who, mow_targets(who, [cell], t))
	if not Tools.can_dig(t, m):
		# A sword digs nothing: at the ground it swings all the same, as at the air.
		if t.tool == "sword":
			return swing_air(who, (Vector3(cell) + Vector3(0.5, 1.0, 0.5)) * CELL)
		who.nag("tool", Tools.why_not(t, m))
		return {}
	return dig(who, dig_targets(who, Tools.area_cells(cell, normal), t), Tools.swing_time(t, m))


## The first cells of `order` the tool `t` of `who` can dig, as many as it takes in a
## swing (`n` when given).
func dig_targets(who, order: Array[Vector3i], t: Dictionary, n := -1) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in order:
		if out.size() >= (t.area if n < 0 else n):
			break
		var m: int = world.get_cell(c.x, c.y, c.z)
		if c.y > 0 and m != Mat.AIR and Tools.can_dig(t, m) and tree_of(c) == null and not too_far(who, c, t.reach) \
				and world.blocker_top(c.x, c.y + 1, c.z) <= 0.0 and world.blocker_top(c.x, c.y, c.z) <= 0.0:
			out.append(c)
	return out


## Digs `cells` in one swing of `swing` seconds; what they give (their item, now and
## then their bonus) falls under them.
func dig(who, cells: Array[Vector3i], swing: float) -> Dictionary:
	if cells.is_empty() or not who.act("dig"):
		return {}
	var keys := {}
	var first: int = world.get_cell(cells[0].x, cells[0].y, cells[0].z)
	for c in cells:
		var was: int = world.get_cell(c.x, c.y, c.z)
		world.set_cell(c.x, c.y, c.z, Mat.AIR)
		_changed(c)
		if rules.free_build:
			continue
		var at := floor_under(c)
		var rec: Dictionary = Mat.RECORDS[was]
		for id in [Items.dug[was], rec.bonus if randf() < rec.bonus_chance else ""]:
			if id != "":
				world.heap_drop(id, at, 1, randf() * TAU)
				keys[WorldData.chunk_key(c.x, c.z)] = true
	for key in keys:
		drops_changed.emit(key)
	var done := _work(swing, "", (Vector3(cells[0]) + Vector3(0.5, 0.5, 0.5)) * CELL, first)
	who.use_tool()
	return done


## Whether the grass on top of `cell` can be cut: a material with a top to cut (see
## Tools.mown) or stone with moss on it (Grass.stone_moss), open to the air above, with
## no bush on it; by tool `t` when given, which may cut only what grows tall on it (see
## Tools.mows_low).
func can_mow(cell: Vector3i, t := {}) -> bool:
	var up := cell + Vector3i.UP
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	if Tools.mown(m) < 0 and not Grass.stone_moss(world, cell.x, cell.y, cell.z) or world.get_cell(up.x, up.y, up.z) != Mat.AIR \
			or world.bushes.has(up) or world.blocker_top(up.x, up.y, up.z) > 0.0:
		return false
	return t.is_empty() or Tools.mows_low(t) or Grass.has_tall(world, cell)


## Plants `ids` without those that are gone in winter (mushrooms; a plant with
## `winter` off) when it is winter.
func in_season(ids: Array) -> Array:
	if clock.season != WINTER:
		return ids
	return ids.filter(func(id: String) -> bool: return Plants.BY_ID.get(id, {}).get("winter", true))


## The name of what is picked by hand on grass cell `cell` (moss, mushrooms; a plant with
## `pick`), "" when nothing there is: cutting the cell picks it first.
func picking(cell: Vector3i) -> String:
	for id in in_season(Grass.plants_on(world, cell.x, cell.y, cell.z)):
		var p: Dictionary = Plants.BY_ID.get(id, {})
		if p.get("pick", false):
			return p.title
	return ""


## The cells tool `t` of `who` cuts the grass of when it swings at the first of `order`
## it can cut: that one, and for a scythe the ones beside it in an arc in front of the body.
func mow_targets(who, order: Array[Vector3i], t: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in order:
		if can_mow(c, t) and not too_far(who, c, t.reach):
			for s in (Tools.sweep(c, who.facing_step()) if t.area > 1 else [c]):
				if out.size() < t.area and can_mow(s, t) and not too_far(who, s, t.reach):
					out.append(s)
			break
	return out


## Cuts the grass on top of `cells` in one swing of the tool in use (see mow).
func mow_swing(who, cells: Array[Vector3i]) -> Dictionary:
	var t: Dictionary = who.tool()
	# A scythe's arc knocks the berries off the ripe bushes in it too.
	# (Not `x if c else []`: an untyped [] put into a typed array is a script error.)
	var arc: Array[Vector3i] = []
	if not cells.is_empty() and t.area > 1:
		arc = Tools.sweep(cells[0], who.facing_step())
	if cells.is_empty():
		return {}
	var was: int = world.get_cell(cells[0].x, cells[0].y, cells[0].z)
	if not mow(who, cells, arc):
		return {}
	var done := _work(t.swing, "", (Vector3(cells[0]) + Vector3(0.5, 1.0, 0.5)) * CELL, Mat.GRASS if was != Mat.STONE else Mat.LEAVES)
	who.use_tool()
	return done


## Cuts the grass on top of `cells` (see can_mow) in two stages: first what grows tall
## on it (tall grass, flowers, ears, reeds; see Grass), and the cell stays grass cut
## short until spring (WorldData.turf); grass with nothing tall on it is cut down to the
## material under it (its `mow`) and gives its `mow_gives` with what the low grass had.
## What is cut falls on the cell, and the berries of ripe bushes on the grass cells
## `knock` (a scythe's arc) fall beside them. True if anything was cut.
func mow(who, cells: Array[Vector3i], knock: Array[Vector3i] = []) -> bool:
	if not who.act("cut"):
		return false
	var keys := {}
	for c in cells:
		var m: int = world.get_cell(c.x, c.y, c.z)
		var to := Tools.mown(m)
		if to < 0 and not Grass.stone_moss(world, c.x, c.y, c.z):
			continue
		var plants := in_season(Grass.plants_on(world, c.x, c.y, c.z))
		var tall := plants.filter(func(id: String) -> bool: return id != Plants.TUFT)
		if tall.is_empty() and to < 0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([c, clock.day])
		var gives := {}
		if not tall.is_empty():
			gives = Plants.harvest(tall, rng)
			world.set_turf(c, "")
			looks_changed.emit(WorldData.chunk_key(c.x, c.z))
		else:
			gives = Plants.harvest(plants, rng)
			var own: Dictionary = Mat.RECORDS[m].mow_gives
			for id in own:
				gives[id] = gives.get(id, 0) + own[id]
			world.set_turf(c, null)
			world.set_material(c.x, c.y, c.z, to)
			_changed(c)
		if rules.free_build:
			continue
		var at: Vector3 = floor_under(c + Vector3i.UP)
		for id in gives:
			world.heap_drop(Items.get_item(id).get("id", id), at, gives[id], rng.randf() * TAU)
		keys[WorldData.chunk_key(c.x, c.z)] = true
	for c in knock:
		var at := c + Vector3i.UP
		if not world.bushes.has(at):
			continue
		var b: Dictionary = Bushes.TYPES[world.bushes[at]]
		if not ripe(at, b):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([at, clock.day])
		var p := (Vector3(at) + Vector3(0.5, 0.0, 0.5)) * CELL
		world.heap_drop(b.fruit, p + Vector3(rng.randf_range(-SCATTER, SCATTER), 0.0, rng.randf_range(-SCATTER, SCATTER)),
			berry_count(at, b), rng.randf() * TAU)
		world.bush_picked[at] = true
		world.note_bush(at)
		looks_changed.emit(WorldData.chunk_key(at.x, at.z))
		keys[WorldData.chunk_key(floori(p.x / CELL), floori(p.z / CELL))] = true
	for key in keys:
		drops_changed.emit(key)
	return true


# --- Placing blocks -------------------------------------------------------------------

## Places the block in the hand in use of `who` with its brush around `center`, across
## face `normal`: each cell that is free, within reach, no higher than level `top` and
## next to something solid. The swing tells how many were placed (`placed`).
func place_at(who, center: Vector3i, normal: Vector3i, top: int) -> Dictionary:
	var item: String = who.held()
	var block := Mat.index(Items.get_item(item).get("place", ""))
	if block < 0:
		return {}
	var free: bool = rules.free_build
	var placed := 0
	var far := false
	for cell in Tools.brush_shape(center, normal, who.brush()):
		if not can_place(who, cell, top):
			far = far or too_far(who, cell, Tools.PLACE_REACH)
			continue
		if not free and who.inventory.count(item) == 0:
			who.nag("no_block", "В сумке нет: %s" % Items.title(item))
			break
		if not who.act("place"):
			break
		if not free:
			who.inventory.remove(item, 1)
		world.set_cell(cell.x, cell.y, cell.z, block)
		_changed(cell)
		placed += 1
	if placed > 0:
		var done := _work(PLACE_SWING, "reach", (Vector3(center) + Vector3(0.5, 0.5, 0.5)) * CELL, block)
		done.placed = placed
		return done
	if far:
		who.nag("far", "Слишком далеко")
	return {}


## Whether `who` can place a block in `cell`: in the world, no higher than level `top`,
## within reach, air or water clear of the body and of placed things, next to something
## solid.
func can_place(who, cell: Vector3i, top: int) -> bool:
	if not world.in_bounds(cell.x, cell.y, cell.z) or cell.y > top or too_far(who, cell, Tools.PLACE_REACH):
		return false
	var cur: int = world.get_cell(cell.x, cell.y, cell.z)
	if cur != Mat.AIR and cur != Mat.WATER or who.overlaps_cell(cell) or world.blocker_top(cell.x, cell.y, cell.z) > 0.0:
		return false
	for d in [Vector3i.DOWN, Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var n: Vector3i = cell + d
		if world.is_solid(n.x, n.y, n.z):
			return true
	return false


# --- The action button ------------------------------------------------------------------

## The action button: works in front of `who` with the hand in use (placing nothing higher
## than level `top`). A block is placed in front (filling a hole first), seeds and bushes
## planted. A tool or bare hands first work the nearest tree or bush in front that they
## can do something to (see useful: an axe chops, hands gather, a sword knocks berries
## off, a shovel digs a bush out), then cut the grass in front (hands, sword, scythe),
## then dig one cell, in the order of Tools.front_cells (round the body, the one it faces
## first); with none of that the hand
## swings at the air. Setting down a placed thing and eating are not this module's.
func act_in_front(who, top: int) -> Dictionary:
	match Tools.use_of(who.held()):
		"place":
			return place_in_front(who, top)
		"plant", "sow":
			if plant(who, who.held()):
				return _work(FRONT_PLACE_SWING, "reach", Vector3.INF)
			return {"swing": IDLE_SWING}
	var t: Dictionary = who.tool()
	var arm := Tools.weapon(who.held())
	# A spear, a sling or a bow shoots ahead; a sword or a knife goes for an animal in
	# front first, any other hand for one right by the body.
	if Tools.shoots(arm):
		return shoot(who)
	var blow := strike(who, Tools.hunts(arm))
	if not blow.is_empty():
		return blow
	var work := front_choice(who)
	if work.has("trunk"):
		return chop(who, work.trunk)
	if work.has("tree") or work.has("bush"):
		if gather(who, work):
			var at: Vector3 = Vector3(work.bush) + Vector3(0.5, 0.4, 0.5) if work.has("bush") \
				else Vector3(trunk_cell(who, work.tree)) + Vector3(0.5, 0.5, 0.5)
			return _work(t.swing, "", at * CELL, Mat.LEAVES)
		return {"swing": IDLE_SWING}
	if work.has("mow"):
		return mow_swing(who, work.mow)
	if work.has("dig"):
		var c: Vector3i = work.dig[0]
		return dig(who, work.dig, Tools.swing_time(t, world.get_cell(c.x, c.y, c.z)))
	return swing_air(who, Vector3.INF)


## Nothing to work: the hand in use swings at the air (toward `at`, if finite), without
## a word and for less stamina.
func swing_air(who, at: Vector3) -> Dictionary:
	var blow := strike(who)
	if not blow.is_empty():
		return blow
	if who.act("swing"):
		return _work(who.tool().swing, "", at)
	return {"swing": IDLE_SWING}


## A blow of the hand in use at the animal in front of `who` (Wildlife.in_front; only
## one right by the body unless `far`), with the hand's power: the animal flees, or dies
## and leaves its carcass (its species' `carcass`) on the ground where it fell. {} with
## no animal there.
func strike(who, far := true) -> Dictionary:
	if wildlife == null:
		return {}
	var s: Vector2i = who.facing_step()
	var at: Vector3 = who.position
	var a = wildlife.in_front(at, Vector2(s), wildlife.STRIKE_REACH if far else wildlife.STRIKE_CLOSE)
	if a == null or not who.act("swing"):
		return {}
	var arm := Tools.weapon(who.held())
	var t: Dictionary = arm if not arm.is_empty() else who.tool()
	var where: Vector3 = a.pos
	_wound(who, a, t.power)
	if t.tool != "hand":
		who.use_tool()
	var done := _work(t.swing, "", where + Vector3(0.0, 0.3, 0.0))
	done.hit = true
	return done


## Animal `a` takes a blow of `power` from `who`; if it dies, its carcass (its species'
## `carcass`) is left on the ground where it fell.
func _wound(who, a, power: int) -> void:
	var where: Vector3 = a.pos
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	if wildlife.hurt(a, power, who.position) and spec.carcass != "" and Items.has(spec.carcass):
		var cell := _cell_at(where)
		world.heap_drop(spec.carcass, floor_under(cell), 1, randf() * TAU)
		drops_changed.emit(WorldData.chunk_key(cell.x, cell.z))
		who.note("hunted")


static func _cell_at(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL + 0.01), floori(p.z / CELL))


## How fast a shot flies, in world units a second (for the flight drawn: the shot itself
## lands at once), and how wide the way it is aimed counts, as the cosine of the half angle.
const SHOT_SPEED := 14.0
const AIM_CONE := 0.9


## A shot of the weapon in hand (a spear thrown, a stone from a sling, an arrow from a
## bow) toward `aim` (world units; the way `who` faces when not finite), as far as the
## weapon's `range`: it hits the first animal along that way (Wildlife.in_front within
## AIM_CONE) unless a solid cell stops it first, and what was shot lies where it ended up,
## to be picked up again. Nothing to shoot (no `ammo` in the bag): a word and an idle swing.
func shoot(who, aim := Vector3.INF) -> Dictionary:
	var item := Tools.weapon(who.held())
	if not Tools.shoots(item):
		return {}
	var ammo: String = item.ammo if item.ammo != "" else item.id
	if who.inventory.count(ammo) == 0:
		who.nag("ammo", "Нечем стрелять: нужно «%s»" % Items.title(ammo))
		return {"swing": IDLE_SWING}
	if not who.act("swing"):
		return {}
	var at: Vector3 = who.position
	var from := at + Vector3(0.0, 0.6, 0.0)
	var s: Vector2i = who.facing_step()
	var dir := Vector2(s).normalized()
	if aim.is_finite() and Vector2(aim.x - at.x, aim.z - at.z).length() > 0.05:
		dir = Vector2(aim.x - at.x, aim.z - at.z).normalized()
	var reach: float = item.range * CELL
	var a = wildlife.in_front(at, dir, reach, AIM_CONE) if wildlife != null else null
	var to: Vector3 = a.pos + Vector3(0.0, 0.3, 0.0) if a != null else from + Vector3(dir.x, 0.0, dir.y) * reach
	# Along the way, the first solid cell stops it.
	var steps := maxi(1, ceili(from.distance_to(to) / (CELL * 0.5)))
	var end := to
	for i in range(1, steps + 1):
		var c := _cell_at(from.lerp(to, float(i) / steps))
		if world.is_solid(c.x, c.y, c.z):
			end = from.lerp(to, float(i - 1) / steps)
			a = null
			break
	# One out of the bag: a thrown weapon keeps its wear.
	var data: Variant = 1
	if ammo == item.id:
		for i in who.inventory.slots.size():
			var slot = who.inventory.slots[i]
			if slot != null and slot[0] == ammo:
				var taken = who.inventory.take_slot(i, 1)
				data = {"n": 1, "worn": taken[2]} if taken.size() > 2 else 1
				break
	else:
		who.inventory.remove(ammo, 1)
		who.use_tool()
	if a != null:
		_wound(who, a, item.power)
	var land := floor_under(_cell_at(end))
	world.add_drop(ammo, land, randf() * TAU, data)
	drops_changed.emit(WorldData.chunk_key(floori(land.x / CELL), floori(land.z / CELL)))
	var done := _work(item.swing, "", end)
	done.hit = a != null
	done.shot = [ammo, from, land, from.distance_to(land) / SHOT_SPEED]
	return done


## Places the block in hand round `who` (front_place_cells), in the hole it faces first.
func place_in_front(who, top: int) -> Dictionary:
	var s: Vector2i = who.facing_step()
	for cell in front_place_cells(who):
		if can_place(who, cell, top):
			var done := place_at(who, cell, Vector3i(s.x, 0, s.y if s.x == 0 else 0), top)
			done.swing = FRONT_PLACE_SWING
			return done
	who.nag("front", "Рядом некуда ставить")
	return {"swing": IDLE_SWING}


## The cells round `who` a block goes in, in order (Tools.place_cells): the near ring
## from the one it faces round to the one behind, below, level, above, then the ring
## beyond.
func front_place_cells(who) -> Array[Vector3i]:
	return Tools.place_cells(who.feet(), who.facing_step())


## What a swing of tool `t` in front of `who` would do: {"mow": cells} (the grass first,
## for the tools that cut it), {"dig": [cell]} (one cell), or {}.
func front_work(who, t: Dictionary) -> Dictionary:
	var order := front_order(who)
	if Tools.mows(t):
		var cells := mow_targets(who, order, t)
		if not cells.is_empty():
			return {"mow": cells}
	var cells := dig_targets(who, order, t, 1)
	return {"dig": cells} if not cells.is_empty() else {}


## The cells the action button digs, in order (Tools.front_cells: the near ring round
## the body, then the one beyond), counted from the cell over the ground the feet stand
## on; last the one under the feet while `who` stands still, so it is dug only once
## nothing the hand in use digs is left in both rings at the head, the waist and the
## ground and the pit it drops into is open on every side; then it starts again a level
## down.
func front_order(who) -> Array[Vector3i]:
	var f: Vector3i = who.feet()
	# On a slope the feet are down in the sloping cell: count from the cell over it.
	if world.get_cell(f.x, f.y, f.z) != Mat.AIR and world.get_cell(f.x, f.y + 1, f.z) == Mat.AIR:
		f += Vector3i.UP
	var cells := Tools.front_cells(f, who.facing_step())
	if not who.moving():
		cells.append(f + Vector3i.DOWN)
	return cells


## The first tree or bush round `who` (in the order of Tools.sector) that the hand in use can do
## something to: {"trunk": cell} for an axe at a tree, {"tree": column} for bare hands,
## {"bush": cell}; {} for none.
func front_target(who) -> Dictionary:
	var all := front_targets(who)
	return all[0] if not all.is_empty() else {}


## All the trees and bushes round `who` that the hand in use can do something to
## (see front_target), in the order of Tools.sector.
func front_targets(who) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f: Vector3i = who.feet()
	var t: Dictionary = who.tool()
	for o in Tools.sector(who.facing_step()):
		var col := Vector2i(f.x + o.x, f.z + o.y)
		if world.trees.has(col) and (Tools.can_chop(t) or Tools.can_gather(t)):
			var trunk := trunk_cell(who, col)
			if world.log_col(col.x, col.y) != 0 and absi(trunk.y - f.y) <= 2:
				if Tools.can_chop(t):
					out.append({"trunk": trunk})
				elif useful(who, {"tree": col}):
					out.append({"tree": col})
		for dy in [0, -1, 1]:
			var cell := Vector3i(col.x, f.y + dy, col.y)
			if world.bushes.has(cell) and useful(who, {"bush": cell}):
				out.append({"bush": cell})
	return out


## What the action button does in front of `who` with a tool or bare hands: {"trunk":
## cell}, {"tree": column}, {"bush": cell} (see front_target), {"mow": cells} or {"dig":
## cells} (see front_work); {} for nothing. An axe chops the nearest tree; hands and a
## sword take what is worth most first, the nearest of it: food (berries, mushrooms),
## then seeds (acorns, ears, grass seeds), then the rest (branches, fibre, moss), and
## only then dig.
func front_choice(who) -> Dictionary:
	var t: Dictionary = who.tool()
	var targets := front_targets(who)
	if not t.tool in ["hand", "sword"]:
		return targets[0] if not targets.is_empty() else front_work(who, t)
	var best := {}
	var best_rank := DIG_RANK
	for target in targets:
		var r := _rank(_gives(who, target))
		if r < best_rank:
			best = target
			best_rank = r
	var order := front_order(who)
	if Tools.mows(t):
		var ranks := {}
		for c in order:
			if best_rank == FOOD_RANK:
				break
			if can_mow(c, t) and not too_far(who, c, t.reach):
				var gives := _mow_gives(c)
				if not ranks.has(gives):
					ranks[gives] = _rank(gives)
				if ranks[gives] < best_rank:
					best = {"mow": mow_targets(who, [c], t)}
					best_rank = ranks[gives]
	if not best.is_empty():
		return best
	var cells := dig_targets(who, order, t, 1)
	return {"dig": cells} if not cells.is_empty() else {}


## The items gathering from tree or bush `target` (see front_targets) would give now.
func _gives(who, target: Dictionary) -> Array:
	if target.has("tree"):
		var s: Dictionary = Trees.SPECIES[world.trees[target.tree]]
		if _tree_seeds_left(target.tree, s) > 0:
			return [s.seed]
		return [s.twig] if s.twig != "" else []
	if not target.has("bush"):
		return []
	var b: Dictionary = Bushes.TYPES[world.bushes[target.bush]]
	if ripe(target.bush, b):
		return [b.fruit]
	return [b.twig] if Tools.can_gather(who.tool()) and b.twig != "" else []


## The items cutting the grass on `cell` would likely give (see mow): what grows tall on
## it first, else the low grass and the material's own; a plant's only when it gives
## them at least every other time.
func _mow_gives(cell: Vector3i) -> Array:
	var plants := in_season(Grass.plants_on(world, cell.x, cell.y, cell.z))
	var tall := plants.filter(func(id: String) -> bool: return id != Plants.TUFT)
	var out := []
	for id in (tall if not tall.is_empty() else plants):
		var p: Dictionary = Plants.BY_ID.get(id, {})
		if p.get("chance", 1.0) >= 0.5:
			out.append_array(p.get("gives", {}).keys())
	if tall.is_empty():
		var m: int = world.get_cell(cell.x, cell.y, cell.z)
		out.append_array(Mat.RECORDS[m].mow_gives.keys())
	return out


## How much what gathering gives is worth, the least first: FOOD_RANK for anything to
## eat, SEED_RANK for something to plant or sow, OTHER_RANK for the rest; DIG_RANK for
## nothing.
static func _rank(ids: Array) -> int:
	var r := DIG_RANK
	for id: String in ids:
		if Items.food(id) > 0.0:
			r = mini(r, FOOD_RANK)
		elif Tools.use_of(Items.get_item(id).get("id", id)) in ["plant", "sow"] or _tree_seed(id):
			r = mini(r, SEED_RANK)
		elif Items.has(id):
			r = mini(r, OTHER_RANK)
	return r


## Whether item `id` is the seed of a tree (an acorn, a cone).
static func _tree_seed(id: String) -> bool:
	var item: String = Items.get_item(id).get("id", id)
	for s: Dictionary in Trees.SPECIES:
		if Items.get_item(s.seed).get("id", s.seed) == item:
			return true
	return false


# --- Gathering ----------------------------------------------------------------------------

## Gathers `target` with what is in the hand in use of `who`: {"drop": [chunk key, index]}
## takes a thing off the ground (with the ones lying close to it), {"tree": trunk's
## column} gathers from a standing tree, {"bush": cell} does what the tool does to a bush.
## True if anything was done. A target out of reach (a thing farther than HAND_REACH, a
## bush beyond the tool's reach, a trunk beyond it and TREE_SPREAD, each with its slack) or of another shape does nothing.
func gather(who, target: Dictionary) -> bool:
	if target.has("drop"):
		var d: Variant = target.drop
		return d is Array and d.size() == 2 and d[0] is Vector2i and d[1] is int and pick_up(who, d[0], d[1])
	var t: Dictionary = who.tool()
	if target.has("tree"):
		var col: Variant = target.tree
		if not col is Vector2i or not world.trees.has(col):
			return false
		# The crown spreads round the trunk: across the ground, the tool's reach and the crown's.
		var from: Vector3 = who.position / CELL
		if Vector2(col.x + 0.5 - from.x, col.y + 0.5 - from.z).length() > t.reach + TREE_SPREAD:
			return false
		return _from_tree(who, col)
	var bush: Variant = target.get("bush")
	if not bush is Vector3i or not world.bushes.has(bush) or too_far(who, bush, t.reach + 2):
		return false
	if Tools.can_gather(t):
		return _from_bush(who, target.bush)
	var done := false
	if Tools.can_knock(t):
		done = _knock_berries(who, target.bush)
	elif Tools.can_chop(t):
		done = _fell_bush(who, target.bush)
	elif Tools.can_dig_out(t):
		done = _dig_out(who, target.bush)
	else:
		who.nag("bush", "Куст: руки собирают, топор рубит, лопата выкапывает")
		return false
	if done:
		who.use_tool()
	return done


## Whether gather(who, target) would do anything to the tree or bush of `target` with the
## hand in use now (the action button passes over the ones it would not).
func useful(who, target: Dictionary) -> bool:
	var t: Dictionary = who.tool()
	if target.has("tree"):
		if not Tools.can_gather(t) or not has_crown(target.tree):
			return false
		var s: Dictionary = Trees.SPECIES[world.trees[target.tree]]
		return _tree_seeds_left(target.tree, s) > 0 or _tree_twigs_left(target.tree, s) > 0
	var cell: Vector3i = target.bush
	if not world.bushes.has(cell):
		return false
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if Tools.can_chop(t) or Tools.can_dig_out(t):
		return true
	if Tools.can_gather(t):
		return ripe(cell, b) or twigs_left(cell, b) > 0
	# The action button knocks berries off with a sword; a scythe mows past them.
	return t.tool == "sword" and ripe(cell, b)


## Takes by themselves the things lying near the feet of `who` that pickup `mode` wants
## (the setting); what it threw away waits until it has walked off. They are taken only
## as far as the bag's weight limit goes unless `past_limit` (a setting), so digging with the button held does not overload the body
## (which then cannot jump out of the pit it dug); the sack of a death is taken whole. The dead take nothing: their sack
## lies at their feet.
func pick_up_near(who, mode := PICKUP_ALL, past_limit := false) -> void:
	if who.is_dead():
		return
	var feet: Vector3 = who.position
	var held_back: Array[Vector3] = who.held_back
	for i in range(held_back.size() - 1, -1, -1):
		if held_back[i].distance_to(feet) > PICKUP:
			held_back.remove_at(i)
	if mode == PICKUP_NONE:
		return
	var home := WorldData.chunk_key(floori(feet.x / CELL), floori(feet.z / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := home + Vector2i(dx, dz)
			var list: Array = world.drops.get(key, [])
			var took := false
			for i in range(list.size() - 1, -1, -1):
				var d: Array = list[i]
				if d[1].distance_to(feet) > PICKUP or _is_held_back(held_back, d[1]):
					continue
				var most := -1
				if d[0] != Items.SACK:
					var id: String = Items.get_item(d[0]).get("id", d[0])
					if who.inventory.room_for(id) == 0 or not _wanted(who.inventory, id, mode):
						continue
					most = -1 if past_limit else _light_enough(who.inventory, id)
					if most == 0:
						who.nag("heavy", "Сумка тяжёлая: вещи больше не поднимаются сами")
						continue
				world.take_drop(key, i)
				var rest := _take(who, d, most)
				if not rest.is_empty():
					world.add_drop(rest[0], rest[1], rest[2], rest[3])
				if rest.is_empty() or str(rest[3]) != str(d[3]):
					taken.emit(d[0], d[1])
				took = true
				list = world.drops.get(key, [])
			if took:
				drops_changed.emit(key)


## Whether things of `id` are taken by themselves in pickup `mode`.
static func _wanted(inv, id: String, mode: int) -> bool:
	match mode:
		PICKUP_KNOWN:
			return inv.count(id) > 0
		PICKUP_FOOD:
			return Items.food(id) > 0.0
	return mode == PICKUP_ALL


## The sack at `at` was taken whole by `who`: if it was theirs, their maps no longer
## mark it.
static func _forget_sack(who, at: Vector3) -> void:
	var sacks: Array[Vector3] = who.sacks
	for i in range(sacks.size() - 1, -1, -1):
		if sacks[i].distance_to(at) < 0.01:
			sacks.remove_at(i)


## How many of `id` the bag `inv` can take before its weight passes its limit.
static func _light_enough(inv, id: String) -> int:
	var each := Items.weight(id)
	if each <= 0.0 or not inv.heavy:
		return 1 << 30
	return maxi(0, floori((inv.weight_limit - inv.weight()) / each + 0.0001))


static func _is_held_back(held_back: Array[Vector3], at: Vector3) -> bool:
	for p in held_back:
		if p.distance_to(at) <= PILE:
			return true
	return false


## Takes thing `i` of chunk `key` off the ground into the bag of `who` with the things
## lying close to it; what does not fit stays where it lay.
func pick_up(who, key: Vector2i, i: int) -> bool:
	var list: Array = world.drops.get(key, [])
	if i < 0 or i >= list.size():
		return false
	var at: Vector3 = list[i][1]
	if not within_hand(who, at) or not who.act("pick_up"):
		return false
	var near: Array[int] = []
	for j in list.size():
		if j == i or list[j][1].distance_to(at) <= PILE:
			near.append(j)
	# The last index first, so the others stay right while things go.
	near.reverse()
	var took := false
	var left := []
	for j in near:
		var d: Array = world.take_drop(key, j)
		var rest := _take(who, d)
		took = took or rest.is_empty() or str(rest[3]) != str(d[3] if d.size() > 3 else 1)
		if not rest.is_empty():
			left.append(rest)
	for d: Array in left:
		world.add_drop(d[0], d[1], d[2], d[3])
	drops_changed.emit(key)
	return took


## Puts what drop `d` holds into the bag of `who`, no more than `most` of it when given;
## returns what is left of it ([] for nothing).
func _take(who, d: Array, most := -1) -> Array:
	if d[0] == Items.SACK:
		var rest := []
		for s: Array in d[3]:
			var got: int = who.inventory.add(s[0], s[1], s[2] if s.size() > 2 else 0, s[3] if s.size() > 3 else null)
			if got < s[1]:
				rest.append([s[0], s[1] - got] + s.slice(2))
		who.say("Вещи из мешка забраны" if rest.is_empty() else "Забрано не всё: сумка полна")
		if rest.is_empty():
			_forget_sack(who, d[1])
		return [] if rest.is_empty() else [d[0], d[1], d[2], rest]
	var n := count(d)
	var worn: int = d[3].get("worn", 0) if d.size() > 3 and d[3] is Dictionary else 0
	var got: int = who.give(Items.get_item(d[0]).get("id", d[0]), n if most < 0 else mini(n, most), worn)
	if got >= n:
		return []
	return [d[0], d[1], d[2], {"n": n - got, "worn": worn} if worn > 0 else n - got]


## How many items drop `d` is (see WorldData.drops): its count, or its "n" for a worn tool.
static func count(d: Array) -> int:
	if d.size() > 3 and d[3] is Dictionary:
		return d[3].get("n", 1)
	return d[3] if d.size() > 3 and d[3] is int else 1


## Berries off a ripe bush, otherwise a branch while it has any left this year.
func _from_bush(who, cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if ripe(cell, b):
		if not who.act("gather"):
			return false
		if who.give(b.fruit, berry_count(cell, b)) == 0:
			return false
		world.bush_picked[cell] = true
		world.note_bush(cell)
		looks_changed.emit(WorldData.chunk_key(cell.x, cell.z))
		return true
	if b.twig == "":
		who.nag("bush", "%s: взять с него нечего" % b.title)
		return false
	if twigs_left(cell, b) <= 0:
		who.nag("bush", "На кусте больше ничего нет до весны")
		return false
	if not who.act("gather"):
		return false
	if who.give(b.twig, 1) == 0:
		return false
	world.bush_twigs[cell] = world.bush_twigs.get(cell, 0) + 1
	world.note_bush(cell)
	return true


## A sword knocks the ripe berries off a bush: they fall on the ground around it.
func _knock_berries(who, cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if not ripe(cell, b):
		who.nag("bush", "Ягод на кусте нет" if b.fruit != "" else "%s без ягод" % b.title)
		return false
	if not who.act("cut"):
		return false
	blow_berries(cell)
	return true


## The ripe berries of the bush in `cell` fall on the ground around it (a sword, a
## storm); true if it had any.
func blow_berries(cell: Vector3i) -> bool:
	if not world.bushes.has(cell):
		return false
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if not ripe(cell, b):
		return false
	_scatter(cell, b.fruit, berry_count(cell, b))
	world.bush_picked[cell] = true
	world.note_bush(cell)
	looks_changed.emit(WorldData.chunk_key(cell.x, cell.z))
	return true


## An axe fells a bush: it is gone, and the twigs it had left this year lie beside it.
func _fell_bush(who, cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if not who.act("chop"):
		return false
	var n := maxi(1, twigs_left(cell, b))
	_remove_bush(cell)
	if b.twig != "":
		_scatter(cell, b.twig, n)
	return true


## A shovel digs the bush out whole: it lies on the ground as an item to plant again.
func _dig_out(who, cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if not who.act("dig"):
		return false
	_remove_bush(cell)
	if b.item != "":
		_scatter(cell, b.item, 1)
	return true


func _remove_bush(cell: Vector3i) -> void:
	if not world.bushes.has(cell):
		return
	world.remove_bush(cell)
	_changed(cell)


## Lays `n` items `id` on the ground around the bush in `cell`.
func _scatter(cell: Vector3i, id: String, n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cell, id, clock.day, n])
	var at := (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL
	var p := at + Vector3(rng.randf_range(-SCATTER, SCATTER), 0.0, rng.randf_range(-SCATTER, SCATTER))
	world.heap_drop(id, Vector3(p.x, at.y, p.z), n, rng.randf() * TAU)
	drops_changed.emit(WorldData.chunk_key(floori(p.x / CELL), floori(p.z / CELL)))


## Hands at a standing tree: in autumn its seeds while it has any left this year, else
## a twig (the species' `twig`) while it has any; they go into the bag.
func _from_tree(who, col: Vector2i) -> bool:
	if not world.trees.has(col) or not has_crown(col):
		return false
	var s: Dictionary = Trees.SPECIES[world.trees[col]]
	var seeds := _tree_seeds_left(col, s) > 0
	if not seeds and s.twig == "":
		who.nag("tree", "%s: взять с него нечего" % s.title)
		return false
	if not seeds and _tree_twigs_left(col, s) <= 0:
		who.nag("tree", "%s: больше ничего до весны" % s.title)
		return false
	if not who.act("gather"):
		return false
	var id: String = s.seed if seeds else s.twig
	if who.give(id, 1) == 0:
		return false
	var map: Dictionary = world.tree_seeds if seeds else world.tree_twigs
	map[col] = map.get(col, 0) + 1
	world.note_edit(col.x, col.y)
	return true


## The wind breaks a branch off the tree with its trunk in `col` while it has any left
## this year: it lies at `at` (world units, on the ground under the crown). True if
## one broke.
func blow_branch(col: Vector2i, at: Vector3, angle: float) -> bool:
	if not world.trees.has(col) or not has_crown(col):
		return false
	var s: Dictionary = Trees.SPECIES[world.trees[col]]
	if s.twig == "" or _tree_twigs_left(col, s) <= 0:
		return false
	world.tree_twigs[col] = world.tree_twigs.get(col, 0) + 1
	world.note_edit(col.x, col.y)
	world.heap_drop(s.twig, at, 1, angle)
	drops_changed.emit(WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL)))
	return true


## Whether the tree with its trunk in `col` still has its crown (a felled one leaves a
## stump): leaves on the columns around the top of its trunk.
func has_crown(col: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if world.leaf_col(col.x + dx, col.y + dz) != 0:
				return true
	return false


func _tree_twigs_left(col: Vector2i, s: Dictionary) -> int:
	return s.twigs - world.tree_twigs.get(col, 0)


func _tree_seeds_left(col: Vector2i, s: Dictionary) -> int:
	if clock.season != AUTUMN or s.seed == "":
		return 0
	return s.seeds - world.tree_seeds.get(col, 0)


## How many berries the bush in `cell` gives today.
func berry_count(cell: Vector3i, b: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cell, clock.day])
	var share: float = Bushes.BERRY_AMOUNT[clock.season]
	return maxi(1, roundi(rng.randi_range(b.fruit_count[0], b.fruit_count[1]) * share))


## Whether the bush in `cell` has ripe berries to pick.
func ripe(cell: Vector3i, b: Dictionary) -> bool:
	return b.fruit != "" and not world.bush_picked.has(cell) and Bushes.BERRY_AMOUNT[clock.season] > 0.0


## How many branches the bush in `cell` has left this year.
func twigs_left(cell: Vector3i, b: Dictionary) -> int:
	return b.twigs - world.bush_twigs.get(cell, 0)


# --- Planting ---------------------------------------------------------------------------

## Plants item `id` from the bag of `who` in front of it: a bush (an item with `plant`)
## on grass, seeds (with `sow`) on the bare ground they grow on; true if it was planted.
func plant(who, id: String) -> bool:
	var spot: Variant = plant_spot(who, id)
	if spot == null:
		var item := Items.get_item(id)
		who.nag("plant", "Сажать можно на ровную траву рядом" if item.get("plant", "") != "" \
			else "Сеять можно на голую землю рядом")
		return false
	return plant_at(who, id, spot)


## The ground cell round `who` where item `id` would be planted (see plant_at), in the
## order of Tools.sector, or null.
func plant_spot(who, id: String) -> Variant:
	var feet: Vector3i = who.feet()
	for o in Tools.sector(who.facing_step()):
		for dy in [-1, 0, -2]:
			var cell: Vector3i = feet + Vector3i(o.x, dy, o.y)
			if _can_plant(who, id, cell):
				return cell
	return null


## Plants item `id` from the bag of `who` on ground cell `cell` (the cell a bush stands
## on, or the ground that seeds turn into their `sow`); true if it was planted.
func plant_at(who, id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if item.is_empty() or who.inventory.count(item.id) == 0:
		who.nag("no_seed", "В сумке нет: %s" % Items.title(id))
		return false
	if not _can_plant(who, id, cell):
		who.nag("plant", "Сюда не посадить")
		return false
	if not who.act("gather"):
		return false
	who.inventory.remove(item.id, 1)
	if item.plant != "":
		var at := cell + Vector3i.UP
		Bushes.place(world, at.x, at.y, at.z, Bushes.index(item.plant))
		world.note_bush(at)
		looks_changed.emit(WorldData.chunk_key(at.x, at.z))
	else:
		world.set_material(cell.x, cell.y, cell.z, Mat.index(item.sow))
		world.set_turf(cell, item.crop)
		_changed(cell)
	return true


## Whether item `id` can be planted on ground cell `cell` within reach of `who`: a bush
## on level grass with air above, seeds on the ground their `sow` grows from (what that
## material is cut down to) open to the air.
func _can_plant(who, id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if item.is_empty() or too_far(who, cell, Tools.PLACE_REACH):
		return false
	var at := cell + Vector3i.UP
	if item.plant != "":
		return Bushes.index(item.plant) >= 0 and Bushes.fits(world, at.x, at.y, at.z) and not world.bushes.has(at) \
			and not who.overlaps_cell(at)
	if item.sow == "":
		return false
	var grows := Mat.index(item.sow)
	return grows >= 0 and Tools.mown(grows) == world.get_cell(cell.x, cell.y, cell.z) \
		and world.get_cell(at.x, at.y, at.z) == Mat.AIR and not world.bushes.has(at)


# --- The year -----------------------------------------------------------------------------

## A new season: in spring the bushes and trees have their berries, branches and
## seeds again, and grass cut short grows tall.
func on_season(season: int) -> void:
	if season != SPRING:
		return
	var keys := {}
	for cell: Vector3i in world.bush_picked:
		keys[WorldData.chunk_key(cell.x, cell.z)] = true
	for cell: Vector3i in world.bush_picked.keys() + world.bush_twigs.keys():
		world.note_bush(cell)
	for col: Vector2i in world.tree_twigs.keys() + world.tree_seeds.keys():
		world.note_edit(col.x, col.y)
	world.bush_picked.clear()
	world.bush_twigs.clear()
	world.tree_twigs.clear()
	world.tree_seeds.clear()
	# Grass cut short grows tall again; what was sown stays.
	for key: Vector2i in world.turf.keys():
		var cells: Dictionary = world.turf[key]
		for cell: Vector3i in cells.keys():
			if cells[cell] == "":
				world.set_turf(cell, null)
				keys[key] = true
	for key in keys:
		looks_changed.emit(key)
