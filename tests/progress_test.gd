extends SceneTree
## The way from bare hands to the first tools, played through in a new world: the
## character starts with an empty bag and gets every material from the world (branches
## off bushes and trees, grass cut by hand, flint dug from the ground, logs felled, stone
## and clay dug with the tools it made), sets down every station and makes every recipe
## of the mods, through the same calls the game's taps, action button and craft tab
## make (Controls, Gathering, WorldActions, Placed, Workshop). It fails on the first
## thing it cannot get or make and says why, so a change to tools, materials, stations
## or recipes that cuts the way is caught in CI. Run:
## timeout 600 godot --headless --path . --script res://tests/progress_test.gd
##
## The animals are hunted the same way: the player is carried up to one and strikes it with
## the action button until it falls, then takes its carcass.
##
## The player is carried to what it works on instead of walking there, its stamina is
## topped up and the crafting clock runs fast: walking, tiredness and waiting are not
## what is tested here.

const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const CELL := WorldData.CELL
const CHUNK := WorldData.CHUNK
## Columns searched around the player for what is wanted, before going further.
const SEARCH := 32
## How deep under the top of a column a material is dug for.
const DEPTH := 6
## Swings of the hands for the whole way: a way that leads nowhere ends.
const MAX_SWINGS := 6000
## How many recipes not made yet, the next in order, keep what they need in the bag.
const WANT_AHEAD := 4
## Trips further out when nothing wanted is near.
const MAX_TRIPS := 16

var main: Node
var checks := 0
var failures := 0
var swings := 0
var trips := 0
## Where the stations stand; the player comes back here to make things.
var camp := Vector3.ZERO
## The recipes in the order they become possible, and the ones made.
var order: Array = []
var made := {}
## The placed things the player set down (the camp starts with a chest and a campfire).
var set_down := {}
## The items being got now, with how many calls of _obtain want each.
var seeking := {}
## The recipes being made now, the outermost first (see _wanted).
var crafting: Array[Dictionary] = []
## What the world gives (see _raw).
var raw := {}


func _initialize() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_setup = true
	root.add_child(main)
	_run()


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func _fail(what: String) -> bool:
	_check(false, what)
	return false


func _run() -> void:
	while not main.ready_to_play:
		await process_frame
	var t0 := Time.get_ticks_msec()
	print("world %d, spawn %s" % [main.world_seed, main.controls.feet()])
	# Only what is wanted is taken off the ground (see _pick_up), so the bag keeps room.
	main.settings.values.pickup = 3
	main.settings.set_tool_wear(false)
	var inv = main.host.player.inventory
	inv.slots.fill(null)
	inv.changed.emit()
	main.controls.hands[0] = ""
	main.controls.hands[1] = ""
	camp = main.player.position
	raw = _raw()
	order = _order()
	_check(order.size() == Crafting.RECIPES.size(), "every recipe can be made from what the world gives")
	for r: Dictionary in order:
		if not made.has(r.id) and not await _craft(r, 1):
			break
	for r: Dictionary in Crafting.RECIPES:
		_check(made.has(r.id), "made: %s" % r.title)
	var props := {}
	for r: Dictionary in Crafting.RECIPES:
		if Items.get_item(r.makes).get("prop", "none") != "none":
			props[r.makes] = true
	for id in props:
		_check(set_down.has(id), "set down: %s" % Items.title(id))
	print("%d swings, %d trips out, %.1f s" % [swings, trips, (Time.get_ticks_msec() - t0) / 1000.0])
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


# --- The plan ---------------------------------------------------------------------------

## What the world gives a player (the content graph, src/shared/content/content_graph.gd,
## finds the same and which tool each takes): what cells, the plants on them, trees and
## bushes give.
func _raw() -> Dictionary:
	var have := {}
	for rec: Dictionary in Mat.RECORDS:
		for id in [rec.item, rec.bonus] + rec.mow_gives.keys():
			if id != "":
				have[Items.get_item(id).get("id", id)] = true
	for p: Dictionary in Plants.BY_ID.values():
		for id in p.gives:
			have[Items.get_item(id).get("id", id)] = true
	for s: Dictionary in Trees.SPECIES:
		for id in [s.seed, s.log, s.twig]:
			if id != "":
				have[id] = true
	for b: Dictionary in Bushes.TYPES:
		for id in [b.fruit, b.item, b.twig]:
			if id != "":
				have[id] = true
	for kind: String in AiRules.SPECIES:
		var spec: Dictionary = AiRules.SPECIES[kind]
		if kind != AiRules.HUMAN and spec.health > 0 and spec.carcass != "" and Items.has(spec.carcass):
			have[spec.carcass] = true
	return have


## The recipes in the order they become possible from what the world gives.
func _order() -> Array:
	var have := raw.duplicate()
	var out: Array = []
	var grew := true
	while grew:
		grew = false
		for r: Dictionary in Crafting.RECIPES:
			if out.has(r) or (r.at != "" and not have.has(r.at)):
				continue
			if not r.tools.all(func(kind: String) -> bool:
					return have.keys().any(func(id: String) -> bool: return Items.get_item(id).get("tool", "none") == kind)):
				continue
			if (r.needs.keys() + r.keeps.keys()).all(func(id: String) -> bool: return have.has(id)):
				out.append(r)
				have[r.makes] = true
				grew = true
	return out


## Whether item `id` is still wanted: it is being got now, a recipe being made or one
## of the next WANT_AHEAD not made yet needs it, it is a thing to set down, or it is the
## first tool of its kind in the bag. (Keeping what every later recipe needs fills the
## bag's 16 slots once the chains are long; what is thrown away is got again.)
func _wanted(id: String) -> bool:
	if seeking.has(id):
		return true
	# Needed by such a recipe, or by the recipe of something such a recipe needs (ore for
	# the bars the copper tools are made of, once a bar has been made).
	var needed := {}
	for r: Dictionary in crafting:
		_needs_of(r, needed)
	var ahead := 0
	for r: Dictionary in order:
		if ahead >= WANT_AHEAD:
			break
		if not made.has(r.id):
			_needs_of(r, needed)
			ahead += 1
	if needed.has(id):
		return true
	var item := Items.get_item(id)
	if item.get("prop", "none") != "none":
		return true
	# The strongest tool of each kind is kept (a copper pickaxe digs what the stone one
	# does not, and the stone one goes), of two as strong the one earlier in the bag.
	var kind: String = item.get("tool", "none")
	if kind == "none":
		return false
	# A sword, a knife and the like only while a recipe not made yet asks for one: the
	# bag has room for the tools that get things from the world.
	if not kind in ["axe", "pickaxe", "shovel", "scythe"] and not order.any(func(r: Dictionary) -> bool:
			return not made.has(r.id) and kind in r.tools):
		return false
	var slots: Array = main.host.player.inventory.slots
	var mine := slots.find(slots.filter(func(s) -> bool: return s != null and s[0] == id).front()) \
		if slots.any(func(s) -> bool: return s != null and s[0] == id) else slots.size()
	for i in slots.size():
		var s = slots[i]
		if s == null or s[0] == id or Items.get_item(s[0]).get("tool", "none") != kind:
			continue
		var power: int = Items.get_item(s[0]).get("power", 0)
		if power > item.get("power", 0) or (power == item.get("power", 0) and i < mine):
			return false
	return true


## Adds to `out` what recipe `r` needs and keeps, and what the recipes of those need, and
## so on.
func _needs_of(r: Dictionary, out: Dictionary) -> void:
	for id: String in r.needs.keys() + r.keeps.keys():
		if out.has(id):
			continue
		out[id] = true
		var sub := _recipe_for(id)
		if not sub.is_empty():
			_needs_of(sub, out)


# --- Making -------------------------------------------------------------------------------

## Makes recipe `r` `times` times at the camp: its station set down, its tools, its
## materials and what it keeps got first.
func _craft(r: Dictionary, times: int) -> bool:
	crafting.append(r)
	var ok: bool = await _craft_now(r, times)
	crafting.pop_back()
	return ok


func _craft_now(r: Dictionary, times: int) -> bool:
	if r.at != "" and _placed_count(r.at) == 0:
		# A station is set down as soon as it is made.
		var station := _recipe_for(r.at)
		if station.is_empty() or not await _craft(station, 1):
			return false
	for kind: String in r.tools:
		if _tool_of_kind(kind) == "":
			if not await _get_tool(kind):
				return false
	# What is made first, then what is gathered: making bricks would use the clay got for
	# the recipe itself.
	var needs: Array = r.needs.keys()
	needs.sort_custom(func(a: String, b: String) -> bool: return not _recipe_for(a).is_empty() and _recipe_for(b).is_empty())
	# Twice: getting one thing can use up another got before (copper bars made into the
	# copper pickaxe that digs the tin for the bronze).
	for round_i in 2:
		for id: String in needs:
			if not await _obtain(id, r.needs[id] * times):
				return false
		for id: String in r.keeps:
			if not await _obtain(id, r.keeps[id]):
				return false
	await _go(camp)
	var inv = main.host.player.inventory
	var before: int = inv.count(r.makes)
	var why: String = main.host.workshop.why_not(r)
	if main.host.workshop.start(r, times) < times:
		return _fail("%s cannot be started at the camp: %s" % [r.title, why])
	var frames := 0
	while not main.host.workshop.queue.jobs.is_empty() and frames < 600:
		# The crafting clock runs fast; the rule that the station must be near still holds.
		main.host.workshop.update(r.time / 4.0)
		await process_frame
		frames += 1
	var got: int = inv.count(r.makes) - before
	if got < r.count * times:
		return _fail("%s: made %d of %d (%s)" % [r.title, got, r.count * times,
			"waits for its station" if main.host.workshop.waiting() else "the bag is full?"])
	made[r.id] = true
	print("made %s ×%d" % [r.title, got])
	if Items.get_item(r.makes).get("prop", "none") != "none" and not await _place(r.makes):
		return false
	_tidy()
	return true


## Gets `n` of item `id` into the bag: from the world, or made by its recipe.
func _obtain(id: String, n: int) -> bool:
	seeking[id] = seeking.get(id, 0) + 1
	var ok: bool = await _obtain_more(id, n)
	seeking[id] -= 1
	if seeking[id] == 0:
		seeking.erase(id)
	return ok


func _obtain_more(id: String, n: int) -> bool:
	var inv = main.host.player.inventory
	var tries := 0
	while inv.count(id) < n:
		if swings > MAX_SWINGS:
			return _fail("out of swings while getting %s" % Items.title(id))
		# Made by a recipe if there is one (planks lie in the world only where someone
		# built with them), else got from the world.
		var r := _recipe_for(id)
		if not r.is_empty():
			if not await _craft(r, ceili(float(n - inv.count(id)) / r.count)):
				return false
		elif raw.has(id):
			if not await _gather(id):
				return false
		else:
			return _fail("no way known to get %s" % Items.title(id))
		tries += 1
		if tries > 2000:
			return _fail("%s does not come" % Items.title(id))
	return true


func _recipe_for(id: String) -> Dictionary:
	for r: Dictionary in order:
		if r.makes == id:
			return r
	return {}


## Makes a tool of kind `kind` (axe, pickaxe...), the first recipe for one.
func _get_tool(kind: String) -> bool:
	for r: Dictionary in order:
		if Items.get_item(r.makes).get("tool", "none") == kind:
			return await _craft(r, 1)
	return _fail("no recipe makes a tool of kind %s" % kind)


## The first item in the bag that is a tool of kind `kind`, "" for none.
func _tool_of_kind(kind: String) -> String:
	for s in main.host.player.inventory.slots:
		if s != null and Items.get_item(s[0]).get("tool", "none") == kind:
			return s[0]
	return ""


## Sets placed thing `id` down from the bag in front of the player at the camp, with
## the action button, turning round until there is room; with many things set down
## already, farther out round the camp.
func _place(id: String) -> bool:
	var before := _placed_count(id)
	var shifts := [Vector3.ZERO]
	for r in [3, 6, 9]:
		for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, -1)]:
			shifts.append(d * r)
	for shift in shifts:
		await _go(camp + shift * CELL)
		for facing in SpriteSheet.COMPASS:
			main.player.facing = facing
			main.controls.put_in_hand(id, -1, false)
			main.controls.act_in_front()
			await process_frame
			if _placed_count(id) > before:
				set_down[id] = true
				print("set down %s" % Items.title(id))
				return true
	return _fail("%s cannot be set down at the camp: %s" % [Items.title(id), _camp_report()])


## The camp as the placing sees it, for a failure's message: the view's cut, the feet,
## the things set down and a map of the ground round the camp (surface level above the
## feet, T a tree, b a bush, # a thing, . a cell not loaded).
func _camp_report() -> String:
	var w = main.world
	var feet: Vector3i = main.controls.feet()
	var out := "cut %d, feet %s, step %s, things %d" % [main.chunks.cut_level, feet, main.controls.step(), main.session.placed.things.size()]
	var taken := {}
	for e in main.session.placed.things:
		for dz in 2:
			for dx in 2:
				taken[Vector2i(e.cell.x + dx, e.cell.z + dz)] = true
	for z in range(feet.z - 6, feet.z + 7):
		var row := ""
		for x in range(feet.x - 6, feet.x + 7):
			var y: int = w.surface_y(x, z)
			var c := str(clampi(y + 1 - feet.y, 0, 9)) if y > 0 else "."
			if taken.has(Vector2i(x, z)):
				c = "#"
			elif w.trees.has(Vector2i(x, z)):
				c = "T"
			elif w.bushes.has(Vector2i(x, z)):
				c = "b"
			row += c
		out += "\n" + row
	return out


func _placed_count(id: String) -> int:
	return main.session.placed.things.filter(func(e: Dictionary) -> bool: return e.item == id).size()


## Throws away what is no longer wanted, so the bag keeps room.
func _tidy() -> void:
	var inv = main.host.player.inventory
	for i in inv.slots.size():
		var s = inv.slots[i]
		if s != null and not _wanted(s[0]):
			main.host.player.throw_away(i, s[1])


# --- Getting things from the world ------------------------------------------------------

## One go at getting item `id` from the world. False when there is no way.
func _gather(id: String) -> bool:
	for s: Dictionary in Trees.SPECIES:
		if id == s.seed:
			return await _tree_seed(id)
	for s: Dictionary in Trees.SPECIES:
		if id == s.twig:
			return await _branch()
		if id == s.log:
			return await _fell()
	for p: Dictionary in Plants.BY_ID.values():
		if p.gives.has(id) or p.gives.has(id.get_slice(":", 1)):
			return await _mow(id, p.id)
	for m in Mat.RECORDS.size():
		var rec: Dictionary = Mat.RECORDS[m]
		if rec.mow_gives.has(id) or rec.mow_gives.has(id.get_slice(":", 1)):
			return await _mow(id, "")
	var mats: Array[int] = []
	for m in Mat.RECORDS.size():
		var rec: Dictionary = Mat.RECORDS[m]
		if Items.dug[m] == id or Items.get_item(rec.bonus).get("id", rec.bonus) == id:
			mats.append(m)
	if not mats.is_empty():
		return await _dig_for(id, mats)
	for kind: String in AiRules.SPECIES:
		if kind != AiRules.HUMAN and AiRules.SPECIES[kind].get("carcass", "") == id:
			return await _hunt(id)
	return _fail("no way known to get %s from the world" % Items.title(id))


## A carcass `id`: the nearest animal on the ground that leaves one is struck with the
## action button, the strongest sword or knife in the bag in hand, until it falls (the
## player carried up to it after each blow, as it flees), and its carcass taken. One is
## let into the world by the player when none of them lives near: how animals come is
## not what is tested here.
func _hunt(id: String) -> bool:
	var life = main.session.wildlife
	var kinds: Array = AiRules.SPECIES.keys().filter(func(k: String) -> bool:
		var spec: Dictionary = AiRules.SPECIES[k]
		return k != AiRules.HUMAN and spec.carcass == id and spec.health > 0 and not spec.flies and not spec.swims)
	if kinds.is_empty():
		return _fail("no animal that walks leaves %s" % Items.title(id))
	var inv = main.host.player.inventory
	var before: int = inv.count(id)
	var weapon := ""
	for s in inv.slots:
		if s != null and Tools.hunts(Tools.of(s[0])) and (weapon == "" or Tools.of(s[0]).power > Tools.of(weapon).power):
			weapon = s[0]
	main.controls.put_in_hand(weapon, -1, false)
	var prey = null
	for blow in 400:
		if prey == null or prey.gone or prey.aloft():
			prey = null
			var best := INF
			for a in life.animals:
				var d: float = a.pos.distance_to(main.player.position)
				if a.kind in kinds and not a.gone and not a.aloft() and d < best:
					prey = a
					best = d
			if prey == null or best > 40.0:
				var at: Vector3 = main.player.position + Vector3(2.0, 0.0, 0.0)
				at.y = life.ground(at.x, at.z)
				prey = life._add(kinds[0], at)
		# Close by, it is struck whichever way the player faces.
		await _go(prey.pos + Vector3(0.0, 0.0, 0.15))
		# The server has the body where the player was carried a frame later.
		await process_frame
		_rest()
		swings += 1
		main.controls.act_in_front()
		await process_frame
		if prey.gone:
			for i in 10:
				await _pick_up(main.player.position, 4)
				if inv.count(id) > before:
					print("hunted %s: %s" % [AiRules.SPECIES[prey.kind].title, Items.title(id)])
					return true
				await process_frame
			return _fail("%s fell, but its %s is not on the ground" % [AiRules.SPECIES[prey.kind].title, Items.title(id)])
	return _fail("%s cannot be hunted down: %s at %s, the player at %s" % [Items.title(id), prey.kind if prey != null else "none",
		prey.pos if prey != null else Vector3.ZERO, main.host.player.position])


## A branch off the nearest bush or tree crown that has one, by hand.
func _branch() -> bool:
	main.controls.put_in_hand("", -1, false)
	var who = main.character
	var w = main.world
	for attempt in MAX_TRIPS:
		var best := {}
		var best_d := INF
		var feet: Vector3i = main.controls.feet()
		for cell: Vector3i in w.bushes:
			var d := Vector2(cell.x - feet.x, cell.z - feet.z).length()
			if d < best_d and d < SEARCH and main.actions.useful(who, {"bush": cell}):
				best = {"bush": cell}
				best_d = d
		for col: Vector2i in w.trees:
			var d := Vector2(col.x - feet.x, col.y - feet.z).length()
			if d < best_d and d < SEARCH and w.log_col(col.x, col.y) != 0 and main.actions.useful(who, {"tree": col}):
				best = {"tree": col}
				best_d = d
		if not best.is_empty():
			var at: Vector3i = best.bush if best.has("bush") else _foot(best.tree)
			await _stand_by(at)
			_rest()
			swings += 1
			if not main.gathering.gather(best):
				_tidy()
				if not main.gathering.gather(best):
					return _fail("hands take nothing from %s at %s, the bag: %s" % ["a bush" if best.has("bush") else "a tree", at,
						main.host.player.inventory.slots.filter(func(sl) -> bool: return sl != null).map(func(sl) -> String: return "%s ×%d" % sl)])
			await process_frame
			return true
		if not await _trip():
			break
	return _fail("no bush or tree with branches found")


## Gathers by hand from the nearest tree whose seed is `id` (an acorn off an oak) while
## it has seeds left (in autumn); out of season fells such a tree for the seeds it leaves.
func _tree_seed(id: String) -> bool:
	if not _seeds_on_trees(id):
		return await _fell(id)
	main.controls.put_in_hand("", -1, false)
	var who = main.character
	var w = main.world
	for attempt in MAX_TRIPS:
		var best := Vector2i.MAX
		var best_d := INF
		var feet: Vector3i = main.controls.feet()
		for col: Vector2i in w.trees:
			if Trees.SPECIES[w.trees[col]].seed != id:
				continue
			var d := Vector2(col.x - feet.x, col.y - feet.z).length()
			if d < best_d and d < SEARCH and w.log_col(col.x, col.y) != 0 and main.actions.useful(who, {"tree": col}) \
					and main.actions._gives(who, {"tree": col}) == [id]:
				best = col
				best_d = d
		if best != Vector2i.MAX:
			await _stand_by(_foot(best))
			_rest()
			swings += 1
			if not main.gathering.gather({"tree": best}):
				return _fail("hands take no %s from the tree at %s" % [Items.title(id), best])
			await process_frame
			return true
		if not await _trip():
			break
	return _fail("no tree with %s found" % Items.title(id))


## Whether a tree within reach of the player holds seeds `id` to gather by hand now.
func _seeds_on_trees(id: String) -> bool:
	var w = main.world
	var feet: Vector3i = main.controls.feet()
	for col: Vector2i in w.trees:
		if Trees.SPECIES[w.trees[col]].seed == id and Vector2(col.x - feet.x, col.y - feet.z).length() < SEARCH \
				and main.actions._gives(main.character, {"tree": col}) == [id]:
			return true
	return false


## Fells the nearest tree with an axe and takes up its logs (with `seed`, the nearest
## tree of the species with that seed, for the seeds it leaves).
func _fell(seed := "") -> bool:
	if _tool_of_kind("axe") == "" and not await _get_tool("axe"):
		return false
	main.controls.put_in_hand(_tool_of_kind("axe"), -1, false)
	var w = main.world
	for attempt in MAX_TRIPS:
		var feet: Vector3i = main.controls.feet()
		var best := Vector2i.MAX
		var best_d := INF
		for col: Vector2i in w.trees:
			if seed != "" and Trees.SPECIES[w.trees[col]].seed != seed:
				continue
			var d := Vector2(col.x - feet.x, col.y - feet.z).length()
			if d < best_d and d < SEARCH and w.log_col(col.x, col.y) != 0 and Vector2(col.x, col.y).distance_to(
					Vector2(camp.x, camp.z) / CELL) > 6:
				best = col
				best_d = d
		if best != Vector2i.MAX:
			await _stand_by(_foot(best))
			for hit in 80:
				if not w.trees.has(best) or w.log_col(best.x, best.y) == 0:
					break
				_rest()
				swings += 1
				main.controls.dig_at(main.actions.trunk_cell(main.host.player, best), Vector3i.UP)
				await process_frame
			if w.trees.has(best) and w.log_col(best.x, best.y) != 0:
				return _fail("a tree at %s does not fall to the axe" % best)
			if await _pick_up(Vector3(best.x + 0.5, feet.y, best.y + 0.5) * CELL, 14) == 0:
				# A tree by the water drops its logs into it: the next one, then.
				print("a felled %s at %s left nothing wanted" % [Trees.SPECIES[w.trees.get(best, 0)].id if w.trees.has(best) else "tree", best])
				continue
			return true
		if not await _trip():
			break
	return _fail("no tree found to fell")


## Cuts grass by hand where it gives `id`: on grass with plant `plant` on it when given.
func _mow(id: String, plant: String) -> bool:
	main.controls.put_in_hand("", -1, false)
	var w = main.world
	var hand := Tools.HAND
	for attempt in MAX_TRIPS:
		var feet: Vector3i = main.controls.feet()
		var best := Vector3i.MAX
		var best_d := INF
		for dz in range(-SEARCH, SEARCH + 1):
			for dx in range(-SEARCH, SEARCH + 1):
				var d := Vector2(dx, dz).length()
				if d >= best_d:
					continue
				var x := feet.x + dx
				var z := feet.z + dz
				var y: int = w.surface_y(x, z) - 1
				if y < 1 or _near_camp(x, z):
					continue
				var cell := Vector3i(x, y, z)
				if not main.actions.can_mow(cell, hand):
					continue
				if plant != "" and not Grass.plants_on(w, x, y, z).has(plant):
					continue
				best = cell
				best_d = d
		if best != Vector3i.MAX:
			await _stand_by(best)
			_rest()
			swings += 1
			if not main.controls.dig_at(best, Vector3i.UP):
				return _fail("hands do not cut the grass at %s for %s" % [best, Items.title(id)])
			await process_frame
			await _pick_up((Vector3(best) + Vector3(0.5, 1.0, 0.5)) * CELL, 3)
			return true
		if not await _trip():
			break
	return _fail("no grass found that gives %s" % Items.title(id))


## Digs for `id` in the cells of materials `mats` (their item or their bonus), with the
## tool in the bag that digs them, a few cells down if need be.
func _dig_for(id: String, mats: Array[int]) -> bool:
	var w = main.world
	for attempt in MAX_TRIPS:
		var feet: Vector3i = main.controls.feet()
		var best := Vector3i.MAX
		var best_cost := INF
		for dz in range(-SEARCH, SEARCH + 1):
			for dx in range(-SEARCH, SEARCH + 1):
				var dist := Vector2(dx, dz).length()
				if dist >= best_cost:
					continue
				var x := feet.x + dx
				var z := feet.z + dz
				var top: int = w.surface_y(x, z) - 1
				if top < 1 or _near_camp(x, z) or w.trees.has(Vector2i(x, z)):
					continue
				for depth in DEPTH:
					var y := top - depth
					var m: int = w.get_cell(x, y, z)
					if y < 1 or m == Mat.WATER or m == Mat.AIR or _digger(m) == "-":
						break
					if mats.has(m):
						var cost := dist + depth * 6.0
						if cost < best_cost:
							best = Vector3i(x, top, z)
							best_cost = cost
						break
		if best == Vector3i.MAX:
			# Nothing the tools in the bag dig: make one that digs these materials.
			var tool := _tool_recipe_for(mats)
			if tool != "" and main.host.player.inventory.count(tool) == 0:
				if not await _obtain(tool, 1):
					return false
				continue
			if not await _trip():
				break
			continue
		# Down the column to the first cell of the materials wanted.
		await _stand_by(best)
		var y := best.y
		while y >= 1:
			var m: int = w.get_cell(best.x, y, best.z)
			if m == Mat.AIR:
				y -= 1
				continue
			var tool := _digger(m)
			if tool == "-" or m == Mat.WATER:
				break
			main.controls.put_in_hand(tool, -1, false)
			_rest()
			swings += 1
			if not main.controls.dig_at(Vector3i(best.x, y, best.z), Vector3i.UP):
				return _fail("%s does not dig %s at %s" % [Items.title(tool) if tool != "" else "Hands", Mat.RECORDS[m].title,
					Vector3i(best.x, y, best.z)])
			await process_frame
			await _pick_up((Vector3(best.x, y, best.z) + Vector3(0.5, 0.0, 0.5)) * CELL, 3)
			if mats.has(m):
				return true
			if swings > MAX_SWINGS:
				return false
		return true
	return _fail("nothing found to dig for %s" % Items.title(id))


## The item in the bag that digs material `m` best ("" for bare hands), "-" for none: a
## shovel or a pickaxe before the hands, never an axe.
func _digger(m: int) -> String:
	var found := "-"
	for s in main.host.player.inventory.slots:
		if s != null and Tools.is_tool_item(s[0]) and Tools.can_dig(Tools.of(s[0]), m) and Tools.of(s[0]).tool != "axe":
			if found == "-" or found == "" or Tools.of(s[0]).tool == "shovel":
				found = s[0]
	if found == "-" and Tools.can_dig(Tools.HAND, m):
		found = ""
	return found


## The item a recipe makes that digs one of `mats`, "" for none.
func _tool_recipe_for(mats: Array[int]) -> String:
	for r: Dictionary in order:
		var t := Tools.of(r.makes)
		if t != Tools.HAND and t.tool != "axe" and mats.any(func(m: int) -> bool: return Tools.can_dig(t, m)):
			return r.makes
	return ""


## Takes up the wanted things lying within `radius` cells of `at` (world units), each
## with a tap as the game does; returns how many were taken.
func _pick_up(at: Vector3, radius: float) -> int:
	var w = main.world
	var took := 0
	var home := WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := home + Vector2i(dx, dz)
			var i: int = w.drops.get(key, []).size() - 1
			while i >= 0:
				var list: Array = w.drops.get(key, [])
				if i < list.size():
					var d: Array = list[i]
					if d[1].distance_to(at) <= radius * CELL and _wanted(Items.get_item(d[0]).get("id", d[0])):
						_rest()
						var before: int = main.host.player.inventory.count(d[0])
						main.gathering.gather({"drop": [key, i]})
						took += main.host.player.inventory.count(d[0]) - before
				i -= 1
	_tidy()
	return took


# --- Moving about ------------------------------------------------------------------------

## Carries the player to `at` (world units) and lets the game run a frame.
func _go(at: Vector3) -> void:
	main.player.position = at
	await process_frame


## Puts the player on open ground beside `cell`, facing it.
func _stand_by(cell: Vector3i) -> void:
	var w = main.world
	for r in range(1, 5):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cell.x + dx
				var z := cell.z + dz
				var y: int = w.surface_y(x, z)
				if y <= 0 or absi(y - cell.y) > 4 or w.get_cell(x, y, z) != Mat.AIR or w.get_cell(x, y + 1, z) != Mat.AIR \
						or w.trees.has(Vector2i(x, z)) or w.blocker_top(x, y, z) > 0.0:
					continue
				await _go((Vector3(x, y, z) + Vector3(0.5, 0.0, 0.5)) * CELL)
				main.player.facing = SpriteSheet.direction_of(Vector2(-dx, -dz))
				return
	await _go((Vector3(cell) + Vector3(0.5, 1.0, 0.5)) * CELL)


## Goes further out from the camp, along a spiral of chunks, and waits for the world
## there to be made.
func _trip() -> bool:
	trips += 1
	if trips > MAX_TRIPS * 6:
		return false
	var turn := trips * 2.4
	var r := (2.0 + trips * 1.5) * CHUNK
	var col := Vector2i((Vector2(camp.x, camp.z) / CELL + Vector2(cos(turn), sin(turn)) * r).round())
	await _go(Vector3(col.x + 0.5, main.world.size_y - 2, col.y + 0.5) * CELL)
	var frames := 0
	while frames < 4000:
		await process_frame
		frames += 1
		var key := WorldData.chunk_key(col.x, col.y)
		if frames > 5 and main.gen.stages.get(key, 0) >= WorldGen.SHAPED and main.chunks.map_done:
			break
	var y: int = main.world.surface_y(col.x, col.y)
	await _go(Vector3(col.x + 0.5, maxi(y, 1), col.y + 0.5) * CELL)
	print("trip %d to %s" % [trips, col])
	return true


## The lowest log of the tree with its trunk in `col`.
func _foot(col: Vector2i) -> Vector3i:
	var logs: int = main.world.log_col(col.x, col.y)
	return Vector3i(col.x, WorldData.level_of(logs & -logs), col.y)


func _near_camp(x: int, z: int) -> bool:
	return Vector2(x + 0.5, z + 0.5).distance_to(Vector2(camp.x, camp.z) / CELL) < 6.0


## Tiredness and hunger are not tested here.
func _rest() -> void:
	var v = main.host.player.vitals
	v.stamina = v.MAX
	v.health = v.MAX
	v.satiety = v.MAX
