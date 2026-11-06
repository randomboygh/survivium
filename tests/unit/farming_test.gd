extends "res://tests/unit/test_case.gd"
## Farming (WorldActions part actions_farm.gd): a hoe tills a bed, grain is sown on it,
## a can waters it, rain wets the open beds, wheat grows only wet and in the warm
## seasons, dies in winter, is reaped ripe by hands, a sickle or a scythe; the beds'
## records survive a chunk's save.

const WHEAT := "plants:wheat"
const GRAIN := "plants:grain"


func run() -> void:
	_test_till_sow_water()
	_test_growth()
	_test_reap()
	_test_save()


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
