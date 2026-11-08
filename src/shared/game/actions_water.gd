extends "res://src/shared/game/actions_fight.gd"
## The rules of the hands, part four (world_actions.gd): drinking and filling a vessel
## at the water, fishing with a rod, and the water and the biome ahead of the body.

const Biomes := preload("res://src/shared/content/biomes.gd")
## The fishing lines cast (Fishing): a rod casts and pulls them.
var fishing
## Water a gulp at fresh water gives, how long it takes, and how far off the water can be
## (cells; a tap on it reaches one more).
const DRINK := 25.0
const DRINK_SWING := 0.8
const DRINK_REACH := 2


## Drinks from, or fills a vessel at, the water at world point `water`: an empty hand
## drinks (Vitals.drink), an empty vessel in the hand (an item with `fills_to`) becomes
## a full one. Only fresh water (fresh_water): the sea is salty.
func drink(who, water: Vector3) -> Dictionary:
	if not fresh_water(water):
		who.nag("salty", "Морская вода солёная: пить её нельзя")
		return {"swing": IDLE_SWING}
	var full := _fills(who)
	if full != "":
		var empty: String = who.held()
		if who.inventory.remove(empty, 1) != 1:
			return {"swing": IDLE_SWING}
		if who.give(full, 1) == 0:
			who.give(empty, 1)
			return {"swing": IDLE_SWING}
		return _work(DRINK_SWING, "", water, Mat.WATER)
	if not who.vitals.drink(DRINK):
		who.nag("not_thirsty", "Пить не хочется")
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


## Whether the hand in use of `who` drinks or fills at water: empty, or an empty vessel.
func _drinks_with(who) -> bool:
	return "vitals" in who and (who.held() == "" or _fills(who) != "")


## What the vessel in the hand in use of `who` becomes filled, "" for none.
func _fills(who) -> String:
	var held: String = who.held()
	return Items.get_item(held).get("fills_to", "") if held != "" else ""


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
## in `shot` (Fishing.pull). Nothing on frozen water, or with no water there.
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
		who.nag("fish", "Вода замёрзла: рыба подо льдом не клюёт")
		return {"swing": IDLE_SWING}
	var water := water_ahead(at, dir, maxi(2, rod.get("range", 0)))
	if water == Vector3.INF:
		who.nag("fish", "Удочку закидывают в воду: подойдите к ней")
		return {"swing": IDLE_SWING}
	if not who.act("swing"):
		return {}
	who.use_tool()
	water = _cast_out(at, dir, water, maxi(2, rod.get("range", 0)))
	# The float lies on the water's surface, not at the top of its cell.
	water.y -= (1.0 - WorldData.WATER_TOP) * CELL
	var item := Items.get_item(who.held())
	fishing.cast(who, water, item.get("ammo", ""))
	if fishing.fish_near(water) == null:
		who.nag("no_fish", "Рядом с поплавком не видно рыбы")
	elif item.get("ammo", "") != "" and fishing.lines[who].bait == "":
		who.nag("bait", Lang.line("Без наживки клюёт редко: нужна «%s»", [Items.title(item.ammo)]))
	var done := _work(CAST_SWING, "", water)
	done.line = water
	return done


## How far past the shore a cast lays the float, in cells, where the water goes on.
const CAST_OUT := 3.0


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
		who.note("fished")
		_learn_each(who, "fish")
		# A skilled angler now and then lands two.
		if _extra(who, "fish"):
			who.give(r.caught, 1)
		var to: Vector3 = who.position + Vector3(0.0, 0.6, 0.0)
		done.shot = [r.caught, r.from, to, r.from.distance_to(to) / CATCH_SPEED]
	elif r.full:
		who.nag("full", "Сумка полна: рыба ушла")
	elif not r.bit:
		who.nag("bite", "Не клюнуло")
	else:
		who.nag("bite", "Сорвалась")
	return done


## The top of the nearest open water from `at` along `dir` (x, z), from a cell out to
## `reach` cells, as a world point; INF when there is none.
func water_ahead(at: Vector3, dir: Vector2, reach: int) -> Vector3:
	var from := Vector2(at.x, at.z) / CELL
	for i in range(2, reach * 2 + 1):
		var p := from + dir * (i * 0.5)
		var x := floori(p.x)
		var z := floori(p.y)
		var bits: int = world.water_col(x, z)
		if bits == 0:
			continue
		var top := WorldData.top_level(bits)
		if world.get_cell(x, top + 1, z) == Mat.AIR:
			return Vector3(p.x, top + 1.0, p.y) * CELL
	return Vector3.INF


## The biome of the column under world point `at` by the layout of the land (Biomes.NONE
## without one).
func biome_under(at: Vector3) -> int:
	if wildlife == null or wildlife.gen == null:
		return Biomes.NONE
	return wildlife.gen.biome_of(floori(at.x / CELL), floori(at.z / CELL))
