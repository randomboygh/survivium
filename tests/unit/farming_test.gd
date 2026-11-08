extends "res://tests/unit/test_case.gd"
## Farming (WorldActions part actions_farm.gd): a hoe tills a bed, grain is sown on it,
## a can waters it, rain wets the open beds, wheat grows only wet and in the warm
## seasons, dies in winter, is reaped ripe by hands, a sickle or a scythe; the beds'
## records survive a chunk's save; the farming mode's marks (Plans.mark, Plans.farm) are
## drawn on the ground and worked with the tools of the bag.

const Plans := preload("res://src/shared/game/plans.gd")

const WHEAT := "plants:wheat"
const GRAIN := "plants:grain"


func run() -> void:
	_test_till_sow_water()
	_test_growth()
	_test_reap()
	_test_crops()
	_test_saplings()
	_test_nature()
	_test_water_keeps()
	_test_save()
	_test_marks()


## A small flat world of grass on stone, its clock in summer, and one standing in it.
func _world() -> Array:
	var w := WorldData.new(16, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.GRASS)
	var clock := Clock.new()
	clock.season = 1
	var actions := WorldActions.new(w, clock, Rules.new())
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 10.5) * WorldData.CELL
	return [w, clock, actions, who]


func _test_till_sow_water() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	var bed := Vector3i(10, 1, 8)
	_check(Mat.BED >= 0 and Mat.BED_WET >= 0 and Mat.is_bed(Mat.BED) and not Mat.is_bed(Mat.DIRT),
		"the soil bundle gives beds, dry and wet")
	who.item = "tools:stone_hoe"
	_check(actions.front_kind(who) == "till", "the action button tills with a hoe in hand")
	var done := actions.dig_at(who, bed, Vector3i.UP)
	_check(done.has("swing") and w.get_cell(bed.x, bed.y, bed.z) == Mat.BED and w.field_at(bed) == ["", 0.0, 0.0],
		"a hoe tills grass into a bed: %s" % [w.field_at(bed)])
	_check(actions.dig_at(who, Vector3i(10, 0, 8), Vector3i.UP).is_empty(), "a hoe tills no stone")
	who.item = "tools:iron_hoe"
	actions.dig_at(who, Vector3i(12, 1, 8), Vector3i.UP)
	var beds := 0
	for x in range(11, 14):
		for z in range(7, 10):
			beds += 1 if w.get_cell(x, 1, z) == Mat.BED else 0
	_check(beds == 3, "an iron hoe tills three cells a swing: %d" % beds)
	# Sowing.
	who.item = GRAIN
	_check(not actions.plant_at(who, GRAIN, bed), "nothing is sown without grain in the bag")
	who.inventory.add(GRAIN, 5)
	_check(not actions.plant_at(who, GRAIN, Vector3i(14, 1, 14)), "grain is not sown on grass")
	_check(actions.plant_at(who, GRAIN, bed) and actions.crop_on(bed) == WHEAT and who.inventory.count(GRAIN) == 4,
		"grain is sown on a bed, and wheat grows there")
	_check(not actions.plant_at(who, GRAIN, bed), "nothing more is sown where wheat grows")
	setup[1].season = Clock.WINTER
	_check(not actions.plant_at(who, GRAIN, Vector3i(12, 1, 8)) and who.said[-1].contains("Зимой"), "nobody sows in winter")
	setup[1].season = 1
	# Watering.
	who.item = "tools:watering_can"
	_check(actions.dig_at(who, Vector3i(12, 1, 8), Vector3i.UP).is_empty() and w.get_cell(12, 1, 8) == Mat.BED,
		"an empty can waters nothing, nor do hands dig a bed")
	who.inventory.add("tools:watering_can_full", 1)
	who.item = "tools:watering_can_full"
	_check(actions.front_kind(who) == "water", "the action button waters a dry bed with a full can")
	actions.dig_at(who, bed, Vector3i.UP)
	_check(w.get_cell(bed.x, bed.y, bed.z) == Mat.BED_WET and w.field_at(bed)[2] > setup[1].now(),
		"a full can wets the bed")
	for i in 12:
		actions.dig_at(who, Vector3i(12, 1, 8), Vector3i.UP)
	_check(who.inventory.count("tools:watering_can_full") == 0 and who.inventory.count("tools:watering_can") == 1,
		"a can is empty after its ten waterings, and can be filled again")
	# A shovel digs the bed out, its crop with it.
	who.item = "tools:wooden_shovel"
	actions.dig_at(who, bed, Vector3i.UP)
	_check(w.get_cell(bed.x, bed.y, bed.z) == Mat.AIR and w.field_at(bed) == null, "a shovel digs a bed out, crop and all")


func _test_growth() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var clock: Clock = setup[1]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	var bed := Vector3i(10, 1, 8)
	who.item = "tools:stone_hoe"
	actions.dig_at(who, bed, Vector3i.UP)
	who.inventory.add(GRAIN, 5)
	actions.plant_at(who, GRAIN, bed)
	var days: float = Plants.BY_ID[WHEAT].grow_days
	actions.grow_fields(days, 0.0)
	_check(actions.growth(bed) == 0.0, "wheat on a dry bed does not grow")
	actions.wet(bed, clock.now() + 100.0)
	actions.grow_fields(days * 0.5, 0.0)
	_check(is_equal_approx(actions.growth(bed), 0.5) and not actions.ripe_at(bed)
		and Plants.stage(WHEAT, w.field_at(bed)[1]) > 0, "wheat on a wet bed grows by the days: %.2f" % actions.growth(bed))
	actions.grow_fields(days, 0.0)
	_check(actions.ripe_at(bed) and Plants.stage(WHEAT, w.field_at(bed)[1]) == Plants.BY_ID[WHEAT].frames - 1,
		"and ripens, the last frame its picture")
	clock.season = Clock.WINTER
	actions.grow_fields(0.1, 0.0)
	_check(actions.crop_on(bed) == "" and Mat.is_bed(w.get_cell(bed.x, bed.y, bed.z)), "winter kills the crop, the bed stays")
	clock.season = 1
	# Rain wets the open beds, not those under a roof; a dry time dries them.
	var roofed := Vector3i(14, 1, 14)
	actions.dig_at(who, roofed, Vector3i.UP)
	w.set_cell(roofed.x, 4, roofed.z, Mat.STONE)
	var open := Vector3i(13, 1, 12)
	actions.dig_at(who, open, Vector3i.UP)
	actions.grow_fields(0.0, 0.5)
	_check(w.get_cell(open.x, open.y, open.z) == Mat.BED_WET and w.get_cell(roofed.x, roofed.y, roofed.z) == Mat.BED,
		"rain wets the beds under the open sky only")
	clock.day += 2
	actions.grow_fields(0.0, 0.0)
	_check(w.get_cell(open.x, open.y, open.z) == Mat.BED, "a wet bed dries after a day")
	# Something put over a crop kills it.
	actions.wet(open, clock.now() + 10.0)
	actions.plant_at(who, GRAIN, open)
	w.set_cell(open.x, 2, open.z, Mat.DIRT)
	actions.grow_fields(0.1, 0.0)
	_check(actions.crop_on(open) == "", "a crop under a block is lost")


func _test_reap() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var clock: Clock = setup[1]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	who.inventory.add(GRAIN, 10)
	var row: Array[Vector3i] = []
	for x in range(9, 13):
		row.append(Vector3i(x, 1, 8))
	who.item = "tools:stone_hoe"
	for c in row:
		actions.dig_at(who, c, Vector3i.UP)
		actions.plant_at(who, GRAIN, c)
		actions.wet(c, clock.now() + 100.0)
	who.item = ""
	_check(actions.dig_at(who, row[0], Vector3i.UP).is_empty() and who.said[-1].contains("не созрело")
		and actions.crop_on(row[0]) == WHEAT, "hands do not pull green wheat, and say how far it is")
	actions.grow_fields(Plants.BY_ID[WHEAT].grow_days, 0.0)
	_check(actions.front_kind(who) == "reap", "the action button reaps a ripe crop in front")
	var done := actions.dig_at(who, row[0], Vector3i.UP)
	var grain := 0
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			grain += d[3] if d[0] == GRAIN else 0
	_check(done.has("swing") and actions.crop_on(row[0]) == "" and Mat.is_bed(w.get_cell(9, 1, 8)) and grain >= 4,
		"hands reap ripe wheat: grain on the bed, the bed left empty (%d grain)" % grain)
	who.item = "tools:copper_sickle"
	actions.dig_at(who, row[1], Vector3i.UP)
	_check(actions.crop_on(row[1]) == "" and actions.crop_on(row[2]) == "", "a sickle reaps several beds a swing")
	who.item = "tools:stone_scythe"
	_check(Tools.can_reap(Tools.of(who.item), Plants.BY_ID[WHEAT]) and actions.dig_at(who, row[3], Vector3i.UP).has("swing")
		and actions.crop_on(row[3]) == "", "a scythe cuts ripe wheat (it is `mown`)")
	_check(not Tools.can_reap(Tools.of("tools:stone_scythe"), {"mown": false}) and Tools.can_reap(Tools.HAND, {"mown": false}),
		"a scythe does not cut a crop that is not `mown`, hands do")


## Turnip, carrot, peas and flax are sown like grain, grow on a wet bed and give their
## crop and seeds back.
func _test_crops() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var clock: Clock = setup[1]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	var seeds := ["plants:turnip_seeds", "plants:carrot_seeds", "plants:peas", "plants:flax_seeds"]
	var gives := ["plants:turnip", "plants:carrot", "plants:peas", "plants:flax_stalks"]
	who.item = "tools:stone_hoe"
	var beds: Array[Vector3i] = []
	for i in seeds.size():
		var bed := Vector3i(8 + i, 1, 12)
		beds.append(bed)
		actions.dig_at(who, bed, Vector3i.UP)
		who.inventory.add(seeds[i], 1)
		_check(actions.plant_at(who, seeds[i], bed) and actions.crop_on(bed) == Items.get_item(seeds[i]).crop,
			"%s is sown on a bed" % seeds[i])
		actions.wet(bed, clock.now() + 1000.0)
	actions.grow_fields(10.0, 0.0)
	who.item = ""
	for i in seeds.size():
		actions.dig_at(who, beds[i], Vector3i.UP)
		var got := 0
		for key: Vector2i in w.drops:
			for d: Array in w.drops[key]:
				got += d[3] if d[0] == gives[i] else 0
		_check(actions.crop_on(beds[i]) == "" and got > 0, "ripe %s is reaped by hand: %d %s" % [seeds[i], got, gives[i]])


## An acorn is planted on open ground on the trees' lattice, away from other trees; the
## sapling grows wet or dry, waits out the winter, and grown becomes an oak.
func _test_saplings() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var clock: Clock = setup[1]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	var acorn := "plants:acorn"
	var sapling: String = Items.get_item(acorn).get("crop", "")
	_check(Plants.is_sapling(sapling) and Plants.is_sown(sapling) and not Plants.is_crop(sapling)
		and Plants.is_sapling(Items.get_item("plants:cone").get("crop", "")), "an acorn and a cone grow into saplings")
	_check(actions.sapling_spot(Vector3i(10, 1, 12)) == Vector3i(11, 1, 13), "a seed takes root on the trees' lattice")
	who.inventory.add(acorn, 3)
	who.item = acorn
	_check(actions.plant_at(who, acorn, Vector3i(10, 1, 12)) and actions.crop_on(Vector3i(11, 1, 13)) == sapling
		and who.inventory.count(acorn) == 2, "an acorn is planted on grass")
	_check(not actions.plant_at(who, acorn, Vector3i(12, 1, 12)), "not beside another sapling")
	_check(actions.plantable(acorn, Vector3i(15, 1, 13)) and not actions.plantable(acorn, Vector3i(14, 1, 13)),
		"the farming mode marks a tree's seed only on the lattice")
	var days: float = Plants.BY_ID[sapling].grow_days
	var young_days: float = days * Plants.BY_ID[sapling].young
	var root := Vector3i(11, 1, 13)
	clock.season = Clock.WINTER
	actions.grow_fields(days, 0.0)
	_check(actions.crop_on(root) == sapling and actions.growth(root) == 0.0, "a sapling waits out the winter")
	clock.season = 1
	actions.grow_fields(young_days * 0.6, 0.0)
	_check(actions.growth(root) > 0.0 and w.get_cell(11, 1, 13) == Mat.GRASS and w.get_cell(11, 2, 13) == Mat.AIR
		and Plants.stage(sapling, w.field_at(root)[1]) == 1, "a sapling grows unwatered on grass, a sprout then a shoot")
	actions.grow_fields(young_days * 0.5, 0.0)
	actions.grow_fields(0.01, 0.0)
	_check(w.trees.has(Vector2i(11, 13)) and w.get_cell(11, 2, 13) == Mat.LOG and w.field_at(root)[2] == 1.0
		and actions.young_tree(Vector3i(11, 2, 13)), "then it is a young tree")
	_check(Growth.young_at(w, 11, 2, 13) and Growth.trunk_box(w.trees[Vector2i(11, 13)], Vector2i(11, 13), 0, true).size.x
		== Growth.YOUNG_GIRTH and not Growth.young_at(w, 11, 3, 13), "a young tree has a thin stem")
	var low := 0
	for y in range(2, 16):
		low = y if w.get_cell(11, y, 13) == Mat.LEAVES else low
	_check(low > 0 and low <= 6, "a young tree is small: leaves up to level %d" % low)
	actions.grow_fields(days, 0.0)
	actions.grow_fields(0.01, 0.0)
	_check(actions.crop_on(root) == "" and w.trees.has(Vector2i(11, 13)) and w.get_cell(11, 2, 13) == Mat.LOG
		and _top_leaf(w, 11, 13) > low, "grown, the sapling becomes an oak, taller than the young tree")
	_check(not actions.plant_at(who, acorn, Vector3i(12, 1, 14)), "nothing is planted beside a tree")
	# A young tree is felled for branches only, and its sapling goes with it.
	who.position = Vector3(6.5, 2.0, 19.5) * WorldData.CELL
	_check(actions.plant_at(who, acorn, Vector3i(4, 1, 20)), "a second acorn is planted")
	var at := Vector3i(5, 1, 21)
	actions.grow_fields(young_days * 1.1, 0.0)
	actions.grow_fields(0.01, 0.0)
	_check(actions.young_tree(at + Vector3i.UP), "a second sapling is a young tree")
	actions.fell(who, at + Vector3i.UP)
	var logs := 0
	var twigs := 0
	var species: Dictionary = Trees.SPECIES[Trees.index(Plants.BY_ID[sapling].tree)]
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			logs += 1 if d[0] == species.log else 0
			twigs += 1 if d[0] == species.twig else 0
	_check(logs == 0 and twigs > 0 and w.field_at(at) == null and w.get_cell(5, 2, 21) == Mat.AIR,
		"a felled young tree gives branches (%d), no logs (%d)" % [twigs, logs])
	who.position = Vector3(6.5, 2.0, 6.5) * WorldData.CELL
	actions.plant_at(who, acorn, Vector3i(4, 1, 4))
	w.set_cell(5, 3, 5, Mat.STONE)
	actions.grow_fields(days * 2.0, 0.0)
	actions.grow_fields(0.1, 0.0)
	_check(actions.crop_on(Vector3i(5, 1, 5)) == sapling and not w.trees.has(Vector2i(5, 5)), "a sapling with no room over it waits")


## Watering a bed keeps what grows there: a sown crop and a sapling planted on a bed
## (whose record keeps its own third field: the young tree's flag, not the wetness).
func _test_water_keeps() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	who.item = "tools:iron_hoe"
	for x in range(9, 14):
		actions.dig_at(who, Vector3i(x, 1, 11), Vector3i.UP)
	who.inventory.add(GRAIN, 1)
	who.inventory.add("plants:acorn", 1)
	var crop := Vector3i(10, 1, 11)
	var root := Vector3i(11, 1, 11)
	_check(actions.plant_at(who, GRAIN, crop) and actions.plant_at(who, "plants:acorn", root)
		and Plants.is_sapling(actions.crop_on(root)), "wheat is sown and an acorn planted on beds")
	who.inventory.add("tools:watering_can_full", 1)
	who.item = "tools:watering_can_full"
	actions.water(who, [crop, root] as Array[Vector3i])
	actions.grow_fields(0.1, 0.0)
	actions.grow_fields(0.1, 0.0)
	_check(actions.crop_on(crop) == WHEAT and w.get_cell(crop.x, crop.y, crop.z) == Mat.BED_WET
		and not actions.can_water(root) and w.get_cell(root.x, root.y, root.z) == Mat.BED,
		"watered wheat stays: %s" % [w.field_at(crop)])
	_check(Plants.is_sapling(actions.crop_on(root)) and w.field_at(root)[2] < 1.0 and not w.trees.has(Vector2i(11, 11)),
		"a watered sapling stays a sapling: %s" % [w.field_at(root)])


func _top_leaf(w: WorldData, x: int, z: int) -> int:
	var top := 0
	for y in w.size_y:
		top = y if w.get_cell(x, y, z) == Mat.LEAVES else top
	return top


func _test_save() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	var bed := Vector3i(10, 1, 8)
	who.item = "tools:stone_hoe"
	actions.dig_at(who, bed, Vector3i.UP)
	who.inventory.add(GRAIN, 1)
	actions.plant_at(who, GRAIN, bed)
	w.field_at(bed)[1] = 1.5
	var key := WorldData.chunk_key(bed.x, bed.z)
	var packed := w.pack_chunk(key)
	var copy := WorldData.new(16, Vector2i(32, 32))
	_check(copy.unpack_chunk(bytes_to_var(var_to_bytes(packed))) and copy.field_at(bed) == [WHEAT, 1.5, 0.0]
		and copy.get_cell(bed.x, bed.y, bed.z) == Mat.BED, "a bed and its crop come back with the chunk: %s" % [copy.field_at(bed)])
	var cards := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	var c: Dictionary = Plants.custom(WHEAT)
	_check(Foliage._crop(cards, bed.x, bed.y, bed.z, [WHEAT, 99.0, 0.0], rng) == 4 and not c.is_empty()
		and int(cards[12]) == Grass.CUSTOM + c.first + c.frames - 1, "a crop is drawn as four plants of its stage's frame")


## Works the farming marks of `plans` near `who` until none can be, at most `n` times.
func _work_marks(plans, actions, who, n: int) -> void:
	for i in n:
		if plans.farm(actions, who).get("idle", false):
			return


func _test_marks() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var clock: Clock = setup[1]
	var actions: WorldActions = setup[2]
	var who: Who = setup[3]
	var plans := Plans.new()
	_check(Plans.is_mark(Plans.TILL) and Plans.is_mark(GRAIN) and not Plans.is_mark("materials:planks")
		and not Plans.is_mark(Plans.CUT), "the farming marks are told apart from the blueprint's ghost")
	# Tilling a line: tapped on the air over the ground, the ground of each column is marked.
	_check(plans.mark(actions, who, "till", Vector3i(8, 2, 9), Vector3i(12, 2, 10), false) == 5
		and plans.cells.get(Vector3i(8, 1, 9)) == Plans.TILL and plans.cells.get(Vector3i(12, 1, 9)) == Plans.TILL,
		"a line of marks to till lies on the ground along the way the stroke went farthest")
	_check(plans.near(who).is_empty() and plans.near(who, true).size() == 5, "the marks are no ghost to build")
	var done := plans.farm(actions, who)
	_check(done.get("idle", false) and plans.cells.size() == 5 and who.said[-1].contains("тяпк"),
		"with no hoe in the bag nothing is tilled, and it is said")
	who.inventory.add("tools:stone_hoe", 1)
	_work_marks(plans, actions, who, 10)
	var beds := 0
	for x in range(8, 13):
		beds += 1 if w.get_cell(x, 1, 9) == Mat.BED else 0
	_check(beds == 5 and plans.cells.is_empty(), "the button tills the marks with the hoe of the bag, and they go")
	# Sowing a square: the ground is tilled first, then sown.
	who.inventory.add(GRAIN, 10)
	who.item = GRAIN
	_check(plans.mark(actions, who, "sow", Vector3i(8, 1, 12), Vector3i(9, 1, 13), true) == 4, "a square of marks to sow")
	_work_marks(plans, actions, who, 20)
	var sown := 0
	for c in [Vector3i(8, 1, 12), Vector3i(9, 1, 12), Vector3i(8, 1, 13), Vector3i(9, 1, 13)]:
		sown += 1 if actions.crop_on(c) == WHEAT else 0
	_check(sown == 4 and plans.cells.is_empty() and who.inventory.count(GRAIN) == 6,
		"the square is tilled and sown with the grain of the bag: %d" % sown)
	# Watering it.
	who.item = ""
	_check(plans.mark(actions, who, "water", Vector3i(8, 1, 12), Vector3i(9, 1, 13), true) == 4, "marks to water the beds")
	_check(plans.mark(actions, who, "water", Vector3i(14, 1, 14), Vector3i(15, 1, 14), false) == 0, "but not the grass")
	who.inventory.add("tools:watering_can_full", 1)
	_work_marks(plans, actions, who, 10)
	_check(w.get_cell(8, 1, 12) == Mat.BED_WET and w.get_cell(9, 1, 13) == Mat.BED_WET and plans.cells.is_empty(),
		"the can of the bag waters the marked beds")
	# Reaping: green wheat waits, ripe is reaped.
	_check(plans.mark(actions, who, "reap", Vector3i(8, 1, 12), Vector3i(9, 1, 13), true) == 4, "marks to reap")
	_check(plans.farm(actions, who).get("idle", false) and plans.cells.size() == 4 and who.said[-1].contains("не созрело"),
		"green wheat is not reaped: the marks wait")
	actions.grow_fields(Plants.BY_ID[WHEAT].grow_days, 0.0)
	_work_marks(plans, actions, who, 10)
	_check(actions.crop_on(Vector3i(8, 1, 12)) == "" and actions.crop_on(Vector3i(9, 1, 13)) == "" and plans.cells.is_empty(),
		"ripe wheat is reaped by hand with no sickle in the bag")
	# Winter: the seeds wait.
	clock.season = Clock.WINTER
	plans.mark(actions, who, "sow", Vector3i(8, 1, 9), Vector3i(8, 1, 9), false)
	who.item = GRAIN
	plans.mark(actions, who, "sow", Vector3i(8, 1, 9), Vector3i(8, 1, 9), false)
	_check(plans.farm(actions, who).get("idle", false) and plans.cells.size() == 1 and who.said[-1].contains("Зимой"),
		"nothing is sown in winter: the mark waits")
	clock.season = 1
	# Taking off: a stroke, or all near; the blueprint's ghost stays.
	plans.cells[Vector3i(10, 3, 10)] = "materials:planks"
	_check(plans.mark(actions, who, "sow", Vector3i(8, 1, 9), Vector3i(8, 1, 9), false, true) == 1
		and not plans.cells.has(Vector3i(8, 1, 9)), "a stroke takes the marks off")
	plans.mark(actions, who, "till", Vector3i(14, 1, 15), Vector3i(16, 1, 15), false)
	_check(plans.clear(actions, who, true) == 3 and plans.cells.size() == 1, "all the marks near go, the blueprint stays")
	_check(plans.clear(actions, who) == 1 and plans.cells.is_empty(), "and the blueprint goes by itself")
	var list := plans.to_list()
	plans.mark(actions, who, "till", Vector3i(14, 1, 15), Vector3i(16, 1, 15), false)
	plans.from_list(plans.to_list())
	_check(list.is_empty() and plans.cells.size() == 3, "the marks are saved with the blueprint")


class AllClaimed extends RefCounted:
	func claim_at(_c: Vector3i) -> Dictionary:
		return {"id": 1}


## Nature on its own once a year (ActionsNature): bare natural ground beside grass grows
## over, a bush and a grown tree spread their kind near them (a wild seed of a species
## with no sapling of its own sprouts as one alike and grows into its own), nothing on
## claimed land; a chunk works a spring once, and keeps the count with it in a save.
func _test_nature() -> void:
	var setup := _world()
	var w: WorldData = setup[0]
	var clock: Clock = setup[1]
	var actions: WorldActions = setup[2]
	var key := Vector2i(0, 0)
	var bare := Vector3i(6, 1, 6)
	w.set_cell(bare.x, bare.y, bare.z, Mat.DIRT)
	w.set_natural(bare.x, bare.y, bare.z, true)
	var placed_dirt := Vector3i(3, 1, 3)
	w.set_cell(placed_dirt.x, placed_dirt.y, placed_dirt.z, Mat.DIRT)
	var bush_at := Vector3i(8, 2, 8)
	Growth.place_bush(w, bush_at.x, bush_at.y, bush_at.z, 0)
	var birch := Trees.index("plants:birch")
	var rng := RandomNumberGenerator.new()
	Growth.place(w, 9, 2, 3, birch, rng, 0.6)
	_check(actions.sapling_of("plants:oak") == "plants:oak_sapling" and actions.sapling_of("plants:birch") != ""
		and actions.sapling_of("plants:spruce") == "plants:spruce_sapling", "a tree with no sapling of its own sprouts as one alike")
	var claimed := WorldActions.new(w, clock, Rules.new())
	claimed.territory = AllClaimed.new()
	for row in WorldData.CHUNK:
		claimed.regrow_row(key, row)
	_check(w.get_cell(bare.x, bare.y, bare.z) == Mat.DIRT, "nothing grows back on claimed land")
	var bushes := w.bushes.size()
	var wild := []
	for year in 12:
		clock.springs += 1
		for row in WorldData.CHUNK:
			actions.regrow_row(key, row)
	for c: Vector3i in w.fields.get(key, {}):
		wild.append(w.fields[key][c])
	_check(w.get_cell(bare.x, bare.y, bare.z) == Mat.GRASS, "bare natural ground beside grass grows over")
	_check(w.get_cell(placed_dirt.x, placed_dirt.y, placed_dirt.z) == Mat.DIRT, "dirt the player laid stays")
	_check(w.bushes.size() > bushes, "a bush puts new ones of its kind beside it (%d to %d)" % [bushes, w.bushes.size()])
	_check(not wild.is_empty() and wild[0].size() == 4 and wild[0][3] == "plants:birch" and Plants.is_sapling(wild[0][0])
		and WorldActions.sapling_tree(wild[0]) == birch, "a birch sows a wild sapling of its own species: %s" % [wild])
	# The year of a chunk: worked once a spring, the count kept in its save.
	var c = w.chunks[key]
	c.final = true
	c.spring = -1
	clock.springs = 20
	clock.season = 0
	for i in 40:
		actions.step_nature(WorldActions.NATURE_EVERY)
	_check(c.spring == 20, "a chunk first seen starts from the spring now")
	clock.springs = 21
	for i in 3 * WorldData.CHUNK:
		actions.step_nature(WorldActions.NATURE_EVERY)
	_check(c.spring == 21, "a chunk a spring behind works it")
	var packed := w.pack_chunk(key)
	var again := WorldData.new(16, Vector2i(32, 32))
	_check(again.unpack_chunk(packed) and again.chunks[key].spring == 21 and again.fields.get(key, {}).size() == w.fields[key].size(),
		"the spring count and the wild saplings' species are saved with the chunk")
	var saved := clock.to_dict()
	var clock2 := Clock.new()
	clock2.from_dict(saved)
	_check(clock2.springs == 21, "the clock keeps its count of springs")
