extends RefCounted
## The quality of things (plan/design/crafting.md «Качество», decision 181): a number
## MIN..MAX on each stack of the bag (Inventory.quality), NORMAL for what nothing has said
## otherwise of (and what older saves had). What the hands get from the world is as good
## as the tool and the skill of the work make it (`gathered`); what is made is the
## quality of its materials together, no better than the skill of the work, the station
## and the recipe allow (`made`). It makes a tool last longer and swing faster, clothes
## warmer, food more filling (`lasts`, `faster`); 50 is what a thing was before quality.

const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")

const NORMAL := Items.NORMAL_QUALITY
const MIN := 1
const MAX := 100
## The works whose skill makes what they get from the world better, and those whose
## skill lets what they make be better.
const GETS := ["gather", "chop", "dig", "hunt", "fish", "farm"]
const MAKES := ["craft", "cook"]
## What the hands get with no tool and no skill.
const BASE := 35
## Quality a point of a tool's power adds to what it gets, up to TOOL_MOST.
const PER_POWER := 5
const TOOL_MOST := 30
## A tool's own quality adds its distance from NORMAL divided by this.
const TOOL_SHARE := 5
## What one thing gotten may lie off the rest, up or down.
const SPREAD := 5
## The most a thing made with no skill can be; the skill's `quality` adds to it.
const UNSKILLED_MOST := 50
## A seed's crop lies this far off the seed, up or down (ActionsFarm.crop_quality), and
## the farmer's skill adds up to FARM_NUDGE at its last level.
const CROP_SPREAD := 8
const FARM_NUDGE := 4.0
## Quality at MAX adds this share to what lasts (durability, warmth, food), at MIN takes
## as much off (linear through NORMAL: 10 is about 60%).
const LASTS_PER_POINT := 0.01
## And this share to the pace of a tool's swing.
const PACE_PER_POINT := 0.004


## The quality of what work `role` gets with tool `t` (Tools.of) of quality `tool_q`, at
## skill share `share` (0..1, SkillSet.share_of) whose skill adds `skill_most` at the last
## level; `roll` (-1..1) puts it off by up to SPREAD.
static func gathered(t: Dictionary, tool_q: int, share: float, skill_most: float, roll := 0.0) -> int:
	var tool_part := mini(TOOL_MOST, PER_POWER * int(t.get("power", 1)))
	var q := BASE + tool_part + (tool_q - NORMAL) / TOOL_SHARE + skill_most * share + SPREAD * roll
	return clampi(roundi(q), MIN, MAX)


## The quality of what `who` gets from the world by work `role` with the tool in hand.
static func by_hand_of(who, role: String) -> int:
	var id: String = who.held() if who.has_method("held") else ""
	var t: Dictionary = Tools.of(id)
	var tool_q: int = who.inventory.tool_quality(id) if id != "" else NORMAL
	var sk = who.get("skills")
	var share: float = 0.0 if sk == null else sk.share_of(role)
	var most: float = 0.0 if sk == null else sk.quality_most(role)
	return gathered(t, tool_q, share, most, randf_range(-1.0, 1.0))


## The most a thing can be when made at skill share `share` of a skill that adds
## `skill_most` at its last level.
static func skill_cap(share: float, skill_most: float) -> int:
	return clampi(roundi(UNSKILLED_MOST + skill_most * share), MIN, MAX)


## The quality of the materials `took` ([id, count, worn, quality] stacks, see
## Inventory.remove) together, by count; NORMAL for none.
static func of_materials(took: Array) -> int:
	var n := 0
	var sum := 0
	for s: Array in took:
		var k: int = s[1]
		n += k
		sum += k * (int(s[3]) if s.size() > 3 else NORMAL)
	return NORMAL if n == 0 else roundi(float(sum) / n)


## The quality of what recipe `r` makes of materials `took`: theirs, but no better than
## `cap` (the skill's and the station's, Workshop.quality_cap) and the recipe's
## `quality_cap`.
static func made(r: Dictionary, took: Array, cap: int) -> int:
	var q := mini(of_materials(took), cap)
	q = mini(q, int(r.get("quality_cap", MAX)))
	return clampi(q, MIN, MAX)


## What a thing of quality `q` lasts, warms or fills, as a share of its normal (1 at NORMAL).
static func lasts(q: int) -> float:
	return 1.0 + (clampi(q, MIN, MAX) - NORMAL) * LASTS_PER_POINT


## How many times as fast a tool of quality `q` swings (1 at NORMAL).
static func faster(q: int) -> float:
	return 1.0 + (clampi(q, MIN, MAX) - NORMAL) * PACE_PER_POINT


## Tool record `t` (Tools.of) of a tool of quality `q`: its swing shorter or longer.
static func tool_record(t: Dictionary, q: int) -> Dictionary:
	if q == NORMAL or not t.has("swing"):
		return t
	var out := t.duplicate()
	out.swing = float(t.swing) / faster(q)
	return out


## The swings a tool of `durability` and quality `q` lasts.
static func durability(durability: int, q: int) -> int:
	return maxi(1, roundi(durability * lasts(q))) if durability > 0 else 0


## The quality of a crop grown from a seed of quality `seed_q`, `roll` -1..1 off it.
static func crop(seed_q: int, roll: float) -> int:
	return clampi(roundi(seed_q + CROP_SPREAD * roll), MIN, MAX)


## The grades of quality, by the least quality past each (the UI's word and the colour of
## the dot on a slot): poor, plain, normal, good, excellent.
const GRADES := [[25, "плохое"], [45, "простое"], [60, "обычное"], [80, "хорошее"], [101, "отличное"]]


static func grade(q: int) -> int:
	for i in GRADES.size():
		if q < GRADES[i][0]:
			return i
	return GRADES.size() - 1


static func grade_name(q: int) -> String:
	return GRADES[grade(q)][1]
