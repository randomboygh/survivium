extends "res://tests/unit/test_case.gd"
## The quality of things (Quality, decision 181): stacks of the bag keep it and join at
## the quality of the two, things on the ground and the materials of a craft job keep it,
## what is made is its materials' no better than the skill, the station and the recipe
## allow, and it makes tools last longer and swing faster, food fill more; seeds give
## crops of about their own quality; saves of before quality read as normal.

const SkillSet := preload("res://src/shared/game/skill_set.gd")
const Skills := preload("res://src/shared/content/skills.gd")

const STONE := "resources:stone"


func run() -> void:
	_test_bag()
	_test_ground()
	_test_made()
	_test_effects()
	_test_gathered()
	_test_crop()


func _test_bag() -> void:
	var inv := Inventory.new()
	inv.add(STONE, 5, 0, null, 30)
	inv.add(STONE, 5, 0, null, 70)
	_check(inv.count(STONE) == 10 and inv.quality_at(0) == 50, "stacks join at the quality of the two: %d" % inv.quality_at(0))
	inv.add(STONE, 10, 0, null, 80)
	_check(inv.quality_at(0) == 65 and inv.count(STONE) == 20, "and again by count: %d" % inv.quality_at(0))
	var taken = inv.take_slot(0, 5)
	_check(Inventory.quality(taken) == 65 and inv.quality_at(0) == 65, "a part taken keeps its quality")
	var other := Inventory.new()
	other.add(STONE, 5, 0, null, 20)
	inv.put_into(0, other, 0)
	_check(other.quality_at(0) == roundi((20.0 * 5 + 65.0 * 15) / 20.0), "put onto a stack, the qualities join: %d" % other.quality_at(0))
	var saved := Inventory.new()
	saved.from_dict(other.to_dict())
	_check(saved.quality_at(0) == other.quality_at(0), "a save keeps the quality")
	var old := Inventory.new()
	old.from_dict({"slots": [[STONE, 3], [STONE, 2, 0]]})
	_check(old.quality_at(0) == Inventory.NORMAL and old.slots[0].size() == 2,
		"a save of before quality reads as normal, the slot as short as it was")
	var sorted := Inventory.new()
	sorted.add(STONE, 4, 0, null, 90)
	sorted.slots[3] = Inventory.stack(STONE, 4, 0, null, 10)
	sorted.sort("kind")
	_check(sorted.count(STONE) == 8 and sorted.quality_at(0) == 50 and sorted.slots[1] == null,
		"sorting joins stacks of one item at their quality together")
	var took := []
	sorted.remove(STONE, 3, took)
	_check(took.size() == 1 and took[0] == [STONE, 3, 0, 50], "what is removed notes its quality: %s" % [took])


func _test_ground() -> void:
	var w := WorldData.new(16, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	w.heap_drop(STONE, Vector3(1, 1, 1), 2, 0.0, 80)
	w.heap_drop(STONE, Vector3(1, 1, 1), 2, 0.0, 40)
	var d: Array = w.drops[Vector2i.ZERO][0]
	_check(w.drops[Vector2i.ZERO].size() == 1 and WorldActions.count(d) == 4 and d[3].q == 60,
		"a heap on the ground joins at the quality of the two: %s" % [d])
	w.heap_drop(STONE, Vector3(3, 1, 3), 2)
	_check(w.drops[Vector2i.ZERO][1][3] is int, "a heap of normal things is a plain count")
	_check(Inventory.drop_data(Inventory.stack(STONE, 3, 0, null, 70)) == {"n": 3, "q": 70}
		and Inventory.drop_data([STONE, 3]) is int, "what is thrown keeps its quality on the ground")
	var stacks = CraftQueue._stacks([[STONE, 2, 0]])
	_check(stacks == [[STONE, 2, 0, Inventory.NORMAL]], "a craft job of an older save takes normal materials")


func _test_made() -> void:
	var r := {"makes": STONE, "at": ""}
	_check(Quality.made(r, [[STONE, 1, 0, 90], [STONE, 3, 0, 50]], 100) == 60, "made: the materials' quality by count")
	_check(Quality.made(r, [[STONE, 1, 0, 90]], 55) == 55, "no better than the skill and the station allow")
	var pick := Crafting.get_recipe("tools:wooden_pickaxe")
	if not pick.is_empty():
		_check(Quality.made(pick, [[STONE, 1, 0, 100]], 100) == 30, "a wooden pickaxe is never better than 30")
	var s := SkillSet.new()
	_check(Quality.skill_cap(s.share_of("craft"), s.quality_most("craft")) == Quality.UNSKILLED_MOST,
		"an unskilled hand makes nothing better than %d" % Quality.UNSKILLED_MOST)
	var fire := Items.get_item(Placed.CAMPFIRE)
	_check(int(fire.get("quality_cap", 100)) < 100, "a campfire cooks plainer than the best")


func _test_effects() -> void:
	_check(is_equal_approx(Quality.lasts(50), 1.0) and is_equal_approx(Quality.lasts(100), 1.5)
		and is_equal_approx(Quality.lasts(10), 0.6), "normal lasts as before, the best half again, poor 60%")
	_check(Quality.faster(100) > 1.15 and Quality.faster(10) < 0.9, "a good tool swings faster, a poor one slower")
	var axe := ""
	for id: String in Items.IDS:
		if Items.get_item(id).get("durability", 0) > 0 and Items.get_item(id).get("tool", "none") == "axe":
			axe = id
			break
	if axe == "":
		return
	var d: int = Items.get_item(axe).durability
	var inv := Inventory.new()
	inv.add(axe, 1, 0, null, 100)
	var swings := 0
	while inv.count(axe) > 0 and swings < d * 3:
		inv.wear_tool(axe, d)
		swings += 1
	_check(swings == roundi(d * 1.5), "the best axe lasts half again its swings: %d of %d" % [swings, d])
	var t := Quality.tool_record(Tools.of(axe), 100)
	_check(t.swing < Tools.of(axe).swing, "and swings faster")


func _test_gathered() -> void:
	var hand := Tools.of("")
	var best := {"power": 8}
	var low := Quality.gathered(hand, Quality.NORMAL, 0.0, 30.0)
	var high := Quality.gathered(best, Quality.NORMAL, 1.0, 30.0)
	_check(low < Quality.NORMAL and high > 90, "bare unskilled hands get plain things, a strong tool and the last level good ones: %d, %d" % [low, high])
	_check(Quality.gathered(hand, 100, 0.0, 30.0) > low, "a better tool of a kind gets better things")


func _test_crop() -> void:
	var who := Who.new()
	var lo := 100
	var hi := 0
	for i in 21:
		var q := WorldActions.crop_quality(who, ["plants:wheat", 0.0, 0.0, "", 70], -1.0 + i * 0.1)
		lo = mini(lo, q)
		hi = maxi(hi, q)
	_check(lo >= 70 - Quality.CROP_SPREAD and hi <= 70 + Quality.CROP_SPREAD and lo < 70 and hi > 70,
		"a crop is about its seed's quality, now worse, now better: %d..%d" % [lo, hi])
	_check(WorldActions.crop_quality(who, ["plants:wheat", 0.0, 0.0], 0.0) == Quality.NORMAL, "a bed of before quality: normal")
