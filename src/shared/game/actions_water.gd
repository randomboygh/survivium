extends "res://src/shared/game/actions_fight.gd"
## The rules of the hands, part four (world_actions.gd): drinking and filling a vessel
## at the water, fishing with a rod (in winter through a hole in the ice), cutting holes
## in the ice, and the water and the biome ahead of the body.

const Biomes := preload("res://src/shared/content/biomes.gd")
## The fishing lines cast (Fishing): a rod casts and pulls them.
var fishing
## The holes in the ice (Ice): a tool of class `ice` cuts them, a rod is cast into them.
var ice
## Water a gulp at fresh water gives, how long it takes, and how far off the water can be
## (cells; a tap on it reaches one more).
const DRINK := 25.0
const DRINK_SWING := 0.8
const DRINK_REACH := 2


## Drinks from, or fills a vessel at, the water at world point `water`: an empty hand
## drinks (Vitals.drink), an empty vessel in the hand (an item with `fills_to`) becomes
## a full one. Only fresh water (fresh_water) is drunk: the sea is salty, and a vessel
## filled there becomes its `fills_salty_to` (sea water, boiled at a campfire).
func drink(who, water: Vector3) -> Dictionary:
	var fresh := fresh_water(water)
	if who.held() != "":
		var to := vessel_to_fill(who, fresh)
		if to.is_empty():
			who.nag("salty" if not fresh else "full", "[this_cannot_hold_sea_water]" if not fresh else "[the_vessel_is_full]")
			return {"swing": IDLE_SWING}
		if who.inventory.pour(to[0], to[1], 1 << 20) <= 0:
			return {"swing": IDLE_SWING}
		return _work(DRINK_SWING, "", water, Mat.WATER)
	if not fresh:
		who.nag("salty", "[sea_water_is_salty_you]")
		return {"swing": IDLE_SWING}
	if not who.vitals.drink(DRINK):
		who.nag("not_thirsty", "[not_thirsty]")
		return {"swing": IDLE_SWING}
	who.note("drunk")
	return _work(DRINK_SWING, "", water, Mat.WATER)


## Whether the water at world point `water` is fresh: a lake, a river, the pools of a
## swamp; not the sea. Fresh without a layout of the land (tests).
func fresh_water(water: Vector3) -> bool:
	if wildlife == null or wildlife.gen == null:
		return true
	var gen = wildlife.gen
	var w: Dictionary = gen.lay_out(floori(water.x / CELL), floori(water.z / CELL), 1, 1)
	return w.feature[0] == gen.LAKE or w.feature[0] == gen.RIVER or w.flags[0] & (gen.MARSH | gen.MIRE) != 0


## Whether the hand in use of `who` drinks or fills at water: empty, an empty vessel, or
## a vessel of water.
func _drinks_with(who) -> bool:
	return "vitals" in who and (who.held() == "" or _fills(who) != "" or _fills_salty(who) != "" or Items.holds(who.held()) > 0)


## The vessel in the hand in use of `who` that takes water, fresh (`fresh`) or of the sea
## (Inventory.vessel_for): [its slot, what it becomes], [] for none.
static func vessel_to_fill(who, fresh: bool) -> Array:
	return who.inventory.vessel_for(who.held(), fresh)


## What the vessel in the hand in use of `who` becomes filled, "" for none.
func _fills(who) -> String:
	var held: String = who.held()
	return Items.get_item(held).get("fills_to", "") if held != "" else ""


## What the vessel in the hand in use of `who` becomes filled at the sea, "" for none.
func _fills_salty(who) -> String:
	var held: String = who.held()
	return Items.get_item(held).get("fills_salty_to", "") if held != "" else ""


# --- Fishing ---------------------------------------------------------------------------

## How long a cast and a pull take, in seconds; how fast a catch flies to the angler, in
## world units a second.
const CAST_SWING := 0.9
const PULL_SWING := 0.6
const CATCH_SPEED := 8.0


## The rod in hand of `who`: with no line in the water, casts it toward `aim` (ahead if
## not finite) into the nearest open water within the rod's `range`, one of its `ammo`
## from the bag on the hook (Fishing.cast; the reply's "line" is where the float lies);
## with a line out, pulls it: a fish biting goes into the bag, its flight to the angler
## in `shot` (Fishing.pull). On frozen water only into an open hole in the ice within
## HOLE_REACH (hole_near); nothing with no water there.
func fish(who, aim := Vector3.INF) -> Dictionary:
	if fishing == null:
		return {"swing": IDLE_SWING}
	if fishing.has_line(who):
		return _pull(who)
	var rod: Dictionary = who.tool()
	var at: Vector3 = who.position
	var dir := Vector2(who.facing_step()).normalized()
	if aim.is_finite() and Vector2(aim.x - at.x, aim.z - at.z).length() > 0.05:
		dir = Vector2(aim.x - at.x, aim.z - at.z).normalized()
	if world.water_frozen:
		return _fish_hole(who, aim)
	var water := water_ahead(at, dir, maxi(2, rod.get("range", 0)), true)
	if water == Vector3.INF and world.icy():
		# Ice ahead while the water freezes: an open hole is fished as in a frozen world.
		return _fish_hole(who, aim)
	if water == Vector3.INF:
		who.nag("fish", "[a_rod_is_cast_into]")
		return {"swing": IDLE_SWING}
	if not who.act("swing"):
		return {}
	who.use_tool()
	water = _cast_out(at, dir, water, maxi(2, rod.get("range", 0)))
	# The float lies on the water's surface, not at the top of its cell.
	water.y -= (1.0 - world.water_top(floori(water.y / CELL) - 1)) * CELL
	return _cast_at(who, water)


## Lays the float of the rod in hand of `who` at `water` (see fish), with the rod's bait
## and lure.
func _cast_at(who, water: Vector3) -> Dictionary:
	var item := Items.get_item(who.held())
	fishing.cast(who, water, item.get("ammo", ""), item.get("lure", 1.0))
	if fishing.fish_near(water) == null:
		who.nag("no_fish", "[no_fish_to_be_seen]")
	elif item.get("ammo", "") != "" and fishing.lines[who].bait == "":
		who.nag("bait", Lang.line("[without_bait_bites_are_rare]", [Items.title(item.ammo)]))
	var done := _work(CAST_SWING, "", water)
	done.line = water
	return done


## How far past the shore a cast lays the float, in cells, where the water goes on.
const CAST_OUT := 3.0
## How far from the body a hole in the ice is fished, and its ice cut, in cells.
const HOLE_REACH := 2.5


## The rod in hand of `who` in a frozen world: cast into the open hole nearest `aim` (or
## the body) within HOLE_REACH, the float on the water in the middle of the hole.
func _fish_hole(who, aim: Vector3) -> Dictionary:
	var col: Variant = hole_near(who, aim)
	if col == null:
		who.nag("fish", "[cut_a_hole_in_the]")
		return {"swing": IDLE_SWING}
	if not who.act("swing"):
		return {}
	who.use_tool()
	var top := WorldData.top_level(world.water_col(col.x, col.y))
	return _cast_at(who, Vector3(col.x + 0.5, top + world.water_top(top), col.y + 0.5) * CELL)


## The open hole in the ice nearest `aim` (else the body of `who`) within HOLE_REACH cells
## of the body, null for none.
func hole_near(who, aim := Vector3.INF) -> Variant:
	if ice == null or world.ice_holes.is_empty():
		return null
	var from: Vector3 = who.position / CELL
	var to: Vector3 = aim / CELL if aim.is_finite() else from
	var best = null
	var best_d := INF
	for col: Vector2i in world.ice_holes:
		if not ice.is_open(col):
			continue
		var mid := Vector2(col.x + 0.5, col.y + 0.5)
		if mid.distance_to(Vector2(from.x, from.z)) > HOLE_REACH:
			continue
		var d := mid.distance_to(Vector2(to.x, to.z))
		if d < best_d:
			best_d = d
			best = col
	return best


## The column of ice a tool of class `ice` in hand of `who` cuts: the one at `aim` (a tap,
## world units) or else ahead of the body, one or two cells off, frozen water within
## HOLE_REACH; null for none.
func ice_ahead(who, aim := Vector3.INF) -> Variant:
	if not world.icy():
		return null
	var from: Vector3 = who.position / CELL
	var cols: Array[Vector2i] = []
	if aim.is_finite():
		cols.append(Vector2i(floori(aim.x / CELL), floori(aim.z / CELL)))
	else:
		var dir := Vector2(who.facing_step()).normalized()
		for i in [2, 3, 4]:
			var p: Vector2 = Vector2(from.x, from.z) + dir * (i * 0.5)
			cols.append(Vector2i(floori(p.x), floori(p.y)))
	var feet := Vector2i(floori(from.x), floori(from.z))
	for col in cols:
		if col == feet or Vector2(col.x + 0.5, col.y + 0.5).distance_to(Vector2(from.x, from.z)) > HOLE_REACH:
			continue
		if world.water_col(col.x, col.y) != 0 and (world.frozen_at(col.x, col.y) or world.ice_holes.has(col)):
			return col
	return null


## A blow of the ice tool in hand of `who` at the ice ahead (or at `aim`): it cuts a hole
## there in a few blows, or breaks the crust over one (Ice.cut).
func cut_ice(who, aim := Vector3.INF) -> Dictionary:
	var t: Dictionary = who.tool()
	var col: Variant = ice_ahead(who, aim)
	if ice == null or col == null:
		who.nag("ice", "[stand_by_the_ice_to]")
		return {"swing": IDLE_SWING}
	var why: String = ice.why_not(col)
	if why != "":
		who.nag("ice", why)
		return {"swing": IDLE_SWING}
	if ice.is_open(col):
		who.nag("ice", "[the_hole_is_open]")
		return {"swing": IDLE_SWING}
	var top := WorldData.top_level(world.water_col(col.x, col.y))
	if _allowed(who, [Vector3i(col.x, top, col.y)] as Array[Vector3i], "build").is_empty() or not who.act("dig", "dig"):
		return {}
	ice.cut(col, int(t.get("power", 1)))
	who.use_tool()
	return _work(skilled(who, "fish", t.swing), "",
		Vector3(col.x + 0.5, top + world.water_top(top), col.y + 0.5) * CELL, Mat.WATER)


## Where a cast from `at` along `dir` lands past `water`, the first open water ahead: up
## to CAST_OUT cells on while the water goes on open at its level, within `reach` cells.
func _cast_out(at: Vector3, dir: Vector2, water: Vector3, reach: int) -> Vector3:
	var level := floori(water.y / CELL)
	var best := water
	for i in range(1, int(CAST_OUT * 2.0) + 1):
		var p := Vector2(water.x, water.z) / CELL + dir * (i * 0.5)
		if (p - Vector2(at.x, at.z) / CELL).length() > reach:
			break
		var bits: int = world.water_col(floori(p.x), floori(p.y))
		if bits == 0 or WorldData.top_level(bits) + 1 != level or world.get_cell(floori(p.x), level, floori(p.y)) != Mat.AIR:
			break
		best = Vector3(p.x, level, p.y) * CELL
	return best


## Pulls the line of `who` out of the water (see fish).
func _pull(who) -> Dictionary:
	var r: Dictionary = fishing.pull(who)
	var done := _work(PULL_SWING, "", r.from)
	done.line = Vector3.INF
	if r.caught != "":
		# The client feels it come out (Vibration "catch").
		done.caught = true
		who.note("fished")
		_learn_each(who, "fish")
		# A skilled angler now and then lands two.
		if _extra(who, "fish"):
			Inventory.give_or_lay(who, r.caught, 1)
		var to: Vector3 = who.position + Vector3(0.0, 0.6, 0.0)
		done.shot = [r.caught, r.from, to, r.from.distance_to(to) / CATCH_SPEED]
	elif r.full:
		who.nag("full", "[the_bag_is_full_the]")
	elif not r.bit:
		who.nag("bite", "[no_bite]")
	else:
		who.nag("bite", "[it_got_away]")
	return done


## The top of the nearest open water from `at` along `dir` (x, z), from a cell out to
## `reach` cells, as a world point; INF when there is none. Open means air over it up to
## the level of the body: water in a cave under the ground in front is not reached (the
## user's report 2026-11-20: the button drank "sea water" in a forest over a cave lake).
## `no_ice`: frozen columns are passed over (a rod is cast past the ice).
func water_ahead(at: Vector3, dir: Vector2, reach: int, no_ice := false) -> Vector3:
	var from := Vector2(at.x, at.z) / CELL
	var feet := floori(at.y / CELL)
	for i in range(2, reach * 2 + 1):
		var p := from + dir * (i * 0.5)
		var x := floori(p.x)
		var z := floori(p.y)
		var bits: int = world.water_col(x, z)
		if bits == 0 or no_ice and world.frozen_at(x, z):
			continue
		var top := WorldData.top_level(bits)
		var open := true
		for y in range(top + 1, maxi(top + 2, feet + 1)):
			if world.get_cell(x, y, z) != Mat.AIR:
				open = false
				break
		if open:
			return Vector3(p.x, top + 1.0, p.y) * CELL
	return Vector3.INF

