extends "res://src/shared/game/placed_build.gd"
## Placed things, part 5 (see placed.gd): fires and their fuel, the rain on them and in the rain
## catchers, snow things melting, what chests hold spoiling, and the time passing for every thing
## and light set down (step).

const Body := preload("res://src/shared/game/body.gd")
const Warmth := preload("res://src/shared/game/warmth.gd")
## How close (in cells) a body pushing into a burning campfire, or over it, comes to be
## burnt.
const SINGE := 0.02
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
## Water (Vitals units) a rain catcher (an item with `rain_water`) under the open sky
## gathers a second in a downpour (rain 1; less in a lighter rain), and how much more
## of it runs in before it is told (water_changed). Drawn from it: a gulp of an empty
## hand (WorldActions.DRINK), a vessel's `drink` (CATCH_FILL for one that is no drink).
const RAIN_CATCH := 1.0
const WATER_TELL := 5.0
const CATCH_GULP := 25.0
const CATCH_FILL := 60.0
## A thing of snow (an item with `melts`, a snowman) melts its `melts` days in air this
## warm (Warmth.air with the fires near, degrees), faster in warmer, not at all at 0 and
## below; it is drawn in MELT_STAGES stages (melt_stage), the first whole, and those who
## copy the world learn of each new stage (melt_changed).
const MELT_WARM := 10.0


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


func _add_fuel(e: Dictionary, fuel: String) -> void:
	var most: float = Items.get_item(e.item).fuel_max
	if most > 0.0:
		e.fuel = minf(most, float(e.get("fuel", 0.0)) + Items.fuel_time(fuel))
		fuel_changed.emit(e)


## True when nothing keeps the rain off thing `e` (a fire, a rain catcher): a column of its cells has no roof above
## it (WorldData.roof_level), its chunk in memory.
func _in_rain(e: Dictionary) -> bool:
	var c: Vector3i = e.cell
	if world.chunk_at(c.x, c.z) == null:
		return false
	for k: Vector3i in cells_of(e):
		if world.roof_level(k.x, k.z) < c.y:
			return true
	return false


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
		elif e.has("water") and rain > 0.0:
			_catch_rain(e, delta, rain)
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


## The things of snow (`melt`) melt `days` of game time in the air round them as warm
## as Warmth.air says with the fires near (MELT_WARM): a new stage is told (melt_changed),
## one melted through is gone (melted, then removed). The session's step.
func melt(days: float, clock) -> void:
	for e: Dictionary in things.duplicate():
		if not e.has("melt"):
			continue
		var c: Vector3i = e.cell
		var p := center(e)
		var roofed: bool = world.chunk_at(c.x, c.z) != null and world.roof_level(c.x, c.z) > c.y
		var warm := Warmth.air(world, clock, p, roofed) + Warmth.fire_heat(self, p)
		if warm <= 0.0:
			continue
		var was := melt_stage(e)
		e.melt = minf(1.0, e.melt + days * warm / MELT_WARM / Items.get_item(e.item).melts)
		if e.melt >= 1.0:
			melted.emit(e)
			_remove(e)
		elif melt_stage(e) != was:
			melt_changed.emit(e)


## What the things that store hold spoils `days` of game time (Inventory.spoil), slower
## in winter and under a roof: a chest in a cellar or a cave keeps food longest. The
## session's step.
func spoil(days: float, winter: bool) -> void:
	for e: Dictionary in things:
		if e.items != null:
			var c: Vector3i = e.cell
			var roofed: bool = world.chunk_at(c.x, c.z) != null and world.roof_level(c.x, c.z) > c.y
			e.items.spoil(days, Inventory.spoil_rate(winter, roofed) * Items.get_item(e.item).get("keeps", 1.0))


## Rain catcher `e` gathers `delta` seconds of a rain of strength `rain` under the open
## sky (RAIN_CATCH), up to its item's `rain_water`.
func _catch_rain(e: Dictionary, delta: float, rain: float) -> void:
	var most: float = Items.get_item(e.item).rain_water
	var was: float = e.water
	if was >= most or not _in_rain(e):
		return
	e.water = minf(most, was + RAIN_CATCH * rain * delta)
	if floori(e.water / WATER_TELL) != floori(was / WATER_TELL) or e.water >= most:
		water_changed.emit(e)


## `who` draws from rain catcher `e` with the hand in use: an empty hand drinks a gulp
## (CATCH_GULP, what it holds if less), an empty vessel or one of fresh water not full is
## filled with what it holds (Inventory.pour; a vessel that keeps no amount, a watering
## can, takes CATCH_FILL and only when that much is there). False, told why, when
## nothing was done.
func draw_water(who, e: Dictionary) -> bool:
	if not is_catcher(e) or not "vitals" in who:
		return false
	var held: String = who.held()
	if e.water < 1.0:
		who.nag("catch", "[too_little_rain_water_here]")
		return false
	if held == "":
		var gulp := minf(CATCH_GULP, e.water)
		if not who.vitals.drink(gulp):
			who.nag("not_thirsty", "[not_thirsty]")
			return false
		who.note("drunk")
		e.water = maxf(0.0, e.water - gulp)
		water_changed.emit(e)
		return true
	var to: Array = who.inventory.vessel_for(held, true)
	if to.is_empty():
		who.nag("catch", "[empty_hand_or_vessel_for_rain_water]")
		return false
	var keeps_amount := Items.holds(to[1]) > 0
	if not keeps_amount and e.water < CATCH_FILL:
		who.nag("catch", "[too_little_rain_water_here]")
		return false
	var poured: int = who.inventory.pour(to[0], to[1], floori(e.water) if keeps_amount else int(CATCH_FILL))
	if poured <= 0:
		return false
	e.water = maxf(0.0, e.water - poured)
	water_changed.emit(e)
	return true


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
		if e.fuel <= 0.0:
			burnt_down.emit(e)
	elif floori(e.fuel / FUEL_TELL) != floori(was / FUEL_TELL):
		fuel_changed.emit(e)
