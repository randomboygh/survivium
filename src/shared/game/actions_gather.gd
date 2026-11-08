extends "res://src/shared/game/actions_base.gd"
## The rules of the hands, part two (world_actions.gd): trees (the trunk a cell belongs
## to, chopping and felling), gathering berries and branches off bushes and trees,
## digging a bush out, and taking the things that lie on the ground into the bag.

const Bushes := preload("res://src/shared/content/bushes.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Growth := preload("res://src/shared/world/growth.gd")
const Felling := preload("res://src/shared/game/felling.gd")
## Things lying this close to the one taken (world units) come along with it.
const PILE := 0.8
## Things lying this close to the feet (world units) are taken by themselves.
const PICKUP := 1.6
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
## What is drawn on chunk `key` changed while its cells did not (berries picked, grass
## cut short, a bush planted).
signal looks_changed(key: Vector2i)
## The things lying on the ground in chunk `key` (WorldData.drops) changed.
signal drops_changed(key: Vector2i)
## A thing lying at `from` flew into the bag of `by` by itself (see pick_up_near).
signal taken(id: String, from: Vector3, by: Object)
## Damage each tree being chopped has taken, by its trunk's column (not saved).
var chops := {}


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
	var best_d := Growth.TREE_REACH * Growth.TREE_REACH * 2 + 1
	var r := Growth.TREE_REACH
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
	if not _is_trunk(cell) or not _may(who, cell, "harvest") or not who.act("chop", "chop"):
		return {}
	who.use_tool()
	var col := Vector2i(cell.x, cell.z)
	var s: Dictionary = Trees.SPECIES[world.trees[col]]
	# The axe decides the blow (its power against the tree's `hits`); the skill of chopping
	# paces the swing, spares the stamina and now and then leaves one log more (fell).
	var blow := _blow(who, "chop", t.power)
	chops[col] = chops.get(col, 0) + blow
	var done := _work(skilled(who, "chop", t.swing), "", (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL, Mat.LOG)
	# No word on the hits left (the user's ask, 2026-11-08): the tree shows it falling.
	if chops[col] < s.hits:
		return done
	chops.erase(col)
	fell(who, cell)
	return done


## Whether the trunk holding `cell` is a young tree (a planted sapling grown small, see
## ActionsFarm): felled, it gives only branches. None in this part.
func young_tree(_cell: Vector3i) -> bool:
	return false


## A young tree whose trunk held `cell` was felled (see young_tree). Nothing in this part.
func felled_young(_cell: Vector3i) -> void:
	pass


## Fells the tree whose trunk holds `cell`, away from `who`; false if it is no trunk of
## a tree.
func fell(who, cell: Vector3i) -> bool:
	var at: Vector3 = who.position
	var away := Vector2(cell.x + 0.5, cell.z + 0.5) * CELL - Vector2(at.x, at.z)
	var before := {}
	for key in world.drops:
		before[key] = world.drops[key].size()
	var tree: int = world.trees.get(Vector2i(cell.x, cell.z), -1)
	var young := young_tree(cell)
	var gone: Array[Vector3i] = Felling.fell(world, cell, away, young)
	if gone.is_empty():
		return false
	who.note("trees")
	# A skilled chopper now and then gets one log more, by the stump (the skill's `yield`).
	var species: Dictionary = Trees.SPECIES[tree] if tree >= 0 else {}
	if young:
		felled_young(cell)
	elif species.get("log", "") != "" and _extra(who, "chop"):
		world.heap_drop(species.log, floor_under(cell), 1, randf() * TAU)
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
		if not _may(who, trunk_cell(who, col), "harvest"):
			return false
		return _from_tree(who, col)
	var bush: Variant = target.get("bush")
	if not bush is Vector3i or not world.bushes.has(bush) or too_far(who, bush, t.reach + 2):
		return false
	if not _may(who, bush, "harvest"):
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
					world.add_drop(rest[0], rest[1], rest[2], rest[3], rest[4] if rest.size() > 4 else -1.0)
				if rest.is_empty() or str(rest[3]) != str(d[3]):
					taken.emit(d[0], d[1], who)
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
	if who.has_method("forget_sack"):
		who.forget_sack(at)
		return
	var sacks: Array[Vector3] = who.sacks
	for i in range(sacks.size() - 1, -1, -1):
		if sacks[i].distance_to(at) < 0.01:
			sacks.remove_at(i)


## The sacks of deaths whose day (the fifth of a drop, Character.SACK_DAYS) is past by
## `now` (Clock.now) are gone from the ground with what they hold, in the chunks the
## world holds (one forgotten keeps its sack until it is made again); the maps of
## `players` no longer mark them.
func expire_sacks(now: float, players: Array) -> void:
	for key: Vector2i in world.drops.keys():
		var list: Array = world.drops[key]
		var gone := false
		for i in range(list.size() - 1, -1, -1):
			var d: Array = list[i]
			if d[0] == Items.SACK and d.size() > 4 and (d[4] is float or d[4] is int) and d[4] <= now:
				world.take_drop(key, i)
				for who in players:
					_forget_sack(who, d[1])
				gone = true
		if gone:
			drops_changed.emit(key)


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
		world.add_drop(d[0], d[1], d[2], d[3], d[4] if d.size() > 4 else -1.0)
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
		return [] if rest.is_empty() else [d[0], d[1], d[2], rest] + d.slice(4)
	var n := count(d)
	var worn: int = d[3].get("worn", 0) if d.size() > 3 and d[3] is Dictionary else 0
	var got: int = who.give(Items.get_item(d[0]).get("id", d[0]), n if most < 0 else mini(n, most), worn)
	if got >= n:
		return []
	return [d[0], d[1], d[2], {"n": n - got, "worn": worn} if worn != 0 else n - got]


## How many items drop `d` is (see WorldData.drops): its count, or its "n" for a worn tool.
static func count(d: Array) -> int:
	if d.size() > 3 and d[3] is Dictionary:
		return d[3].get("n", 1)
	return d[3] if d.size() > 3 and d[3] is int else 1


## Berries off a ripe bush, otherwise a branch while it has any left this year.
func _from_bush(who, cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if ripe(cell, b):
		if not who.act("gather", "gather"):
			return false
		if who.give(b.fruit, berry_count(cell, b) + (1 if _extra(who, "gather") else 0)) == 0:
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
	if not who.act("gather", "gather"):
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
	if not who.act("cut", "gather"):
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
	if not who.act("chop", "chop"):
		return false
	var n := maxi(1, twigs_left(cell, b))
	_remove_bush(cell)
	if b.twig != "":
		_scatter(cell, b.twig, n)
	return true


## A shovel digs the bush out whole: it lies on the ground as an item to plant again.
func _dig_out(who, cell: Vector3i) -> bool:
	var b: Dictionary = Bushes.TYPES[world.bushes[cell]]
	if not who.act("dig", "dig"):
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
	if not who.act("gather", "gather"):
		return false
	var id: String = s.seed if seeds else s.twig
	if who.give(id, 2 if _extra(who, "gather") else 1) == 0:
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
