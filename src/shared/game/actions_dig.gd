extends "res://src/shared/game/actions_water.gd"
## The rules of the hands, part five (world_actions.gd): what a tap on a cell does with
## the hand in use (dig_at), digging cells, and cutting the grass.

const Grass := preload("res://src/shared/world/grass.gd")
const Plants := preload("res://src/shared/content/plants.gd")


## Works at `cell`, tapped on its face `normal`, with the hand in use: an axe chops the
## tree whose trunk or crown it is, bare hands gather from that tree, hands, a sword or a
## scythe cut the grass on top of it, else the tool digs as many cells around it as it
## takes in a swing.
func dig_at(who, cell: Vector3i, normal: Vector3i) -> Dictionary:
	if Tools.shoots(Tools.weapon(who.held())):
		return shoot(who, (Vector3(cell) + Vector3(0.5, 1.0, 0.5)) * CELL)
	if Tools.can_fish(who.tool()):
		return fish(who, (Vector3(cell) + Vector3(0.5, 1.0, 0.5)) * CELL)
	if _drinks_with(who):
		var bits: int = world.water_col(cell.x, cell.z)
		if bits != 0 and cell.y <= WorldData.top_level(bits) + 1 and not too_far(who, cell, DRINK_REACH + 1):
			return drink(who, Vector3(cell.x + 0.5, WorldData.top_level(bits) + 1.0, cell.z + 0.5) * CELL)
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
				return _work(skilled(who, "gather", t.swing), "", (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL, Mat.LEAVES)
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
## then their bonus) falls under them. The tool in hand wears, or tool `wear` of the bag
## when given (flattening digs with the best tool there, Plans.best_tool).
func dig(who, cells: Array[Vector3i], swing: float, wear: Variant = null) -> Dictionary:
	cells = _allowed(who, cells, "build")
	if cells.is_empty() or not who.act("dig"):
		return {}
	var keys := {}
	var first: int = world.get_cell(cells[0].x, cells[0].y, cells[0].z)
	var fresh := 0
	for c in cells:
		var was: int = world.get_cell(c.x, c.y, c.z)
		if _built.has(c):
			_built.erase(c)
			_undone[c] = true
		else:
			fresh += 1
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
	var done := _work(skilled(who, "dig", swing, float(fresh) / cells.size()), "",
		(Vector3(cells[0]) + Vector3(0.5, 0.5, 0.5)) * CELL, first)
	if wear == null:
		who.use_tool()
	elif wear is String and wear != "" and rules.tool_wear \
			and who.inventory.wear_tool(wear, Items.get_item(wear).get("durability", 0)):
		who.say("Сломалось: %s" % Items.title(wear))
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
	var done := _work(skilled(who, "gather", t.swing), "", (Vector3(cells[0]) + Vector3(0.5, 1.0, 0.5)) * CELL,
		Mat.GRASS if was != Mat.STONE else Mat.LEAVES)
	who.use_tool()
	return done


## Cuts the grass on top of `cells` (see can_mow) in two stages: first what grows tall
## on it (tall grass, flowers, ears, reeds; see Grass), and the cell stays grass cut
## short until spring (WorldData.turf); grass with nothing tall on it is cut down to the
## material under it (its `mow`) and gives its `mow_gives` with what the low grass had.
## What is cut falls on the cell, and the berries of ripe bushes on the grass cells
## `knock` (a scythe's arc) fall beside them. True if anything was cut.
func mow(who, cells: Array[Vector3i], knock: Array[Vector3i] = []) -> bool:
	var asked := not cells.is_empty()
	cells = _allowed(who, cells, "harvest")
	knock = _allowed(who, knock, "harvest")
	if asked and cells.is_empty() or not who.act("cut"):
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
		if not gives.is_empty() and _extra(who, "gather"):
			var first: String = gives.keys()[0]
			gives[first] += 1
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
