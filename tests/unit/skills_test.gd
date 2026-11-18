extends "res://tests/unit/test_case.gd"
## The skills (decision 164): the levels the points make, what a level does to the time of
## the work, the points useful work gives (and work undone does not), the recipe made over
## and over, the save, a client's copy told a level rose, the land a player may hold.

const Skills := preload("res://src/shared/content/skills.gd")
const SkillSet := preload("res://src/shared/game/skill_set.gd")
const Territory := preload("res://src/shared/game/territory.gd")
const Teams := preload("res://src/shared/game/teams.gd")


func run() -> void:
	_test_levels()
	_test_work()
	_test_craft()
	_test_land()
	_test_yield_quality()
	_test_hardiness()
	_test_strength()


## Strength adds an even share of its `carry` to the carrying limit at each level, and a
## character's bag (on the server or a client's copy) follows the points it is told.
func _test_strength() -> void:
	var strong := Skills.of_role("carry")
	_check(strong.get("carry", 0.0) == 60.0, "strength adds 60 kg at its last level")
	var s := SkillSet.new()
	_check(s.carry_bonus() == 0.0, "no strength, no more weight")
	s.gain("carry", Skills.need(strong, 1))
	_check(s.carry_bonus() == 6.0, "the first level adds 6 kg")
	var who = load("res://src/shared/game/character.gd").new()
	_check(who.inventory.weight_limit == 40.0, "a new character carries 40 kg")
	who.skills.take(s.to_dict(), false)
	_check(who.inventory.weight_limit == 46.0, "a level of strength raises the limit of the bag")
	who.skills.gain("carry", Skills.need(strong, 20))
	_check(who.inventory.weight_limit == 100.0, "the last level carries 100 kg")


## Hardiness adds a cell of health every second level; golden health over the most is
## lost first and runs out; the most cuts health back and a save keeps what is over MAX.
func _test_hardiness() -> void:
	var hard := Skills.of_role("endure")
	var s := SkillSet.new()
	_check(s.health_bonus() == 0.0, "no hardiness, no more health")
	s.gain("endure", Skills.need(hard, 1))
	_check(s.health_bonus() == 0.0, "the first level adds no cell yet")
	s.gain("endure", Skills.need(hard, 2) - Skills.need(hard, 1))
	_check(s.health_bonus() == Vitals.CELL, "the second level adds a cell")
	s.gain("endure", Skills.need(hard, 20))
	_check(s.health_bonus() == 50.0, "the last level five cells")
	var v := Vitals.new()
	v.set_most(Vitals.MAX + s.health_bonus())
	_check(v.most == 150.0 and v.heal(100.0) and v.health == 150.0 and not v.heal(40.0), "it heals up to the higher most, then is not hurt")
	v.wound(30.0, "test")
	_check(is_equal_approx(v.health, 120.0) and v.suffered == 30.0, "a wound counts for hardiness")
	_check(v.fortify(20.0, 60.0) and not v.fortify(10.0, 30.0) and v.extra == 20.0, "golden health tops up, never adds up")
	v.wound(25.0, "test")
	_check(v.extra == 0.0 and is_equal_approx(v.health, 115.0) and v.suffered == 55.0, "a wound takes the gold first")
	v.fortify(10.0, 1.0)
	v.step(1.5, 0.0, false)
	_check(v.extra == 0.0 and v.extra_time == 0.0, "golden health is gone when its time runs out")
	var again := Vitals.new()
	again.from_dict(v.to_dict())
	_check(is_equal_approx(again.health, 115.0), "a save keeps health over MAX until the skills set the most")
	again.set_most(110.0)
	_check(again.health == 110.0, "and a lower most cuts it back")


func _test_levels() -> void:
	_check(Skills.ALL.size() == 12 and Skills.ALL[0].role == "gather" and Lang.t(Skills.of_role("swim").title) == "Swim"
		and Lang.t(Skills.of_role("farm").title) == "Farm" and Lang.t(Skills.of_role("endure").title) == "Hardiness" and Lang.t(Skills.of_role("carry").title) == "Strength",
		"twelve skills in their order, each found by its work")
	var dig := Skills.of_role("dig")
	_check(Skills.level_at(dig, 0.0) == 0 and Skills.level_at(dig, dig.first) == 1
		and Skills.level_at(dig, Skills.need(dig, 10) * 2.0) == dig.levels, "points make levels, no more than the last")
	_check(Skills.need(dig, 2) - Skills.need(dig, 1) > Skills.need(dig, 1), "each level takes more than the one before")
	var s := SkillSet.new()
	var rose: Array = []
	s.leveled.connect(func(id: String, n: int) -> void: rose.append([id, n]))
	_check(s.pace("dig") == 1.0 and s.boost("swim") == 1.0, "no skill: the work takes its time")
	s.gain("dig", Skills.need(dig, 3))
	_check(s.level_of("dig") == 3 and rose == [[dig.id, 3]], "points to the third level raise it and say so")
	_check(is_equal_approx(s.pace("dig"), 1.0 / (1.0 + dig.speed * 0.3)) and s.total() == 3, "a level makes the work faster")
	s.gain("dig", Skills.need(dig, 20))
	_check(is_equal_approx(s.pace("dig"), 1.0 / (1.0 + dig.speed)), "the last level adds the skill's `speed` to the pace")
	var swim := Skills.of_role("swim")
	s.gain("swim", Skills.need(swim, 20))
	_check(s.boost("swim") >= 2.0, "the last level of swimming swims twice as fast at least (×%.2f)" % s.boost("swim"))
	var back := SkillSet.new()
	back.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check(back.level_of("dig") == dig.levels, "the save keeps the points through JSON")
	var copy := SkillSet.new()
	var told: Array = []
	copy.leveled.connect(func(id: String, n: int) -> void: told.append([id, n]))
	copy.take(s.to_dict(), false)
	_check(told.is_empty() and copy.level_of("dig") == dig.levels, "the first points told raise no level")
	var more := s.to_dict()
	var chop := Skills.of_role("chop")
	more.points[chop.id] = Skills.need(chop, 1)
	copy.take(more)
	_check(told == [[chop.id, 1]], "points told later raise the levels they make")


func _test_work() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var who := Survivor.new()
	who.world = w
	who.at = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	who.hands = ["tools:wooden_shovel", ""]
	var done := actions.dig_at(who, Vector3i(10, 1, 10), Vector3i.UP)
	var dug := who.skills.points_of(Skills.of_role("dig").id)
	_check(not done.is_empty() and dug > 0.0 and is_equal_approx(dug, done.swing), "digging the ground teaches digging")
	who.give("resources:dirt", 4)
	who.hands = ["resources:dirt", ""]
	done = actions.place_at(who, Vector3i(10, 1, 10), Vector3i.UP, 40)
	var built := who.skills.points_of(Skills.of_role("build").id)
	_check(not done.is_empty() and w.get_cell(10, 1, 10) == Mat.DIRT and built > 0.0, "a block built teaches building")
	who.hands = ["tools:wooden_shovel", ""]
	_check(not actions.dig_at(who, Vector3i(10, 1, 10), Vector3i.UP).is_empty()
		and who.skills.points_of(Skills.of_role("dig").id) == dug, "digging out a block a player built teaches nothing")
	who.hands = ["resources:dirt", ""]
	actions.place_at(who, Vector3i(10, 1, 10), Vector3i.UP, 40)
	_check(w.get_cell(10, 1, 10) == Mat.DIRT and who.skills.points_of(Skills.of_role("build").id) == built,
		"nor building again where one was dug out")
	who.skills.gain("dig", Skills.need(Skills.of_role("dig"), 10))
	who.hands = ["tools:wooden_shovel", ""]
	var fast := actions.dig_at(who, Vector3i(12, 1, 10), Vector3i.UP)
	_check(not fast.is_empty() and fast.swing < dug * 0.9, "a skilled hand digs faster")


func _test_craft() -> void:
	var r := {}
	for rec: Dictionary in Crafting.RECIPES:
		if rec.at == "" and rec.tools.is_empty() and rec.keeps.is_empty() and rec.time >= 2.0 and rec.process == "craft":
			r = rec
			break
	_check(not r.is_empty(), "a recipe made by hand is found")
	if r.is_empty():
		return
	var who := Survivor.new()
	var placed := Placed.new()
	placed.world = WorldData.new(8, Vector2i(16, 16))
	var shop := Workshop.new(who, placed, Rules.new())
	for id: String in r.needs:
		who.give(id, r.needs[id] * 3)
	_check(shop.start(r, 3) == 3, "three of it are queued")
	shop.update(r.time + 0.01)
	var craft := Skills.of_role("craft")
	var first := who.skills.points_of(craft.id)
	_check(is_equal_approx(first, r.time), "a thing made teaches the craft by its time")
	shop.update(r.time + 0.01)
	_check(who.skills.points_of(craft.id) - first < first, "the same thing made again teaches less")
	who.skills.gain("craft", Skills.need(craft, 10))
	_check(shop.time_of(r) < r.time and shop.queue.jobs.size() == 1, "a skilled hand takes less time")
	shop.update(r.time / (1.0 + craft.speed) + 0.01)
	_check(shop.queue.jobs.is_empty(), "and makes it in that time")
	var skilled := shop.time_of(r)
	who.haste = 4.0
	_check(is_equal_approx(shop.time_of(r) * 4.0, skilled), "the playtest pace of work ×4 makes it four times faster")
	for id: String in r.needs:
		who.give(id, r.needs[id])
	_check(shop.start(r, 1) == 1, "one more is queued")
	shop.update(skilled / 4.0 + 0.01)
	_check(shop.queue.jobs.is_empty(), "and the queue works it in that time")
	who.haste = 1.0
	_check(Workshop.role_of({"process": "cook"}) == "cook" and Workshop.role_of({"process": "smelt"}) == "craft",
		"cooking teaches cooking, the rest the craft")


func _test_land() -> void:
	var t := Territory.new()
	t.rules = Rules.of({"territory_start": 4, "territory_per_level": 2})
	t.teams = Teams.new()
	var who := Numbered.new()
	who.id = 7
	who.skills.gain("chop", Skills.need(Skills.of_role("chop"), 2))
	who.skills.gain("fish", Skills.need(Skills.of_role("fish"), 1))
	t.step(0.0, [who])
	_check(t.budget(7) == 4 + 2 * 3, "each level of the skills adds land")


func _test_yield_quality() -> void:
	var s := SkillSet.new()
	_check(s.extra_chance("gather") == 0.0 and not s.extra("gather")
		and Quality.skill_cap(s.share_of("craft"), s.quality_most("craft")) == Quality.UNSKILLED_MOST,
		"no skill: no more than the work gives, things made no better than plain")
	var craft := Skills.of_role("craft")
	s.gain("craft", Skills.need(craft, craft.levels))
	s.gain("gather", Skills.need(Skills.of_role("gather"), 10))
	_check(Quality.skill_cap(s.share_of("craft"), s.quality_most("craft")) == Quality.MAX
		and is_equal_approx(s.extra_chance("gather"), Skills.of_role("gather").yield),
		"the last level: things made as good as their materials, now and then one more")
	_check(Workshop.yield_role({"process": "cook", "needs": {}}) == "cook"
		and Workshop.yield_role({"process": "craft", "needs": {"animals:carcass": 1}}) == "hunt"
		and Workshop.yield_role({"process": "craft", "needs": {"resources:stone": 1}}) == "",
		"cooking and cutting up a carcass may give one more")
	# A tool made by a skilled hand starts with swings to spare; wearing it spends them first.
	var inv := Inventory.new()
	inv.add("tools:stone_axe", 1, -5)
	var d: int = Items.get_item("tools:stone_axe").durability
	_check(inv.worn(0) == -5, "a tool made by a skilled hand keeps its swings to spare")
	inv.wear_tool("tools:stone_axe", d)
	_check(inv.worn(0) == -4 and inv.count("tools:stone_axe") == 1, "a swing spends one of them")
	var back := Inventory.new()
	back.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(back.worn(0) == -4, "the save keeps them")


class Numbered extends Survivor:
	var id := 0
