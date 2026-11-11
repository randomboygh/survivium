extends "res://src/shared/game/actions_boat.gd"
## What a character's hands do to the world (plan/design/character.md, "Взаимодействие с
## миром"): digging cells, cutting the grass, chopping and felling trees, placing blocks,
## the action button's work in front of the body, taking things off the ground, berries
## and branches off bushes and trees, planting, farming (beds, sowing, watering,
## reaping, the growth of crops), and the spring that gives them back. What
## each tool can do is Tools; these are the rules the server will run.
##
## `who` is the one acting (Character on the client) and gives: `inventory` (Inventory),
## `position` (the body, in world units), `held_back` (where it threw things away),
## `feet()` (the cell of its feet), `facing_step()` (the column step it faces),
## `moving()`, `overlaps_cell(cell)`, `held()` (the item in the hand in use), `tool()`
## (that item's record as a tool, Tools.of), `brush()` (one of Tools.BRUSHES), `act(action)`
## (pays the stamina, false when too tired), `give(id, n, worn)` (into the bag, returns how
## many fit), `use_tool()` (wears the tool in use), `nag(reason, text)` and `say(text)`
## (messages to the player), `note(stat, n)` (counts a deed in its life's statistics),
## `is_dead()` and `sacks` (where its death sacks lie).
##
## A swing that did something returns {"swing": seconds until the hands can swing again,
## "work": the work to play (see Player.work), "time": its seconds, "at": what it is done
## to, in world units}; one that did nothing returns {}, or only {"swing"} for a short
## wait. What changes in the world is told through the signals, for the views (the
## chunks, the things on the ground) and later the network.

const Plans := preload("res://src/shared/game/plans.gd")

## The blueprint's ghost cells (Plans): the action button with a block builds them.
var plans


## The action button: works in front of `who` with the hand in use (placing nothing higher
## than level `top`). With a block in hand it builds the blueprint's ghost cells within
## reach (Plans.build), else the block is placed in front (filling a hole first), seeds and bushes
## planted. A tool or bare hands first work the nearest tree or bush in front that they
## can do something to (see useful: an axe chops, hands gather, a sword knocks berries
## off, a shovel digs a bush out) after the farming work in front (a hoe tills, a can
## waters, a ripe crop is reaped: front_farm), then cut the grass in front (hands, sword, scythe),
## then dig one cell, in the order of Tools.front_cells (round the body, the one it faces
## first); with none of that the hand
## swings at the air. Setting down a placed thing and eating are not this module's.
func act_in_front(who, top: int) -> Dictionary:
	if plans != null and Plans.is_fence(who.held()) and plans.builds(who):
		return plans.build(self, who)
	match Tools.use_of(who.held()):
		"place":
			if plans != null and plans.builds(who):
				return plans.build(self, who)
			return place_in_front(who, top)
		"plant", "sow":
			if plant(who, who.held()):
				return _work(FRONT_PLACE_SWING, "reach", Vector3.INF)
			return {"swing": IDLE_SWING}
	var afloat := boat(who)
	if not afloat.is_empty():
		return afloat
	var t: Dictionary = who.tool()
	if Tools.can_fish(t):
		return fish(who)
	if _drinks_with(who):
		var water := water_ahead(who.position, Vector2(who.facing_step()).normalized(), DRINK_REACH)
		if water.is_finite() and (who.vitals.water < who.vitals.MAX - DRINK * 0.5 or _fills(who) != ""):
			return drink(who, water)
	var tending := tend(who)
	if not tending.is_empty():
		return tending
	var arm := Tools.weapon(who.held())
	# A spear, a sling or a bow shoots ahead; a sword or a knife goes for an animal in
	# front first, any other hand for one right by the body.
	if Tools.shoots(arm):
		return shoot(who)
	var blow := strike(who, Tools.hunts(arm))
	if not blow.is_empty():
		return blow
	var farm := farm_in_front(who)
	if not farm.is_empty():
		return farm
	var work := front_choice(who)
	if work.has("trunk"):
		return chop(who, work.trunk)
	if work.has("tree") or work.has("bush"):
		return _gather_work(who, work)
	if work.has("mow"):
		return mow_swing(who, work.mow)
	if work.has("dig"):
		var c: Vector3i = work.dig[0]
		return dig(who, work.dig, Tools.swing_time(t, world.get_cell(c.x, c.y, c.z)))
	return swing_air(who, Vector3.INF)


## Gathers from the tree or the bush of `work` (see front_targets) with the hand in use of
## `who`: the swing done, or a short wait when there was nothing to take.
func _gather_work(who, work: Dictionary) -> Dictionary:
	if not gather(who, work):
		return {"swing": IDLE_SWING}
	var t: Dictionary = who.tool()
	var at: Vector3 = Vector3(work.bush) + Vector3(0.5, 0.4, 0.5) if work.has("bush") \
		else Vector3(trunk_cell(who, work.tree)) + Vector3(0.5, 0.5, 0.5)
	return _work(skilled(who, _gather_role(t), t.swing), "", at * CELL, Mat.LEAVES)


## A tap or a click on `cell` (on its face `normal`) does what the action button does in
## front, in the same order, only at that cell instead of in front of the body (the user's
## ask, 2026-11-11): a shot, a rod or a drink first (the earlier parts aim them at the cell),
## then an animal standing on the cell is tended or hit, then the farming work on it,
## then with hands or a sword what is worth most on it and round it is gathered
## (tap_choice: food, then seeds, then the rest), and only then the earlier parts work the
## cell itself (a tree there, the grass on it, digging).
func dig_at(who, cell: Vector3i, normal: Vector3i) -> Dictionary:
	var t: Dictionary = who.tool()
	if Tools.shoots(Tools.weapon(who.held())) or Tools.can_fish(t) or water_tapped(who, cell).is_finite():
		return super(who, cell, normal)
	var done := _tap_animal(who, cell)
	if not done.is_empty():
		return done
	var farm: Variant = farm_at(who, cell)
	if farm != null:
		return farm
	var work := tap_choice(who, cell)
	if work.has("tree") or work.has("bush"):
		return _gather_work(who, work)
	if work.has("mow"):
		return mow_swing(who, work.mow)
	return super(who, cell, normal)


## An animal standing on `cell` (a tap on it, see dig_at) tended (fed, shorn, told to stay
## or follow) or hit by the hand in use of `who`, turned towards it; {} when none is there
## or nothing was done to it.
func _tap_animal(who, cell: Vector3i) -> Dictionary:
	if wildlife == null:
		return {}
	var aim := (Vector3(cell) + Vector3(0.5, 1.0, 0.5)) * CELL
	var on := false
	for a in wildlife.animals:
		if a.gone or a.health <= 0 or a.aloft() or absf(a.pos.y - aim.y) > 1.5 * CELL:
			continue
		if Vector2(a.pos.x - aim.x, a.pos.z - aim.z).length() <= a.radius + 0.5 * CELL:
			on = true
			break
	if not on:
		return {}
	var dir := Vector2(aim.x - who.position.x, aim.z - who.position.z)
	if dir.length() < 0.05:
		dir = Vector2.ZERO
	if not tend_kind(who, dir) in ["", "release"]:
		var tending := tend(who, dir)
		if not tending.is_empty():
			return tending
	return strike(who, Tools.hunts(Tools.weapon(who.held())), dir)


## The tap ring round a tapped cell, in order: the cell itself, the four beside it, the
## four corners (see tap_choice).
const TAP_RING: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


## What a tap or a click on `cell` gathers with hands or a sword (see dig_at), chosen as
## the action button chooses in front (front_choice), only at the cell instead of in
## front of the body: food first, also off the trees, bushes and grass right round the
## cell (TAP_RING), the nearest to it; else what is worth most on the cell itself (seeds,
## then the rest: the tree it is part of, the bush on it, its grass), so a click on grass
## or ground still works the cell it is aimed at. {"tree": column}, {"bush": cell},
## {"mow": cells}, or {} when nothing there gives anything (then the cell is dug).
func tap_choice(who, cell: Vector3i) -> Dictionary:
	var t: Dictionary = who.tool()
	if not t.tool in ["hand", "sword"] or not world.in_bounds(cell.x, cell.y, cell.z):
		return {}
	# A tap on a bush or on the air over the ground counts from the ground under it.
	var ground := cell if world.get_cell(cell.x, cell.y, cell.z) != Mat.AIR else cell + Vector3i.DOWN
	var best := {}
	var best_rank := DIG_RANK
	var own: Variant = tree_of(cell)
	if own != null and _tree_in_reach(who, own) and useful(who, {"tree": own}):
		var r := _rank(_gives(who, {"tree": own}))
		if r < best_rank:
			best = {"tree": own}
			best_rank = r
	for o in TAP_RING:
		if best_rank == FOOD_RANK:
			break
		# Round the cell only food is worth going past the cell for.
		var top := DIG_RANK if o == Vector2i.ZERO else FOOD_RANK + 1
		var col := Vector2i(ground.x + o.x, ground.z + o.y)
		if col != own and world.trees.has(col) and world.log_col(col.x, col.y) != 0 \
				and absi(trunk_cell(who, col).y - ground.y) <= 3 and _tree_in_reach(who, col) and useful(who, {"tree": col}):
			var r := _rank(_gives(who, {"tree": col}))
			if r < best_rank and r < top:
				best = {"tree": col}
				best_rank = r
		for dy in [0, -1, 1]:
			var c := Vector3i(col.x, ground.y + dy, col.y)
			var bush := c + Vector3i.UP
			if world.bushes.has(bush) and not too_far(who, bush, t.reach) and useful(who, {"bush": bush}):
				var r := _rank(_gives(who, {"bush": bush}))
				if r < best_rank and r < top:
					best = {"bush": bush}
					best_rank = r
			if Tools.mows(t) and can_mow(c, t) and not too_far(who, c, t.reach):
				var r := _rank(_mow_gives(c))
				if r < best_rank and r < top:
					best = {"mow": mow_targets(who, [c] as Array[Vector3i], t)}
					best_rank = r
	return best


## Whether the crown of the tree on `col` is in reach of the hand in use of `who` (as
## gather checks it).
func _tree_in_reach(who, col: Vector2i) -> bool:
	var from: Vector3 = who.position / CELL
	return Vector2(col.x + 0.5 - from.x, col.y + 0.5 - from.z).length() <= who.tool().reach + TREE_SPREAD


## What the action button would do in front of `who` now (see act_in_front), changing
## nothing, for its label: "build" (the blueprint), "place", "plant", "fish", "drink", "fill" (a vessel at the
## water), "shoot", "hit" (a player or an animal there), "till", "water", "reap" (farming,
## front_farm), "chop", "gather" (a tree or a bush), "mow", "dig", or "" for a swing at
## the air.
func front_kind(who) -> String:
	if plans != null and Plans.is_fence(who.held()) and plans.builds(who):
		return "build"
	match Tools.use_of(who.held()):
		"place":
			return "build" if plans != null and plans.builds(who) else "place"
		"plant", "sow":
			return "plant"
	var afloat := boat_kind(who)
	if afloat != "":
		return afloat
	var t: Dictionary = who.tool()
	if Tools.can_fish(t):
		return "fish"
	if _drinks_with(who):
		var water := water_ahead(who.position, Vector2(who.facing_step()).normalized(), DRINK_REACH)
		if water.is_finite():
			if _fills(who) != "":
				return "fill"
			if who.vitals.water < who.vitals.MAX - DRINK * 0.5:
				return "drink"
	var tending := tend_kind(who)
	if tending != "":
		return tending
	var arm := Tools.weapon(who.held())
	if Tools.shoots(arm):
		return "shoot"
	if _someone_in_front(who, Tools.hunts(arm)):
		return "hit"
	var farm: Variant = front_farm(who)
	if farm != null:
		return farm[0]
	var work := front_choice(who)
	if work.has("trunk"):
		return "chop"
	if work.has("tree") or work.has("bush"):
		return "gather"
	if work.has("mow"):
		return "mow"
	if work.has("dig"):
		return "dig"
	return ""


## Whether a blow of `who` would land on a player they may hit or an animal in front
## (see strike; only one right by the body unless `far`), without a word.
func _someone_in_front(who, far: bool) -> bool:
	var dir := Vector2(who.facing_step())
	var weapon := Tools.weapon(who.held())
	if fights != null and people.size() >= 2 and (not weapon.is_empty() or who.tool().tool == "hand"):
		var other = fights.in_front(who, people, dir, fights.STRIKE_REACH if far else STRIKE_CLOSE, fights.STRIKE_CONE)
		if other != null and fights.why_not(who, other).is_empty():
			return true
	if wildlife == null:
		return false
	return wildlife.in_front(who.position, dir, wildlife.STRIKE_REACH if far else wildlife.STRIKE_CLOSE) != null


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


## All the trees and bushes round `who` that the hand in use can do something to, in the
## order of Tools.sector: {"trunk": cell} for an axe at a tree, {"tree": column} for bare
## hands, {"bush": cell}.
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
## cell}, {"tree": column}, {"bush": cell} (see front_targets), {"mow": cells} or {"dig":
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
