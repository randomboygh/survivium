extends "res://src/shared/game/actions_build.gd"
## The rules of the hands, part seven (world_actions.gd): farming (thread «Сделать режим
## земледелия», 2026-11-06). A hoe tills grass or bare ground into a bed (Mat.BED); seeds
## of a crop (an item with `crop`, a plant of kind crop) are sown on a bed; a watering
## can wets it (Mat.BED_WET) for WET_DAYS, and so does rain on a bed under the open sky;
## a crop grows only in the warm seasons on a wet bed, its `grow_days` until it is ripe,
## and dies in winter (grow_fields, a step of the session); a ripe crop is reaped by bare
## hands and a sickle, by a scythe when it is cut by one (`mown`), and gives what its
## `gives` says. The bed's crop, growth and wetness are WorldData.fields; the work
## teaches the skill of farming (role "farm"). A tree's seed (an item whose `crop` is a
## plant of kind sapling) is planted on open ground on the trees' lattice (odd x and z,
## away from other trees); the sapling grows in the warm seasons, wet or dry, and grown
## becomes its tree (Growth.place) where there is room for one.

## How long a bed stays wet after watering or rain, in days.
const WET_DAYS := 1.0
## Rain at least this strong (Clock.WEATHERS `rain`) wets the beds under the open sky.
const RAIN_WETS := 0.3
## How often the beds are looked at (grow_fields), in seconds of play.
const FIELD_TICK := 1.0
## Seconds a sowing and a watering take with no skill.
const SOW_SWING := 0.3
const WATER_SWING := 0.6
## A sapling is planted no nearer than this to another tree or sapling, in cells (the
## crowns' lattice: trunks on odd columns).
const SAPLING_GAP := 2
## Cells of air a young tree (Growth.place_young) needs over its ground.
const YOUNG_HEIGHT := 8

var _field_clock := 0.0


## A tap on `cell` with the hand in use, when it is farming work: a hoe tills, a can
## waters a bed, a ripe crop on a bed is reaped by what can reap it; else the work of
## the earlier parts (dig_at: a shovel digs a bed out, its crop lost).
func dig_at(who, cell: Vector3i, normal: Vector3i) -> Dictionary:
	var done: Variant = farm_at(who, cell)
	if done != null:
		return done
	return super(who, cell, normal)


## The farming work a tap on `cell` does with the hand in use of `who` (see dig_at), null
## when it is none.
func farm_at(who, cell: Vector3i) -> Variant:
	if not world.in_bounds(cell.x, cell.y, cell.z):
		return null
	var t: Dictionary = who.tool()
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	if Mat.is_bed(m):
		if too_far(who, cell, t.reach):
			who.nag("far", "Слишком далеко")
			return {}
		if Tools.can_water(t):
			return water(who, farm_cells(who, cell, t, func(c: Vector3i) -> bool: return can_water(c)))
		var crop := crop_on(cell)
		if crop != "":
			var c: Dictionary = Plants.BY_ID.get(crop, {})
			if ripe_at(cell):
				if Tools.can_reap(t, c):
					return reap(who, farm_cells(who, cell, t, func(at: Vector3i) -> bool: return can_reap(at, t)))
				if t.tool == "scythe":
					who.nag("reap", "%s косой не срезать: соберите руками или серпом" % c.title)
					return {}
			elif t.tool in ["hand", "sickle", "scythe", "hoe"]:
				who.nag("ripe", "Ещё не созрело: %s, %d%%" % [c.title, roundi(growth(cell) * 100.0)])
				return {}
		if Tools.can_till(t):
			who.nag("tilled", "Здесь уже грядка")
			return {}
		if t.tool == "hand":
			# Hands do not scrape a bed away by a slip of a tap: a shovel digs it.
			who.nag("bed", "Грядку убирают лопатой")
			return {}
		return null
	if Tools.can_till(t):
		if too_far(who, cell, t.reach):
			who.nag("far", "Слишком далеко")
			return {}
		var cells := farm_cells(who, cell, t, func(c: Vector3i) -> bool: return can_till(c))
		if cells.is_empty():
			who.nag("till", "Вскопать грядку можно на траве или земле под открытым верхом")
			return {}
		return till(who, cells)
	if Tools.can_water(t):
		who.nag("water", "Поливают грядки")
		return {}
	return null


## The farming work the action button does in front of `who` (see act_in_front) at the
## nearest ground cell round the body it applies to (front_farm), {} for none.
func farm_in_front(who) -> Dictionary:
	var spot: Variant = front_farm(who)
	if spot == null:
		return {}
	var done: Variant = farm_at(who, spot[1])
	return done if done is Dictionary else {}


## The farming work in front of `who` and its cell, [kind, cell], null for none: "till"
## (a hoe, ground it tills), "water" (a can with water, a dry bed), "reap" (a ripe crop
## the hand in use reaps); in the order of Tools.sector, the ground under each column.
func front_farm(who) -> Variant:
	var t: Dictionary = who.tool()
	var till := Tools.can_till(t)
	var waters := Tools.can_water(t)
	var feet: Vector3i = who.feet()
	for o in Tools.sector(who.facing_step()):
		for dy in [-1, 0, -2]:
			var c: Vector3i = feet + Vector3i(o.x, dy, o.y)
			if too_far(who, c, t.reach):
				continue
			if till:
				if can_till(c):
					return ["till", c]
			elif waters:
				if world.get_cell(c.x, c.y, c.z) == Mat.BED:
					return ["water", c]
			elif can_reap(c, t):
				return ["reap", c]
	return null


## The cells round `cell` (it first, then the ones beside it on its level, Tools.area_cells)
## that pass `fits` and lie within reach of the tool `t` of `who`, as many as it works in
## a swing (`area`).
func farm_cells(who, cell: Vector3i, t: Dictionary, fits: Callable) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in Tools.area_cells(cell, Vector3i.UP):
		if out.size() >= maxi(1, t.get("area", 1)):
			break
		if fits.call(c) and not too_far(who, c, t.reach):
			out.append(c)
	return out


# --- Tilling ------------------------------------------------------------------------------


## Whether `cell` can be tilled: grass or bare ground with air over it and nothing
## standing there (a bush, a thing set down), when a mod gives beds.
func can_till(cell: Vector3i) -> bool:
	if Mat.BED < 0 or not world.in_bounds(cell.x, cell.y, cell.z):
		return false
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	var up := cell + Vector3i.UP
	return (m == Mat.GRASS or m == Mat.DIRT) and world.get_cell(up.x, up.y, up.z) == Mat.AIR \
		and not world.bushes.has(up) and world.blocker_top(up.x, up.y, up.z) <= 0.0 \
		and world.blocker_top(cell.x, cell.y, cell.z) <= 0.0 and tree_of(cell) == null


## Tills `cells` into beds in one swing of the hoe in hand (or hoe item `tool` of the
## bag: the farming mode's marks, FarmMarks): grass gives its fibre (its `mow_gives`) as
## when it is cut.
func till(who, cells: Array[Vector3i], tool: Variant = null) -> Dictionary:
	cells = _allowed(who, cells, "build")
	if cells.is_empty() or not who.act("dig", "farm"):
		return {}
	var keys := {}
	for c in cells:
		var was: int = world.get_cell(c.x, c.y, c.z)
		world.set_cell(c.x, c.y, c.z, Mat.BED)
		world.set_field(c, ["", 0.0, 0.0])
		_changed(c)
		var own: Dictionary = Mat.RECORDS[was].mow_gives
		for id in own:
			world.heap_drop(Items.get_item(id).get("id", id), floor_under(c + Vector3i.UP), own[id], randf() * TAU)
			keys[WorldData.chunk_key(c.x, c.z)] = true
	for key in keys:
		drops_changed.emit(key)
	var t: Dictionary = who.tool() if tool == null else Tools.of(tool)
	var done := _work(skilled(who, "farm", t.swing), "", (Vector3(cells[0]) + Vector3(0.5, 1.0, 0.5)) * CELL, Mat.DIRT)
	_wear(who, tool)
	return done


## Wears the hand's tool (`tool` null) or tool item `tool` of the bag by one swing.
func _wear(who, tool: Variant) -> void:
	if tool == null:
		who.use_tool()
	elif tool is String and tool != "" and rules.tool_wear \
			and who.inventory.wear_tool(tool, Items.get_item(tool).get("durability", 0)):
		who.say("Сломалось: %s" % Items.title(tool))


# --- Sowing -------------------------------------------------------------------------------


## The crop growing on bed `cell` (a plant id), "" for none or no bed.
func crop_on(cell: Vector3i) -> String:
	var f: Variant = world.field_at(cell)
	return f[0] if f != null else ""


## How far the crop on bed `cell` has grown, 0..1 (1 ripe).
func growth(cell: Vector3i) -> float:
	var f: Variant = world.field_at(cell)
	if f == null or f[0] == "":
		return 0.0
	var days: float = Plants.BY_ID.get(f[0], {}).get("grow_days", 0.0)
	return 1.0 if days <= 0.0 else clampf(f[1] / days, 0.0, 1.0)


## Whether the crop on bed `cell` is ripe.
func ripe_at(cell: Vector3i) -> bool:
	var f: Variant = world.field_at(cell)
	return f != null and f[0] != "" and Plants.ripe(f[0], f[1])


## Whether crop item `item` (a record with `crop`) can be sown on `cell`: a bed with no
## crop and air over it, not in winter.
func can_sow(item: Dictionary, cell: Vector3i) -> bool:
	if Plants.is_sapling(item.get("crop", "")):
		return can_root(cell) and clock.season != WINTER
	if not Plants.is_crop(item.get("crop", "")) or not Mat.is_bed(world.get_cell(cell.x, cell.y, cell.z)):
		return false
	var up := cell + Vector3i.UP
	return crop_on(cell) == "" and world.field_at(cell) != null and world.get_cell(up.x, up.y, up.z) == Mat.AIR \
		and clock.season != WINTER


## Plants item `id` on `cell` (see ActionsBuild.plant_at): a crop's seeds go on a bed (sow).
func plant_at(who, id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if not Plants.is_sown(item.get("crop", "")):
		return super(who, id, cell)
	var sapling := Plants.is_sapling(item.crop)
	if sapling:
		var spot: Variant = sapling_spot(cell)
		if spot != null:
			cell = spot
	if who.inventory.count(item.id) == 0:
		who.nag("no_seed", "В сумке нет: %s" % Items.title(id))
		return false
	if clock.season == WINTER:
		who.nag("winter", "Зимой не сеют: дождитесь весны")
		return false
	if too_far(who, cell, Tools.PLACE_REACH) or not can_sow(item, cell):
		if sapling:
			who.nag("plant", "Сюда не посадить: дереву нужна открытая земля подальше от других деревьев")
		else:
			who.nag("plant", "Сеют на пустую грядку: вскопайте её тяпкой")
		return false
	if not _may(who, cell, "build") or not who.act("gather", "farm"):
		return false
	sow(who, item, cell)
	return true


## Sows crop item `item` from the bag of `who` on bed `cell` (can_sow holds).
func sow(who, item: Dictionary, cell: Vector3i) -> void:
	who.inventory.remove(item.id, 1)
	var f: Variant = world.field_at(cell)
	world.set_field(cell, [item.crop, 0.0, f[2] if f != null else 0.0])
	skilled(who, "farm", SOW_SWING)
	looks_changed.emit(WorldData.chunk_key(cell.x, cell.z))


## Whether a crop of `id` sown in front of `who` would go on a bed there (see plant_spot).
func _can_plant(who, id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if Plants.is_sapling(item.get("crop", "")):
		var spot: Variant = sapling_spot(cell)
		return spot != null and not too_far(who, spot, Tools.PLACE_REACH) and can_sow(item, spot)
	if Plants.is_crop(item.get("crop", "")):
		return not too_far(who, cell, Tools.PLACE_REACH) and can_sow(item, cell)
	return super(who, id, cell)


## Whether item `id` could be planted on ground cell `cell` some day, wherever the one
## planting stands (the farming mode's marks): a crop's seeds on an empty bed or on
## ground a hoe tills first, a bush on ground it fits, seeds of grass on the bare ground
## they grow on.
func plantable(id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if item.is_empty() or not world.in_bounds(cell.x, cell.y, cell.z):
		return false
	var up := cell + Vector3i.UP
	if Plants.is_sapling(item.get("crop", "")):
		return cell.x & 1 == 1 and cell.z & 1 == 1 and can_root(cell)
	if Plants.is_crop(item.get("crop", "")):
		if can_till(cell):
			return true
		return Mat.is_bed(world.get_cell(cell.x, cell.y, cell.z)) and crop_on(cell) == "" \
			and world.get_cell(up.x, up.y, up.z) == Mat.AIR
	if item.get("plant", "") != "":
		return Bushes.index(item.plant) >= 0 and Growth.bush_fits(world, up.x, up.y, up.z) and not world.bushes.has(up)
	if item.get("sow", "") == "":
		return false
	var grows := Mat.index(item.sow)
	return grows >= 0 and Tools.mown(grows) == world.get_cell(cell.x, cell.y, cell.z) \
		and world.get_cell(up.x, up.y, up.z) == Mat.AIR and not world.bushes.has(up)


# --- Saplings -----------------------------------------------------------------------------


## The ground cell a tree's seed planted on `cell` takes root on: the cell of the trees'
## lattice (odd x and z) in the 2x2 cells round it, on its ground within a cell up or
## down; null for none.
func sapling_spot(cell: Vector3i) -> Variant:
	for dy in [0, -1, 1]:
		var c := Vector3i(cell.x | 1, cell.y + dy, cell.z | 1)
		if world.in_bounds(c.x, c.y, c.z) and world.in_bounds(c.x, c.y + 1, c.z) \
				and _ground_roots(world.get_cell(c.x, c.y, c.z)) and world.get_cell(c.x, c.y + 1, c.z) == Mat.AIR:
			return c
	return null


## Whether a sapling can take root on ground cell `cell`: on the trees' lattice, grass,
## bare ground or an empty bed with air over it, no bush, and no tree or sapling near.
func can_root(cell: Vector3i) -> bool:
	if cell.x & 1 == 0 or cell.z & 1 == 0 or not world.in_bounds(cell.x, cell.y + 1, cell.z):
		return false
	var up := cell + Vector3i.UP
	if not _ground_roots(world.get_cell(cell.x, cell.y, cell.z)) or world.get_cell(up.x, up.y, up.z) != Mat.AIR \
			or world.bushes.has(up) or crop_on(cell) != "":
		return false
	for dz in range(-SAPLING_GAP, SAPLING_GAP + 1):
		for dx in range(-SAPLING_GAP, SAPLING_GAP + 1):
			if world.trees.has(Vector2i(cell.x + dx, cell.z + dz)):
				return false
	return not _sapling_near(cell)


## Whether ground of material `m` lets a sapling root: grass, bare ground, a bed.
func _ground_roots(m: int) -> bool:
	return m == Mat.GRASS or m == Mat.DIRT or Mat.is_bed(m)


## Whether a sapling grows within SAPLING_GAP columns of `cell`.
func _sapling_near(cell: Vector3i) -> bool:
	var keys := {}
	for dz in [-SAPLING_GAP, SAPLING_GAP]:
		for dx in [-SAPLING_GAP, SAPLING_GAP]:
			keys[WorldData.chunk_key(cell.x + dx, cell.z + dz)] = true
	for key: Vector2i in keys:
		for c: Vector3i in world.fields.get(key, {}):
			if absi(c.x - cell.x) <= SAPLING_GAP and absi(c.z - cell.z) <= SAPLING_GAP and absi(c.y - cell.y) <= 4 \
					and Plants.is_sapling(world.fields[key][c][0]):
				return true
	return false


## The sapling on ground cell `cell` grown its `young` share (Plants.young) becomes a
## young tree, the smallest of its species (Growth.place_young) that can be felled for
## branches, where there is room for it; true when it did, else it waits.
func grow_young(cell: Vector3i) -> bool:
	var f: Variant = world.field_at(cell)
	if f == null or not Plants.is_sapling(f[0]):
		return false
	var species := sapling_tree(f)
	if species < 0 or _room(cell) < YOUNG_HEIGHT:
		return false
	_place_tree(cell, species, 0.0)
	var young: Array = f.duplicate()
	young[2] = 1.0
	world.set_field(cell, young)
	return true


## The species (Trees) sapling record `f` grows into: its fourth field (a wild seed's tree,
## ActionsNature), else its plant's `tree`; -1 for none.
static func sapling_tree(f: Array) -> int:
	if f.size() > 3 and f[3] is String:
		return Trees.index(f[3])
	return Trees.index(Plants.BY_ID.get(f[0], {}).get("tree", ""))


## The grown sapling on ground cell `cell` becomes its tree (the young one it was, if
## any, gone first) where there is room for one over it (Growth.fit), true when it did;
## else it waits.
func grow_tree(cell: Vector3i) -> bool:
	var f: Variant = world.field_at(cell)
	if f == null or not Plants.is_sapling(f[0]):
		return false
	var species := sapling_tree(f)
	if species < 0:
		return false
	var young: Array[Vector3i] = []
	if f[2] >= 1.0:
		young = Felling.clear(world, cell + Vector3i.UP)
	var scale := Growth.fit(species, _room(cell))
	if scale <= 0.0:
		if not young.is_empty():
			_place_tree(cell, species, 0.0)
		return false
	world.set_field(cell, null)
	if Mat.is_bed(world.get_cell(cell.x, cell.y, cell.z)):
		world.set_material(cell.x, cell.y, cell.z, Mat.DIRT)
		cell_changed.emit(cell)
	_place_tree(cell, species, scale)
	return true


## How many cells of air stand over ground cell `cell`.
func _room(cell: Vector3i) -> int:
	var room := 0
	var y := cell.y + 1
	while y < world.size_y and world.get_cell(cell.x, y, cell.z) == Mat.AIR:
		room += 1
		y += 1
	return room


## Grows a tree of `species` at `scale` on ground cell `cell` (Growth.place, the same
## shape each time for the cell; a young one at scale 0, Growth.place_young) and sends
## the chunks round it again.
func _place_tree(cell: Vector3i, species: int, scale: float) -> void:
	if scale <= 0.0:
		Growth.place_young(world, cell.x, cell.y + 1, cell.z, species)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(cell)
		Growth.place(world, cell.x, cell.y + 1, cell.z, species, rng, scale)
	var reach := Growth.TREE_REACH
	for kz in range((cell.z - reach) >> WorldData.SHIFT, ((cell.z + reach) >> WorldData.SHIFT) + 1):
		for kx in range((cell.x - reach) >> WorldData.SHIFT, ((cell.x + reach) >> WorldData.SHIFT) + 1):
			world.note_edit(kx << WorldData.SHIFT, kz << WorldData.SHIFT)
			looks_changed.emit(Vector2i(kx, kz))


## The ground cell under the young tree whose trunk is in column x, z (a sapling's record
## with its third field 1), null for none.
func _young_ground(x: int, z: int) -> Variant:
	for c: Vector3i in world.fields.get(WorldData.chunk_key(x, z), {}):
		if c.x == x and c.z == z:
			var f: Array = world.fields[WorldData.chunk_key(x, z)][c]
			if Plants.is_sapling(f[0]) and f[2] >= 1.0:
				return c
	return null


## A young tree (see grow_young) is felled for branches, not logs.
func young_tree(cell: Vector3i) -> bool:
	return _young_ground(cell.x, cell.z) != null


## A felled young tree is gone: its sapling's record with it.
func felled_young(cell: Vector3i) -> void:
	var at: Variant = _young_ground(cell.x, cell.z)
	if at != null:
		world.set_field(at, null)
		looks_changed.emit(WorldData.chunk_key(cell.x, cell.z))


# --- Watering -----------------------------------------------------------------------------


## Whether bed `cell` can be watered: any bed but one a sapling grows on (a sapling needs
## no water, and the third field of its record is the young tree's flag, not wetness).
func can_water(cell: Vector3i) -> bool:
	return Mat.is_bed(world.get_cell(cell.x, cell.y, cell.z)) and not Plants.is_sapling(crop_on(cell))


## Waters beds `cells` with the can in hand (or can item `with` of the bag): each stays
## wet WET_DAYS; each takes one of the can's uses (its wear), and an emptied can becomes
## its `empties_to`.
func water(who, cells: Array[Vector3i], with := "") -> Dictionary:
	cells = _allowed(who, cells, "build")
	if cells.is_empty() or not who.act("gather", "farm"):
		return {}
	var can: String = who.held() if with == "" else with
	var item := Items.get_item(can)
	if who.inventory.count(can) == 0:
		return {}
	for c in cells:
		wet(c, clock.now() + WET_DAYS)
		if item.durability > 0 and who.inventory.wear_tool(can, item.durability):
			var empty: String = item.get("empties_to", "")
			if empty != "":
				who.give(empty, 1)
			who.say("Лейка опустела: наберите воды")
			break
	return _work(skilled(who, "farm", WATER_SWING), "", (Vector3(cells[0]) + Vector3(0.5, 1.0, 0.5)) * CELL, Mat.WATER)


## Makes bed `cell` wet until time `until` (Clock.now), wet to look at (Mat.BED_WET).
func wet(cell: Vector3i, until: float) -> void:
	var f: Variant = world.field_at(cell)
	if f == null:
		f = ["", 0.0, 0.0]
	elif Plants.is_sapling(f[0]):
		return
	world.set_field(cell, [f[0], f[1], maxf(f[2], until)])
	_look_wet(cell, true)


## Gives bed `cell` the material of its wetness.
func _look_wet(cell: Vector3i, wet_now: bool) -> void:
	var want := Mat.BED_WET if wet_now and Mat.BED_WET >= 0 else Mat.BED
	if want >= 0 and world.get_cell(cell.x, cell.y, cell.z) != want:
		world.set_material(cell.x, cell.y, cell.z, want)
		cell_changed.emit(cell)


# --- Reaping ------------------------------------------------------------------------------


## Whether tool `t` can reap the crop on bed `cell`: one is there, ripe, and `t` cuts it.
func can_reap(cell: Vector3i, t: Dictionary) -> bool:
	return ripe_at(cell) and Tools.can_reap(t, Plants.BY_ID.get(crop_on(cell), {}))


## Reaps the ripe crops on beds `cells` in one swing of the hand in use (or tool item
## `tool` of the bag, "" bare hands): each gives its `gives` (now and then one more with
## the skill), lying on the bed; the bed stays, empty.
func reap(who, cells: Array[Vector3i], tool: Variant = null) -> Dictionary:
	cells = _allowed(who, cells, "harvest")
	if cells.is_empty() or not who.act("cut", "farm"):
		return {}
	var keys := {}
	for c in cells:
		var f: Array = world.field_at(c)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([c, clock.day])
		var gives := Plants.harvest([f[0]], rng)
		world.set_field(c, ["", 0.0, f[2]])
		keys[WorldData.chunk_key(c.x, c.z)] = true
		if gives.is_empty():
			continue
		if _extra(who, "farm"):
			var first: String = gives.keys()[0]
			gives[first] += 1
		for id in gives:
			world.heap_drop(Items.get_item(id).get("id", id), floor_under(c + Vector3i.UP), gives[id], rng.randf() * TAU)
	for key in keys:
		looks_changed.emit(key)
		drops_changed.emit(key)
	var t: Dictionary = who.tool() if tool == null else Tools.of(tool)
	var done := _work(skilled(who, "farm", t.swing), "", (Vector3(cells[0]) + Vector3(0.5, 1.0, 0.5)) * CELL, Mat.GRASS)
	if t.tool != "hand":
		_wear(who, tool)
	return done


# --- The year of the beds -----------------------------------------------------------------


## The beds over `seconds` of play, with rain of strength `rain` falling (Clock.WEATHERS),
## looked at every FIELD_TICK: rain wets those under the open sky, a wet one dries after
## its time, a crop on a wet bed grows in the warm seasons and dies in winter, a crop
## something was put over is lost. Chunks whose crops changed how they look are told
## (looks_changed); a bed's wetness changes its material (cell_changed).
func step_fields(seconds: float, rain: float) -> void:
	_field_clock += seconds
	if _field_clock < FIELD_TICK:
		return
	var days: float = clock.days(_field_clock)
	_field_clock = 0.0
	grow_fields(days, rain)


## One look at every bed (see step_fields), `days` of growth since the last one.
func grow_fields(days: float, rain: float) -> void:
	var now: float = clock.now()
	var winter: bool = clock.season == WINTER
	var grown: Array[Vector3i] = []
	for key: Vector2i in world.fields.keys():
		var beds: Dictionary = world.fields[key]
		var looks := false
		for cell: Vector3i in beds.keys():
			var f: Array = beds[cell]
			if f[0] != "" and Plants.is_sapling(f[0]):
				# A sapling: in the warm seasons it grows, wet or dry; it waits out the
				# winter. A sprout and a shoot (its frames), then a young tree (its third
				# field 1), then grown its tree.
				var above := cell + Vector3i.UP
				var young: bool = f[2] >= 1.0
				if Mat.is_bed(world.get_cell(cell.x, cell.y, cell.z)):
					_look_wet(cell, false)
				var lost: bool = world.get_cell(above.x, above.y, above.z) != (Mat.LOG if young else Mat.AIR)
				if lost or not _ground_roots(world.get_cell(cell.x, cell.y, cell.z)):
					world.set_field(cell, null)
					looks = true
				elif Plants.ripe(f[0], f[1]):
					grown.append(cell)
				elif not young and Plants.young(f[0], f[1]):
					grown.append(cell)
				elif not winter:
					var was := Plants.stage(f[0], f[1])
					f[1] += days
					looks = looks or (not young and Plants.stage(f[0], f[1]) != was)
				continue
			if not Mat.is_bed(world.get_cell(cell.x, cell.y, cell.z)):
				world.set_field(cell, null)
				looks = looks or f[0] != ""
				continue
			if rain >= RAIN_WETS and world.roof_level(cell.x, cell.z) <= cell.y:
				f[2] = maxf(f[2], now + WET_DAYS)
			var is_wet: bool = f[2] > now
			_look_wet(cell, is_wet)
			if f[0] == "":
				continue
			var up := cell + Vector3i.UP
			if winter or world.get_cell(up.x, up.y, up.z) != Mat.AIR or not Plants.BY_ID.has(f[0]):
				f[0] = ""
				f[1] = 0.0
				looks = true
				continue
			if not is_wet or Plants.ripe(f[0], f[1]):
				continue
			var before := Plants.stage(f[0], f[1])
			f[1] += days
			if Plants.stage(f[0], f[1]) != before:
				looks = true
		world.note_edit(key.x << WorldData.SHIFT, key.y << WorldData.SHIFT)
		if looks:
			looks_changed.emit(key)
	for cell in grown:
		var f: Array = world.field_at(cell)
		if f[2] < 1.0 and not Plants.ripe(f[0], f[1]):
			grow_young(cell)
		else:
			grow_tree(cell)
