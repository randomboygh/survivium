extends "res://tests/unit/test_case.gd"
## The limits the game's balance keeps within (docs/balance/GAME_BALANCE_DESIGN.md, section
## «Автоматические проверки»), read off the data of the mods and the rules' own formulas, so
## a tool, a tree, a beast or a skill written out of proportion fails here before it is played.
## Each limit says why it is where it is. tools/balance_report.gd prints the full tables.

const Skills := preload("res://src/shared/content/skills.gd")
const SkillSet := preload("res://src/shared/game/skill_set.gd")

## The tiers of a class are told apart by their power or, at the same power, by their swing:
## a later tier is never slower, weaker or frailer than an earlier one (section 6: each
## step of progress is felt, none is a side-grade by accident).
const CLASSES := ["axe", "pickaxe", "shovel", "sword", "knife", "spear", "sling", "bow", "scythe", "sickle", "hoe"]
## A tree with the weakest axe takes at most this many swings (about 10 s at no skill: a
## tree is work, not a chore), and the hardest tree with the best axe at least this many (a
## tree is never a tap even for the best gear, section 4.8); no tree falls in one blow of any axe.
const MOST_TREE_HITS := 20
const LEAST_HARDEST_TREE_HITS := 5
## A cell takes at most this many times the tool's swing with the weakest tool that digs it
## (a slow pick is slow, not stuck), and the better pick is faster on the hardest cell it digs.
const MOST_DIG_SLOWDOWN := 4.0
## A big beast (mass from BIG_MASS) takes at least this many blows of the best weapon at no
## skill (a hunt is aimed and chased, not a swat), and bare hands take at most this many on
## any beast (hands can hunt, slowly).
const BIG_MASS := 20.0
const LEAST_BIG_HITS := 3
const MOST_HAND_HITS := 50
## A skill's first level comes within this many seconds of work (the first reward is quick),
## its last within these hours (specializing is a long game, but one that ends inside a
## playthrough: 1–6 hours of the work itself, several times that of play).
const FIRST_LEVEL_WITHIN := 300.0
const LAST_LEVEL_HOURS := Vector2(1.0, 6.0)
## The most a skill multiplies the work's pace, and the most it adds to the tool's blow: a
## skill makes the hand better, it never doubles the tool (section 4: neither side obsoletes
## the other).
const MOST_SPEED := 1.5
const MOST_MIGHT := 1.0
## Sustained work with the best axe at no skill tires the body, but no axe at any level
## empties it within this many seconds; a tree at the last level costs at most this share
## of its stamina at no skill: stamina is felt by the strong and spared by the skilled
## (what counts is the work a full body does, not how long it swings: the skilled swing
## faster, so they tire sooner by the clock and fell more by the tree).
## The best cases count a tool of the best quality (Quality.MAX swings Quality.faster times as
## fast): quality is reachable at the top, so the limits hold for it too.
const LEAST_WORK_SECONDS := 8.0
const SKILLED_TREE_COST := 0.65
## The best weapon kills a player in no fewer blows than this and fists in no fewer than
## this (a fight takes several hits even at the top; fists are a nuisance).
const LEAST_PVP_HITS := 4
const LEAST_FIST_HITS := 20


func run() -> void:
	_test_tiers()
	_test_trees()
	_test_cells()
	_test_beasts()
	_test_skills()
	_test_stamina()
	_test_pvp()
	_test_food()
	_test_rules_agree()


func _of_class(kind: String) -> Array:
	var out: Array = []
	for id in Items.IDS:
		var it := Items.get_item(id)
		if it.get("tool", "none") == kind:
			out.append(it)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.power < b.power or (a.power == b.power and a.swing > b.swing))
	return out


func _at(n: int) -> SkillSet:
	var s := SkillSet.new()
	for sk: Dictionary in Skills.ALL:
		if n > 0:
			s.gain(sk.role, Skills.need(sk, n))
	return s


func _test_tiers() -> void:
	for kind in CLASSES:
		var tiers := _of_class(kind)
		_check(tiers.size() >= 1, "%s: at least one tool of the class" % kind)
		var ok := true
		var distinct := true
		for i in range(1, tiers.size()):
			var a: Dictionary = tiers[i - 1]
			var b: Dictionary = tiers[i]
			if b.power < a.power or b.swing > a.swing + 0.001 or b.durability < a.durability or b.area < a.area:
				ok = false
			if b.power == a.power and is_equal_approx(b.swing, a.swing) and b.area == a.area and b.durability == a.durability:
				distinct = false
		_check(ok, "%s: each tier is at least as strong, as quick, as wide and as lasting as the one before" % kind)
		_check(distinct, "%s: no two tiers are the same tool" % kind)
		for it: Dictionary in tiers:
			_check(it.durability > 0 or it.tool == "can", "%s wears out (durability > 0)" % it.title)


func _test_trees() -> void:
	var axes := _of_class("axe")
	var weakest: Dictionary = axes[0]
	var best: Dictionary = axes[-1]
	var hardest := 0
	var most_hits := 0
	var one_blow := false
	for s: Dictionary in Trees.SPECIES:
		hardest = maxi(hardest, s.hits)
		most_hits = maxi(most_hits, Tools.hits_to(s.hits, weakest.power))
		if s.hits <= best.power:
			one_blow = true
	_check(most_hits <= MOST_TREE_HITS, "the weakest axe fells any tree within %d swings (%d)" % [MOST_TREE_HITS, most_hits])
	_check(not one_blow, "no tree falls in one blow of the best axe (%d)" % best.power)
	_check(Tools.hits_to(hardest, best.power) >= LEAST_HARDEST_TREE_HITS,
		"the hardest tree (%d) takes the best axe %d swings at least (%d)" % [hardest, LEAST_HARDEST_TREE_HITS, Tools.hits_to(hardest, best.power)])
	# Gear and skill each count, and neither makes the other pointless (section 14).
	var oak: Dictionary = Trees.SPECIES[Trees.first(Trees.BROAD)]
	var chop := Skills.of_role("chop")
	var s0 := _at(0)
	var s10 := _at(chop.levels)
	var weak0: float = Tools.hits_to(oak.hits, weakest.power) * weakest.swing * s0.pace("chop")
	var weak10: float = Tools.hits_to(oak.hits, weakest.power) * weakest.swing * s10.pace("chop")
	var best0: float = Tools.hits_to(oak.hits, best.power) * best.swing * s0.pace("chop")
	var best10: float = Tools.hits_to(oak.hits, best.power) * best.swing * s10.pace("chop")
	_check(weak10 <= weak0 * 0.6, "the last level of chopping cuts the time with the weakest axe by 40%% at least (%.1f -> %.1f s)" % [weak0, weak10])
	_check(best10 <= best0 * 0.6, "and with the best axe too (%.1f -> %.1f s)" % [best0, best10])
	_check(best0 < weak10, "the best axe at no skill still beats the weakest at the last level (%.1f < %.1f s)" % [best0, weak10])
	# The top of both roads: four swings and the fall, not a tap (the fall itself takes a moment).
	var top: float = best10 / Quality.faster(Quality.MAX)
	_check(top >= 0.5 and Tools.hits_to(oak.hits, best.power) >= 3, "the best axe of the best quality at the last level still takes over half a second and three swings on an oak (%.2f s)" % top)
	for i in range(1, axes.size()):
		_check(Tools.hits_to(hardest, axes[i].power) <= Tools.hits_to(hardest, axes[i - 1].power),
			"%s fells the hardest tree in no more swings than %s" % [axes[i].title, axes[i - 1].title])


func _test_cells() -> void:
	for kind in ["pickaxe", "shovel"]:
		var tools := _of_class(kind)
		for m in Mat.COUNT:
			var rec: Dictionary = Mat.RECORDS[m]
			if rec.dig != kind:
				continue
			var first := {}
			for t: Dictionary in tools:
				if Tools.can_dig(t, m):
					first = t
					break
			_check(not first.is_empty(), "%s is dug by some %s" % [rec.title, kind])
			if first.is_empty():
				continue
			_check(Tools.swing_time(first, m) <= first.swing * MOST_DIG_SLOWDOWN + 0.001,
				"%s with %s takes at most %.0f swings' time (%.2f of %.2f s)" % [rec.title, first.title, MOST_DIG_SLOWDOWN, Tools.swing_time(first, m), first.swing])
		var hardest := -1
		for m in Mat.COUNT:
			if Mat.RECORDS[m].dig == kind and Tools.can_dig(tools[-1], m) and (hardest < 0 or Tools.toughness(m) > Tools.toughness(hardest)):
				hardest = m
		var faster := true
		for i in range(1, tools.size()):
			if Tools.can_dig(tools[i - 1], hardest) and Tools.swing_time(tools[i], hardest) >= Tools.swing_time(tools[i - 1], hardest) - 0.001:
				faster = false
		_check(faster, "%s: each tier digs the hardest cell (%s) faster than the one before" % [kind, Mat.NAMES[hardest]])
	# Bare hands: slow in soft ground, and no faster than a shovel.
	var shovel: Dictionary = _of_class("shovel")[0]
	_check(Tools.swing_time(Tools.HAND, Mat.DIRT) > Tools.swing_time(shovel, Mat.DIRT) * 1.5, "hands dig dirt far slower than a wooden shovel")


func _test_beasts() -> void:
	var weapons: Array = []
	for kind in ["sword", "knife", "spear", "sling", "bow"]:
		weapons.append_array(_of_class(kind))
	var best := 0
	for w: Dictionary in weapons:
		best = maxi(best, w.power)
	var s0 := _at(0)
	var s10 := _at(Skills.of_role("hunt").levels)
	for kind in AiRules.SPECIES:
		var a: Dictionary = AiRules.SPECIES[kind]
		if a.health <= 0:
			continue
		if a.mass >= BIG_MASS:
			_check(Tools.hits_to(a.health, s0.blow("hunt", best)) >= LEAST_BIG_HITS,
				"%s (health %d) takes the best weapon (%d) %d blows at least" % [a.title, a.health, best, LEAST_BIG_HITS])
			_check(Tools.hits_to(a.health, s10.blow("hunt", best)) >= 2, "%s takes a skilled best weapon two blows at least" % a.title)
		_check(Tools.hits_to(a.health, s0.blow("hunt", Tools.HAND.power)) <= MOST_HAND_HITS, "%s can be hunted with bare hands" % a.title)
		_check(a.carcass == "" or Items.has(a.carcass), "%s leaves a carcass that is an item" % a.title)
	_check(s10.blow("hunt", 2) > 2 and s10.blow("hunt", 2) <= 4, "the last level of hunting adds to a weak blow but does not double it (%d)" % s10.blow("hunt", 2))


func _test_skills() -> void:
	for sk: Dictionary in Skills.ALL:
		_check(Skills.need(sk, 1) <= FIRST_LEVEL_WITHIN, "%s: the first level within %.0f s of work (%.0f)" % [sk.title, FIRST_LEVEL_WITHIN, Skills.need(sk, 1)])
		var hours := Skills.need(sk, sk.levels) / 3600.0
		_check(hours >= LAST_LEVEL_HOURS.x and hours <= LAST_LEVEL_HOURS.y, "%s: the last level within %.0f–%.0f hours of work (%.1f)" % [sk.title, LAST_LEVEL_HOURS.x, LAST_LEVEL_HOURS.y, hours])
		_check(sk.speed <= MOST_SPEED and sk.might <= MOST_MIGHT and sk.yield <= 1.0 and sk.effort <= 0.9 and sk.care <= 0.9,
			"%s: no effect past its bound (speed %.1f, might %.1f)" % [sk.title, sk.speed, sk.might])
		_check(sk.speed > 0.0 or sk.yield > 0.0 or sk.might > 0.0 or sk.quality > 0.0, "%s does something" % sk.title)
		for n in range(1, sk.levels):
			_check(Skills.need(sk, n + 1) - Skills.need(sk, n) > Skills.need(sk, n) - Skills.need(sk, n - 1), "%s: level %d costs more than level %d" % [sk.title, n + 1, n])
	var s0 := _at(0)
	var s5 := _at(5)
	var s10 := _at(10)
	for role in ["chop", "dig", "gather", "craft", "build", "hunt", "farm"]:
		_check(s0.blow(role, 5) == 5 and s0.effort(role) == 1.0 and s0.pace(role) == 1.0 and s0.extra_chance(role) == 0.0, "%s: no skill changes nothing" % role)
		_check(s5.pace(role) < s0.pace(role) and s10.pace(role) < s5.pace(role) or Skills.of_role(role).speed == 0.0, "%s: each level makes the work faster" % role)
		if role != "hunt":
			_check(s10.blow(role, 5) == 5, "%s: the skill adds nothing to the tool's blow" % role)
	_check(s10.blow("hunt", 6) > 6, "hunting adds to the blow")


func _test_stamina() -> void:
	var axes := _of_class("axe")
	var chop := Skills.of_role("chop")
	var s0 := _at(0)
	var s10 := _at(chop.levels)
	var rest := Vitals.REST * Vitals.WORK_REST
	var best: Dictionary = axes[-1]
	var drain_best: float = Vitals.cost_of("chop", s0.effort("chop")) / (best.swing * s0.pace("chop")) - rest
	_check(drain_best > 0.0, "sustained chopping with the best axe tires an unskilled body (%.1f a second)" % drain_best)
	_check(drain_best <= 0.0 or Vitals.MAX / drain_best >= LEAST_WORK_SECONDS, "but not within %.0f s (%.0f s)" % [LEAST_WORK_SECONDS, Vitals.MAX / maxf(0.01, drain_best)])
	var top := Quality.faster(Quality.MAX)
	for a: Dictionary in axes:
		var drain: float = Vitals.cost_of("chop", s10.effort("chop")) / (a.swing * s10.pace("chop") / top) - rest
		_check(drain <= 0.0 or Vitals.MAX / drain >= LEAST_WORK_SECONDS, "%s of the best quality at the last level does not empty the body within %.0f s (%.1f)" % [a.title, LEAST_WORK_SECONDS, Vitals.MAX / maxf(0.01, drain)])
	var oak: Dictionary = Trees.SPECIES[Trees.first(Trees.BROAD)]
	var weakest: Dictionary = axes[0]
	var tree0 := Tools.hits_to(oak.hits, weakest.power) * Vitals.cost_of("chop", s0.effort("chop"))
	var tree10 := Tools.hits_to(oak.hits, weakest.power) * Vitals.cost_of("chop", s10.effort("chop"))
	_check(tree10 <= tree0 * SKILLED_TREE_COST, "an oak costs the skilled at most %.0f%% of the stamina it costs the unskilled (%.0f of %.0f)" % [SKILLED_TREE_COST * 100.0, tree10, tree0])
	_check(Tools.hits_to(oak.hits, best.power) * Vitals.cost_of("chop", 1.0) < tree0 * 0.5, "and the best axe at least halves it too")
	for action in Vitals.COSTS:
		_check(Vitals.COSTS[action] <= Vitals.MAX / 10.0, "%s costs no more than a tenth of the stamina" % action)
	_check(Vitals.cost_of("chop", s10.effort("chop")) < Vitals.cost_of("chop", 1.0), "the skilled pay less a swing")
	# A busy body rests slower: the formula the tables use is the one Vitals runs.
	var v := Vitals.new()
	v.stamina = 50.0
	v.step(1.0, 0.0, false)
	var idle := v.stamina
	v.stamina = 50.0
	v.spend("chop")
	v.step(1.0, 0.0, false)
	_check(is_equal_approx(idle, 50.0 + Vitals.REST) and is_equal_approx(v.stamina, 50.0 - Vitals.COSTS.chop + Vitals.REST * Vitals.WORK_REST),
		"idle a body rests at REST, busy at WORK_REST of it")
	v.spend("swing")
	var busy_before := v.busy
	_check(busy_before == 0.0, "a swing at the air (under WORK_COST) does not keep the body busy")


func _test_pvp() -> void:
	var rules := Rules.new()
	var best := 0
	for kind in ["sword", "knife", "spear", "sling", "bow"]:
		for w: Dictionary in _of_class(kind):
			best = maxi(best, w.power)
	_check(ceili(Vitals.MAX / (best * rules.pvp_damage)) >= LEAST_PVP_HITS, "the best weapon takes %d blows at least to kill a player" % LEAST_PVP_HITS)
	_check(ceili(Vitals.MAX / (maxi(1, Tools.HAND.power) * rules.pvp_damage)) >= LEAST_FIST_HITS, "fists take %d blows at least" % LEAST_FIST_HITS)


func _test_food() -> void:
	var raw := 0.0
	var cooked := 0.0
	for id in Items.IDS:
		var it := Items.get_item(id)
		if it.food <= 0.0:
			continue
		_check(it.food <= Vitals.HUNGER_PER_DAY, "%s feeds less than a day's hunger in one piece" % it.title)
		for r: Dictionary in Crafting.RECIPES:
			if r.makes == id and r.process == "cook":
				cooked = maxf(cooked, it.food)
				for need: String in r.needs:
					raw = maxf(raw, Items.get_item(need).food)
	_check(cooked > raw * 2.0, "cooking is worth it: the best cooked food feeds over twice the best raw one (%.0f vs %.0f)" % [cooked, raw])


## The rules do what the tables say: a chop lands the swings Tools.hits_to counts, a dig
## takes Tools.swing_time, a skilled blow is SkillSet.blow (one source of the numbers,
## section 3 of the task).
func _test_rules_agree() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	w.set_cell(10, 1, 10, Mat.STONE)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var who := Survivor.new()
	who.world = w
	who.at = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	who.vitals.fatigue = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var oak := Trees.first(Trees.BROAD)
	Growth.place(w, 15, 2, 23, oak, rng)
	who.at = Vector3(13.5, 2.0, 23.5) * WorldData.CELL
	var axes := _of_class("axe")
	who.hands = [axes[-1].id, ""]
	var logs := w.log_col(15, 23)
	var hits := 0
	while w.log_col(15, 23) == logs and hits < 50:
		actions.chop(who, actions.trunk_cell(who, Vector2i(15, 23)))
		hits += 1
	_check(hits == Tools.hits_to(Trees.SPECIES[oak].hits, axes[-1].power), "the best axe fells an oak in the swings the table counts (%d)" % hits)
	who.at = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	var picks := _of_class("pickaxe")
	who.hands = [picks[0].id, ""]
	var dug := actions.dig_at(who, Vector3i(10, 1, 10), Vector3i.UP)
	_check(not dug.is_empty() and is_equal_approx(dug.swing, Tools.swing_time(picks[0], Mat.STONE)),
		"a pick's swing at stone takes the time the table gives (%.2f)" % dug.get("swing", 0.0))
	who.skills.gain("hunt", Skills.need(Skills.of_role("hunt"), 10))
	_check(actions._blow(who, "hunt", 4) == who.skills.blow("hunt", 4) and actions._blow(who, "chop", 4) == 4,
		"the rules' blow is the skill set's")
